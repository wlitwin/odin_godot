package replay_transfer_test
import "core:testing"
import tf "godot:replay/transfer"
import tr "godot:replay/transport"
import r "godot:replay"
import sc "godot:replay/schema"

@(test)
compressed_archive_survives_loss_and_preserves_raw_identity_and_retention :: proc(t: ^testing.T) {
    f: Fixture
    faults := tr.DEFAULT_FAULTS
    faults.latency_ticks, faults.jitter_ticks, faults.loss_permyriad, faults.duplicate_permyriad = 30, 20, 1000, 1000
    init(&f, faults, tf.MAX_BYTES)
    defer destroy(&f)
    f.sender.compress = true
    payload := make([]u8, 900000)
    defer delete(payload)

    for &byte, i in payload {
        byte = u8(i % 251)
    }

    for tick in 1 ..= 2 {
        bytes := packet(payload, u64(tick))
        defer delete(bytes)
        testing.expect_value(t, tf.sender_begin(&f.sender, bytes, f.clock), tf.Error.None)
        testing.expect(t, len(f.sender.wire_bytes) > 0 && len(f.sender.wire_bytes) < len(bytes) / 10)
        testing.expect_value(t, f.sender.archive.hash, tf.hash(bytes))
        testing.expect_value(t, f.sender.archive.bytes, u32(len(bytes)))

        for _ in 0 ..< 2000 {
            pump(&f)

            if f.sender.phase == .Complete {
                break
            }
        }

        testing.expect_value(t, f.sender.phase, tf.Phase.Complete)
        testing.expect_value(t, f.installed, u32(tick))
        testing.expect_value(t, f.digest, tf.hash(payload))
        testing.expect_value(t, f.receiver.latest.archive, f.sender.archive)
    }

    testing.expect_value(t, f.receiver.previous_receipt.archive.sequence, u64(1))
    testing.expect_value(t, f.receiver.stats.validated_bytes, u64(2 * len(f.sender.bytes)))
}

@(test)
compression_is_opt_in_and_incompressible_data_uses_original_offer :: proc(t: ^testing.T) {
    f: Fixture
    init(&f)
    defer destroy(&f)
    payload := make([]u8, 32000)
    defer delete(payload)
    rng := r.rng_make(9)

    for &byte in payload {
        byte = u8(r.rng_next(&rng))
    }

    for mode in 0 ..< 2 {
        f.sender.compress = mode == 1
        bytes := packet(payload, u64(mode))
        defer delete(bytes)
        testing.expect_value(t, tf.sender_begin(&f.sender, bytes, f.clock), tf.Error.None)
        testing.expect_value(t, len(f.sender.wire_bytes), 0)

        for _ in 0 ..< 1500 {
            pump(&f)

            if f.sender.phase == .Complete {
                break
            }
        }

        testing.expect_value(t, f.sender.phase, tf.Phase.Complete)
        testing.expect_value(t, len(f.receiver.decoded), 0)
    }
}

@(test)
corrupt_compression_or_raw_hash_never_installs_a_candidate :: proc(t: ^testing.T) {
    for mode in 0 ..< 3 {
        f: Fixture
        init(&f)
        defer destroy(&f)
        f.sender.compress = true
        payload: [32000]u8
        bytes := packet(payload[:], 1)
        defer delete(bytes)
        tf.sender_begin(&f.sender, bytes, 0)

        for _ in 0 ..< 1000 {
            pump(&f)

            if f.sender.phase == .Complete {
                break
            }
        }

        testing.expect_value(t, f.installed, u32(1))
        before := f.receiver.latest
        next := packet(payload[:], 2)
        defer delete(next)
        tf.sender_begin(&f.sender, next, f.clock)

        switch mode {
        case 0:
            f.sender.wire_bytes[0] = 0 // Invalid block stream, valid packet envelopes.
        case 1:
            f.sender.archive.hash[0] ~= 1 // Valid decompression, wrong raw digest.
        case 2:
            f.reject = true // Valid raw envelope and digest, typed installation refuses.
        }

        for _ in 0 ..< 1000 {
            pump(&f)

            if f.sender.phase == .Failed {
                break
            }
        }

        testing.expect_value(t, f.sender.phase, tf.Phase.Failed)
        testing.expect_value(t, f.installed, u32(1))
        testing.expect_value(t, f.receiver.latest, before)
        testing.expect_value(t, f.sender.remote_failure, mode == 2 ? tf.Failure.Archive : tf.Failure.Integrity)
    }
}

@(test)
compressed_offers_enforce_raw_caps_wire_bounds_and_routing :: proc(t: ^testing.T) {
    capture: Capture
    sender: tf.Sender
    defer tf.sender_destroy(&sender)
    tf.sender_init(&sender, SCOPE, 2, capture_wire(&capture), archive_kind = PAYLOAD_KIND)
    sender.compress = true
    payload: [32000]u8
    bytes := packet(payload[:], 1)
    defer delete(bytes)
    tf.sender_begin(&sender, bytes, 0)
    tf.sender_update(&sender, 0)
    offer := capture.bytes
    size := capture.count
    testing.expect_value(t, tf.destination(offer[:size]), tf.Destination.Receiver)

    for mode in 0 ..< 5 {
        f: Fixture
        init(&f, cap = mode == 0 ? 4096 : 65536)
        defer destroy(&f)
        bad := offer

        if mode > 0 {
            wire_size := mode == 1 ? u32(0) : mode == 2 ? u32(len(bytes)) : mode == 3 ? max(u32) : u32(5)

            for i in 0 ..< 4 {
                bad[size - 4 + i] = u8(wire_size >> uint(i * 8))
            }

            meta, fingerprint, _ := sc.inspect(bad[:size])
            sc.pack_bytes(fingerprint, meta, bad[sc.HEADER_BYTES:size], bad[:size])
        }

        testing.expect_value(t, tf.blob_receive(&f.receiver, 1, bad[:size], 0), tf.Received.Rejected)
        testing.expect(t, !f.receiver.active && f.installed == 0 && len(f.receiver.decoded) == 0)
    }

    f: Fixture
    init(&f)
    defer destroy(&f)
    testing.expect_value(t, tf.blob_receive(&f.receiver, 1, offer[:size], 0), tf.Received.Accepted)
    bad := offer
    bad[size - 4] ~= 1
    meta, fingerprint, _ := sc.inspect(bad[:size])
    sc.pack_bytes(fingerprint, meta, bad[sc.HEADER_BYTES:size], bad[:size])
    testing.expect_value(t, tf.blob_receive(&f.receiver, 1, bad[:size], 0), tf.Received.Rejected)
    testing.expect(t, f.receiver.active && f.installed == 0)
    testing.expect_value(t, tf.blob_receive(&f.receiver, 1, offer[:size], 0), tf.Received.Accepted)
}
