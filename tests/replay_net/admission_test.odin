package replay_net_test

import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"

fresh_player :: proc(w: ^World, seat: u16, ctx: ^r.Step(Event)) {
    w.chest += w.players[seat - 1].bag
    w.players[seat - 1] = {}
}

@(test)
locked_rooms_reject_unknown_tokens_but_keep_reserved_reconnects :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)
    net.server_set_locked(&f.server, true)

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    for client in f.clients {
        testing.expect_value(t, client.phase, net.Phase.Rejected)
        testing.expect_value(t, client.rejection, net.Reject.Locked)
    }

    net.server_set_locked(&f.server, false)

    for &client, i in f.clients {
        token := client.token
        net.client_destroy(&client)
        net.client_init(
            &client,
            model(),
            tr.memory_transport(&f.endpoints[i + 1]),
            token,
            spectator = i == 2,
            cfg = f.server.cfg,
        )
    }

    for _ in 0 ..< 40 {
        fixture_step(&f)
    }

    net.client_issue(&f.clients[0], Action{take = true})

    for _ in 0 ..< 40 {
        fixture_step(&f)
    }

    seat, generation := f.clients[0].seat, f.clients[0].generation
    net.server_set_locked(&f.server, true)
    tr.close(&f.clients[0].wire)

    for _ in 0 ..< 620 {
        fixture_step(&f)
    }

    testing.expect(t, tr.memory_open(&f.network, &f.endpoints[1], 2))
    testing.expect_value(t, net.client_reconnect(&f.clients[0], tr.memory_transport(&f.endpoints[1])), net.Error.None)

    for _ in 0 ..< 60 {
        fixture_step(&f)
    }

    testing.expect_value(t, f.clients[0].phase, net.Phase.Running)
    testing.expect_value(t, f.clients[0].seat, seat)
    testing.expect(t, f.clients[0].generation > generation)
    frame, _ := r.current(&f.server.timeline)
    testing.expect_value(t, frame.state.players[seat - 1].bag, u32(5))
}

@(test)
custom_admission_and_ban_unban_apply_to_actual_handshakes :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)
    denied := net.token_hash(f.clients[1].token)
    net.server_set_admission(&f.server, &denied, proc(user: rawptr, hash: [32]u8, spectator: bool) -> bool {
        return !spectator && hash != (cast(^[32]u8)user)^
    })

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    testing.expect_value(t, f.clients[0].phase, net.Phase.Running)

    for i in 1 ..< 3 {
        testing.expect_value(t, f.clients[i].phase, net.Phase.Rejected)
        testing.expect_value(t, f.clients[i].rejection, net.Reject.Denied)
    }

    net.server_set_admission(&f.server, nil, nil)

    for i in 1 ..< 3 {
        client := &f.clients[i]
        token := client.token
        net.client_destroy(client)
        net.client_init(
            client,
            model(),
            tr.memory_transport(&f.endpoints[i + 1]),
            token,
            spectator = i == 2,
            cfg = f.server.cfg,
        )
    }

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    for client in f.clients {
        testing.expect_value(t, client.phase, net.Phase.Running)
    }

    token := f.clients[0].token
    testing.expect_value(t, net.server_ban(&f.server, token), net.Error.None)
    testing.expect_value(t, net.server_ban(&f.server, token), net.Error.None)
    testing.expect_value(t, f.server.banned_count, 1)

    for _ in 0 ..< 20 {
        fixture_step(&f)
    }

    testing.expect_value(t, f.clients[0].rejection, net.Reject.Banned)
    net.client_destroy(&f.clients[0])
    net.client_init(&f.clients[0], model(), tr.memory_transport(&f.endpoints[1]), token, cfg = f.server.cfg)

    for _ in 0 ..< 20 {
        fixture_step(&f)
    }

    testing.expect_value(t, f.clients[0].phase, net.Phase.Rejected)
    testing.expect_value(t, f.clients[0].rejection, net.Reject.Banned)
    testing.expect(t, net.server_unban(&f.server, token))
    testing.expect(t, !net.server_unban(&f.server, token))
    net.client_destroy(&f.clients[0])
    net.client_init(&f.clients[0], model(), tr.memory_transport(&f.endpoints[1]), token, cfg = f.server.cfg)

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    testing.expect_value(t, f.clients[0].phase, net.Phase.Running)
    testing.expect_value(t, f.clients[0].seat, u16(1))
}

@(test)
released_reservation_resets_a_new_occupant_inside_the_joining_tick :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)
    testing.expect_value(t, net.server_release_seat(&f.server, 1), net.Error.Invalid_Model)
    f.server.model.reset_player = fresh_player

    for &client in f.clients {
        client.model.reset_player = fresh_player
    }

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    testing.expect_value(t, net.server_release_seat(&f.server, 1), net.Error.Wrong_Phase)
    net.client_issue(&f.clients[0], Action{take = true})

    for _ in 0 ..< 40 {
        fixture_step(&f)
    }

    generation := f.clients[0].generation
    testing.expect_value(t, net.server_kick(&f.server, 1), net.Error.None)

    for _ in 0 ..< 20 {
        fixture_step(&f)
    }

    testing.expect_value(t, f.clients[0].rejection, net.Reject.Removed)
    testing.expect_value(t, net.server_release_seat(&f.server, 1), net.Error.None)
    before, _ := r.current(&f.server.timeline)
    testing.expect_value(t, before.state.players[0].bag, u32(5))
    net.client_destroy(&f.clients[0])
    definition := model()
    definition.reset_player = fresh_player
    net.client_init(
        &f.clients[0],
        definition,
        tr.memory_transport(&f.endpoints[1]),
        net.Token{0 = 9},
        cfg = f.server.cfg,
    )

    for _ in 0 ..< 60 {
        fixture_step(&f)
    }

    testing.expect_value(t, f.clients[0].phase, net.Phase.Running)
    testing.expect_value(t, f.clients[0].seat, u16(1))
    testing.expect(t, f.clients[0].generation > generation)
    after, _ := r.current(&f.server.timeline)
    testing.expect_value(t, after.state.players[0].bag, u32(0))
    testing.expect_value(t, after.state.chest, u32(5))
    testing.expect(t, after.state.players[0].active && state_valid(after.state))
}
