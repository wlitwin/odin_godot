package scan_corpus

import sc "godot:replay/schema"
import d "godot:replay/delta"
import r "godot:replay"

reference_digest :: proc(bytes: []u8, seed: u64 = 0xcbf29ce484222325) -> u64 {
    h := seed

    for byte in bytes {
        h = (h ~ u64(byte)) * 0x100000001b3
    }

    return h
}

reference_delta :: proc(base, target, out: []u8) -> int {
    put :: proc(out: []u8, v: int) {
        out[0] = u8(v)
        out[1] = u8(v >> 8)
    }

    cursor, runs := 2, 0

    for i := 0; i < len(base); {
        if base[i] == target[i] {
            i += 1
            continue
        }

        start := i

        for i < len(base) && base[i] != target[i] {
            i += 1
        }

        put(out[cursor:cursor + 2], start)
        put(out[cursor + 2:cursor + 4], i - start)
        cursor += 4

        for j in start ..< i {
            out[cursor] = base[j] ~ target[j]
            cursor += 1
        }

        runs += 1
    }

    put(out[:2], runs)
    return cursor
}

base, target, restored: [65543]u8
encoded, reference: [327680]u8

verify :: proc() -> (code: u32, fingerprint: u64) {
    rng := r.rng_make(918)
    fingerprint = 0xcbf29ce484222325

    for mode in 0 ..< 4 {
        for &byte, i in base {
            byte = mode == 0 ? 0 : u8(r.rng_next(&rng))
            target[i] = byte
        }

        for &byte, i in target {
            if mode == 1 && i % 29 == 0 || mode == 2 && i % 2 == 0 || mode == 3 {
                byte ~= u8(r.rng_next(&rng) % 255 + 1)
            }
        }

        for offset in 0 ..< 8 {
            for length in ([12]int{0, 1, 7, 8, 9, 15, 16, 17, 127, 1024, 65534, 65535}) {
                b, v := base[offset:offset + length], target[offset:offset + length]

                for seed in ([3]u64{0, 0xcbf29ce484222325, max(u64)}) {
                    if sc.digest(v, seed) != reference_digest(v, seed) {
                        return 1, 0
                    }
                }

                expected := reference_delta(b, v, reference[:])
                size, ok := d.encode(b, v, encoded[:])

                if !ok || size != expected {
                    return 2, 0
                }

                for byte, i in encoded[:size] {
                    if byte != reference[i] {
                        return 3, 0
                    }
                }

                if !d.apply(b, encoded[:size], restored[:length]) {
                    return 4, 0
                }

                for byte, i in v {
                    if byte != restored[i] {
                        return 5, 0
                    }
                }

                fingerprint = sc.digest(encoded[:size], fingerprint)
            }
        }
    }

    return 0, fingerprint
}
