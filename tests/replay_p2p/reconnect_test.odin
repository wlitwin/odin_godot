package replay_p2p_test
import "core:reflect"
import "core:testing"
import rb "godot:replay/p2p"
import r "godot:replay"
import tr "godot:replay/transport"

@(test)
one_restored_participant_rejoins_a_retained_live_runner :: proc(t: ^testing.T) {
    f: Fixture
    setup(&f, {latency_ticks = 3, jitter_ticks = 1, loss_permyriad = 800, duplicate_permyriad = 800, retry_ticks = 3})
    defer cleanup(&f)

    for _ in 0 ..< 100 {
        cycle(&f, 90)
    }

    archive: rb.Archive(World, Input, Event, 2)
    defer rb.archive_destroy(&archive)
    testing.expect_value(t, rb.archive_capture(&f.peers[1], &archive), rb.Error.None)
    survivor := &f.peers[0]
    storage := raw_data(survivor.timeline.records)
    rb.destroy(&f.peers[1])

    // The survivor keeps its process/state and reaches its normal prediction bound.
    for _ in 0 ..< 40 {
        tr.memory_advance(&f.network, f.clock)
        rb.pump(survivor, f.clock * 1000 / 60)
        rb.advance(survivor, control(survivor.timeline.head + u64(survivor.cfg.delay) + 1, 0))
        f.clock += 1
    }

    testing.expect(t, survivor.stats.stalls > 0)
    before, _ := r.current(&survivor.timeline)
    sampled := survivor.sampled
    received := survivor.received

    // This memory provider explicitly retires the old delivery queue. The native
    // gate uses fresh ENet identities and Remap instead.
    for &packet in f.network.packets {
        packet.active = false
    }

    testing.expect_value(
        t,
        rb.restore(&f.peers[1], &archive, model(), [2]tr.Peer_Id{1, 2}, 1, tr.memory_transport(&f.endpoints[1])),
        rb.Error.None,
    )
    testing.expect_value(
        t,
        rb.reconnect(survivor, tr.memory_transport(&f.endpoints[0]), f.clock * 1000 / 60),
        rb.Error.None,
    )
    after, _ := r.current(&survivor.timeline)
    testing.expect(t, reflect.equal(before, after) && raw_data(survivor.timeline.records) == storage)
    testing.expect_value(t, survivor.sampled, sampled)
    testing.expect_value(t, survivor.received, received)

    for _ in 0 ..< 600 {
        cycle(&f, 300)
    }

    expect_reference(t, &f, 300)
}

@(test)
reconnect_keeps_stopped_divergence_and_rejects_invalid_boundaries :: proc(t: ^testing.T) {
    f: Fixture
    setup(&f)
    defer cleanup(&f)

    for _ in 0 ..< 60 {
        cycle(&f, 50)
    }

    p := &f.peers[0]
    before, _ := r.current(&p.timeline)
    testing.expect_value(t, rb.reconnect(p, {}, p.now), rb.Error.Transport)
    testing.expect_value(t, rb.reconnect(p, p.wire, p.now - 1), rb.Error.Time)
    p.dirty = 3
    testing.expect_value(t, rb.reconnect(p, p.wire, p.now), rb.Error.Not_Ready)
    p.dirty = 0
    p.timeline.busy = true
    testing.expect_value(t, rb.reconnect(p, p.wire, p.now), rb.Error.Not_Ready)
    p.timeline.busy = false
    p.phase = .Failed
    p.error = .Conflict
    testing.expect_value(t, rb.reconnect(p, p.wire, p.now), rb.Error.Not_Ready)
    p.phase = .Diverged
    p.error = .Diverged
    testing.expect_value(t, rb.reconnect(p, p.wire, p.now), rb.Error.Not_Ready)
    after, _ := r.current(&p.timeline)
    testing.expect(t, reflect.equal(before, after))
    testing.expect_value(t, p.phase, rb.Phase.Diverged)
}

@(test)
rejoin_refuses_a_required_retransmission_that_was_evicted :: proc(t: ^testing.T) {
    f: Fixture
    setup(&f)
    defer cleanup(&f)

    for _ in 0 ..< 60 {
        cycle(&f, 50)
    }

    archive: rb.Archive(World, Input, Event, 2)
    defer rb.archive_destroy(&archive)
    testing.expect_value(t, rb.archive_capture(&f.peers[1], &archive), rb.Error.None)

    for _ in 0 ..< 220 {
        cycle(&f, 180)
    }

    survivor := &f.peers[0]
    testing.expect(t, survivor.sampled - archive.peers.received[0] > u64(survivor.cfg.history))
    rb.destroy(&f.peers[1])

    for &packet in f.network.packets {
        packet.active = false
    }

    testing.expect_value(
        t,
        rb.restore(&f.peers[1], &archive, model(), [2]tr.Peer_Id{1, 2}, 1, tr.memory_transport(&f.endpoints[1])),
        rb.Error.None,
    )
    testing.expect_value(t, rb.reconnect(survivor, survivor.wire, f.clock * 1000 / 60), rb.Error.None)
    before, _ := r.current(&survivor.timeline)
    sampled := survivor.sampled
    // Deliver only the returning participant's Hello so this checks the survivor's
    // missing retransmission history independently of the returning peer's limits.
    testing.expect_value(t, rb.pump(&f.peers[1], f.clock * 1000 / 60), rb.Error.None)
    tr.memory_advance(&f.network, f.clock + 1)
    testing.expect_value(t, rb.pump(survivor, (f.clock + 1) * 1000 / 60), rb.Error.History)
    after, _ := r.current(&survivor.timeline)
    testing.expect_value(t, survivor.phase, rb.Phase.Failed)
    testing.expect(t, reflect.equal(before, after) && survivor.sampled == sampled)
}

@(test)
rejoining_archive_cannot_invent_forgotten_local_inputs :: proc(t: ^testing.T) {
    f: Fixture
    setup(&f)
    defer cleanup(&f)

    for _ in 0 ..< 60 {
        cycle(&f, 50)
    }

    archive: rb.Archive(World, Input, Event, 2)
    defer rb.archive_destroy(&archive)
    testing.expect_value(t, rb.archive_capture(&f.peers[1], &archive), rb.Error.None)

    for _ in 0 ..< 50 {
        cycle(&f, 85)
    }

    testing.expect(t, f.peers[0].received[1] > archive.header.sampled)
    rb.destroy(&f.peers[1])

    for &packet in f.network.packets {
        packet.active = false
    }

    testing.expect_value(
        t,
        rb.restore(&f.peers[1], &archive, model(), [2]tr.Peer_Id{1, 2}, 1, tr.memory_transport(&f.endpoints[1])),
        rb.Error.None,
    )
    testing.expect_value(t, rb.reconnect(&f.peers[0], f.peers[0].wire, f.clock * 1000 / 60), rb.Error.None)
    failed := false

    for _ in 0 ..< 20 {
        tr.memory_advance(&f.network, f.clock)
        rb.pump(&f.peers[0], f.clock * 1000 / 60)

        if rb.pump(&f.peers[1], f.clock * 1000 / 60) == .History {
            failed = true
            break
        }

        f.clock += 1
    }

    testing.expect(t, failed)
    testing.expect_value(t, f.peers[1].phase, rb.Phase.Failed)
}
