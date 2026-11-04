package replay_net_test
import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import v "godot:replay/view"

Large_Parts_World :: struct {
    tick: u64,
    data: [60000]u8,
}

@(test)
maximum_sized_world_uses_more_than_128_small_parts_without_partial_publication :: proc(t: ^testing.T) {
    large_parts_check(t, false)
}

@(test)
maximum_sized_world_recovers_two_erased_data_shards_per_group :: proc(t: ^testing.T) {
    large_parts_check(t, true)
}

large_parts_check :: proc(t: ^testing.T, erase: bool) {
    memory: tr.Memory
    assert(tr.memory_init(&memory, 73, {2, 512, 65536, 32768}))
    defer tr.memory_destroy(&memory)
    ends: [2]tr.Memory_Endpoint

    for &e, i in ends {
        assert(tr.memory_open(&memory, &e, tr.Peer_Id(i + 1)))
    }

    defer for &e in ends {
        wire := tr.memory_transport(&e)
        tr.close(&wire)
    }

    model := net.Model(Large_Parts_World, Control, Action, Event, 2) {
        step = proc(w: ^Large_Parts_World, controls: [2]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
            w.tick = ctx.tick

            for &b, i in w.data {
                b = u8(ctx.tick) ~ u8(i)
            }
        },
        control_valid = control_valid,
        hold = hold,
        action_valid = action_valid,
        state_valid = proc(w: Large_Parts_World) -> bool {
            return true
        },
    }
    cfg := net.DEFAULT_CONFIG
    cfg.unreliable_packet_limit = 512
    cfg.snapshot_every = 1
    cfg.packets_per_pump = 256
    cfg.egress_bytes_per_second = 4 * 1024 * 1024
    server: net.Server(Large_Parts_World, Control, Action, Event, 2)
    client: net.Client(Large_Parts_World, Control, Action, Event, 2)
    assert(
        net.server_init(
            &server,
            r.Frame(Large_Parts_World){},
            model,
            tr.memory_transport(&ends[0]),
            cfg,
            local_seat = 1,
        ) ==
        .None,
    )
    defer net.server_destroy(&server)
    assert(net.client_init(&client, model, tr.memory_transport(&ends[1]), net.Token{0 = 2}, cfg = cfg) == .None)
    defer net.client_destroy(&client)
    client.lz4_snapshots_enabled = false
    max_index: u16

    for tick in u64(0) ..< 40 {
        assert(tr.memory_advance(&memory, tick))
        assert(net.server_pump(&server, tick * 1000 / 60) == .None)
        assert(net.client_pump(&client, tick * 1000 / 60) == .None)
        assert(net.server_step(&server) == .None)

        for p, i in memory.packets {
            if p.active && p.from == 1 {
                bytes := memory.bytes[i * memory.config.packet_bytes:i * memory.config.packet_bytes + p.count]
                meta, _, report := sc.inspect(bytes)

                if report.error == .None && meta.kind == 17 {
                    max_index = max(
                        max_index,
                        u16(bytes[sc.HEADER_BYTES + 36]) | u16(bytes[sc.HEADER_BYTES + 37]) << 8,
                    )
                    testing.expect(t, p.count <= 512 && p.channel == .Unreliable)
                    index := int(bytes[sc.HEADER_BYTES + 36]) | int(bytes[sc.HEADER_BYTES + 37]) << 8

                    if erase && index % 8 < 2 {
                        memory.packets[i].active = false
                    }
                }
            }
        }

        if client.phase == .Running {
            err := net.client_step(&client, Control{})
            assert(err == .None || err == .Capacity)
        }

        changes: [512]v.Change(net.Net_Event(Event))

        for v.drain(&client.journal, changes[:]) > 0 {}
    }

    testing.expect(t, max_index >= 128)

    if erase {
        testing.expect(t, client.stats.snapshot_shards_recovered > 100)
    }

    testing.expect(t, client.authority_frame.tick > 35)

    for b, i in client.authority_frame.state.data {
        testing.expect_value(t, b, u8(client.authority_frame.tick) ~ u8(i))
    }

    testing.expect_value(t, client.stats.rejected_packets, u64(0))
    testing.expect_value(t, client.stats.resyncs, u64(0))
}
