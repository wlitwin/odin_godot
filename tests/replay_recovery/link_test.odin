package replay_recovery_test

import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"
import view "godot:replay/view"
import game "godot:examples/replay_hello/shared/hello"

Game_Link :: rec.Link(game.World, game.Controls, game.Action, game.Event, 2)

Link_Fixture :: struct {
    memory:    tr.Memory,
    endpoints: [3]tr.Memory_Endpoint,
    links:     [3]Game_Link,
    server:    net.Server(game.World, game.Controls, game.Action, game.Event, 2),
    clients:   [2]net.Client(game.World, game.Controls, game.Action, game.Event, 2),
    tick:      u64,
}

link_fixture_init :: proc(f: ^Link_Fixture) {
    assert(
        tr.memory_init(
            &f.memory,
            413,
            {3, 256, 8192, 65536},
            {latency_ticks = 2, jitter_ticks = 3, loss_permyriad = 1000, duplicate_permyriad = 2000, retry_ticks = 3},
        ),
    )

    for &endpoint, i in f.endpoints {
        tr.memory_open(&f.memory, &endpoint, tr.Peer_Id(i + 1))
        cfg := rec.DEFAULT_LINK_CONFIG
        cfg.accept_checkpoints = i == 1
        assert(rec.link_init(&f.links[i], tr.memory_transport(&endpoint), cfg))
    }

    assert(
        net.server_init(
            &f.server,
            r.Frame(game.World){},
            game.network_model(),
            rec.link_game_transport(&f.links[0]),
            local_seat = 1,
        ) ==
        .None,
    )
    net.server_set_local_token(&f.server, net.Token{0 = 11})

    for &client, i in f.clients {
        token: net.Token
        token[0] = u8(i + 20)
        assert(
            net.client_init(
                &client,
                game.network_model(),
                rec.link_game_transport(&f.links[i + 1]),
                token,
                spectator = i == 1,
            ) ==
            .None,
        )
    }
}

link_fixture_destroy :: proc(f: ^Link_Fixture) {
    for &client in f.clients {
        net.client_destroy(&client)
    }

    net.server_destroy(&f.server)

    for &link in f.links {
        rec.link_destroy(&link)
    }

    for &endpoint in f.endpoints {
        wire := tr.memory_transport(&endpoint)
        tr.close(&wire)
    }

    tr.memory_destroy(&f.memory)
}

link_fixture_step :: proc(f: ^Link_Fixture, moving: bool = false) {
    f.tick += 1
    assert(tr.memory_advance(&f.memory, f.tick))
    now := f.tick * 1000 / 60

    for &link in f.links {
        assert(rec.link_pump(&link, now))
    }

    net.server_pump(&f.server, now)

    for &client in f.clients {
        net.client_pump(&client, now)
    }

    net.server_local(&f.server, game.Controls{})
    assert(net.server_step(&f.server) == .None)

    for &client in f.clients {
        if client.phase == .Running && !client.spectator {
            err := net.client_step(&client, game.Controls{move = moving ? [2]i8{1, 0} : [2]i8{}})
            assert(err == .None || err == .Capacity)
        }

        changes: [512]view.Change(net.Net_Event(game.Event))

        for view.drain(&client.journal, changes[:]) > 0 {}

        outcomes: [16]net.Action_Outcome
        net.client_outcomes(&client, outcomes[:])
    }

    rec.link_server(&f.links[0], &f.server, now)

    for &client, i in f.clients {
        rec.link_client(&f.links[i + 1], &client, now)
    }
}

@(test)
gameplay_and_periodic_archives_share_a_connection_without_cross_protocol_rejection :: proc(t: ^testing.T) {
    f: Link_Fixture
    link_fixture_init(&f)
    defer link_fixture_destroy(&f)

    for _ in 0 ..< 60 {
        link_fixture_step(&f)
    }

    testing.expect_value(t, f.clients[0].phase, net.Phase.Running)
    testing.expect_value(t, f.clients[0].seat, u16(2))
    connection, live := net.server_seat_connection(&f.server, 2)
    testing.expect(t, live)
    testing.expect_value(t, rec.link_target(&f.links[0], &f.server, connection.peer, 15), net.Error.None)

    for _ in 0 ..< 60 {
        link_fixture_step(&f, true)
    }

    testing.expect_value(t, rec.link_target(&f.links[0], &f.server, 99), net.Error.Invalid_Input)
    net.client_issue(&f.clients[0], game.Action{fire = true})

    for _ in 0 ..< 180 {
        link_fixture_step(&f)
    }

    testing.expect(t, f.links[0].outgoing.acknowledged.archive.sequence > 2)
    testing.expect_value(t, f.links[0].outgoing.channel, tr.Channel.Reliable)
    testing.expect(t, f.links[1].incoming.reliable_replies)
    testing.expect(t, f.links[1].incoming.stats.validated > 2)
    testing.expect(t, !f.links[2].incoming.ready)
    testing.expect_value(t, f.links[2].ignored, u64(0))
    testing.expect_value(t, f.server.stats.rejected_packets, u64(0))

    for client in f.clients {
        testing.expect_value(t, client.stats.rejected_packets, u64(0))
    }

    frame, _ := r.current(&f.server.timeline)
    player, _ := r.pool_get(&frame.state.actors, frame.state.players[1])
    // The authored crate starts at x=300 and the player's half-width is 8.
    testing.expect(t, player.body.position[0] > 280 && player.body.position[0] <= 292.001)
    testing.expect_value(t, frame.state.shots, u32(1))

    for &client in f.clients {
        state, _ := r.current(&client.timeline)
        testing.expect_value(t, state.state.shots, u32(1))
    }

    receipt := f.links[0].outgoing.acknowledged
    cp, found := rec.receiver_checkpoint(&f.links[1].incoming, receipt.archive)
    testing.expect(t, found)
    testing.expect_value(t, cp.frame.state.shots, u32(1))
    testing.expect(
        t,
        f.links[0].router.stats.tx_bytes <=
        f.tick * 1000 / 60 * u64(f.links[0].cfg.transport.egress_per_second) / 1000 +
            u64(f.links[0].cfg.transport.burst_bytes),
    )
    rec.link_untarget(&f.links[0])
    testing.expect_value(t, rec.link_target(&f.links[0], &f.server, connection.peer, 15), net.Error.None)

    for _ in 0 ..< 60 {
        link_fixture_step(&f)
    }

    testing.expect(t, f.links[0].outgoing.acknowledged.archive.sequence > receipt.archive.sequence)
    receipt = f.links[0].outgoing.acknowledged
    // Revocation stops new backup work. Its previous receipt remains observable
    // and the driver reports that the selected connection is unavailable.
    net.server_kick(&f.server, 2)

    for _ in 0 ..< 20 {
        link_fixture_step(&f)
    }

    testing.expect_value(t, f.links[0].error, rec.Error.Transport)
    testing.expect_value(t, f.links[0].outgoing.acknowledged, receipt)
    testing.expect_value(t, f.clients[0].rejection, net.Reject.Removed)
}

@(test)
independent_application_routes_keep_existing_lane_and_primary_traffic :: proc(t: ^testing.T) {
    memory: tr.Memory
    assert(tr.memory_init(&memory, 901, {2, 256, 8192, 65536}, {retry_ticks = 1}))
    defer tr.memory_destroy(&memory)
    endpoints: [2]tr.Memory_Endpoint
    links: [2]Game_Link

    defer for &link in links {
        rec.link_destroy(&link)
    }

    defer for &endpoint in endpoints {
        wire := tr.memory_transport(&endpoint)
        tr.close(&wire)
    }

    cfg := rec.DEFAULT_LINK_CONFIG
    cfg.application_handles = proc(_: rawptr, _: tr.Peer_Id, _: tr.Channel, bytes: []u8) -> bool {
        return len(bytes) > 0 && bytes[0] == 42
    }
    route := rec.Application_Route {
        handles = proc(_: rawptr, _: tr.Peer_Id, _: tr.Channel, bytes: []u8) -> bool {
            return len(bytes) > 0 && bytes[0] == 43
        },
    }
    lane, ok := rec.link_add_application(&cfg, route)
    testing.expect(t, ok && lane == 3)
    again, same := rec.link_add_application(&cfg, route)
    testing.expect(t, same && again == lane)

    for &endpoint, i in endpoints {
        assert(tr.memory_open(&memory, &endpoint, tr.Peer_Id(i + 1)))
        assert(rec.link_init(&links[i], tr.memory_transport(&endpoint), cfg))
        rec.link_pump(&links[i], 0)
    }

    game_wire := rec.link_game_transport(&links[0])
    old_wire := rec.link_application_transport(&links[0])
    extra_wire := rec.link_application_lane(&links[0], lane)

    for value, i in ([3]u8{41, 42, 43}) {
        packet := [1]u8{value}
        wire := i == 0 ? &game_wire : i == 1 ? &old_wire : &extra_wire
        testing.expect_value(t, tr.send(wire, 2, .Reliable, packet[:]), tr.Send_Result.Sent)
    }

    tr.memory_advance(&memory, 1)
    rec.link_pump(&links[1], 20)
    outputs := [3]tr.Transport {
        rec.link_game_transport(&links[1]),
        rec.link_application_transport(&links[1]),
        rec.link_application_lane(&links[1], lane),
    }

    for &wire, i in outputs {
        bytes: [16]u8
        packet := tr.receive(&wire, bytes[:])
        testing.expect_value(t, packet.state, tr.Receive_State.Received)
        testing.expect_value(t, bytes[0], u8(41 + i))
        testing.expect_value(t, tr.receive(&wire, bytes[:]).state, tr.Receive_State.Empty)
    }
}

@(test)
checkpoint_channel_falls_back_for_a_peer_without_capability_advertisement :: proc(t: ^testing.T) {
    f := new(Link_Fixture)
    defer free(f)
    link_fixture_init(f)
    defer link_fixture_destroy(f)
    f.clients[0].snapshot_parts_enabled = false

    for _ in 0 ..< 60 {
        link_fixture_step(f)
    }

    connection, live := net.server_seat_connection(&f.server, 2)
    testing.expect(t, live)
    testing.expect_value(t, rec.link_target(&f.links[0], &f.server, connection.peer, 30), net.Error.None)

    for _ in 0 ..< 120 {
        link_fixture_step(f)
    }

    testing.expect(t, f.links[0].outgoing.acknowledged.archive.sequence > 0)
    testing.expect_value(t, f.links[0].outgoing.channel, tr.Channel.Unreliable)
    testing.expect(t, !f.links[1].incoming.reliable_replies)
}
