package replay_p2p

import rec "godot:replay/recovery"
import tr "godot:replay/transport"

watch_anchor :: proc(w: ^Watch($S, $I, $E, $N)) -> (Watch_Anchor, Error) {
    if !w.ready || !w.has_world || w.states[w.active].timeline.busy {
        return {}, .Not_Ready
    }

    peer := &w.states[w.active]
    digest, ok := frame_digest(peer, peer.timeline.head, 0xcbf29ce484222325)

    if !ok {
        return {}, .History
    }

    return {peer.cfg.session, peer.cfg.epoch, peer.cfg.content, w.contract, peer.timeline.head, peer.chain, digest},
        .None
}

// The admission provider verifies the replacement source and fences old traffic.
// Binding is a strictly increasing spectator-stream generation. Transports are
// borrowed; this operation neither authenticates nor closes them.
watch_rebind :: proc(
    w: ^Watch($S, $I, $E, $N),
    source: tr.Peer_Id,
    wire: tr.Transport,
    binding, now_ms: u64,
) -> (
    Watch_Anchor,
    Error,
) {
    if !w.ready ||
       !w.has_world ||
       w.states[0].timeline.busy ||
       w.states[1].timeline.busy ||
       w.error == .Diverged ||
       w.error == .Replay_Mismatch {
        return {}, .Not_Ready
    }

    if w.transfer.clock.set && now_ms < w.transfer.clock.now {
        return {}, .Time
    }

    if binding <= w.transfer.scope.binding {
        return {}, .Invalid_Config
    }

    if wire.send == nil || wire.receive == nil || wire.status == nil {
        return {}, .Transport
    }

    anchor, error := watch_anchor(w)

    if error != .None {
        return {}, error
    }

    next: rec.Blob_Receiver
    scope := w.transfer.scope
    scope.binding = binding

    if rec.blob_init(&next, scope, source, wire, WATCH_KIND, w.transfer.accept, w, w.transfer.cfg, w.allocator) !=
       .None {
        return {}, .Invalid_Config
    }

    next.clock = {
        set    = true,
        now    = now_ms,
        budget = f64(next.cfg.bytes_per_update),
    }
    rec.blob_destroy(&w.transfer)
    w.transfer = next
    w.error, w.report = .None, {}
    w.rebind_pending = true
    w.stats.rebinds += 1
    return anchor, .None
}

@(private)
watch_source_anchor :: proc(peer: ^Runner($S, $I, $E, $N), anchor: Watch_Anchor) -> Error {
    if !peer.ready || peer.timeline.busy || peer.dirty != 0 || peer.phase != .Running {
        return .Not_Ready
    }

    if anchor.session != peer.cfg.session ||
       anchor.epoch != peer.cfg.epoch ||
       anchor.content != peer.cfg.content ||
       anchor.contract != peer.contract {
        return .Invalid_Archive
    }

    if anchor.tick > peer.timeline.confirmed {
        return .Waiting
    }

    hash := peer.hashes[anchor.tick % u64(peer.cfg.history)]
    digest, ok := frame_digest(peer, anchor.tick, 0xcbf29ce484222325)

    if !ok || !hash.valid || hash.tick != anchor.tick {
        return .History
    }

    if hash.value != anchor.chain || digest != anchor.digest {
        return .Diverged
    }

    return .None
}
