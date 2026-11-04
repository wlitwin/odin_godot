package replay_delta_test

import "core:testing"
import "core:bytes"
import r "godot:replay"
import d "godot:replay/delta"

// Independent bytewise format oracle, deliberately kept without word skips.
reference_delta :: proc(base, target: []u8, out: []u8) -> int {
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

@(test)
word_skipping_keeps_exact_sparse_format_and_transactional_failure :: proc(t: ^testing.T) {
    rng := r.rng_make(712)
    base, target: [1040]u8
    encoded, oracle: [8192]u8

    for mode in 0 ..< 5 {
        for &byte, i in base {
            byte = mode == 0 ? 0 : u8(r.rng_next(&rng))
            target[i] = byte
        }

        for &byte, i in target {
            if (mode == 1 && i % 2 == 0) ||
               (mode == 2 && i % 31 == 0) ||
               (mode == 3 && i >= 7 && i <= 25) ||
               mode == 4 {
                byte ~= u8(r.rng_next(&rng) % 255 + 1)
            }
        }

        for offset in 0 ..< 8 {
            for length in 0 ..= 1024 {
                b, v := base[offset:offset + length], target[offset:offset + length]
                expected := reference_delta(b, v, oracle[:])
                size, ok := d.encode(b, v, encoded[:])
                testing.expect(t, ok && size == expected && bytes.equal(encoded[:size], oracle[:expected]))
                before := encoded
                needed, small := d.encode(b, v, encoded[:expected - 1])
                testing.expect(t, !small && needed == expected)
                testing.expect_value(t, encoded, before)
            }
        }
    }
}
