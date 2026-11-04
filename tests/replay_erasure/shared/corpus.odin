package erasure_corpus
import "core:mem"
import e "godot:replay/erasure"
import r "godot:replay"
import sc "godot:replay/schema"
original, restored: [10][1032]u8

// Independent polynomial product/reduction oracle (no Horner or xtime helper).
product :: proc(a, b: u8) -> u8 {
    value := u16(0)

    for bit in 0 ..< 8 {
        if b & (u8(1) << uint(bit)) != 0 {
            value ~= u16(a) << uint(bit)
        }
    }

    for bit := 14; bit >= 8; bit -= 1 {
        if value & (u16(1) << uint(bit)) != 0 {
            value ~= u16(0x11d) << uint(bit - 8)
        }
    }

    return u8(value)
}

verify :: proc() -> (code: u32, hash: u64, cases: u64) {
    rng := r.rng_make(4401)
    hash = 0xcbf29ce484222325

    for pattern in 0 ..< 3 {
        for count in 1 ..= 8 {
            for width in ([3]int{1, 17, 932}) {
                for offset in 0 ..< 4 {
                    source, target: [8][]u8

                    for i in 0 ..< count {
                        length := i == count - 1 ? max(1, width / 3) : width

                        if count == 1 {
                            length = width
                        }

                        source[i] = original[i][offset:offset + length]
                        target[i] = restored[i][offset:offset + length]

                        for &byte, j in source[i] {
                            byte = pattern == 0 ? 0 : pattern == 1 ? u8(i * 31 + j) : u8(r.rng_next(&rng))
                        }
                    }

                    p := [2][]u8{original[8][offset:offset + width], original[9][offset:offset + width]}

                    if !e.encode(source[:count], p) {
                        return 1, 0, 0
                    }

                    for byte in 0 ..< width {
                        a, b := u8(0), u8(0)

                        for shard, i in source[:count] {
                            value := byte < len(shard) ? shard[byte] : u8(0)
                            a ~= value
                            b ~= product(value, u8(1) << uint(i))
                        }

                        if p[0][byte] != a || p[1][byte] != b {
                            return 2, 0, 0
                        }
                    }

                    for erased in 0 ..< (1 << uint(count + 2)) {
                        n := 0

                        for bit in 0 ..< count + 2 {
                            if erased & (1 << uint(bit)) != 0 {
                                n += 1
                            }
                        }

                        if n > 2 {
                            continue
                        }

                        restored = original

                        for i in 0 ..< count {
                            if erased & (1 << uint(i)) != 0 {
                                for &byte in target[i] {
                                    byte = 0xcc
                                }
                            }
                        }

                        parity := [2][]u8{restored[8][offset:offset + width], restored[9][offset:offset + width]}
                        present := u8(3)

                        for i in 0 ..< 2 {
                            if erased & (1 << uint(count + i)) != 0 {
                                present &= ~(u8(1) << uint(i))

                                for &byte in parity[i] {
                                    byte = 0xcc
                                }
                            }
                        }

                        missing := u8(erased & ((1 << uint(count)) - 1))

                        if !e.recover(target[:count], parity, missing, present) {
                            return 3, 0, 0
                        }

                        for shard, i in target[:count] {
                            if mem.compare(shard, source[i]) != 0 {
                                return 4, 0, 0
                            }

                            hash = sc.digest(shard, hash)
                        }

                        for i in 0 ..< count {
                            if mem.compare(restored[i][:offset], original[i][:offset]) != 0 ||
                               mem.compare(
                                   restored[i][offset + len(target[i]):],
                                   original[i][offset + len(source[i]):],
                               ) !=
                                   0 {
                                return 5, 0, 0
                            }
                        }

                        cases += 1
                    }

                    if count >= 3 {
                        restored = original
                        before := restored

                        if e.recover(target[:count], p, 7, 3) {
                            return 6, 0, 0
                        }

                        if restored != before {
                            return 7, 0, 0
                        }
                    }
                }
            }
        }
    }

    data := [1][]u8{original[0][:8]}
    parity := [2][]u8{original[8][:8], original[9][:8]}

    if e.recover(data[:], parity, 2, 3) || e.recover(data[:], parity, 1, 4) || e.recover(data[:], parity, 1, 0) {
        return 8, 0, 0
    }

    parity[0] = original[0][:8]

    if e.encode(data[:], parity) {
        return 9, 0, 0
    }

    return
}
