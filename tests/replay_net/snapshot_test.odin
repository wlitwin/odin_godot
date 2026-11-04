package replay_net_test

import "core:reflect"
import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import d "godot:replay/delta"
import sc "godot:replay/schema"
import v "godot:replay/view"
import game "../../examples/replay_hello/shared/hello"

Hello_Fixture :: struct {
    network:   tr.Memory,
    endpoints: [3]tr.Memory_Endpoint,
    server:    net.Server(game.World, game.Controls, game.Action, game.Event, 2),
    clients:   [2]net.Client(game.World, game.Controls, game.Action, game.Event, 2),
    clock:     u64,
}

hello_fixture_init :: proc(
    f: ^Hello_Fixture,
    compressed: bool = true,
    rate: int = 256 * 1024,
    faults := tr.DEFAULT_FAULTS,
    action_timing := net.Action_Timing.Scheduled,
) {
    assert(tr.memory_init(&f.network, 99, cfg = {3, 512, 8192, 65536}, faults = faults))

    for &endpoint, i in f.endpoints {
        assert(tr.memory_open(&f.network, &endpoint, tr.Peer_Id(i + 1)))
    }

    cfg := net.DEFAULT_CONFIG
    cfg.delta_snapshots, cfg.egress_bytes_per_second = compressed, rate
    model := game.network_model()
    model.action_timing = action_timing
    assert(
        net.server_init(&f.server, r.Frame(game.World){}, model, tr.memory_transport(&f.endpoints[0]), cfg) == .None,
    )

    for &client, i in f.clients {
        token: net.Token
        token[0] = u8(i + 1)
        assert(net.client_init(&client, model, tr.memory_transport(&f.endpoints[i + 1]), token, cfg = cfg) == .None)
    }
}

hello_fixture_destroy :: proc(f: ^Hello_Fixture) {
    for &client in f.clients {
        net.client_destroy(&client)
    }

    net.server_destroy(&f.server)

    for &endpoint in f.endpoints {
        wire := tr.memory_transport(&endpoint)
        tr.close(&wire)
    }

    tr.memory_destroy(&f.network)
}

hello_fixture_step :: proc(f: ^Hello_Fixture, move: bool = false) {
    tr.memory_advance(&f.network, f.clock)
    now := f.clock * 1000 / 60
    assert(net.server_pump(&f.server, now) == .None)

    for &client in f.clients {
        assert(net.client_pump(&client, now) == .None)
    }

    assert(net.server_step(&f.server) == .None)

    for &client in f.clients {
        if client.phase == .Running {
            control: game.Controls

            if move {
                control.move[0] = 1
            }

            err := net.client_step(&client, control)
            assert(err == .None || err == .Capacity)
        }

        changes: [512]v.Change(net.Net_Event(game.Event))

        for v.drain(&client.journal, changes[:]) > 0 {}
    }

    f.clock += 1
}

@(test)
acknowledged_deltas_reduce_real_hello_traffic_without_changing_state :: proc(t: ^testing.T) {
    compressed, full: Hello_Fixture
    hello_fixture_init(&compressed)
    hello_fixture_init(&full, false)
    defer hello_fixture_destroy(&compressed)
    defer hello_fixture_destroy(&full)

    for tick in 0 ..< 240 {
        hello_fixture_step(&compressed, tick < 60)
        hello_fixture_step(&full, tick < 60)
    }

    a, _ := r.current(&compressed.server.timeline)
    b, _ := r.current(&full.server.timeline)
    testing.expect(t, reflect.equal(a, b))

    for &client in compressed.clients {
        frame, _ := r.current(&client.timeline)
        testing.expect(t, reflect.equal(frame.state, a.state))
        testing.expect(t, client.stats.delta_snapshots > 0)
    }

    testing.expect(t, compressed.server.stats.delta_snapshots > 0)
    testing.expect(t, compressed.server.stats.snapshot_bytes_saved > 10000)
    testing.expect(t, compressed.server.stats.tx_bytes < full.server.stats.tx_bytes)
    // Fixed recent-fact redundancy is the same delivery work in both variants;
    // retain the stronger compression ratio check on the remaining traffic.
    testing.expect(
        t,
        compressed.server.stats.tx_bytes - compressed.server.stats.redundant_fact_bytes <
        (full.server.stats.tx_bytes - full.server.stats.redundant_fact_bytes) / 2,
    )
}

@(test)
large_bootstrap_snapshots_do_not_queue_behind_an_unacknowledged_baseline :: proc(t: ^testing.T) {
    f: Hello_Fixture
    hello_fixture_init(&f)
    defer hello_fixture_destroy(&f)
    f.server.cfg.snapshot_every = 1
    f.server.cfg.unreliable_packet_limit = 512

    for &client in f.clients {
        client.cfg.unreliable_packet_limit = 512
    }

    testing.expect(t, f.server.codecs.snapshot.wire_size + sc.HEADER_BYTES > f.server.cfg.unreliable_packet_limit)

    // Suppress acknowledgements for both peers, without pausing their game or
    // reliable facts. A large first snapshot must not generate a full copy
    // every tick while the reverse path is delayed or loses its first ACK.
    for _ in 0 ..< 24 {
        for &packet, i in f.network.packets {
            if !packet.active || packet.from == 1 {
                continue
            }

            bytes := f.network.bytes[i *
            f.network.config.packet_bytes:i * f.network.config.packet_bytes +
            packet.count]
            meta, _, report := sc.inspect(bytes)

            if report.error == .None && meta.kind == 11 {
                packet.active = false
            }
        }

        hello_fixture_step(&f)
    }

    testing.expect_value(t, f.server.stats.full_snapshots, u64(2))

    for _ in 0 ..< 90 {
        hello_fixture_step(&f)
    }

    testing.expect(t, f.server.stats.delta_snapshots > 0)

    for &client in f.clients {
        testing.expect_value(t, client.phase, net.Phase.Running)
        testing.expect_value(t, client.stats.resyncs, u64(0))
        testing.expect(t, client.facts_contiguous + 3 >= f.server.timeline.head)
    }
}

@(test)
missing_baseline_requests_full_snapshot_without_resetting_the_game :: proc(t: ^testing.T) {
    f: Hello_Fixture
    hello_fixture_init(&f)
    defer hello_fixture_destroy(&f)

    for _ in 0 ..< 80 {
        hello_fixture_step(&f)
    }

    full_before := f.server.stats.full_snapshots
    reset_before := f.clients[0].stats.resyncs
    d.cache_clear(&f.clients[0].snapshot_rx)

    for _ in 0 ..< 30 {
        hello_fixture_step(&f)
    }

    testing.expect(t, f.clients[0].stats.baseline_misses > 0)
    testing.expect(t, f.server.stats.full_snapshots > full_before)
    testing.expect_value(t, f.clients[0].stats.resyncs, reset_before)
    testing.expect_value(t, f.clients[0].phase, net.Phase.Running)
}

@(test)
reused_digest_never_trusts_an_unverified_snapshot_target_hash :: proc(t: ^testing.T) {
    f: Hello_Fixture
    hello_fixture_init(&f)
    defer hello_fixture_destroy(&f)
    packet: []u8

    for _ in 0 ..< 100 {
        hello_fixture_step(&f)

        for queued, i in f.network.packets {
            if !queued.active || queued.from != 1 || queued.to != 2 {
                continue
            }

            bytes := f.network.bytes[i *
            f.network.config.packet_bytes:i * f.network.config.packet_bytes +
            queued.count]
            meta, _, report := sc.inspect(bytes)

            if report.error == .None && meta.kind == 10 {
                packet = make([]u8, len(bytes))
                copy(packet, bytes)
                break
            }
        }

        if packet != nil {
            break
        }
    }

    testing.expect(t, packet != nil)

    if packet == nil {
        return
    }

    defer delete(packet)
    id := u64(0)

    for b, i in packet[sc.HEADER_BYTES + 32:sc.HEADER_BYTES + 40] {
        id |= u64(b) << uint(i * 8)
    }

    testing.expect(t, id > f.clients[0].snapshot_latest)

    for &queued in f.network.packets {
        if queued.to == 2 {
            queued.active = false
        }
    }

    packet[sc.HEADER_BYTES + 40] ~= 1
    checksum := sc.digest(packet[sc.HEADER_BYTES:], sc.digest(packet[:44]))

    for i in 0 ..< 8 {
        packet[44 + i] = u8(checksum >> uint(i * 8))
    }

    before := f.clients[0].stats.rejected_packets
    testing.expect_value(t, tr.send(&f.server.wire, 2, .Unreliable, packet), tr.Send_Result.Sent)
    tr.memory_advance(&f.network, f.clock)
    net.client_pump(&f.clients[0], f.clock * 1000 / 60)
    testing.expect_value(t, f.clients[0].stats.rejected_packets, before + 1)
    _, _, cached := d.cache_find(&f.clients[0].snapshot_rx, id)
    testing.expect(t, !cached)
}

@(test)
forged_acknowledgement_cannot_authorize_an_unsent_baseline :: proc(t: ^testing.T) {
    f: Hello_Fixture
    hello_fixture_init(&f)
    defer hello_fixture_destroy(&f)

    for _ in 0 ..< 40 {
        hello_fixture_step(&f)
    }

    for _ in 0 ..< 6 {
        hello_fixture_step(&f)
    }

    packet: []u8

    for queued, i in f.network.packets {
        if !queued.active || queued.from != 2 {
            continue
        }

        bytes := f.network.bytes[i * f.network.config.packet_bytes:i * f.network.config.packet_bytes + queued.count]
        meta, _, report := sc.inspect(bytes)

        if report.error == .None && meta.kind == 11 {
            packet = make([]u8, len(bytes))
            copy(packet, bytes)
            break
        }
    }

    // If this frame held no ack, advance until a snapshot/ack roundtrip occurs.
    for packet == nil {
        hello_fixture_step(&f)

        for queued, i in f.network.packets {
            if !queued.active || queued.from != 2 {
                continue
            }

            bytes := f.network.bytes[i *
            f.network.config.packet_bytes:i * f.network.config.packet_bytes +
            queued.count]
            meta, _, report := sc.inspect(bytes)

            if report.error == .None && meta.kind == 11 {
                packet = make([]u8, len(bytes))
                copy(packet, bytes)
                break
            }
        }

        assert(f.clock < 100)
    }

    defer delete(packet)

    // Ack's ID is its third u64. Keep the envelope checksum valid.
    for i in 0 ..< 8 {
        packet[sc.HEADER_BYTES + 16 + i] = 255
    }

    checksum := sc.digest(packet[sc.HEADER_BYTES:], sc.digest(packet[:44]))

    for i in 0 ..< 8 {
        packet[44 + i] = u8(checksum >> uint(i * 8))
    }

    before := f.server.stats.rejected_acks
    tr.send(&f.clients[0].wire, 1, .Unreliable, packet)
    hello_fixture_step(&f)
    testing.expect_value(t, f.server.stats.rejected_acks, before + 1)
    testing.expect(t, f.server.snapshot_tx[0].baseline_id < max(u64))
}

@(test)
outbound_rate_budget_defers_work_and_recovers_fairly :: proc(t: ^testing.T) {
    f: Hello_Fixture
    hello_fixture_init(&f, false, 8192)
    defer hello_fixture_destroy(&f)

    for _ in 0 ..< 360 {
        hello_fixture_step(&f)
    }

    testing.expect(t, f.server.stats.egress_deferred > 0)
    f.server.cfg.egress_bytes_per_second = 256 * 1024

    for _ in 0 ..< 180 {
        hello_fixture_step(&f)
    }

    for client in f.clients {
        testing.expect_value(t, client.phase, net.Phase.Running)
    }
}

@(test)
delta_stream_survives_loss_jitter_duplication_and_action_churn :: proc(t: ^testing.T) {
    f: Hello_Fixture
    hello_fixture_init(
        &f,
        faults = {
            latency_ticks = 2,
            jitter_ticks = 3,
            loss_permyriad = 1000,
            duplicate_permyriad = 2000,
            retry_ticks = 3,
        },
    )
    defer hello_fixture_destroy(&f)

    for tick in 0 ..< 360 {
        if tick == 60 || tick == 120 {
            for &client in f.clients {
                _, err := net.client_issue(&client, game.Action{fire = true})
                testing.expect_value(t, err, net.Error.None)
            }
        }

        hello_fixture_step(&f, tick < 180)
    }

    tr.memory_set_faults(&f.network, tr.DEFAULT_FAULTS)

    for _ in 0 ..< 120 {
        hello_fixture_step(&f)
    }

    truth, _ := r.current(&f.server.timeline)

    for &client in f.clients {
        testing.expect_value(t, client.phase, net.Phase.Running)
        frame, _ := r.current(&client.timeline)
        testing.expect(t, reflect.equal(frame.state, truth.state))
        testing.expect(t, client.stats.delta_snapshots > 0)
    }
}

@(test)
losing_acknowledgements_does_not_create_a_delta_dependency_chain :: proc(t: ^testing.T) {
    f: Hello_Fixture
    hello_fixture_init(&f)
    defer hello_fixture_destroy(&f)

    for _ in 0 ..< 60 {
        hello_fixture_step(&f)
    }

    for _ in 0 ..< 180 {
        for &packet, i in f.network.packets {
            if !packet.active || packet.from != 2 {
                continue
            }

            bytes := f.network.bytes[i *
            f.network.config.packet_bytes:i * f.network.config.packet_bytes +
            packet.count]
            meta, _, report := sc.inspect(bytes)

            if report.error == .None && meta.kind == 11 {
                packet.active = false
            }
        }

        hello_fixture_step(&f)
    }

    testing.expect(t, f.clients[0].stats.baseline_misses > 0)

    for _ in 0 ..< 60 {
        hello_fixture_step(&f)
    }

    truth, _ := r.current(&f.server.timeline)
    frame, _ := r.current(&f.clients[0].timeline)
    testing.expect(t, reflect.equal(frame.state, truth.state))
    testing.expect_value(t, f.clients[0].phase, net.Phase.Running)
}
