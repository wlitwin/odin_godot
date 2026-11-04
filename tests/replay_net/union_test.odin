package replay_net_test

import "core:testing"
import "core:fmt"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import v "godot:replay/view"

import game "../replay_unions/godot/shared/game"

Coins :: game.Coins
Pocket :: game.Pocket
Union_Player :: game.Union_Player
Union_World :: game.Union_World
Move :: game.Move
Union_Control :: game.Union_Control
Take :: game.Take
Put :: game.Put
Union_Action :: game.Union_Action
Taken :: game.Taken
Returned :: game.Returned
Union_Event :: game.Union_Event
union_model :: game.union_model

@(test)
unions_flow_through_prediction_actions_events_and_checkpoint_restore :: proc(t: ^testing.T) {
    memory: tr.Memory
    assert(
        tr.memory_init(
            &memory,
            seed = 77,
            cfg = {3, 512, 8192, 65536},
            faults = {
                latency_ticks = 2,
                jitter_ticks = 2,
                loss_permyriad = 1000,
                duplicate_permyriad = 1000,
                retry_ticks = 3,
            },
        ),
    )
    defer tr.memory_destroy(&memory)
    endpoints: [3]tr.Memory_Endpoint

    for &endpoint, i in endpoints {
        assert(tr.memory_open(&memory, &endpoint, tr.Peer_Id(i + 1)))
    }

    server: net.Server(Union_World, Union_Control, Union_Action, Union_Event, 2)
    defer net.server_destroy(&server)
    clients: [2]net.Client(Union_World, Union_Control, Union_Action, Union_Event, 2)

    defer for &client in clients {
        net.client_destroy(&client)
    }

    testing.expect_value(
        t,
        net.server_init(
            &server,
            r.Frame(Union_World){state = {chest = 5}},
            union_model(),
            tr.memory_transport(&endpoints[0]),
        ),
        net.Error.None,
    )

    for &client, i in clients {
        testing.expect_value(
            t,
            net.client_init(&client, union_model(), tr.memory_transport(&endpoints[i + 1]), net.Token{0 = u8(i + 1)}),
            net.Error.None,
        )
    }

    for clock in 0 ..< 400 {
        tr.memory_advance(&memory, u64(clock))
        net.server_pump(&server, u64(clock * 16))

        for &client in clients {
            net.client_pump(&client, u64(clock * 16))
        }

        if clock == 100 {
            fmt.printf(
                "UNION_CLIENT phase=%v rejection=%v rx=%d rejected=%d\n",
                clients[0].phase,
                clients[0].rejection,
                clients[0].stats.rx_bytes,
                clients[0].stats.rejected_packets,
            )
            _, err := net.client_issue(&clients[0], Union_Action(Take{3}))
            testing.expect_value(t, err, net.Error.None)
        }

        if clock == 200 {
            _, err := net.client_issue(&clients[0], Union_Action(Put{1}))
            testing.expect_value(t, err, net.Error.None)
        }

        testing.expect_value(t, net.server_step(&server), net.Error.None)

        for &client, i in clients {
            if client.phase == .Running {
                control: Union_Control

                if clock < 250 {
                    control = Move{i == 0 ? 1 : -1}
                }

                net.client_step(&client, control)
            }

            changes: [512]v.Change(net.Net_Event(Union_Event))

            for v.drain(&client.journal, changes[:]) > 0 {}
        }
    }

    truth, _ := r.current(&server.timeline)
    testing.expect_value(t, truth.state.chest, u32(3))
    coins, ok := truth.state.players[clients[0].seat - 1].pocket.(Coins)
    testing.expect(t, ok && coins.amount == 2)

    for &client in clients {
        frame, _ := r.current(&client.timeline)
        testing.expect(t, reflect.equal(frame.state, truth.state))
    }

    testing.expect_value(t, r.audit(&server.timeline, server.timeline.head - 20).error, r.Error.None)
    cp, decoded: net.Checkpoint(Union_World, Union_Control, Union_Action, 2)
    defer net.checkpoint_destroy(&cp)
    defer net.checkpoint_destroy(&decoded)
    testing.expect_value(t, net.checkpoint_capture(&server, &cp), net.Error.None)
    bytes, encoded := net.checkpoint_encode(&cp, union_model())
    defer delete(bytes)
    testing.expect_value(t, encoded, net.Error.None)
    testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, union_model(), 1), net.Error.None)
    testing.expect(t, reflect.equal(decoded.frame, cp.frame))
    resumed: net.Server(Union_World, Union_Control, Union_Action, Union_Event, 2)
    defer net.server_destroy(&resumed)
    testing.expect_value(t, net.server_restore(&resumed, &decoded, union_model(), {}, {epoch = 2}), net.Error.None)
}
