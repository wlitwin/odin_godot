package replay_assets

import "core:hash"

PNG_Info :: struct {
    width, height: u32,
}

// Resource preflight, not a complete PNG decoder. Check the signature and IHDR
// (including its CRC) before allowing an image decoder to allocate pixels.
// Format: https://www.w3.org/TR/png-3/#11IHDR and #5CRC-algorithm.
png_info :: proc(
    bytes: []u8,
    max_bytes: int = 128 * 1024,
    max_dimension: u32 = 2048,
    max_pixels: u64 = 1024 * 1024,
) -> (
    PNG_Info,
    bool,
) {
    if len(bytes) < 33 || len(bytes) > max_bytes || max_dimension == 0 || max_pixels == 0 {
        return {}, false
    }

    signature := [8]u8{137, 80, 78, 71, 13, 10, 26, 10}

    for b, i in signature {
        if bytes[i] != b {
            return {}, false
        }
    }

    if png_u32(bytes[8:12]) != 13 || bytes[12] != 'I' || bytes[13] != 'H' || bytes[14] != 'D' || bytes[15] != 'R' {
        return {}, false
    }

    if hash.crc32(bytes[12:29]) != png_u32(bytes[29:33]) {
        return {}, false
    }

    size := PNG_Info{png_u32(bytes[16:20]), png_u32(bytes[20:24])}

    if size.width == 0 ||
       size.height == 0 ||
       size.width > max_dimension ||
       size.height > max_dimension ||
       u64(size.width) * u64(size.height) > max_pixels {
        return {}, false
    }

    depth, color := bytes[24], bytes[25]
    valid_depth := false

    switch color {
    case 0:
        valid_depth = depth == 1 || depth == 2 || depth == 4 || depth == 8 || depth == 16
    case 2, 4, 6:
        valid_depth = depth == 8 || depth == 16
    case 3:
        valid_depth = depth == 1 || depth == 2 || depth == 4 || depth == 8
    }

    if !valid_depth || bytes[26] != 0 || bytes[27] != 0 || bytes[28] > 1 {
        return {}, false
    }

    return size, true
}

@(private)
png_u32 :: proc(bytes: []u8) -> u32 {
    return u32(bytes[0]) << 24 | u32(bytes[1]) << 16 | u32(bytes[2]) << 8 | u32(bytes[3])
}
