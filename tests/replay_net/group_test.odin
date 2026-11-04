package replay_net_test

import "core:reflect"
import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"

self_group :: proc() -> net.Prediction_Group(World) {
    return {id = 7, project = proc(frame: r.Frame(World), seat: u16) -> World {
            w := frame.state

            for &player, i in w.players {
                if i + 1 != int(seat) {
                    player = {}
                }
            }

            return w
        }, valid = proc(w: World, seat: u16) -> bool {
            for player, i in w.players {
                if i + 1 != int(seat) && player != (Player{}) {
                    return false
                }
            }

            return true
        }}
}

group_client :: proc(f: ^Fixture) {
    token := f.clients[0].token
    cfg := f.clients[0].cfg
    net.client_destroy(&f.clients[0])
    m := model()
    m.group = self_group()
    assert(net.client_init(&f.clients[0], m, tr.memory_transport(&f.endpoints[1]), token, cfg = cfg) == .None)
}

@(test)
group_simulates_self_shared_state_and_preserves_complete_observed_world :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, tr.Faults{latency_ticks = 3, retry_ticks = 3})
    defer fixture_destroy(&f)
    group_client(&f)

    for _ in 0 ..< 90 {
        fixture_step(&f, true)
    }

    prediction, ok := net.client_prediction(&f.clients[0])
    testing.expect(t, ok)
    testing.expect_value(t, prediction.group, u64(7))
    testing.expect(t, prediction.frame.state.players[0].active && prediction.frame.state.players[0].x > 0)
    testing.expect_value(t, prediction.frame.state.players[1], Player{})
    auth := f.clients[0].authority_frame
    testing.expect(t, auth.state.players[1].active && auth.state.players[1].x < 0)
    input, known := r.read_input(&f.clients[0].timeline, prediction.frame.tick)
    testing.expect(t, known)
    testing.expect_value(t, input.prediction_seat, u16(1))
    testing.expect_value(t, input.prediction_group, u64(7))
    testing.expect_value(t, input.controls[1], Control{})
    net.client_issue(&f.clients[0], Action{take = true})

    for _ in 0 ..< 50 {
        fixture_step(&f)
    }

    prediction, _ = net.client_prediction(&f.clients[0])
    testing.expect_value(t, prediction.frame.state.players[0].bag, u32(5))
    testing.expect_value(t, prediction.frame.state.chest, u32(0))
    testing.expect_value(t, prediction.frame.state.players[1], Player{})
}

@(test)
group_footprint_violation_aborts_without_publishing_outside_mutation :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)
    group_client(&f)

    for _ in 0 ..< 25 {
        fixture_step(&f)
    }

    c := &f.clients[0]
    before, _ := r.current(&c.timeline)
    c.model.step = proc(w: ^World, controls: [2]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
        w.players[1].x = 99 // an accidentally reintroduced out-of-group dependency
    }
    testing.expect_value(t, net.client_step(c, Control{}), net.Error.Simulation)
    after, _ := r.current(&c.timeline)
    testing.expect(t, reflect.equal(before, after))
}

@(test)
group_reconnect_reprojects_instead_of_retaining_remote_simulation_members :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)
    group_client(&f)

    for _ in 0 ..< 30 {
        fixture_step(&f, true)
    }

    c := &f.clients[0]
    old_reset := c.view_reset
    tr.close(&c.wire)
    fixture_step(&f)
    testing.expect(t, tr.memory_open(&f.network, &f.endpoints[1], 2))
    testing.expect_value(t, net.client_reconnect(c, tr.memory_transport(&f.endpoints[1])), net.Error.None)

    for _ in 0 ..< 40 {
        fixture_step(&f, true)
    }

    testing.expect(t, c.view_reset > old_reset)
    prediction, ok := net.client_prediction(c)
    testing.expect(t, ok)
    testing.expect_value(t, prediction.frame.state.players[1], Player{})
    testing.expect(t, c.authority_frame.state.players[1].active)
}

@(test)
group_authority_change_restores_complete_server_and_reprojects_the_client :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)
    group_client(&f)

    for _ in 0 ..< 45 {
        fixture_step(&f, true)
    }

    cp: Checkpoint
    defer net.checkpoint_destroy(&cp)
    testing.expect_value(t, net.checkpoint_capture(&f.server, &cp), net.Error.None)
    testing.expect(t, cp.frame.state.players[0].active && cp.frame.state.players[1].active)
    net.server_destroy(&f.server)
    testing.expect_value(
        t,
        net.server_restore(&f.server, &cp, model(), tr.memory_transport(&f.endpoints[0]), {epoch = 2}),
        net.Error.None,
    )

    for &client, i in f.clients {
        testing.expect_value(
            t,
            net.client_authority(&client, 2, tr.memory_transport(&f.endpoints[i + 1])),
            net.Error.None,
        )
    }

    for _ in 0 ..< 55 {
        fixture_step(&f, true)
    }

    c := &f.clients[0]
    testing.expect_value(t, c.cfg.epoch, u64(2))
    testing.expect_value(t, c.phase, net.Phase.Running)
    prediction, ok := net.client_prediction(c)
    testing.expect(t, ok)
    testing.expect_value(t, prediction.group, u64(7))
    testing.expect_value(t, prediction.frame.state.players[1], Player{})
    testing.expect(t, c.authority_frame.state.players[1].active)
}
