package replay_transfer_test
import "core:testing"
import tf "godot:replay/transfer"
import tr "godot:replay/transport"
import sc "godot:replay/schema"

Reliable_Gate :: struct {
    base:                                tr.Transport,
    reliable, unreliable, chunk_packets: u64,
}

reliable_gate_wire :: proc(g: ^Reliable_Gate) -> tr.Transport {
    return {user = g, connected = proc(user: rawptr, id: tr.Peer_Id) -> bool {
            return tr.peer_connected(&(cast(^Reliable_Gate)user).base, id)
        }, send = proc(user: rawptr, id: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> tr.Send_Result {
            g := cast(^Reliable_Gate)user

            if channel == .Unreliable {
                g.unreliable += 1
                return .Backpressure
            }

            result := tr.send(&g.base, id, channel, bytes)

            if result == .Sent {
                g.reliable += 1
                meta, _, report := sc.inspect(bytes)

                if report.error == .None && meta.kind == tf.DEFAULT_KIND_BASE + 2 {
                    g.chunk_packets += 1
                }
            }

            return result
        }}
}

@(test)
reliable_transfer_progresses_with_unreliable_capacity_exhausted_and_does_not_resend_chunks :: proc(t: ^testing.T) {
    f: Fixture
    faults := tr.DEFAULT_FAULTS
    faults.latency_ticks, faults.jitter_ticks, faults.loss_permyriad = 200, 20, 1000
    init(&f, faults)
    defer destroy(&f)
    a := Reliable_Gate {
        base = f.sender.wire,
    }
    b := Reliable_Gate {
        base = f.receiver.wire,
    }
    f.sender.wire = reliable_gate_wire(&a)
    f.receiver.wire = reliable_gate_wire(&b)
    payload: [32000]u8
    bytes := packet(payload[:], 1)
    defer delete(bytes)
    testing.expect_value(t, tf.sender_begin(&f.sender, bytes, 0, .Reliable), tf.Error.None)

    for _ in 0 ..< 2000 {
        pump(&f)

        if f.sender.phase == .Complete {
            break
        }
    }

    testing.expect_value(t, f.sender.phase, tf.Phase.Complete)
    testing.expect_value(t, f.installed, u32(1))
    testing.expect(t, f.receiver.reliable_replies)
    testing.expect_value(t, a.chunk_packets, u64((len(bytes) + tf.CHUNK_BYTES - 1) / tf.CHUNK_BYTES))
    testing.expect(t, a.reliable > 0 && b.reliable > 0 && a.unreliable == 0 && b.unreliable == 0)
    testing.expect(
        t,
        f.sender.stats.tx_bytes <=
        f.clock * u64(f.sender.cfg.bytes_per_second) / 1000 + u64(f.sender.cfg.bytes_per_update) * 2,
    )
}

@(test)
reply_upgrade_requires_valid_peer_traffic_and_stale_datagrams_do_not_downgrade_it :: proc(t: ^testing.T) {
    f: Fixture
    init(&f)
    defer destroy(&f)
    capture: Capture
    f.sender.wire = capture_wire(&capture)
    payload: [256]u8
    bytes := packet(payload[:], 1)
    defer delete(bytes)
    tf.sender_begin(&f.sender, bytes, 0, .Reliable)
    tf.sender_update(&f.sender, 0)
    testing.expect_value(
        t,
        tf.blob_receive(&f.receiver, 99, capture.bytes[:capture.count], 0, .Reliable),
        tf.Received.Rejected,
    )
    testing.expect(t, !f.receiver.reliable_replies)
    bad := capture.bytes
    bad[capture.count - 1] ~= 1
    testing.expect_value(t, tf.blob_receive(&f.receiver, 1, bad[:capture.count], 0, .Reliable), tf.Received.Rejected)
    testing.expect(t, !f.receiver.reliable_replies)
    testing.expect_value(
        t,
        tf.blob_receive(&f.receiver, 1, capture.bytes[:capture.count], 0, .Reliable),
        tf.Received.Accepted,
    )
    testing.expect(t, f.receiver.reliable_replies)
    testing.expect_value(
        t,
        tf.blob_receive(&f.receiver, 1, capture.bytes[:capture.count], 0, .Unreliable),
        tf.Received.Accepted,
    )
    testing.expect(t, f.receiver.reliable_replies)
}
