package replay_cave_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import p "godot:replay/play"
import net "godot:replay/net"
import tr "godot:replay/transport"
import v "godot:replay/view"
import cave "../../examples/replay_cavecrawl/shared/cave"

@(test)
real_cave_model_predicts_contested_loot_and_converges_under_loss :: proc(t: ^testing.T) {
    memory: tr.Memory
    tr.memory_init(
        &memory,
        77,
        cfg = {3, 512, 8192, 65536},
        faults = {latency_ticks = 2, jitter_ticks = 1, loss_permyriad = 500, retry_ticks = 2},
    )
    defer tr.memory_destroy(&memory)
    endpoints: [3]tr.Memory_Endpoint

    for &endpoint, i in endpoints {
        tr.memory_open(&memory, &endpoint, tr.Peer_Id(i + 1))
    }

    defer for &endpoint in endpoints {
        wire := tr.memory_transport(&endpoint)
        tr.close(&wire)
    }

    server: net.Server(cave.World, cave.Control, cave.Action, cave.Event, cave.SEATS)
    clients: [2]net.Client(cave.World, cave.Control, cave.Action, cave.Event, cave.SEATS)
    cfg := net.DEFAULT_CONFIG
    cfg.hz, cfg.lead, cfg.snapshot_every = cave.HZ, 4, 1
    testing.expect_value(
        t,
        net.server_init(
            &server,
            r.Frame(cave.World){state = cave.initial()},
            cave.model(),
            tr.memory_transport(&endpoints[0]),
            cfg,
        ),
        net.Error.None,
    )
    defer net.server_destroy(&server)

    for &client, i in clients {
        token: net.Token
        token[0] = u8(i + 1)
        testing.expect_value(
            t,
            net.client_init(&client, cave.model(), tr.memory_transport(&endpoints[i + 1]), token, cfg = cfg),
            net.Error.None,
        )
    }

    defer for &client in clients {
        net.client_destroy(&client)
    }

    issued := false

    for tick in u64(0) ..< 300 {
        tr.memory_advance(&memory, tick)
        net.server_pump(&server, tick * 50)

        for &client in clients {
            testing.expect_value(t, net.client_pump(&client, tick * 50), net.Error.None)
        }

        testing.expect_value(t, net.server_step(&server), net.Error.None)
        ready := 0

        for &client in clients {
            if client.phase != .Running {
                continue
            }

            frame, _ := r.current(&client.timeline)
            player := frame.state.players[client.seat - 1]
            goal := cave.floor(1).chest
            control: cave.Control

            if p.in_reach(player.position, goal, 8) {
                ready += 1
            } else {
                difference := goal - player.position
                control.move = {
                    abs(difference[0]) > 4 ? (difference[0] > 0 ? i8(1) : i8(-1)) : 0,
                    abs(difference[1]) > 4 ? (difference[1] > 0 ? i8(1) : i8(-1)) : 0,
                }
            }

            testing.expect_value(t, net.client_step(&client, control), net.Error.None)
            changes: [512]v.Change(net.Net_Event(cave.Event))

            for v.drain(&client.journal, changes[:]) > 0 {}
        }

        if !issued && ready == 2 {
            for &client in clients {
                _, err := net.client_issue(&client, cave.Action{verb = .Take, index = 0})
                testing.expect_value(t, err, net.Error.None)
            }

            issued = true
        }
    }

    testing.expect(t, issued)
    truth, _ := r.current(&server.timeline)
    testing.expect_value(t, cave.world_items(&truth.state, cave.GEM), u32(3))
    testing.expect_value(t, truth.state.chest[0].count, u16(0))
    applied := 0

    for &client in clients {
        outcomes: [4]net.Action_Outcome
        n := net.client_outcomes(&client, outcomes[:])
        testing.expect_value(t, n, 1)

        if outcomes[0].applied {
            applied += 1
        }

        frame, _ := r.current(&client.timeline)
        testing.expect_value(t, cave.world_items(&frame.state, cave.GEM), u32(3))

        for i in 0 ..< cave.SEATS {
            testing.expect(t, reflect.equal(frame.state.players[i].bag, truth.state.players[i].bag))
        }
    }

    testing.expect_value(t, applied, 1)
}
