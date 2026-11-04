package replay_transfer_test
import "core:testing"
import "core:mem"
import tf "godot:replay/transfer"
import sc "godot:replay/schema"
import tr "godot:replay/transport"
import r "godot:replay"

Layout_Row :: struct {
    position: u32,
    health:   u8,
    spare:    [7]u8,
}

Layout_World :: struct {
    rows: [1024]Layout_Row,
}

layout_payload :: proc(schema: ^sc.Schema) -> []u8 {
    assert(sc.init(schema, Layout_World).error == .None)
    world := new(Layout_World)
    defer free(world)
    rng := r.rng_make(919)

    for &row in world.rows {
        row.position = u32(r.rng_next(&rng))
        row.health = u8(r.rng_next(&rng) % 4)
    }

    bytes := make([]u8, schema.wire_size)
    assert(sc.encode(schema, world^, bytes).error == .None)
    return bytes
}

@(test)
layout_transfer_roundtrips_raw_identity_under_loss_and_retains_prior_receipts :: proc(t: ^testing.T) {
    schema: sc.Schema
    payload := layout_payload(&schema)
    defer sc.destroy(&schema)
    defer delete(payload)
    f: Fixture
    faults := tr.DEFAULT_FAULTS
    faults.latency_ticks, faults.jitter_ticks, faults.loss_permyriad, faults.duplicate_permyriad = 30, 20, 1000, 1000
    init(&f, faults)
    defer destroy(&f)
    f.sender.compress, f.sender.shuffle = true, true
    f.sender.layout = {&schema, sc.HEADER_BYTES}
    f.receiver.layout = f.sender.layout

    for tick in 1 ..= 2 {
        bytes := packet(payload, u64(tick))
        defer delete(bytes)
        testing.expect_value(t, tf.sender_begin(&f.sender, bytes, f.clock), tf.Error.None)
        testing.expect(t, f.sender.wire_layout != 0 && f.sender.stats.shuffle_bytes_saved > 0)
        testing.expect_value(t, f.sender.archive.hash, tf.hash(bytes))

        for _ in 0 ..< 1500 {
            pump(&f)

            if f.sender.phase == .Complete {
                break
            }
        }

        testing.expect_value(t, f.sender.phase, tf.Phase.Complete)
        testing.expect_value(t, f.digest, tf.hash(payload))
        testing.expect_value(t, f.installed, u32(tick))
        testing.expect_value(t, f.receiver.latest.archive, f.sender.archive)
    }

    testing.expect_value(t, f.receiver.previous_receipt.archive.sequence, u64(1))
    testing.expect_value(t, f.receiver.stats.shuffled_archives, u64(2))
}

@(test)
layout_offers_reject_unagreed_or_changed_plans_before_installation :: proc(t: ^testing.T) {
    schema: sc.Schema
    payload := layout_payload(&schema)
    defer sc.destroy(&schema)
    defer delete(payload)

    for mode in 0 ..< 4 {
        f: Fixture
        init(&f)
        defer destroy(&f)
        f.sender.compress, f.sender.shuffle = true, true
        f.sender.layout = {&schema, sc.HEADER_BYTES}

        if mode != 0 {
            f.receiver.layout = f.sender.layout
        }

        if mode == 1 {
            f.receiver.layout.offset += 1
        }

        bytes := packet(payload, 1)
        defer delete(bytes)
        tf.sender_begin(&f.sender, bytes, 0)
        capture: Capture
        f.sender.wire = capture_wire(&capture)
        tf.sender_update(&f.sender, 0)
        testing.expect_value(t, tf.destination(capture.bytes[:capture.count]), tf.Destination.Receiver)

        if mode == 2 {
            capture.bytes[capture.count - 1] ~= 1
            meta, fp, _ := sc.inspect(capture.bytes[:capture.count])
            sc.pack_bytes(fp, meta, capture.bytes[sc.HEADER_BYTES:capture.count], capture.bytes[:capture.count])
        }

        result := tf.blob_receive(&f.receiver, 1, capture.bytes[:capture.count], 0)

        if mode < 3 {
            testing.expect_value(t, result, tf.Received.Rejected)
            testing.expect(t, !f.receiver.active && len(f.receiver.decoded) == 0 && f.installed == 0)
        } else {
            testing.expect_value(t, result, tf.Received.Accepted)
            f.receiver.layout = {} // Revoked local plan cannot partially install in flight.
            f.sender.wire = tr.memory_transport(&f.endpoints[0])

            for _ in 0 ..< 1500 {
                pump(&f)

                if f.sender.phase == .Failed {
                    break
                }
            }

            testing.expect(t, f.installed == 0 && f.receiver.latest.archive.sequence == 0)
        }
    }
}

@(test)
layout_is_optional_and_never_expands_the_selected_representation :: proc(t: ^testing.T) {
    schema: sc.Schema
    payload := layout_payload(&schema)
    defer sc.destroy(&schema)
    defer delete(payload)
    f: Fixture
    init(&f)
    defer destroy(&f)
    f.sender.compress = true
    bytes := packet(payload, 1)
    defer delete(bytes)
    f.sender.layout = {&schema, sc.HEADER_BYTES}
    tf.sender_begin(&f.sender, bytes, 0)
    plain := len(f.sender.wire_bytes)
    testing.expect_value(t, f.sender.wire_layout, u64(0))
    tf.sender_cancel(&f.sender)
    f.sender.shuffle = true
    tf.sender_begin(&f.sender, bytes, 0)
    testing.expect(t, f.sender.wire_layout != 0 && len(f.sender.wire_bytes) + 8 < plain)
    tf.sender_cancel(&f.sender)
    f.sender.layout.offset = max(int)
    tf.sender_begin(&f.sender, bytes, 0)
    testing.expect(t, f.sender.wire_layout == 0 && len(f.sender.wire_bytes) == plain)
    // Reusing the sender's owned canonical bytes must copy before freeing them.
    tf.sender_cancel(&f.sender)
    tf.sender_begin(&f.sender, bytes, 0)
    f.sender.phase = .Complete
    testing.expect_value(t, tf.sender_begin(&f.sender, f.sender.bytes, 0), tf.Error.None)
    testing.expect(t, mem.compare(f.sender.bytes, bytes) == 0 && f.sender.archive.hash == tf.hash(bytes))
    tf.sender_cancel(&f.sender)
    f.sender.layout = {&schema, sc.HEADER_BYTES}
    zeros := make([]u8, len(payload))
    defer delete(zeros)
    zero_packet := packet(zeros, 2)
    defer delete(zero_packet)
    tf.sender_begin(&f.sender, zero_packet, 0)
    testing.expect(t, f.sender.wire_layout == 0 && len(f.sender.wire_bytes) > 0)
}

@(test)
layout_can_compress_an_archive_that_plain_blocks_cannot_reduce :: proc(t: ^testing.T) {
    schema: sc.Schema
    assert(sc.init(&schema, Layout_World).error == .None)
    defer sc.destroy(&schema)
    world := new(Layout_World)
    defer free(world)
    rng := r.rng_make(1741)

    for &row in world.rows {
        row.position = u32(r.rng_next(&rng))

        for &byte in row.spare {
            byte = u8(r.rng_next(&rng))
        }
    }

    payload := make([]u8, schema.wire_size)
    defer delete(payload)
    assert(sc.encode(&schema, world^, payload).error == .None)
    bytes := packet(payload, 1)
    defer delete(bytes)
    f: Fixture
    init(&f)
    defer destroy(&f)
    f.sender.compress = true
    f.sender.layout = {&schema, sc.HEADER_BYTES}
    f.receiver.layout = f.sender.layout
    tf.sender_begin(&f.sender, bytes, 0)
    testing.expect_value(t, len(f.sender.wire_bytes), 0)
    tf.sender_cancel(&f.sender)
    f.sender.shuffle = true
    tf.sender_begin(&f.sender, bytes, 0)
    testing.expect(t, f.sender.wire_layout != 0 && len(f.sender.wire_bytes) + 12 < len(bytes))

    for _ in 0 ..< 1500 {
        pump(&f)

        if f.sender.phase == .Complete {
            break
        }
    }

    testing.expect_value(t, f.sender.phase, tf.Phase.Complete)
    testing.expect_value(t, f.installed, u32(1))
    testing.expect_value(t, f.digest, tf.hash(payload))
}
