package claimball_trace
import net "godot:replay/net"
import sc "godot:replay/schema"
import v "godot:replay/view"

Header :: struct {
    settings:                                                          net.Checkpoint_Settings,
    epoch, content:                                                    u64,
    token, query_nonce:                                                net.Token,
    authority, incarnation:                                            u64,
    drain_capacity:                                                    u32,
    query, mixed, parts, lz4, erasure, shuffle, facts, actions, reuse: bool,
}

Frame :: struct {
    now, epoch, head, timeline_confirmed, confirmed, watch, facts, latest, pending, resyncs, view_reset: u64,
    world_tick, world_hash, changes_hash:                                                                u64,
    changes:                                                                                             u32,
    phase:                                                                                               net.Phase,
    has_pending:                                                                                         bool,
    watch_clock:                                                                                         f64,
}

observation :: proc(c: ^net.Client($S, $C, $A, $E, $N), changes: []v.Change(net.Net_Event(E))) -> Frame {
    world, events: sc.Schema
    defer sc.destroy(&world)
    defer sc.destroy(&events)
    assert(sc.init(&world, S).error == .None && sc.init(&events, v.Change(net.Net_Event(E))).error == .None)
    state := make([]u8, world.wire_size, context.temp_allocator)
    assert(sc.encode(&world, c.authority_frame.state, state).error == .None)
    data := make([]u8, events.wire_size * len(changes), context.temp_allocator)

    for change, i in changes {
        assert(sc.encode(&events, change, data[i * events.wire_size:(i + 1) * events.wire_size]).error == .None)
    }

    return {
        now = c.now,
        epoch = c.cfg.epoch,
        head = c.timeline.head,
        timeline_confirmed = c.timeline.confirmed,
        confirmed = c.journal.confirmed,
        watch = c.journal.watch_tick,
        facts = c.facts_contiguous,
        latest = c.snapshot_latest,
        pending = c.pending.frame.tick,
        resyncs = c.stats.resyncs,
        view_reset = c.view_reset,
        world_tick = c.authority_frame.tick,
        world_hash = sc.digest(state),
        changes_hash = sc.digest(data),
        changes = u32(len(changes)),
        phase = c.phase,
        has_pending = c.has_pending,
        watch_clock = c.watch_clock,
    }
}

settings :: proc(c: net.Config) -> net.Checkpoint_Settings {
    return {
        c.hz,
        u32(c.history),
        c.lead,
        c.max_future,
        c.max_prediction,
        c.snapshot_every,
        c.watch_delay,
        c.timeout_ms,
        u32(c.packets_per_pump),
        u32(c.bytes_per_pump),
        u32(c.snapshot_history),
        c.delta_snapshots,
        u32(c.egress_bytes_per_second),
        u32(c.egress_bytes_per_pump),
        u32(c.unreliable_packet_limit),
        c.require_permit,
        c.max_rewind,
        c.max_view_span,
        c.view_slack,
    }
}

config :: proc(h: Header) -> net.Config {
    return net.checkpoint_config({epoch = h.epoch, content = h.content}, h.settings)
}

// Explicit test stimulus, recorded as mark 3. It asks the normal server for a
// same-epoch checkpoint; gameplay frames, facts and effect state stay untouched.
request_refresh :: proc(c: ^net.Client($S, $C, $A, $E, $N)) {
    assert(c.phase == .Running && c.has_world && !c.recovering && c.request_sequence < max(u64))
    c.phase, c.hello_sent, c.has_pending = .Resyncing, false, false
    c.request_sequence += 1
}
