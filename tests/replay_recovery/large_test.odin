package replay_recovery_test

import "core:reflect"
import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"
import tr "godot:replay/transport"
import sample "shared/archive"

@(test)
large_private_cave_archive_repairs_loss_and_reordering_with_bounded_traffic :: proc(t: ^testing.T) {
    source, resumed: sample.Server
    defer net.server_destroy(&source)
    defer net.server_destroy(&resumed)
    testing.expect_value(t, sample.authority(&source), net.Error.None)
    cp: sample.Checkpoint
    defer net.checkpoint_destroy(&cp)
    testing.expect_value(t, net.checkpoint_capture(&source, &cp), net.Error.None)
    network: tr.Memory
    testing.expect(
        t,
        tr.memory_init(
            &network,
            817,
            {2, 128, 1200, 32768},
            {latency_ticks = 4, jitter_ticks = 12, loss_permyriad = 2000, duplicate_permyriad = 3000, retry_ticks = 3},
        ),
    )
    defer tr.memory_destroy(&network)
    a, b: tr.Memory_Endpoint
    tr.memory_open(&network, &a, 1)
    tr.memory_open(&network, &b, 2)
    wa, wb := tr.memory_transport(&a), tr.memory_transport(&b)
    defer tr.close(&wa)
    defer tr.close(&wb)
    scope := SCOPE
    scope.content = sample.CONTENT
    sender: rec.Sender
    receiver: rec.Receiver(sample.World, sample.Control, sample.Action, sample.Event, sample.SEATS)
    defer rec.sender_destroy(&sender)
    defer rec.receiver_destroy(&receiver)
    cfg := rec.DEFAULT_CONFIG
    cfg.bytes_per_second = 32 * 1024
    cfg.bytes_per_update = 4096
    rec.sender_init(&sender, scope, 2, wa, cfg)
    rec.receiver_init(&receiver, scope, 1, wb, sample.model(), cfg)
    testing.expect_value(t, rec.sender_publish(&sender, &cp, sample.model(), 0), rec.Error.None)
    testing.expect(t, sender.archive.bytes > tr.MAX_PACKET_BYTES)
    buffer: [1200]u8
    elapsed := u64(0)
    checked_index := false

    for tick in u64(1) ..< 3000 {
        elapsed = tick * 10
        tr.memory_advance(&network, tick)

        for _ in 0 ..< 128 {
            packet := tr.receive(&wa, buffer[:])

            if packet.state == .Empty {
                break
            }

            testing.expect_value(t, packet.state, tr.Receive_State.Received)
            rec.sender_receive(&sender, packet.from, buffer[:packet.count], elapsed)
        }

        for _ in 0 ..< 128 {
            packet := tr.receive(&wb, buffer[:])

            if packet.state == .Empty {
                break
            }

            testing.expect_value(t, packet.state, tr.Receive_State.Received)
            rec.receiver_receive(&receiver, packet.from, buffer[:packet.count], elapsed)
            meta, fingerprint, _ := sc.inspect(buffer[:packet.count])

            if !checked_index && receiver.active && receiver.count > 0 && meta.kind == 0x5102 {
                // A checksum-valid but out-of-range chunk must not change accepted
                // membership in the reassembly bitmap or corrupt an earlier chunk.
                for field in receiver.codecs.chunk.fields {
                    if field.path == "$.index" {
                        buffer[sc.HEADER_BYTES + field.wire_offset] = 255
                        buffer[sc.HEADER_BYTES + field.wire_offset + 1] = 255
                    }
                }

                sc.pack_bytes(fingerprint, meta, buffer[sc.HEADER_BYTES:packet.count], buffer[:])
                before := receiver.count
                testing.expect_value(
                    t,
                    rec.receiver_receive(&receiver, packet.from, buffer[:packet.count], elapsed),
                    rec.Received.Rejected,
                )
                testing.expect_value(t, receiver.count, before)
                checked_index = true
            }
        }

        testing.expect_value(t, rec.sender_update(&sender, elapsed), rec.Error.None)
        testing.expect_value(t, rec.receiver_update(&receiver, elapsed), rec.Error.None)

        if sender.phase == .Complete {
            break
        }
    }

    testing.expect_value(t, sender.phase, rec.Phase.Complete)
    testing.expect(t, checked_index)
    testing.expect(t, sender.stats.retries > 0 && receiver.stats.duplicates > 0)
    testing.expect(
        t,
        sender.stats.tx_bytes <= elapsed * u64(cfg.bytes_per_second) / 1000 + u64(cfg.bytes_per_update) * 2,
    )
    decoded, ok := rec.receiver_checkpoint(&receiver, sender.acknowledged.archive)
    testing.expect(t, ok)
    testing.expect(t, reflect.equal(decoded.frame, cp.frame))
    testing.expect_value(
        t,
        net.server_restore(&resumed, decoded, sample.model(), {}, {epoch = 2, local_seat = 1}),
        net.Error.None,
    )
    frame, _ := r.current(&resumed.timeline)
    testing.expect_value(t, frame.state.cave.players[0].bag[0].count, u16(3))
    testing.expect_value(t, frame.state.cave.rocks.count, u32(1))
    testing.expect_value(t, net.server_step(&resumed), net.Error.None)
    frame, _ = r.current(&resumed.timeline)
    testing.expect_value(t, frame.tick, cp.frame.tick + 1)
    testing.expect_value(t, frame.state.private_data, cp.frame.state.private_data)
}
