package replay_schema_test

import "core:testing"
import r "godot:replay"
import sc "godot:replay/schema"

reference_digest :: proc(bytes: []u8, seed: u64) -> u64 {
    value := seed

    for byte in bytes {
        value = (value ~ u64(byte)) * 0x100000001b3
    }

    return value
}

@(test)
word_zero_digest_matches_byte_fold_for_seeds_alignment_and_tails :: proc(t: ^testing.T) {
    rng := r.rng_make(91)
    storage: [1040]u8
    seeds := [5]u64{0, 1, max(u64), 0xcbf29ce484222325, 0x123456789abcdef0}

    for mode in 0 ..< 4 {
        for &byte, i in storage {
            byte =
                mode == 0 ? 0 : mode == 1 ? u8(r.rng_next(&rng)) : mode == 2 ? u8(i % 17 == 0 ? 1 : 0) : u8(i % 9 == 0 ? 0 : 255)
        }

        for offset in 0 ..< 8 {
            for length in 0 ..= 1024 {
                for seed in seeds {
                    bytes := storage[offset:offset + length]
                    testing.expect_value(t, sc.digest(bytes, seed), reference_digest(bytes, seed))
                }
            }
        }
    }
}

@(test)
large_sparse_digest_preserves_streaming_seed_composition :: proc(t: ^testing.T) {
    bytes := make([]u8, 65535)
    defer delete(bytes)

    for i := 0; i < len(bytes); i += 257 {
        bytes[i] = u8(i % 251 + 1)
    }

    expected := reference_digest(bytes, 0xcbf29ce484222325)
    testing.expect_value(t, sc.digest(bytes), expected)

    for cut in ([8]int{0, 1, 7, 8, 9, 1023, 32768, 65535}) {
        testing.expect_value(t, sc.digest(bytes[cut:], sc.digest(bytes[:cut])), expected)
    }
}
