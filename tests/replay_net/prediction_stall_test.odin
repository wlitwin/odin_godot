package replay_net_test
import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import v "godot:replay/view"

@(test)
prediction_horizon_stalls_without_discarding_world_or_pending_action :: proc(t: ^testing.T) {
    cfg := net.DEFAULT_CONFIG
    cfg.max_prediction = 12
    cfg.lead = 2
    f: Fixture
    fixture_init(&f, config = cfg)
    defer fixture_destroy(&f)

    for _ in 0 ..< 45 {
        fixture_step(&f)
    }

    c := &f.clients[0]
    c.cfg.packets_per_pump = 256

    for c.timeline.head - c.timeline.confirmed < u64(c.cfg.max_prediction) {
        testing.expect_value(t, net.client_step(c, Control{}), net.Error.None)
    }

    sequence, issued := net.client_issue(c, Action{take = true})
    testing.expect_value(t, issued, net.Error.None)
    before, _ := r.current(&c.timeline)
    truth := c.authority_frame
    serial := c.serial
    resyncs := c.stats.resyncs

    for _ in 0 ..< 8 {
        testing.expect_value(t, net.client_step(c, Control{move = 1}), net.Error.Capacity)
    }

    after, _ := r.current(&c.timeline)
    testing.expect(t, c.phase == .Running && c.has_world && c.stats.resyncs == resyncs && c.serial == serial)
    testing.expect(t, reflect.equal(before, after) && reflect.equal(truth, c.authority_frame))
    testing.expect(t, c.action_count == 1 && c.actions[0].sequence == sequence && !c.actions[0].predicted)

    // Keep the server and other clients running. This peer's incoming facts and
    // snapshots remain within history, and its already-issued action reaches authority.
    for _ in 0 ..< 30 {
        tr.memory_advance(&f.network, f.clock)
        now := f.clock * 1000 / 60
        net.server_pump(&f.server, now)

        for &client in f.clients[1:] {
            net.client_pump(&client, now)
        }

        net.server_step(&f.server)

        if f.clients[1].phase == .Running {
            net.client_step(&f.clients[1], Control{})
        }

        changes: [512]v.Change(net.Net_Event(Event))

        for &client in f.clients[1:] {
            for v.drain(&client.journal, changes[:]) > 0 {}
        }

        f.clock += 1
    }

    tr.memory_advance(&f.network, f.clock)
    testing.expect_value(t, net.client_pump(c, f.clock * 1000 / 60), net.Error.None)
    testing.expect(
        t,
        c.phase == .Running && c.has_world && c.stats.resyncs == resyncs && c.stats.snapshot_catchups > 0,
    )
    testing.expect_value(t, c.authority_frame.state.players[0].bag, u32(5))
    outcomes: [8]net.Action_Outcome
    n := net.client_outcomes(c, outcomes[:])
    testing.expect_value(t, n, 1)

    if n == 1 {
        testing.expect(t, outcomes[0].sequence == sequence && outcomes[0].applied)
    }

    testing.expect_value(t, net.client_outcomes(c, outcomes[:]), 0)
}
