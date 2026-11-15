package replay_p2p

import r "godot:replay"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

watch_init :: proc(
    w: ^Watch($S, $I, $E, $N),
    initial: r.Frame(S),
    model: Model(S, I, E, N),
    roster: [N]tr.Peer_Id,
    source: tr.Peer_Id,
    wire: tr.Transport,
    binding: u64,
    cfg := DEFAULT_CONFIG,
    transfer_cfg := rec.DEFAULT_CONFIG,
    allocator := context.allocator,
) -> Error {
    if w.ready {
        return .Not_Ready
    }

    w.allocator = allocator
    committed := false

    defer if !committed {
        watch_destroy(w)
    }

    if err := init(&w.states[0], initial, model, roster, 0, {}, cfg, allocator); err != .None {
        return err
    }

    w.contract, w.initial_tick, w.initial_hash = w.states[0].contract, initial.tick, w.states[0].initial_hash

    if !watch_codecs_init(&w.codecs, S, I, E, N, allocator) {
        return .Schema
    }

    accept := proc(user: rawptr, archive: rec.Archive, bytes: []u8) -> bool {
        w := cast(^Watch(S, I, E, N))user

        if w.error == .Replay_Mismatch || w.error == .Diverged {
            return false
        }

        w.error = watch_install(w, bytes)
        return w.error == .None
    }

    if rec.blob_init(
           &w.transfer,
           {cfg.session, cfg.epoch, binding, cfg.content},
           source,
           wire,
           WATCH_KIND,
           accept,
           w,
           transfer_cfg,
           allocator,
       ) !=
       .None {
        return .Invalid_Config
    }

    w.rxb = make([]u8, tr.MAX_PACKET_BYTES, allocator)
    w.ready, committed = true, true
    return .None
}

watch_destroy :: proc(w: ^Watch($S, $I, $E, $N)) {
    for &state in w.states {
        destroy(&state)
    }

    rec.blob_destroy(&w.transfer)
    watch_codecs_destroy(&w.codecs)
    delete(w.rxb, w.allocator)
    w^ = {}
}

watch_current :: proc(w: ^Watch($S, $I, $E, $N)) -> (r.Frame(S), bool) {
    if !w.ready || !w.has_world {
        return {}, false
    }

    return r.current(&w.states[w.active].timeline)
}

// Read-only borrow for event journals/interpolation; invalid after the next pump.
watch_timeline :: proc(w: ^Watch($S, $I, $E, $N)) -> ^r.Timeline(S, [N]I, E) {
    return w.ready && w.has_world ? &w.states[w.active].timeline : nil
}

watch_pump :: proc(w: ^Watch($S, $I, $E, $N), now_ms: u64) -> Error {
    if !w.ready {
        return .Not_Ready
    }

    tr.poll(&w.transfer.wire)

    for _ in 0 ..< 64 {
        packet := tr.receive(&w.transfer.wire, w.rxb)

        if packet.state == .Empty {
            break
        }

        if packet.state != .Received {
            continue
        }

        rec.blob_receive(&w.transfer, packet.from, w.rxb[:packet.count], now_ms)
    }

    if err := rec.blob_update(&w.transfer, now_ms); err == .Invalid_Time {
        return .Time
    } else if err == .Transport {
        return .Transport
    }

    return w.error
}

@(private)
watch_install :: proc(w: ^Watch($S, $I, $E, $N), bytes: []u8) -> Error {
    w.report = {}

    if len(bytes) > MAX_WATCH_BYTES {
        return .Invalid_Archive
    }

    old := &w.states[w.active]
    meta, body, envelope := sc.unpack_bytes(
        w.codecs.fingerprint,
        bytes,
        {kind = WATCH_KIND, epoch = old.cfg.epoch, content = old.cfg.content},
    )

    if envelope.error != .None {
        return .Invalid_Archive
    }

    cursor := Archive_Cursor {
        bytes = body,
    }
    h: Watch_Header
    archive_get(&cursor, &w.codecs.header, &h)
    size, fits := watch_size(&w.codecs, h)

    if cursor.failed ||
       !fits ||
       size != len(bytes) ||
       h.version != WATCH_VERSION ||
       h.contract != w.contract ||
       h.initial_tick != w.initial_tick ||
       h.initial_hash != w.initial_hash ||
       h.base_tick < w.initial_tick ||
       h.head != meta.tick ||
       h.head < h.base_tick ||
       h.head > max(u64) - u64(old.cfg.history) ||
       h.head - h.base_tick >= u64(old.cfg.history) ||
       u64(h.ticks) != h.head - h.base_tick ||
       h.events > u32(old.cfg.events_per_tick) {
        return .Invalid_Archive
    }

    if w.has_world && h.head < old.timeline.head {
        return .History
    }

    // A replacement broadcaster must prove overlap with the retained world.
    // Ordinary later delivery may still report an explicit history-gap reset.
    if w.rebind_pending && h.base_tick > old.timeline.head {
        return .History
    }

    base: r.Frame(S)
    archive_get(&cursor, &w.codecs.frame, &base)

    if cursor.failed || base.tick != h.base_tick || !old.model.state_valid(base.state) {
        return .Invalid_Archive
    }

    stage := &w.states[1 - w.active]
    destroy(stage)
    committed := false

    defer if !committed {
        destroy(stage)
    }

    if err := init(stage, base, old.model, old.roster, 0, {}, old.cfg, w.allocator); err != .None {
        return err
    }

    for &event in stage.event_scratch[:h.events] {
        archive_get(&cursor, &w.codecs.event, &event)
    }

    if cursor.failed || r.seed_checkpoint_events(&stage.timeline, stage.event_scratch[:h.events]) != .None {
        return .Invalid_Archive
    }

    digest, ok := frame_digest(stage, base.tick, 0xcbf29ce484222325)

    if !ok ||
       digest != h.base_digest ||
       (base.tick == w.initial_tick && (digest != w.initial_hash || h.base_chain != digest)) {
        return .Invalid_Archive
    }

    for &hash in stage.hashes {
        hash = {}
    }

    stage.chain = h.base_chain
    stage.hashes[base.tick % u64(stage.cfg.history)] = {base.tick, h.base_chain, true}

    if w.has_world && base.tick == old.timeline.head {
        if h.base_chain != old.chain {
            w.report = {.Diverged, base.tick, old.chain, h.base_chain}
            return .Diverged
        }

        previous, valid := frame_digest(old, old.timeline.head, 0xcbf29ce484222325)

        if !valid {
            return .History
        }

        if digest != previous {
            w.report = {.Diverged, base.tick, previous, digest}
            return .Diverged
        }
    }

    for tick := base.tick + 1; tick <= h.head; tick += 1 {
        input: Watch_Tick(I, N)
        archive_get(&cursor, &w.codecs.tick, &input)

        if cursor.failed {
            return .Invalid_Archive
        }

        for value in input.inputs {
            if !old.model.input_valid(value) {
                return .Invalid_Archive
            }
        }

        if r.advance(&stage.timeline, input.inputs).error != .None ||
           !hash_frame(stage, tick) ||
           stage.chain != input.chain {
            w.report = {.Replay_Mismatch, tick, input.chain, stage.chain}
            return .Replay_Mismatch
        }

        if w.has_world && tick == old.timeline.head && stage.chain != old.chain {
            w.report = {.Diverged, tick, old.chain, stage.chain}
            return .Diverged
        }
    }

    if cursor.failed ||
       cursor.at != len(body) ||
       stage.chain != h.chain ||
       r.confirm_through(&stage.timeline, h.head) != .None {
        return .Invalid_Archive
    }

    if !w.has_world || base.tick > old.timeline.head {
        w.stats.resets += 1
        w.reset = {w.stats.resets, old.timeline.head, base.tick}
        w.stats.skipped_ticks += base.tick - old.timeline.head
    }

    stage.initial_tick, stage.initial_hash, stage.contract, stage.hash_tick =
        w.initial_tick, w.initial_hash, w.contract, h.head
    w.stats.installed += 1
    w.stats.replayed += u64(h.ticks)
    w.stats.bytes += u64(len(bytes))
    w.active, w.has_world, committed = 1 - w.active, true, true
    w.rebind_pending = false
    destroy(old)
    return .None
}

watch_source_init :: proc(
    s: ^Watch_Source($S, $I, $E, $N),
    peer: ^Runner(S, I, E, N),
    target: tr.Peer_Id,
    wire: tr.Transport,
    binding: u64,
    transfer_cfg := rec.DEFAULT_CONFIG,
    interval_ms: u64 = 50,
    allocator := context.allocator,
    resume: ^Watch_Anchor = nil,
) -> Error {
    if s.ready || peer == nil || !peer.ready || interval_ms < 1 || interval_ms > 10000 {
        return .Invalid_Config
    }

    if resume != nil {
        if err := watch_source_anchor(peer, resume^); err != .None {
            return err
        }
    }

    s.allocator, s.peer, s.interval_ms = allocator, peer, interval_ms
    committed := false

    defer if !committed {
        watch_source_destroy(s)
    }

    if !watch_codecs_init(&s.codecs, S, I, E, N, allocator) {
        return .Schema
    }

    if rec.sender_init(
           &s.transfer,
           {peer.cfg.session, peer.cfg.epoch, binding, peer.cfg.content},
           target,
           wire,
           transfer_cfg,
           allocator,
           WATCH_KIND,
       ) !=
       .None {
        return .Invalid_Config
    }

    s.rxb = make([]u8, tr.MAX_PACKET_BYTES, allocator)

    if resume != nil {
        s.resume_anchor, s.resume_pending = resume^, true
    }

    s.ready, committed = true, true
    return .None
}

watch_source_destroy :: proc(s: ^Watch_Source($S, $I, $E, $N)) {
    rec.sender_destroy(&s.transfer)
    watch_codecs_destroy(&s.codecs)
    delete(s.rxb, s.allocator)
    s^ = {}
}

watch_source_pump :: proc(s: ^Watch_Source($S, $I, $E, $N), now_ms: u64) -> Error {
    if !s.ready || !s.peer.ready {
        return .Not_Ready
    }

    tr.poll(&s.transfer.wire)

    for _ in 0 ..< 64 {
        packet := tr.receive(&s.transfer.wire, s.rxb)

        if packet.state == .Empty {
            break
        }

        if packet.state != .Received {
            continue
        }

        rec.sender_receive(&s.transfer, packet.from, s.rxb[:packet.count], now_ms)
    }

    if err := rec.sender_update(&s.transfer, now_ms); err == .Invalid_Time {
        return .Time
    } else if err == .Transport {
        return .Transport
    }

    if s.transfer.phase == .Failed {
        if s.transfer.remote_failure == .Archive || s.transfer.remote_failure == .Integrity {
            return .Invalid_Archive
        }

        if s.transfer.remote_failure == .Retention {
            return .History
        }

        rec.sender_cancel(&s.transfer)
    }

    if s.transfer.phase == .Sending || s.peer.phase != .Running || now_ms < s.next_at {
        return .None
    }

    ack := s.transfer.acknowledged.archive

    if ack.sequence != 0 {
        s.resume_pending = false
    }

    if ack.sequence != 0 && ack.tick >= s.peer.timeline.confirmed {
        return .None
    }

    from := ack.sequence == 0 ? s.peer.timeline.confirmed : ack.tick

    if s.resume_pending {
        if err := watch_source_anchor(s.peer, s.resume_anchor); err != .None {
            return err
        }

        from = s.resume_anchor.tick
    }

    bytes, err := watch_encode(s.peer, from, &s.codecs, s.allocator)
    defer delete(bytes, s.allocator)

    if err != .None {
        return err
    }

    if rec.sender_begin(&s.transfer, bytes, now_ms) != .None {
        return .Invalid_Archive
    }

    s.publications += 1
    s.next_at = min(now_ms, max(u64) - s.interval_ms) + s.interval_ms
    return .None
}
