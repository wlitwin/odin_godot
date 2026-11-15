package replay_p2p

import "core:mem"
import r "godot:replay"
import sc "godot:replay/schema"

@(private)
watch_codecs_init :: proc(c: ^Watch_Codecs, $S, $I, $E: typeid, $N: int, allocator: mem.Allocator) -> bool {
    if sc.init(&c.header, Watch_Header, allocator = allocator).error != .None ||
       sc.init(&c.frame, r.Frame(S), allocator = allocator).error != .None ||
       sc.init(&c.event, r.Occurrence(E), allocator = allocator).error != .None ||
       sc.init(&c.tick, Watch_Tick(I, N), allocator = allocator).error != .None {
        return false
    }

    c.fingerprint = mix(
        mix(mix(mix(u64(WATCH_VERSION), c.header.fingerprint), c.frame.fingerprint), c.event.fingerprint),
        c.tick.fingerprint,
    )
    return true
}

@(private)
watch_codecs_destroy :: proc(c: ^Watch_Codecs) {
    sc.destroy(&c.header)
    sc.destroy(&c.frame)
    sc.destroy(&c.event)
    sc.destroy(&c.tick)
    c^ = {}
}

@(private)
watch_size :: proc(c: ^Watch_Codecs, h: Watch_Header) -> (int, bool) {
    size :=
        u64(sc.HEADER_BYTES) +
        u64(c.header.wire_size) +
        u64(c.frame.wire_size) +
        u64(h.events) * u64(c.event.wire_size) +
        u64(h.ticks) * u64(c.tick.wire_size)
    return size <= MAX_WATCH_BYTES ? int(size) : 0, size <= MAX_WATCH_BYTES
}

// Includes confirmed values only. Missing old history chooses a current confirmed
// baseline, which the consumer exposes as an explicit presentation discontinuity.
@(private)
watch_encode :: proc(
    p: ^Runner($S, $I, $E, $N),
    from: u64,
    c: ^Watch_Codecs,
    allocator: mem.Allocator,
) -> (
    []u8,
    Error,
) {
    if !p.ready || p.phase != .Running || p.dirty != 0 || from > p.timeline.confirmed {
        return nil, .Not_Ready
    }

    base, found := r.read(&p.timeline, from)

    if !found {
        base, found = r.read(&p.timeline, p.timeline.confirmed)
    }

    if !found {
        return nil, .History
    }

    base_hash := p.hashes[base.tick % u64(p.cfg.history)]

    if !base_hash.valid || base_hash.tick != base.tick {
        return nil, .History
    }

    base_digest, hashed := frame_digest(p, base.tick, 0xcbf29ce484222325)

    if !hashed {
        return nil, .History
    }

    n, err := r.copy_events(&p.timeline, base.tick, p.event_scratch)

    if err != .None {
        return nil, .History
    }

    h := Watch_Header {
        WATCH_VERSION,
        p.contract,
        p.initial_tick,
        p.initial_hash,
        base.tick,
        p.timeline.confirmed,
        base_hash.value,
        base_digest,
        p.chain,
        u32(n),
        u32(p.timeline.confirmed - base.tick),
    }
    size, fits := watch_size(c, h)

    if !fits {
        return nil, .Capacity
    }

    bytes := make([]u8, size, allocator)
    committed := false

    defer if !committed {
        delete(bytes, allocator)
    }

    w := Archive_Cursor {
        bytes = bytes[sc.HEADER_BYTES:],
    }
    archive_put(&w, &c.header, h)
    archive_put(&w, &c.frame, base)

    for event in p.event_scratch[:n] {
        archive_put(&w, &c.event, event)
    }

    for tick := base.tick + 1; tick <= p.timeline.confirmed; tick += 1 {
        inputs, known := r.read_input(&p.timeline, tick)
        hash := p.hashes[tick % u64(p.cfg.history)]

        if !known || !hash.valid || hash.tick != tick {
            return nil, .History
        }

        archive_put(&w, &c.tick, Watch_Tick(I, N){inputs, hash.value})
    }

    if w.failed ||
       w.at != size - sc.HEADER_BYTES ||
       sc.pack_bytes(c.fingerprint, {kind = WATCH_KIND, epoch = p.cfg.epoch, tick = h.head, content = p.cfg.content}, bytes[sc.HEADER_BYTES:], bytes).error !=
           .None {
        return nil, .Invalid_Archive
    }

    committed = true
    return bytes, .None
}
