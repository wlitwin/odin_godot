package replay_compress
import "core:mem"
import d "godot:replay/delta"

MAX_BYTES :: 1024 * 1024
BLOCK_BYTES :: 65535

Workspace :: struct {
    lz4:   d.Lz4_Workspace,
    zeros: [BLOCK_BYTES]u8,
}

// Private transfer representation; raw byte count comes from the authenticated
// archive descriptor. Each block has a u16 encoded length (zero means raw).
// Encoding may modify scratch/dst on failure; callers publish only on success.
encode :: proc(src, dst: []u8, w: ^Workspace) -> (count: int, ok: bool) {
    if len(src) == 0 ||
       len(src) > MAX_BYTES ||
       len(dst) < 4 ||
       w == nil ||
       overlap(src, dst) ||
       overlap(src, mem.slice_ptr(cast(^u8)w, size_of(Workspace))) ||
       overlap(dst, mem.slice_ptr(cast(^u8)w, size_of(Workspace))) {
        return
    }

    for &byte in w.zeros {
        byte = 0
    }

    copy(dst[:4], []u8{'R', 'L', 'C', 1})
    count = 4

    for start := 0; start < len(src); start += BLOCK_BYTES {
        size := min(BLOCK_BYTES, len(src) - start)

        if len(dst) - count < 2 {
            return 0, false
        }

        n, compressed := d.lz4_xor_encode(w.zeros[:size], src[start:start + size], dst[count + 2:], &w.lz4)

        if compressed && n < size {
            dst[count], dst[count + 1] = u8(n), u8(n >> 8)
            count += 2 + n
        } else {
            if size > len(dst) - count - 2 {
                return 0, false
            }

            dst[count], dst[count + 1] = 0, 0
            copy(dst[count + 2:count + 2 + size], src[start:start + size])
            count += 2 + size
        }
    }

    return count, true
}

// Decoder commits only after all blocks have validated, using caller-owned
// scratch distinct from the source and destination. No allocation per block.
decode :: proc(src, dst, scratch: []u8) -> bool {
    if len(dst) == 0 ||
       len(dst) > MAX_BYTES ||
       len(scratch) < len(dst) ||
       len(src) < 4 ||
       src[0] != 'R' ||
       src[1] != 'L' ||
       src[2] != 'C' ||
       src[3] != 1 ||
       overlap(src, dst) ||
       overlap(src, scratch) ||
       overlap(dst, scratch) {
        return false
    }

    zeros: [BLOCK_BYTES]u8
    cursor := 4

    for start := 0; start < len(dst); start += BLOCK_BYTES {
        size := min(BLOCK_BYTES, len(dst) - start)

        if len(src) - cursor < 2 {
            return false
        }

        encoded := int(src[cursor]) | int(src[cursor + 1]) << 8
        cursor += 2

        if encoded == 0 {
            if size > len(src) - cursor {
                return false
            }

            copy(scratch[start:start + size], src[cursor:cursor + size])
            cursor += size
        } else {
            if encoded >= size ||
               encoded > len(src) - cursor ||
               !d.lz4_xor_apply(zeros[:size], src[cursor:cursor + encoded], scratch[start:start + size]) {
                return false
            }

            cursor += encoded
        }
    }

    if cursor != len(src) {
        return false
    }

    copy(dst, scratch[:len(dst)])
    return true
}

@(private)
overlap :: proc(a, b: []u8) -> bool {
    if len(a) == 0 || len(b) == 0 {
        return false
    }

    x, y := uintptr(raw_data(a)), uintptr(raw_data(b))
    return x <= y ? y - x < uintptr(len(a)) : x - y < uintptr(len(b))
}
