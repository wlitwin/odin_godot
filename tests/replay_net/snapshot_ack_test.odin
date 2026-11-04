package replay_net_test

import "core:testing"
import "core:fmt"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import game "../../examples/replay_hello/shared/hello"

Ack_Record :: struct {
    generation, serial, id, hash: u64,
}

first_hello_ack :: proc(f: ^Hello_Fixture) -> int {
    for _ in 0 ..< 40 {
        hello_fixture_step(f)

        for packet, i in f.network.packets {
            if !packet.active || packet.from != 2 {
                continue
            }

            bytes := f.network.bytes[i *
            f.network.config.packet_bytes:i * f.network.config.packet_bytes +
            packet.count]
            meta, _, report := sc.inspect(bytes)

            if report.error == .None && meta.kind == 11 {
                return i
            }
        }
    }

    return -1
}

@(test)
delayed_large_snapshot_ack_does_not_block_a_receipt_action :: proc(t: ^testing.T) {
    f: Hello_Fixture
    hello_fixture_init(&f, compressed = false, action_timing = .Receipt)
    defer hello_fixture_destroy(&f)
    f.server.cfg.unreliable_packet_limit = 512

    for &c in f.clients {
        c.cfg.unreliable_packet_limit = 512
    }

    index := first_hello_ack(&f)
    testing.expect(t, index >= 0)

    if index < 0 {
        return
    }

    channel := f.network.packets[index].channel
    // Hold an actual generated ACK for a second. Memory preserves reliable
    // per-direction ordering, so this exposes an application channel dependency.
    f.network.packets[index].ready = false
    f.network.packets[index].due = f.clock + 60
    sequence, error := net.client_issue(&f.clients[0], game.Action{fire = true})
    testing.expect_value(t, error, net.Error.None)

    for _ in 0 ..< 8 {
        hello_fixture_step(&f)
    }

    frame, _ := r.current(&f.server.timeline)
    fmt.printf(
        "SNAPSHOT_ACK_ACTION channel=%v authority_shots=%d held_until=%d now=%d\n",
        channel,
        frame.state.shots,
        f.network.packets[index].due,
        f.clock,
    )
    testing.expect_value(t, frame.state.shots, u32(1))

    // This first-baseline fixture may await the repeated ACK before it can
    // confirm a newer snapshot. Delivery to authority must already have happened.
    for _ in 0 ..< 90 {
        hello_fixture_step(&f)
    }

    outcomes: [4]net.Action_Outcome
    n := net.client_outcomes(&f.clients[0], outcomes[:])
    testing.expect_value(t, n, 1)

    if n == 1 {
        testing.expect(t, outcomes[0].sequence == sequence && outcomes[0].applied)
    }
}

@(test)
lost_snapshot_ack_is_repeated_and_releases_the_large_snapshot_gate :: proc(t: ^testing.T) {
    f: Hello_Fixture
    hello_fixture_init(&f, compressed = false)
    defer hello_fixture_destroy(&f)
    f.server.cfg.unreliable_packet_limit = 512

    for &c in f.clients {
        c.cfg.unreliable_packet_limit = 512
        c.snapshot_parts_enabled = false
    }

    index := first_hello_ack(&f)
    testing.expect(t, index >= 0)

    if index < 0 {
        return
    }

    f.network.packets[index].active = false

    for _ in 0 ..< 100 {
        hello_fixture_step(&f)
    }

    testing.expect(
        t,
        f.clients[0].snapshot_latest > 1 && f.clients[0].phase == .Running && f.clients[0].stats.resyncs == 0,
    )

    for peer, i in f.server.peers {
        if peer.connection == 2 {
            testing.expect(t, f.server.snapshot_tx[i].baseline_id > 1)
        }
    }
}

@(test)
reordered_and_invalid_acknowledgments_cannot_replace_a_newer_baseline :: proc(t: ^testing.T) {
    f: Hello_Fixture
    hello_fixture_init(&f, compressed = false)
    defer hello_fixture_destroy(&f)
    f.server.cfg.unreliable_packet_limit = 512

    for &c in f.clients {
        c.cfg.unreliable_packet_limit = 512
    }

    index := first_hello_ack(&f)
    testing.expect(t, index >= 0)

    if index < 0 {
        return
    }

    queued := f.network.packets[index]
    bytes := f.network.bytes[index *
    f.network.config.packet_bytes:index * f.network.config.packet_bytes +
    queued.count]
    schema: sc.Schema
    testing.expect_value(t, sc.init(&schema, Ack_Record).error, sc.Error.None)
    defer sc.destroy(&schema)
    testing.expect_value(t, schema.fingerprint, f.clients[0].codecs.snapshot_ack.fingerprint)
    old: Ack_Record
    _, decoded := sc.unpack(
        &schema,
        &old,
        bytes,
        {kind = 11, epoch = f.server.cfg.epoch, content = f.server.cfg.content},
    )
    testing.expect_value(t, decoded.error, sc.Error.None)

    for _ in 0 ..< 80 {
        hello_fixture_step(&f)
    }

    peer_index := -1

    for peer, i in f.server.peers {
        if peer.connection == 2 {
            peer_index = i
            break
        }
    }

    testing.expect(t, peer_index >= 0)

    if peer_index < 0 {
        return
    }

    before := f.server.snapshot_tx[peer_index].baseline_id
    hash := f.server.snapshot_tx[peer_index].baseline_hash
    testing.expect(t, before > old.id)
    rejected := f.server.stats.rejected_acks

    for kind in 0 ..< 3 {
        ack := old

        if kind == 1 {
            ack.id = f.server.snapshot_tx[peer_index].next_id + 1000
        }

        if kind == 2 {
            ack.serial += 1
        }

        packet: [128]u8
        testing.expect_value(
            t,
            sc.pack(&schema, ack, {kind = 11, epoch = f.server.cfg.epoch, content = f.server.cfg.content}, packet[:]).error,
            sc.Error.None,
        )
        testing.expect_value(
            t,
            tr.send(
                &f.clients[0].wire,
                1,
                .Unreliable,
                packet[:sc.HEADER_BYTES + f.clients[0].codecs.snapshot_ack.wire_size],
            ),
            tr.Send_Result.Sent,
        )
    }

    tr.memory_advance(&f.network, f.clock)
    testing.expect_value(t, net.server_pump(&f.server, f.clock * 1000 / 60), net.Error.None)
    testing.expect(t, f.server.snapshot_tx[peer_index].baseline_id >= before)

    if f.server.snapshot_tx[peer_index].baseline_id == before {
        testing.expect_value(t, f.server.snapshot_tx[peer_index].baseline_hash, hash)
    }

    testing.expect_value(t, f.server.stats.rejected_acks, rejected + 2)
}
