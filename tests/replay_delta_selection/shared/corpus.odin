package selection_corpus
import "core:mem"
import d "godot:replay/delta"
import r "godot:replay"
import sc "godot:replay/schema"
import patterns "../../replay_lz4/shared"

sparse: [327680]u8
compressed, selected: [65816]u8
decoded: [65543]u8
workspace: d.Lz4_Workspace

verify :: proc() -> (code: u32, hash: u64) {
    rng := r.rng_make(7301)
    hash = 0xcbf29ce484222325

    for mode in 0 ..< 6 {
        patterns.fill(mode, &rng)

        for offset in 0 ..< 8 {
            for length in patterns.LENGTHS {
                base, target := patterns.base[offset:offset + length], patterns.target[offset:offset + length]
                sn, sok := d.encode(base, target, sparse[:])
                ln, lok := d.lz4_xor_encode(base, target, compressed[:], &workspace)

                if !sok || !lok {
                    return 1, 0
                }

                for budget in ([7]int {
                        0,
                        1,
                        2,
                        max(min(sn, ln) - 1, 0),
                        min(sn, ln),
                        max(sn, ln),
                        len(selected) - offset,
                    }) {
                    budget := min(budget, len(selected) - offset)

                    for &byte in selected {
                        byte = 0xcc
                    }

                    dst := selected[offset:offset + budget]
                    n, kind, ok := d.encode_smallest(base, target, dst, &workspace)
                    expected := min(sn, ln)
                    choice := sn <= ln ? d.Encoding.Sparse : .Lz4

                    if ok != (expected <= budget) {
                        return 2, 0
                    }

                    if !ok {
                        for byte in selected {
                            if byte != 0xcc {
                                return 3, 0
                            }
                        }

                        continue
                    }

                    source := choice == .Sparse ? sparse[:sn] : compressed[:ln]

                    if n != expected || kind != choice || mem.compare(dst[:n], source) != 0 {
                        return 4, 0
                    }

                    for byte in selected[:offset] {
                        if byte != 0xcc {
                            return 5, 0
                        }
                    }

                    for byte in selected[offset + n:] {
                        if byte != 0xcc {
                            return 6, 0
                        }
                    }

                    valid :=
                        kind == .Sparse ? d.apply(base, dst[:n], decoded[:length]) : d.lz4_xor_apply(base, dst[:n], decoded[:length])

                    if !valid || mem.compare(decoded[:length], target) != 0 {
                        return 7, 0
                    }

                    hash = sc.digest(dst[:n], hash)
                }

                n, kind, ok := d.encode_smallest(base, target, selected[:], nil)

                if ok != (sn <= len(selected)) ||
                   ok && (kind != .Sparse || n != sn || mem.compare(selected[:n], sparse[:sn]) != 0) {
                    return 8, 0
                }

                for &byte in selected {
                    byte = 0xcc
                }

                if _, ok := d.encode_bounded(base, target, selected[:], sn - 1); ok {
                    return 9, 0
                }

                for byte in selected {
                    if byte != 0xcc {
                        return 10, 0
                    }
                }
            }
        }
    }

    if _, _, ok := d.encode_smallest(patterns.base[:65536], patterns.target[:65536], selected[:], &workspace); ok {
        return 11, 0
    }

    if _, _, ok := d.encode_smallest(patterns.base[:8], patterns.target[:7], selected[:], &workspace); ok {
        return 12, 0
    }

    if _, _, ok := d.encode_smallest(patterns.base[:8], patterns.target[:8], patterns.base[:8], &workspace); ok {
        return 13, 0
    }

    scratch := (cast([^]u8)&workspace)[:size_of(d.Lz4_Workspace)]

    if _, _, ok := d.encode_smallest(patterns.base[:8], patterns.target[:8], scratch[:8], &workspace); ok {
        return 14, 0
    }

    return
}
