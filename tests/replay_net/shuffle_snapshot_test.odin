package replay_net_test
import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import delta "godot:replay/delta"

shuffle_value :: proc(tick: u64, index: int) -> u32 {
    value := u32(tick) * 2654435761 ~ u32(index) * 2246822519
    value ~= value >> 16
    value *= 2246822519
    value ~= value >> 13
    return value & 0xffff
}

shuffle_fixture :: proc(f: ^Parts_Fixture, enabled: bool = true, fragmented: bool = true) {
    parts_init(f)
    f.client.lz4_snapshots_enabled = true
    f.client.snapshot_shuffle_enabled = enabled

    step := proc(w: ^Parts_World, controls: [2]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
        w.tick = ctx.tick

        for &value, i in w.payload {
            value = shuffle_value(ctx.tick, i)
        }
    }

    valid := proc(w: Parts_World) -> bool {
        if w.tick == 0 {
            return true
        }

        for value, i in w.payload {
            if value != shuffle_value(w.tick, i) {
                return false
            }
        }

        return true
    }

    f.server.model.step, f.client.model.step = step, step
    f.server.model.state_valid, f.client.model.state_valid = valid, valid

    if !fragmented {
        f.server.cfg.unreliable_packet_limit = 8192
        f.client.cfg.unreliable_packet_limit = 8192
    }
}

@(test)
shuffled_snapshots_preserve_exact_worlds_and_reduce_array_payloads :: proc(t: ^testing.T) {
    modern, legacy: Parts_Fixture
    shuffle_fixture(&modern)
    shuffle_fixture(&legacy, false)
    defer parts_destroy(&modern)
    defer parts_destroy(&legacy)

    for _ in 0 ..< 500 {
        parts_step(&modern)
        parts_step(&legacy)
    }

    testing.expect(t, modern.server.stats.shuffled_snapshots > 200 && modern.client.stats.shuffled_snapshots > 200)
    testing.expect(t, modern.server.stats.shuffle_bytes_saved > 100000)
    testing.expect(t, modern.server.stats.tx_bytes < legacy.server.stats.tx_bytes)
    testing.expect_value(t, legacy.server.stats.shuffled_snapshots, u64(0))

    for f in ([2]^Parts_Fixture{&modern, &legacy}) {
        for _ in 0 ..< 60 {
            tr.memory_advance(&f.memory, f.clock)
            net.server_pump(&f.server, f.clock * 1000 / 60)
            net.client_pump(&f.client, f.clock * 1000 / 60)
            f.clock += 1
        }

        testing.expect_value(t, f.client.authority_frame.tick, f.server.timeline.head)
        testing.expect_value(t, f.client.stats.rejected_packets, u64(0))
    }

    testing.expect(t, reflect.equal(modern.client.authority_frame, legacy.client.authority_frame))
}

shuffle_capture :: proc(f: ^Parts_Fixture) -> []u8 {
    for _ in 0 ..< 100 {
        parts_step(f)
    }

    saved: []u8

    for packet, i in f.memory.packets {
        if !packet.active || packet.from != 1 || parts_packet_kind(f, i) != 24 {
            continue
        }

        bytes := f.memory.bytes[i * f.memory.config.packet_bytes:i * f.memory.config.packet_bytes + packet.count]
        saved = make([]u8, len(bytes))
        copy(saved, bytes)
        break
    }

    assert(saved != nil)

    for &packet in f.memory.packets {
        packet.active = false
    }

    tr.memory_set_faults(&f.memory, tr.DEFAULT_FAULTS)
    return saved
}

@(test)
shuffled_snapshot_requires_plan_signature_target_hash_and_valid_compressed_bytes :: proc(t: ^testing.T) {
    for mode in 0 ..< 3 {
        f: Parts_Fixture
        shuffle_fixture(&f, fragmented = false)
        packet := shuffle_capture(&f)
        before := f.client.snapshot_latest
        rejected := f.client.stats.rejected_packets

        if mode == 0 {
            packet[sc.HEADER_BYTES + 48] ~= 1
        }

        if mode == 1 {
            packet[sc.HEADER_BYTES + 40] ~= 1
        }

        if mode == 2 {
            packet[len(packet) - 1] ~= 0x81
        }

        parts_checksum(packet)
        parts_deliver(&f, packet)
        testing.expect_value(t, f.client.snapshot_latest, before)
        testing.expect_value(t, f.client.stats.rejected_packets, rejected + 1)
        delete(packet)
        parts_destroy(&f)
    }
}

@(test)
shuffled_snapshot_missing_baseline_requests_recovery_without_publishing :: proc(t: ^testing.T) {
    f: Parts_Fixture
    shuffle_fixture(&f, fragmented = false)
    defer parts_destroy(&f)
    packet := shuffle_capture(&f)
    defer delete(packet)
    before := f.client.snapshot_latest
    misses := f.client.stats.baseline_misses
    delta.cache_clear(&f.client.snapshot_rx)
    parts_deliver(&f, packet)
    testing.expect_value(t, f.client.snapshot_latest, before)
    testing.expect_value(t, f.client.stats.baseline_misses, misses + 1)

    for _ in 0 ..< 100 {
        parts_step(&f)
    }

    testing.expect(t, f.client.authority_frame.tick + 12 >= f.server.timeline.head)
    testing.expect_value(t, f.client.stats.resyncs, u64(0))
}

@(test)
shuffled_snapshots_survive_loss_and_parity_reconstruction :: proc(t: ^testing.T) {
    f: Parts_Fixture
    shuffle_fixture(&f)
    defer parts_destroy(&f)
    tr.memory_set_faults(
        &f.memory,
        {latency_ticks = 4, jitter_ticks = 3, loss_permyriad = 1000, duplicate_permyriad = 1000, retry_ticks = 3},
    )

    for _ in 0 ..< 600 {
        parts_step(&f)
    }

    testing.expect(t, f.client.stats.shuffled_snapshots > 100 && f.client.stats.snapshot_shards_recovered > 0)
    tr.memory_set_faults(&f.memory, tr.DEFAULT_FAULTS)

    for _ in 0 ..< 100 {
        parts_step(&f)
    }

    testing.expect(t, f.client.authority_frame.tick + 12 >= f.server.timeline.head)
    testing.expect_value(t, f.client.stats.rejected_packets, u64(0))
    testing.expect_value(t, f.client.stats.resyncs, u64(0))
}

@(test)
shuffled_snapshot_is_rejected_when_the_recipient_did_not_offer_it :: proc(t: ^testing.T) {
    modern, legacy: Parts_Fixture
    shuffle_fixture(&modern, fragmented = false)
    shuffle_fixture(&legacy, false, false)
    defer parts_destroy(&modern)
    defer parts_destroy(&legacy)
    packet := shuffle_capture(&modern)
    defer delete(packet)

    for _ in 0 ..< 100 {
        parts_step(&legacy)
    }

    for &p in legacy.memory.packets {
        p.active = false
    }

    tr.memory_set_faults(&legacy.memory, tr.DEFAULT_FAULTS)
    before := legacy.client.snapshot_latest
    rejected := legacy.client.stats.rejected_packets
    parts_deliver(&legacy, packet)
    testing.expect_value(t, legacy.client.snapshot_latest, before)
    testing.expect_value(t, legacy.client.stats.rejected_packets, rejected + 1)
    testing.expect_value(t, legacy.server.stats.shuffled_snapshots, u64(0))
    testing.expect(t, legacy.client.shuffle_workspace == nil)
}
