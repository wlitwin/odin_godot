package lz4_reference

import "base:intrinsics"

// Independent LZ4 blocks over canonical XOR bytes. No foreign dependency.
// Bounded to the same 65,535-byte canonical values as the sparse delta codec.
// Workspace is single-owner scratch and contains no persistent dictionary.
Lz4_Workspace :: struct {
    positions: [4096]u32,
}

lz4_xor_encode :: proc(base, target, dst: []u8, work: ^Lz4_Workspace) -> (size: int, ok: bool) {
    if len(base) != len(target) || len(base) > 65535 || work == nil || overlaps(dst, base) || overlaps(dst, target) {
        return
    }

    scratch := (cast([^]u8)work)[:size_of(Lz4_Workspace)]

    if overlaps(scratch, base) || overlaps(scratch, target) || overlaps(scratch, dst) {
        return
    }

    needed := lz4_encode_pass(base, target, nil, work, false)

    if needed > len(dst) {
        return needed, false
    }

    written := lz4_encode_pass(base, target, dst, work, true)
    assert(written == needed)
    return written, true
}

// Preflight validates the entire block before writing. Output must not overlap
// either input. The block decodes to XOR bytes, then the base restores the value.
lz4_xor_apply :: proc(base, encoded, dst: []u8) -> bool {
    if len(base) != len(dst) || len(base) > 65535 || overlaps(dst, base) || overlaps(dst, encoded) {
        return false
    }

    if !lz4_decode_pass(encoded, dst, false) {
        return false
    }

    assert(lz4_decode_pass(encoded, dst, true))

    for &b, i in dst {
        b ~= base[i]
    }

    return true
}

@(private)
overlaps :: proc(a, b: []u8) -> bool {
    if len(a) == 0 || len(b) == 0 {
        return false
    }

    x, y := uintptr(raw_data(a)), uintptr(raw_data(b))
    return x <= y ? y - x < uintptr(len(a)) : x - y < uintptr(len(b))
}

@(private)
lz4_word :: proc(a, b: []u8, at: int) -> u32 {
    value := intrinsics.unaligned_load(cast(^u32)&a[at]) ~ intrinsics.unaligned_load(cast(^u32)&b[at])

    when ODIN_ENDIAN == .Big {
        return intrinsics.byte_swap(value)
    } else {
        return value
    }
}

@(private)
lz4_hash :: proc(value: u32) -> int {
    return int((value * u32(2654435761)) >> 20)
}

@(private)
lz4_emit :: proc(dst: []u8, cursor: ^int, value: u8, write: bool) {
    if write {
        dst[cursor^] = value
    }

    cursor^ += 1
}

@(private)
lz4_length :: proc(dst: []u8, cursor: ^int, length: int, write: bool) {
    n := length

    for n >= 255 {
        lz4_emit(dst, cursor, 255, write)
        n -= 255
    }

    lz4_emit(dst, cursor, u8(n), write)
}

@(private)
lz4_sequence :: proc(a, b, dst: []u8, cursor: ^int, anchor, at, offset, match: int, write: bool) {
    literals := at - anchor
    encoded_match := max(match - 4, 0)
    lz4_emit(dst, cursor, u8(min(literals, 15) << 4) | u8(min(encoded_match, 15)), write)

    if literals >= 15 {
        lz4_length(dst, cursor, literals - 15, write)
    }

    if write {
        for i in anchor ..< at {
            dst[cursor^] = a[i] ~ b[i]
            cursor^ += 1
        }
    } else {
        cursor^ += literals
    }

    if match == 0 {
        return
    }

    lz4_emit(dst, cursor, u8(offset), write)
    lz4_emit(dst, cursor, u8(offset >> 8), write)

    if encoded_match >= 15 {
        lz4_length(dst, cursor, encoded_match - 15, write)
    }
}

@(private)
lz4_encode_pass :: proc(a, b, dst: []u8, work: ^Lz4_Workspace, write: bool) -> int {
    work.positions = {}
    cursor, anchor, at := 0, 0, 0
    n := len(a)

    // The final five bytes remain literals and the last match begins at least
    // twelve bytes before the end, as required by the LZ4 block format.
    for at <= n - 12 {
        word := lz4_word(a, b, at)
        hash := lz4_hash(word)
        stored := work.positions[hash]
        work.positions[hash] = u32(at + 1)

        if stored == 0 {
            at += 1
            continue
        }

        previous := int(stored - 1)

        if previous >= at || at - previous > 65535 || lz4_word(a, b, previous) != word {
            at += 1
            continue
        }

        match := 4

        for at + match + 8 <= n - 5 {
            difference :=
                intrinsics.unaligned_load(cast(^u64)&a[previous + match]) ~
                intrinsics.unaligned_load(cast(^u64)&b[previous + match]) ~
                intrinsics.unaligned_load(cast(^u64)&a[at + match]) ~
                intrinsics.unaligned_load(cast(^u64)&b[at + match])

            if difference != 0 {
                when ODIN_ENDIAN == .Little {
                    match += int(intrinsics.count_trailing_zeros(difference) / 8)
                } else {
                    match += int(intrinsics.count_leading_zeros(difference) / 8)
                }

                break
            }

            match += 8
        }

        for at + match < n - 5 && a[previous + match] ~ b[previous + match] == a[at + match] ~ b[at + match] {
            match += 1
        }

        lz4_sequence(a, b, dst, &cursor, anchor, at, at - previous, match, write)
        at += match
        anchor = at

        if at >= 2 && at - 2 <= n - 4 {
            work.positions[lz4_hash(lz4_word(a, b, at - 2))] = u32(at - 1)
        }
    }

    lz4_sequence(a, b, dst, &cursor, anchor, n, 0, 0, write)
    return cursor
}

@(private)
lz4_read_length :: proc(src: []u8, cursor: ^int, initial, limit: int) -> (length: int, ok: bool) {
    length = initial

    if length > limit {
        return length, false
    }

    if initial != 15 {
        return length, true
    }

    for {
        if cursor^ == len(src) {
            return length, false
        }

        extra := int(src[cursor^])
        cursor^ += 1

        if extra > limit - length {
            return length, false
        }

        length += extra

        if extra != 255 {
            return length, true
        }
    }
}

@(private)
lz4_decode_pass :: proc(src, dst: []u8, write: bool) -> bool {
    ip, op := 0, 0
    had_match := false
    last_match := 0

    for ip < len(src) {
        token := src[ip]
        ip += 1
        literals, ok := lz4_read_length(src, &ip, int(token >> 4), len(dst) - op)

        if !ok || literals > len(src) - ip {
            return false
        }

        if write {
            copy(dst[op:op + literals], src[ip:ip + literals])
        }

        ip += literals
        op += literals

        if ip == len(src) {
            return op == len(dst) && (!had_match || literals >= 5 && last_match <= len(dst) - 12)
        }

        if len(src) - ip < 2 {
            return false
        }

        offset := int(src[ip]) | int(src[ip + 1]) << 8
        ip += 2

        if offset == 0 || offset > op || len(dst) - op < 4 {
            return false
        }

        match, found := lz4_read_length(src, &ip, int(token & 15), len(dst) - op - 4)

        if !found {
            return false
        }

        match += 4
        last_match = op
        had_match = true

        if write {
            if offset == 1 {
                value := dst[op - 1]

                for &b in dst[op:op + match] {
                    b = value
                }
            } else {
                for i in 0 ..< match {
                    dst[op + i] = dst[op - offset + i]
                }
            }
        }

        op += match
    }

    return false
}
