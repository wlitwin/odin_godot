package lz4_corpus
import d "godot:replay/delta"
import r "godot:replay"
import sc "godot:replay/schema"
base, target, decoded, xor_bytes: [65543]u8
encoded, reference, backup: [65816]u8
work: d.Lz4_Workspace
LENGTHS :: [16]int{0, 1, 4, 5, 11, 12, 13, 15, 16, 127, 128, 255, 256, 1024, 65534, 65535}

fill :: proc(mode: int, rng: ^r.Rng) {
    for &b, i in base {
        b = u8(r.rng_next(rng))
        target[i] = b
    }

    for &b, i in target {
        switch mode {
        case 0:
        case 1:
            if i % 131 == 0 {
                b ~= 1
            }
        case 2:
            b ~= u8(i % 11)
        case 3:
            b ~= u8(r.rng_next(rng))
        case 4:
            b = 0
        case 5:
            b ~= 0xff
        }
    }
}

check_case :: proc(offset, length: int) -> (code: u32, hash: u64) {
    b, t := base[offset:offset + length], target[offset:offset + length]
    n, ok := d.lz4_xor_encode(b, t, encoded[:], &work)

    if !ok {
        return 1, 0
    }

    if !d.lz4_xor_apply(b, encoded[:n], decoded[:length]) {
        return 2, 0
    }

    for byte, i in t {
        if byte != decoded[i] {
            return 3, 0
        }
    }

    copy(backup[:], encoded[:])
    needed, small := d.lz4_xor_encode(b, t, encoded[:n - 1], &work)

    if small || needed != n {
        return 4, 0
    }

    for byte, i in encoded {
        if byte != backup[i] {
            return 5, 0
        }
    }

    hash = sc.digest(encoded[:n])
    count := min(n, 128)

    for attempt in 0 ..< count {
        at := n <= 128 ? attempt : attempt * (n - 1) / 127

        for &byte in decoded[:length] {
            byte = 0xcc
        }

        if d.lz4_xor_apply(b, encoded[:at], decoded[:length]) {
            return 6, 0
        }

        for byte in decoded[:length] {
            if byte != 0xcc {
                return 7, 0
            }
        }

        encoded[at] ~= 0x81
        accepted := d.lz4_xor_apply(b, encoded[:n], decoded[:length])

        if !accepted {
            for byte in decoded[:length] {
                if byte != 0xcc {
                    return 8, 0
                }
            }
        } else {
            hash = sc.digest(decoded[:length], hash)
        }

        encoded[at] ~= 0x81
    }

    return 0, hash
}

verify :: proc() -> (code: u32, hash: u64) {
    hash = 0xcbf29ce484222325
    rng := r.rng_make(703)

    for mode in 0 ..< 6 {
        fill(mode, &rng)

        for offset in 0 ..< 8 {
            for length in LENGTHS {
                result, value := check_case(offset, length)

                if result != 0 {
                    return result, 0
                }

                hash = (hash ~ value) * 0x100000001b3
            }
        }
    }

    if _, ok := d.lz4_xor_encode(base[:65536], target[:65536], encoded[:], &work); ok {
        return 9, 0
    }

    if d.lz4_xor_apply(base[:8], encoded[:8], base[:8]) {
        return 10, 0
    }

    if _, ok := d.lz4_xor_encode(base[:8], target[:8], base[:8], &work); ok {
        return 11, 0
    }

    scratch := (cast([^]u8)&work)[:size_of(d.Lz4_Workspace)]

    if _, ok := d.lz4_xor_encode(scratch[:8], target[:8], encoded[:], &work); ok {
        return 12, 0
    }

    return
}

// The native reference implementation receives standard independent LZ4 blocks
// containing XOR bytes; it need not know Replay's delta or snapshot formats.
verify_reference :: proc(compress: proc(src, dst: []u8) -> int, decompress: proc(src, dst: []u8) -> int) -> u32 {
    rng := r.rng_make(1703)

    for mode in 0 ..< 6 {
        fill(mode, &rng)

        for offset in 0 ..< 8 {
            for length in LENGTHS {
                b, t := base[offset:offset + length], target[offset:offset + length]

                for i in 0 ..< length {
                    xor_bytes[i] = b[i] ~ t[i]
                }

                n, ok := d.lz4_xor_encode(b, t, encoded[:], &work)

                if !ok {
                    return 20
                }

                if decompress(encoded[:n], decoded[:length]) != length {
                    return 21
                }

                for byte, i in decoded[:length] {
                    if byte != xor_bytes[i] {
                        return 22
                    }
                }

                count := compress(xor_bytes[:length], reference[:])

                if count <= 0 {
                    return 23
                }

                if !d.lz4_xor_apply(b, reference[:count], decoded[:length]) {
                    return 24
                }

                for byte, i in t {
                    if byte != decoded[i] {
                        return 25
                    }
                }

                for j in 0 ..< min(n, 16) {
                    at := j * (n - 1) / max(min(n, 16) - 1, 1)
                    encoded[at] ~= 0x81

                    if d.lz4_xor_apply(b, encoded[:n], decoded[:length]) {
                        if decompress(encoded[:n], xor_bytes[:length]) != length {
                            return 26
                        }

                        for byte, i in decoded[:length] {
                            if byte != xor_bytes[i] ~ b[i] {
                                return 27
                            }
                        }
                    }

                    encoded[at] ~= 0x81
                }
            }
        }
    }

    return 0
}
