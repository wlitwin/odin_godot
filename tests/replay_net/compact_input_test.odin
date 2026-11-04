package replay_net_test

import "core:testing"
import "core:reflect"
import net "godot:replay/net"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

compact_packet :: proc(f: ^Fixture, views: bool = false) -> []u8 {
    for _ in 0 ..< 35 {
        if views {
            net.client_present(&f.clients[0])
        }

        fixture_step(f)
    }

    for &queued in f.network.packets {
        if queued.from == 2 {
            queued.active = false
        }
    }

    assert(net.client_step(&f.clients[0], Control{}) == .None)
    return capture_packet(f, 2, 15, true)
}

@(test)
compact_view_differences_preserve_provenance_and_reject_bitmap_overrun :: proc(t: ^testing.T) {
    a, b: Fixture
    fixture_init(&a)
    fixture_init(&b)
    defer fixture_destroy(&a)
    defer fixture_destroy(&b)
    compact := compact_packet(&a, true)
    unused := compact_packet(&b, true)
    defer delete(compact)
    defer delete(unused)
    testing.expect(t, len(compact) > 0)

    if len(compact) == 0 {
        return
    }

    full := make([]u8, sc.HEADER_BYTES + len(b.clients[0].input_scratch))
    defer delete(full)
    testing.expect_value(
        t,
        sc.pack_bytes(b.clients[0].codecs.inputs.fingerprint, {kind = 4, epoch = b.clients[0].cfg.epoch, tick = b.clients[0].timeline.head, content = b.clients[0].cfg.content}, b.clients[0].input_scratch, full).error,
        sc.Error.None,
    )
    body := compact[sc.HEADER_BYTES:]
    cursor := 17
    bitmap := -1

    for _ in 0 ..< int(body[16]) {
        flags := body[cursor]
        cursor += 1

        if flags & 1 == 0 {
            cursor += 8
        }

        if flags & 2 == 0 {
            cursor += 1
        }

        if flags & 8 != 0 {
            bitmap = cursor
            mask := body[cursor:cursor + 5]
            cursor += 5

            for j in 0 ..< 35 {
                if mask[j / 8] & (u8(1) << uint(j % 8)) != 0 {
                    cursor += 1
                }
            }
        } else if flags & 4 == 0 {
            cursor += 35
        }
    }

    testing.expect_value(t, cursor, len(body))
    testing.expect(t, bitmap >= 0)

    if bitmap >= 0 {
        bad := make([]u8, len(body))
        copy(bad, body)
        bad[bitmap + 4] |= 0x80
        framed := reframe_input(&a, bad)
        delete(bad)
        before := a.server.stats.rejected_inputs
        deliver_input(&a, framed)
        delete(framed)
        testing.expect_value(t, a.server.stats.rejected_inputs, before + 1)
    }

    deliver_input(&a, compact)
    deliver_input(&b, full)

    for slot, i in a.server.inputs {
        testing.expect(t, reflect.equal(slot, b.server.inputs[i]))
    }
}

deliver_input :: proc(f: ^Fixture, bytes: []u8, peer: int = 0) {
    for &queued in f.network.packets {
        if queued.to == 1 {
            queued.active = false
        }
    }

    assert(tr.send(&f.clients[peer].wire, 1, .Unreliable, bytes) == .Sent)
    tr.memory_advance(&f.network, f.clock)
    assert(net.server_pump(&f.server, f.clock * 1000 / 60) == .None)
}

reframe_input :: proc(f: ^Fixture, body: []u8) -> []u8 {
    packet := make([]u8, sc.HEADER_BYTES + len(body))
    assert(
        sc.pack_bytes(f.clients[0].codecs.inputs.fingerprint, {kind = 15, epoch = f.clients[0].cfg.epoch, tick = f.clients[0].timeline.head, content = f.clients[0].cfg.content}, body, packet).error ==
        .None,
    )
    return packet
}

@(test)
compact_window_is_self_contained_and_matches_full_input_admission :: proc(t: ^testing.T) {
    a, b: Fixture
    fixture_init(&a)
    fixture_init(&b)
    defer fixture_destroy(&a)
    defer fixture_destroy(&b)
    compact := compact_packet(&a)
    unused := compact_packet(&b)
    defer delete(compact)
    defer delete(unused)
    testing.expect(t, len(compact) > 0)

    if len(compact) == 0 {
        return
    }

    full := make([]u8, sc.HEADER_BYTES + len(b.clients[0].input_scratch))
    defer delete(full)
    testing.expect_value(
        t,
        sc.pack_bytes(b.clients[0].codecs.inputs.fingerprint, {kind = 4, epoch = b.clients[0].cfg.epoch, tick = b.clients[0].timeline.head, content = b.clients[0].cfg.content}, b.clients[0].input_scratch, full).error,
        sc.Error.None,
    )
    testing.expect(t, len(compact) < len(full) / 2)
    testing.expect_value(t, compact[sc.HEADER_BYTES + 16], u8(net.INPUT_WINDOW))
    // Delivery does not depend on any earlier input packet reaching the server.
    deliver_input(&a, compact)
    deliver_input(&b, full)

    for slot, i in a.server.inputs {
        testing.expect(t, reflect.equal(slot, b.server.inputs[i]))
    }

    testing.expect_value(t, a.server.peers[0].input_newest, b.server.peers[0].input_newest)
    before := a.server.peers[0].input_newest
    deliver_input(&a, compact)
    testing.expect_value(t, a.server.peers[0].input_newest, before)
}

@(test)
compact_input_rejects_bad_shapes_and_late_values_before_partial_admission :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)
    packet := compact_packet(&f)
    defer delete(packet)
    testing.expect(t, len(packet) > 0)

    if len(packet) == 0 {
        return
    }

    body := packet[sc.HEADER_BYTES:]

    for mutation in 0 ..< 7 {
        bad := make([]u8, len(body) + 1)
        copy(bad, body)
        size := len(body)

        switch mutation {
        case 0:
            bad[16] = 0
        case 1:
            bad[16] = net.INPUT_WINDOW + 1
        case 2:
            bad[17] = 1 // cannot refer to a previous first sample
        case 3:
            bad[17] = 128 // reserved flag
        case 4:
            size -= 1
        case 5:
            size += 1 // trailing garbage
        case 6:
            // All earlier samples are valid. The final record explicitly carries
            // an out-of-language control instead of repeating the preceding one.
            testing.expect_value(t, bad[size - 1], u8(7))
            bad[size - 1] = 5
            bad[size] = 127
            size += 1
        }

        encoded := reframe_input(&f, bad[:size])
        delete(bad)
        before := f.server.stats.rejected_inputs
        newest := f.server.peers[0].input_newest
        deliver_input(&f, encoded)
        delete(encoded)
        testing.expect_value(t, f.server.stats.rejected_inputs, before + 1)
        testing.expect_value(t, f.server.peers[0].input_newest, newest)
    }

    before := f.server.stats.rejected_inputs
    deliver_input(&f, packet, 1)
    testing.expect_value(t, f.server.stats.rejected_inputs, before + 1)
}
