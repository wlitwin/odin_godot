package replay_net_test

import "core:testing"
import "core:fmt"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import v "godot:replay/view"

Budget_Event :: struct {
    tick:    u32,
    padding: [256]u32,
}

Budget_Action :: struct {
    amount:  u32,
    padding: [8192]u32,
}

Budget_Receiver :: struct {
    base:         tr.Transport,
    bytes, calls: int,
}

budget_receive :: proc(user: rawptr, dst: []u8) -> tr.Received {
    receiver := cast(^Budget_Receiver)user
    receiver.calls += 1
    packet := tr.receive(&receiver.base, dst)

    if packet.state == .Received {
        receiver.bytes += packet.count
    }

    return packet
}

@(test)
untrusted_senders_share_the_byte_budget_and_exact_exhaustion_stops_reading :: proc(t: ^testing.T) {
    sizes := [2]int{40000, 65536}

    for size in sizes {
        memory: tr.Memory
        tr.memory_init(&memory, cfg = {3, 8, 65536, 65536})
        defer tr.memory_destroy(&memory)
        endpoints: [3]tr.Memory_Endpoint

        for &endpoint, index in endpoints {
            tr.memory_open(&memory, &endpoint, tr.Peer_Id(index + 1))
        }

        receiver := Budget_Receiver {
            base = tr.memory_transport(&endpoints[1]),
        }
        wire := receiver.base
        wire.user = &receiver
        wire.receive = budget_receive
        wire.send = proc(user: rawptr, to: tr.Peer_Id, channel: tr.Channel, data: []u8) -> tr.Send_Result {
            return tr.send(&(cast(^Budget_Receiver)user).base, to, channel, data)
        }
        wire.status = proc(user: rawptr) -> tr.Status {
            return tr.status(&(cast(^Budget_Receiver)user).base)
        }
        wire.connected = proc(user: rawptr, peer: tr.Peer_Id) -> bool {
            return tr.peer_connected(&(cast(^Budget_Receiver)user).base, peer)
        }
        wire.close = nil
        client: Client
        cfg := net.DEFAULT_CONFIG
        cfg.bytes_per_pump = 65536
        net.client_init(&client, model(), wire, net.Token{0 = 1}, true, cfg = cfg)
        defer net.client_destroy(&client)
        sender := tr.memory_transport(&endpoints[2])
        data := make([]u8, size)
        defer delete(data)
        testing.expect_value(t, tr.send(&sender, 2, .Reliable, data), tr.Send_Result.Sent)
        testing.expect_value(t, tr.send(&sender, 2, .Reliable, data), tr.Send_Result.Sent)
        tr.memory_advance(&memory, 0)
        testing.expect_value(t, net.client_pump(&client, 0), net.Error.None)
        testing.expect_value(t, receiver.bytes, size)
        testing.expect_value(t, client.stats.rejected_packets, u64(1))

        if size == 65536 {
            testing.expect_value(t, receiver.calls, 1)
        }

        testing.expect_value(t, net.client_pump(&client, 1), net.Error.None)
        testing.expect_value(t, receiver.bytes, size * 2)
        testing.expect_value(t, client.stats.rejected_packets, u64(2))
        testing.expect_value(t, client.stats.rx_packets, u64(0))
    }
}

@(test)
byte_budget_defers_reliable_facts_without_losing_observer_effects :: proc(t: ^testing.T) {
    memory: tr.Memory
    testing.expect(t, tr.memory_init(&memory, cfg = {2, 128, 65536, 65536}))
    defer tr.memory_destroy(&memory)
    a, b: tr.Memory_Endpoint
    tr.memory_open(&memory, &a, 1)
    tr.memory_open(&memory, &b, 2)
    server := new(net.Server(u32, u8, u8, Budget_Event, 1))
    defer free(server)
    client := new(net.Client(u32, u8, u8, Budget_Event, 1))
    defer free(client)
    model := net.Model(u32, u8, u8, Budget_Event, 1) {
        step = proc(w: ^u32, c: [1]u8, j, l: u64, ctx: ^r.Step(Budget_Event)) {
            w^ += 1

            if ctx.tick >= 20 {
                for i in 0 ..< 32 {
                    r.emit(ctx, 1, u64(i + 1), Budget_Event{tick = u32(ctx.tick)})
                }
            }
        },
        control_valid = proc(c: u8) -> bool {
            return c == 0
        },
        state_valid = proc(w: u32) -> bool {
            return true
        },
        hold = proc(c: u8) -> u8 {
            return c
        },
        event_policy = proc(e: Budget_Event) -> v.Policy {
            return .Watched
        },
    }
    cfg := net.DEFAULT_CONFIG
    cfg.bytes_per_pump = 65536
    cfg.snapshot_every = 1
    cfg.watch_delay = 0
    cfg.view_slack = 0
    cfg.egress_bytes_per_second = 16 * 1024 * 1024
    cfg.egress_bytes_per_pump = 1024 * 1024
    testing.expect_value(
        t,
        net.server_init(server, r.Frame(u32){}, model, tr.memory_transport(&a), cfg),
        net.Error.None,
    )
    defer net.server_destroy(server)
    testing.expect_value(
        t,
        net.client_init(client, model, tr.memory_transport(&b), net.Token{0 = 1}, true, cfg = cfg),
        net.Error.None,
    )
    defer net.client_destroy(client)
    client.snapshot_parts_enabled = false
    client.fact_repair_enabled = false
    clock := u64(0)

    for clock < 18 {
        tr.memory_advance(&memory, clock)
        now := clock * 1000 / 60
        net.server_pump(server, now)
        net.client_pump(client, now)
        net.server_step(server)
        clock += 1
    }

    testing.expect_value(t, client.phase, net.Phase.Running)

    // Three authentic >32 KiB fact packets queue while the observer is stalled.
    for clock < 22 {
        tr.memory_advance(&memory, clock)
        net.server_pump(server, clock * 1000 / 60)
        net.server_step(server)
        clock += 1
    }

    tr.memory_advance(&memory, clock)
    before_rejected := client.stats.rejected_packets
    seen: [3][32]bool
    total := 0
    changes := make([]v.Change(net.Net_Event(Budget_Event)), 256)
    defer delete(changes)

    for attempt in 0 ..< 5 {
        before := client.stats.rx_bytes
        testing.expect_value(t, net.client_pump(client, (clock + u64(attempt)) * 1000 / 60), net.Error.None)
        testing.expect(t, client.stats.rx_bytes - before <= u64(cfg.bytes_per_pump))

        for {
            count := v.drain(&client.journal, changes)

            if count == 0 {
                break
            }

            for change in changes[:count] {
                if change.kind == .Begin && change.occurrence.value.kind == .Gameplay {
                    tick, key := change.occurrence.id.tick, change.occurrence.id.key
                    testing.expect(t, tick >= 20 && tick <= 22 && key >= 1 && key <= 32)

                    if tick >= 20 && tick <= 22 && key >= 1 && key <= 32 {
                        testing.expect(t, !seen[tick - 20][key - 1])
                        seen[tick - 20][key - 1] = true
                        total += 1
                    }
                }
            }
        }
    }

    fmt.printf(
        "RECEIVE_BUDGET_FACTS confirmed=%d facts=%d effects=%d rejected=%d resyncs=%d\n",
        client.journal.confirmed,
        client.facts_contiguous,
        total,
        client.stats.rejected_packets - before_rejected,
        client.stats.resyncs,
    )
    testing.expect_value(t, client.journal.confirmed, u64(22))
    testing.expect_value(t, total, 96)
    testing.expect_value(t, client.stats.rejected_packets, before_rejected)
    testing.expect_value(t, client.stats.resyncs, u64(0))
}

@(test)
byte_budget_defers_large_actions_without_waiting_for_retry :: proc(t: ^testing.T) {
    memory: tr.Memory
    tr.memory_init(&memory, cfg = {2, 128, 65536, 65536})
    defer tr.memory_destroy(&memory)
    a, b: tr.Memory_Endpoint
    tr.memory_open(&memory, &a, 1)
    tr.memory_open(&memory, &b, 2)
    server := new(net.Server(u32, u8, Budget_Action, u32, 1))
    defer free(server)
    client := new(net.Client(u32, u8, Budget_Action, u32, 1))
    defer free(client)
    model := net.Model(u32, u8, Budget_Action, u32, 1) {
        action_timing = .Receipt,
        step = proc(w: ^u32, c: [1]u8, j, l: u64, ctx: ^r.Step(u32)) {},
        action = proc(w: ^u32, seat: u16, a: Budget_Action, ctx: ^r.Step(u32)) -> bool {
            w^ += a.amount
            return true
        },
        control_valid = proc(c: u8) -> bool {
            return c == 0
        },
        state_valid = proc(w: u32) -> bool {
            return w <= 3
        },
        hold = proc(c: u8) -> u8 {
            return c
        },
        action_valid = proc(a: Budget_Action) -> bool {
            return a.amount > 0 && a.amount <= 2
        },
    }
    cfg := net.DEFAULT_CONFIG
    cfg.bytes_per_pump = 65536
    cfg.egress_bytes_per_pump = 1024 * 1024
    testing.expect_value(
        t,
        net.server_init(server, r.Frame(u32){}, model, tr.memory_transport(&a), cfg),
        net.Error.None,
    )
    defer net.server_destroy(server)
    testing.expect_value(
        t,
        net.client_init(client, model, tr.memory_transport(&b), net.Token{0 = 1}, cfg = cfg),
        net.Error.None,
    )
    defer net.client_destroy(client)
    client.action_copies_enabled = false

    for clock in 0 ..< 20 {
        tr.memory_advance(&memory, u64(clock))
        now := u64(clock) * 1000 / 60
        net.server_pump(server, now)
        net.client_pump(client, now)
        net.server_step(server)

        if client.phase == .Running {
            net.client_step(client, u8(0))
        }
    }

    testing.expect_value(t, client.phase, net.Phase.Running)
    _, one := net.client_issue(client, Budget_Action{amount = 1})
    _, two := net.client_issue(client, Budget_Action{amount = 2})
    testing.expect_value(t, one, net.Error.None)
    testing.expect_value(t, two, net.Error.None)
    before_rejected := server.stats.rejected_packets
    tr.memory_advance(&memory, 20)

    // No further client pump or send: recovery must not depend on 500 ms retries.
    for i in 0 ..< 3 {
        before := server.stats.rx_bytes
        testing.expect_value(t, net.server_pump(server, u64(20 + i) * 1000 / 60), net.Error.None)
        testing.expect(t, server.stats.rx_bytes - before <= u64(cfg.bytes_per_pump))
        testing.expect_value(t, net.server_step(server), net.Error.None)
    }

    frame, _ := r.current(&server.timeline)
    fmt.printf(
        "RECEIVE_BUDGET_ACTIONS applied_sum=%d rejected=%d\n",
        frame.state,
        server.stats.rejected_packets - before_rejected,
    )
    testing.expect_value(t, frame.state, u32(3))
    testing.expect_value(t, server.stats.rejected_packets, before_rejected)
}
