package replay_net_test

import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import v "godot:replay/view"

drain_old :: proc(f: ^Fixture) {
    for &client in f.clients {
        changes: [512]v.Change(net.Net_Event(Event))

        for v.drain(&client.journal, changes[:]) > 0 {}

        outcomes: [16]net.Action_Outcome
        net.client_outcomes(&client, outcomes[:])
    }
}

change_authority :: proc(f: ^Fixture, cp: ^Checkpoint, preserve: bool) {
    drain_old(f)
    net.server_destroy(&f.server)
    assert(
        net.server_restore(
            &f.server,
            cp,
            model(),
            tr.memory_transport(&f.endpoints[0]),
            {epoch = 2, preserve_pending = preserve, retain_membership = true},
        ) ==
        .None,
    )

    for &client, i in f.clients {
        assert(net.client_authority(&client, 2, tr.memory_transport(&f.endpoints[i + 1])) == .None)
    }
}

@(test)
new_authority_retires_unreplicated_commands_without_sequence_holes :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    cp: Checkpoint
    defer net.checkpoint_destroy(&cp)
    net.checkpoint_capture(&f.server, &cp)
    net.client_issue(&f.clients[0], Action{take = true})
    net.client_step(&f.clients[0], Control{})
    change_authority(&f, &cp, false)

    for _ in 0 ..< 40 {
        fixture_step(&f)
    }

    report, ready := net.client_recovery(&f.clients[0])
    testing.expect(t, ready)
    testing.expect_value(t, report.count, u8(1))
    testing.expect_value(t, report.actions[0].disposition, net.Recovery_Disposition.Retired)
    testing.expect_value(t, report.actions[0].epoch, u64(1))
    testing.expect_value(t, f.clients[0].next_action, u64(0))
    sequence, err := net.client_issue(&f.clients[0], Action{take = true})
    testing.expect_value(t, sequence, u64(1))
    testing.expect_value(t, err, net.Error.None)

    for _ in 0 ..< 40 {
        fixture_step(&f)
    }

    frame, _ := r.current(&f.server.timeline)
    testing.expect_value(t, frame.state.players[0].bag, u32(5))
    testing.expect_value(t, frame.state.chest, u32(0))
}

@(test)
new_authority_resolves_pending_commands_already_settled_in_checkpoint :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    net.client_issue(&f.clients[0], Action{take = true})
    net.client_step(&f.clients[0], Control{})

    // Let the authority settle it while the client receives no verdict.
    for _ in 0 ..< 20 {
        tr.memory_advance(&f.network, f.clock)
        net.server_pump(&f.server, f.clock * 1000 / 60)
        net.server_step(&f.server)
        f.clock += 1
    }

    cp: Checkpoint
    defer net.checkpoint_destroy(&cp)
    net.checkpoint_capture(&f.server, &cp)
    change_authority(&f, &cp, false)

    for _ in 0 ..< 40 {
        fixture_step(&f)
    }

    report, ready := net.client_recovery(&f.clients[0])
    testing.expect(t, ready)
    testing.expect_value(t, report.actions[0].disposition, net.Recovery_Disposition.Applied)
    testing.expect_value(t, report.actions[0].outcome.sequence, u64(1))
    testing.expect_value(t, f.clients[0].next_action, u64(1))
    testing.expect_value(t, f.clients[0].action_count, 0)
    frame, _ := r.current(&f.clients[0].timeline)
    testing.expect_value(t, frame.state.players[0].bag, u32(5))
}

@(test)
accepted_unexecuted_commands_follow_the_authoritys_explicit_resume_policy :: proc(t: ^testing.T) {
    policies := [2]bool{true, false}

    for preserve in policies {
        f: Fixture
        fixture_init(&f)
        defer fixture_destroy(&f)

        for _ in 0 ..< 30 {
            fixture_step(&f)
        }

        net.client_issue(&f.clients[0], Action{take = true})
        net.client_step(&f.clients[0], Control{})
        tr.memory_advance(&f.network, f.clock)
        net.server_pump(&f.server, f.clock * 1000 / 60)
        cp: Checkpoint
        defer net.checkpoint_destroy(&cp)
        net.checkpoint_capture(&f.server, &cp)
        testing.expect_value(t, len(cp.actions), 1)
        change_authority(&f, &cp, preserve)

        for _ in 0 ..< 6 {
            fixture_step(&f)
        }

        report, ready := net.client_recovery(&f.clients[0])
        testing.expect(t, ready)
        testing.expect_value(
            t,
            report.actions[0].disposition,
            preserve ? net.Recovery_Disposition.Retained : net.Recovery_Disposition.Rejected,
        )

        for _ in 0 ..< 40 {
            fixture_step(&f)
        }

        frame, _ := r.current(&f.server.timeline)
        testing.expect_value(t, frame.state.players[0].bag, preserve ? u32(5) : u32(0))
        testing.expect_value(t, f.clients[0].action_count, 0)
    }
}

@(test)
departing_host_preserves_its_local_pending_actions_for_rejoin_reconciliation :: proc(t: ^testing.T) {
    s: Server
    defer net.server_destroy(&s)
    net.server_init(&s, r.Frame(World){state = {chest = 5}}, model(), {}, local_seat = 1)
    token := net.Token {
        0 = 31,
    }
    net.server_set_local_token(&s, token)
    net.server_step(&s)
    cp: Checkpoint
    defer net.checkpoint_destroy(&cp)
    net.checkpoint_capture(&s, &cp)
    net.server_issue(&s, Action{take = true})
    history := net.server_departing(&s)
    c: Client
    defer net.client_destroy(&c)
    net.client_init(&c, model(), {}, token)
    testing.expect_value(t, net.client_seed_departing(&c, history), net.Error.None)
    testing.expect_value(t, c.action_count, 1)
    testing.expect(t, c.has_world)
    report, found := net.client_checkpoint_recovery(&c, &cp, 2)
    testing.expect(t, found)
    testing.expect_value(t, report.actions[0].disposition, net.Recovery_Disposition.Retired)
    testing.expect_value(t, c.action_count, 1) // report preparation does not mutate the old owner
}
