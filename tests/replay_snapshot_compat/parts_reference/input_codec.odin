package replay_net_parts_reference

import sc "godot:replay/schema"

// Packet-local reuse only: loss/reordering cannot remove a decoding baseline.
// Header is generation:u64, serial:u64, count:u8. Each sample has flags:u8:
// bit 0 = previous tick + 1; bit 1 = previous control; bit 2 = previous view;
// bit 3 = view XOR bytes, selected by a five-byte bitmap over its 35 bytes.
// Missing fields follow in tick/control/view order. The first flags byte is zero.
@(private)
compact_inputs_encode :: proc(c: ^Codecs, canonical: []u8, count: u8, dst: []u8) -> (int, bool) {
    if count < 1 || count > INPUT_WINDOW || len(canonical) != c.inputs.wire_size {
        return 0, false
    }

    control_size, view_size := c.controls.wire_size, c.view_stamp.wire_size

    if view_size != 35 {
        return 0, false
    }

    stride := 8 + control_size + view_size
    flags: [INPUT_WINDOW]u8
    needed := 17

    for i in 0 ..< int(count) {
        at := 17 + i * stride

        if i > 0 {
            prior := at - stride
            tick := get64(canonical[prior:prior + 8])

            if tick != max(u64) && get64(canonical[at:at + 8]) == tick + 1 {
                flags[i] |= 1
            }

            if input_bytes_equal(
                canonical[prior + 8:prior + 8 + control_size],
                canonical[at + 8:at + 8 + control_size],
            ) {
                flags[i] |= 2
            }

            if input_bytes_equal(
                canonical[prior + 8 + control_size:prior + stride],
                canonical[at + 8 + control_size:at + stride],
            ) {
                flags[i] |= 4
            }

            if flags[i] & 4 == 0 {
                changes := 0

                for j in 0 ..< view_size {
                    if canonical[prior + 8 + control_size + j] != canonical[at + 8 + control_size + j] {
                        changes += 1
                    }
                }

                if 5 + changes < view_size {
                    flags[i] |= 8
                }
            }
        }

        needed += 1

        if flags[i] & 1 == 0 {
            needed += 8
        }

        if flags[i] & 2 == 0 {
            needed += control_size
        }

        if flags[i] & 8 != 0 {
            needed += 5
            prior := at - stride

            for j in 0 ..< view_size {
                if canonical[prior + 8 + control_size + j] != canonical[at + 8 + control_size + j] {
                    needed += 1
                }
            }
        } else if flags[i] & 4 == 0 {
            needed += view_size
        }
    }

    if needed > len(dst) {
        return needed, false
    }

    copy(dst[:17], canonical[:17])
    cursor := 17

    for i in 0 ..< int(count) {
        at := 17 + i * stride
        dst[cursor] = flags[i]
        cursor += 1

        if flags[i] & 1 == 0 {
            copy(dst[cursor:cursor + 8], canonical[at:at + 8])
            cursor += 8
        }

        if flags[i] & 2 == 0 {
            copy(dst[cursor:cursor + control_size], canonical[at + 8:at + 8 + control_size])
            cursor += control_size
        }

        if flags[i] & 8 != 0 {
            bitmap := cursor

            for j in 0 ..< 5 {
                dst[cursor + j] = 0
            }

            cursor += 5
            prior := at - stride

            for j in 0 ..< view_size {
                byte := canonical[prior + 8 + control_size + j] ~ canonical[at + 8 + control_size + j]

                if byte != 0 {
                    dst[bitmap + j / 8] |= u8(1) << uint(j % 8)
                    dst[cursor] = byte
                    cursor += 1
                }
            }
        } else if flags[i] & 4 == 0 {
            copy(dst[cursor:cursor + view_size], canonical[at + 8 + control_size:at + stride])
            cursor += view_size
        }
    }

    return needed, true
}

@(private)
compact_inputs_decode :: proc(c: ^Codecs, dst: ^Inputs_Packet($C), bytes: []u8, expected: sc.Envelope_Meta) -> bool {
    _, body, report := sc.unpack_bytes(c.inputs.fingerprint, bytes, expected)

    if report.error != .None || len(body) < 18 || c.view_stamp.wire_size != 35 {
        return false
    }

    packet := Inputs_Packet(C) {
        generation = get64(body[:8]),
        serial     = get64(body[8:16]),
        count      = body[16],
    }

    if packet.count < 1 || packet.count > INPUT_WINDOW {
        return false
    }

    cursor := 17
    view_bytes: [35]u8

    for i in 0 ..< int(packet.count) {
        if cursor >= len(body) {
            return false
        }

        flags := body[cursor]
        cursor += 1

        if flags > 15 || i == 0 && flags != 0 || flags & 12 == 12 {
            return false
        }

        item := &packet.samples[i]

        if flags & 1 != 0 {
            if packet.samples[i - 1].tick == max(u64) {
                return false
            }

            item.tick = packet.samples[i - 1].tick + 1
        } else {
            if len(body) - cursor < 8 {
                return false
            }

            item.tick = get64(body[cursor:cursor + 8])
            cursor += 8
        }

        if flags & 2 != 0 {
            item.value = packet.samples[i - 1].value
        } else {
            n := c.controls.wire_size

            if len(body) - cursor < n {
                return false
            }

            if sc.decode(&c.controls, &item.value, body[cursor:cursor + n]).error != .None {
                return false
            }

            cursor += n
        }

        if flags & 4 != 0 {
            item.view = packet.samples[i - 1].view
        } else if flags & 8 != 0 {
            if len(body) - cursor < 5 || body[cursor + 4] & 0xf8 != 0 {
                return false
            }

            bitmap := body[cursor:cursor + 5]
            cursor += 5
            changes := 0

            for j in 0 ..< 35 {
                if bitmap[j / 8] & (u8(1) << uint(j % 8)) != 0 {
                    if cursor >= len(body) || body[cursor] == 0 {
                        return false
                    }

                    view_bytes[j] ~= body[cursor]
                    cursor += 1
                    changes += 1
                }
            }

            if changes == 0 || sc.decode(&c.view_stamp, &item.view, view_bytes[:]).error != .None {
                return false
            }
        } else {
            n := c.view_stamp.wire_size

            if len(body) - cursor < n {
                return false
            }

            if sc.decode(&c.view_stamp, &item.view, body[cursor:cursor + n]).error != .None {
                return false
            }

            cursor += n
            copy(view_bytes[:], body[cursor - n:cursor])
        }
    }

    if cursor != len(body) {
        return false
    }

    dst^ = packet
    return true
}

@(private)
input_bytes_equal :: proc(a, b: []u8) -> bool {
    if len(a) != len(b) {
        return false
    }

    for byte, i in a {
        if byte != b[i] {
            return false
        }
    }

    return true
}
