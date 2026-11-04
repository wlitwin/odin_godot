package main
import "core:fmt"
import "core:time"
import "core:mem"
import d "godot:replay/delta"
import old "reference"
import r "godot:replay"
import sc "godot:replay/schema"

main :: proc() {
    base, target: [65543]u8
    before, after: [65543]u8
    encoded: [65816]u8
    work: old.Lz4_Workspace
    current: d.Lz4_Workspace
    rng := r.rng_make(2031)

    for &b in base {
        b = u8(r.rng_next(&rng))
    }

    hash := u64(0xcbf29ce484222325)
    cases := 0

    for period in ([11]int{1, 2, 3, 4, 7, 8, 9, 11, 16, 32, 257}) {
        for &b, i in target {
            b = base[i] ~ u8((i % period) * 37 + 1)

            if i % 509 == 0 {
                b ~= 31
            }
        }

        for alignment in 0 ..< 8 {
            for length in ([5]int{0, 17, 1024, 52724, 65535}) {
                b, t := base[alignment:alignment + length], target[alignment:alignment + length]
                n, ok := old.lz4_xor_encode(b, t, encoded[:], &work)
                assert(ok)
                same: [65816]u8
                nn, new_ok := d.lz4_xor_encode(b, t, same[:], &current)
                assert(new_ok && nn == n && mem.compare(same[:nn], encoded[:n]) == 0)
                a, z := before[alignment:alignment + length], after[alignment:alignment + length]
                assert(old.lz4_xor_apply(b, encoded[:n], a))
                assert(d.lz4_xor_apply(b, encoded[:n], z))
                assert(mem.compare(a, z) == 0 && mem.compare(z, t) == 0)

                for truncation in 0 ..< min(n, 24) {
                    for &v in before {
                        v = 0xcc
                    }

                    for &v in after {
                        v = 0xcc
                    }

                    keep := n - 1 - truncation
                    old_ok := old.lz4_xor_apply(b, encoded[:keep], a)
                    new_ok := d.lz4_xor_apply(b, encoded[:keep], z)
                    assert(old_ok == new_ok && mem.compare(before[:], after[:]) == 0)
                }

                assert(d.lz4_xor_apply(b, encoded[:n], z))
                hash = sc.digest(z, hash)
                cases += 1

                if alignment == 0 && length == 52724 {
                    times: [2]i64

                    for version in 0 ..< 2 {
                        began := time.tick_now()

                        for _ in 0 ..< 200 {
                            if version == 0 {
                                assert(old.lz4_xor_apply(b, encoded[:n], a))
                            } else {
                                assert(d.lz4_xor_apply(b, encoded[:n], z))
                            }
                        }

                        times[version] = i64(time.tick_since(began)) / 200
                    }

                    encode_times: [2]i64

                    for version in 0 ..< 2 {
                        began := time.tick_now()

                        for _ in 0 ..< 100 {
                            if version == 0 {
                                size, ok := old.lz4_xor_encode(b, t, same[:], &work)
                                assert(ok && size == n)
                            } else {
                                size, ok := d.lz4_xor_encode(b, t, same[:], &current)
                                assert(ok && size == n)
                            }
                        }

                        encode_times[version] = i64(time.tick_since(began)) / 100
                    }

                    fmt.printf(
                        "LZ4_ENCODE_COST period=%d bytes=%d original_ns=%d staged_ns=%d\n",
                        period,
                        n,
                        encode_times[0],
                        encode_times[1],
                    )
                    fmt.printf(
                        "LZ4_DECODE_CONTROL period=%d bytes=%d original_ns=%d words_ns=%d\n",
                        period,
                        n,
                        times[0],
                        times[1],
                    )
                }
            }
        }
    }

    fmt.printf("LZ4_STAGING_OK cases=%d hash=%d\n", cases, hash)
}
