package scan_corpus

// Frozen pre-optimization codec from the recorded comparison source archive.
reference_encode :: proc(base, target, dst: []u8) -> (size: int, ok: bool) {
    if len(base) != len(target) || len(base) > 65535 {
        return 0, false
    }

    needed, runs := 2, 0

    for i := 0; i < len(base); {
        if base[i] == target[i] {
            i += 1
            continue
        }

        start := i

        for i < len(base) && base[i] != target[i] {
            i += 1
        }

        needed += 4 + i - start
        runs += 1
    }

    if needed > len(dst) || runs > 65535 {
        return needed, false
    }

    reference_put16(dst[:2], u16(runs))
    cursor := 2

    for i := 0; i < len(base); {
        if base[i] == target[i] {
            i += 1
            continue
        }

        start := i

        for i < len(base) && base[i] != target[i] {
            i += 1
        }

        reference_put16(dst[cursor:cursor + 2], u16(start))
        reference_put16(dst[cursor + 2:cursor + 4], u16(i - start))
        cursor += 4

        for j in start ..< i {
            dst[cursor] = base[j] ~ target[j]
            cursor += 1
        }
    }

    return needed, true
}

reference_put16 :: proc(dst: []u8, value: u16) {
    dst[0], dst[1] = u8(value), u8(value >> 8)
}
