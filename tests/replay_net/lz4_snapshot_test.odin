package replay_net_test
import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import delta "godot:replay/delta"

@(test)
lz4_snapshot_selection_preserves_worlds_and_reduces_repetitive_payloads :: proc(t: ^testing.T) {
    modern, old: Parts_Fixture
    parts_init(&modern)
    parts_init(&old)
    modern.client.lz4_snapshots_enabled = true
    defer parts_destroy(&modern)
    defer parts_destroy(&old)

    for _ in 0 ..< 400 {
        parts_step(&modern)
        parts_step(&old)
    }

    testing.expect(t, modern.server.stats.lz4_snapshots > 300 && modern.client.stats.lz4_snapshots > 300)
    testing.expect(t, modern.server.stats.tx_bytes < old.server.stats.tx_bytes / 4)

    // Different fragment overhead can leave the latest received worlds at
    // different ticks. Stop advancing both authorities and require exact settled
    // equality at their common final tick, not equality between different times.
    for fixture in ([2]^Parts_Fixture{&modern, &old}) {
        for _ in 0 ..< 30 {
            tr.memory_advance(&fixture.memory, fixture.clock)
            net.server_pump(&fixture.server, fixture.clock * 1000 / 60)
            net.client_pump(&fixture.client, fixture.clock * 1000 / 60)
            fixture.clock += 1
        }

        testing.expect_value(t, fixture.client.authority_frame.tick, fixture.server.timeline.head)
    }

    testing.expect(t, reflect.equal(modern.client.authority_frame.state, old.client.authority_frame.state))
    testing.expect_value(t, modern.client.stats.rejected_packets, u64(0))
    testing.expect_value(t, old.server.stats.lz4_snapshots, u64(0))
}

@(test)
lz4_snapshot_baseline_miss_resyncs_encoding_without_resetting_game :: proc(t: ^testing.T) {
    f: Parts_Fixture
    parts_init(&f)
    f.client.lz4_snapshots_enabled = true
    defer parts_destroy(&f)

    for _ in 0 ..< 100 {
        parts_step(&f)
    }

    before := f.server.stats.full_snapshots
    delta.cache_clear(&f.client.snapshot_rx)

    for _ in 0 ..< 150 {
        parts_step(&f)
    }

    testing.expect(t, f.client.stats.baseline_misses > 0 && f.server.stats.full_snapshots > before)
    testing.expect_value(t, f.client.stats.resyncs, u64(0))
    testing.expect(t, f.client.authority_frame.tick + 10 >= f.server.timeline.head)
}

@(test)
lz4_snapshot_requires_the_verified_target_hash :: proc(t: ^testing.T) {
    f: Parts_Fixture
    parts_init(&f)
    f.client.lz4_snapshots_enabled = true
    defer parts_destroy(&f)

    for _ in 0 ..< 100 {
        parts_step(&f)
    }

    packet: []u8

    for p, i in f.memory.packets {
        if p.active && p.from == 1 && p.to == 2 && parts_packet_kind(&f, i) == 18 {
            packet = make([]u8, p.count)
            copy(packet, f.memory.bytes[i * f.memory.config.packet_bytes:i * f.memory.config.packet_bytes + p.count])
            break
        }
    }

    testing.expect(t, packet != nil)

    if packet == nil {
        return
    }

    defer delete(packet)

    for &p in f.memory.packets {
        p.active = false
    }

    tr.memory_set_faults(&f.memory, tr.DEFAULT_FAULTS)
    packet[sc.HEADER_BYTES + 40] ~= 1
    parts_checksum(packet)
    before := f.client.snapshot_latest
    rejected := f.client.stats.rejected_packets
    parts_deliver(&f, packet)
    testing.expect_value(t, f.client.snapshot_latest, before)
    testing.expect_value(t, f.client.stats.rejected_packets, rejected + 1)
}

lz4_varied :: proc(tick: u64, index: int) -> u32 {
    h := u32(tick) * 2654435761 ~ u32(index / 4) * 2246822519
    h ~= h >> 16
    h *= 2246822519
    h ~= h >> 13
    return h
}

@(test)
lz4_snapshots_survive_fragmentation_loss_and_reordering :: proc(t: ^testing.T) {
    f: Parts_Fixture
    parts_init(
        &f,
        faults = {
            latency_ticks = 4,
            jitter_ticks = 3,
            loss_permyriad = 1000,
            duplicate_permyriad = 1000,
            retry_ticks = 3,
        },
    )
    defer parts_destroy(&f)
    f.client.lz4_snapshots_enabled = true

    step := proc(w: ^Parts_World, controls: [2]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
        w.tick = ctx.tick

        for &v, i in w.payload {
            v = lz4_varied(ctx.tick, i)
        }
    }

    valid := proc(w: Parts_World) -> bool {
        if w.tick == 0 {
            return true
        }

        for v, i in w.payload {
            if v != lz4_varied(w.tick, i) {
                return false
            }
        }

        return true
    }

    f.server.model.step, f.client.model.step = step, step
    f.server.model.state_valid, f.client.model.state_valid = valid, valid

    for _ in 0 ..< 500 {
        parts_step(&f)
    }

    tr.memory_set_faults(&f.memory, tr.DEFAULT_FAULTS)

    for _ in 0 ..< 100 {
        parts_step(&f)
    }

    testing.expect(t, f.server.stats.lz4_snapshots > 100 && f.server.stats.fragmented_snapshots > 100)
    testing.expect(t, f.client.stats.lz4_snapshots > 100 && f.client.stats.snapshot_parts_received > 100)
    testing.expect(
        t,
        valid(f.client.authority_frame.state) && f.client.authority_frame.tick + 5 >= f.server.timeline.head,
    )
    testing.expect_value(t, f.client.presentation_failure.serial, u64(0))
}

@(test)
receiver_refuses_lz4_when_it_was_not_advertised :: proc(t: ^testing.T) {
    modern, old: Parts_Fixture
    parts_init(&modern)
    parts_init(&old)
    modern.client.lz4_snapshots_enabled = true
    defer parts_destroy(&modern)
    defer parts_destroy(&old)

    for _ in 0 ..< 100 {
        parts_step(&modern)
        parts_step(&old)
    }

    packet: []u8

    for p, i in modern.memory.packets {
        if p.active && p.from == 1 && p.to == 2 && parts_packet_kind(&modern, i) == 18 {
            packet = make([]u8, p.count)
            copy(
                packet,
                modern.memory.bytes[i *
                modern.memory.config.packet_bytes:i * modern.memory.config.packet_bytes +
                p.count],
            )
            break
        }
    }

    testing.expect(t, packet != nil)

    if packet == nil {
        return
    }

    defer delete(packet)

    for &p in old.memory.packets {
        p.active = false
    }

    tr.memory_set_faults(&old.memory, tr.DEFAULT_FAULTS)
    latest, rejected := old.client.snapshot_latest, old.client.stats.rejected_packets
    parts_deliver(&old, packet)
    testing.expect_value(t, old.client.snapshot_latest, latest)
    testing.expect_value(t, old.client.stats.rejected_packets, rejected + 1)
}
