package replay_erasure

// Two systematic parity rows over GF(256), polynomial x^8+x^4+x^3+x^2+1.
// P = sum(data[i]); Q = sum(2^i * data[i]). Up to eight data shards;
// any two erased shards among data/P/Q can be recovered without an allocation.
DATA_SHARDS :: 8
PARITY_SHARDS :: 2
MAX_SHARD_BYTES :: 1024

@(private)
twice :: proc(x: u8) -> u8 {
    return (x << 1) ~ (x & 0x80 != 0 ? u8(0x1d) : 0)
}

@(private)
mul :: proc(a, b: u8) -> u8 {
    x, y, out := a, b, u8(0)

    for _ in 0 ..< 8 {
        if y & 1 != 0 {
            out ~= x
        }

        x = twice(x)
        y >>= 1
    }

    return out
}

@(private)
inverse :: proc(x: u8) -> u8 {
    out, base := u8(1), x
    exponent := 254

    for exponent > 0 {
        if exponent & 1 != 0 {
            out = mul(out, base)
        }

        base = mul(base, base)
        exponent >>= 1
    }

    return out
}

@(private)
alias :: proc(a, b: []u8) -> bool {
    if len(a) == 0 || len(b) == 0 {
        return false
    }

    x, y := uintptr(raw_data(a)), uintptr(raw_data(b))
    return x <= y ? y - x < uintptr(len(a)) : x - y < uintptr(len(b))
}

@(private)
valid :: proc(data: [][]u8, parity: [2][]u8) -> bool {
    if len(data) < 1 ||
       len(data) > DATA_SHARDS ||
       len(parity[0]) < 1 ||
       len(parity[0]) > MAX_SHARD_BYTES ||
       len(parity[1]) != len(parity[0]) ||
       alias(parity[0], parity[1]) {
        return false
    }

    largest := 0

    for shard, i in data {
        if len(shard) < 1 || len(shard) > len(parity[0]) || alias(shard, parity[0]) || alias(shard, parity[1]) {
            return false
        }

        for prior in data[:i] {
            if alias(shard, prior) {
                return false
            }
        }

        largest = max(largest, len(shard))
    }

    return largest == len(parity[0])
}

// Short data shards are virtually padded with zeros. The two parity buffers
// must both equal the largest data length and must not alias any data buffer.
encode :: proc(data: [][]u8, parity: [2][]u8) -> bool {
    if !valid(data, parity) {
        return false
    }

    for byte in 0 ..< len(parity[0]) {
        p, q := u8(0), u8(0)

        for i := len(data) - 1; i >= 0; i -= 1 {
            value := byte < len(data[i]) ? data[i][byte] : u8(0)
            p ~= value
            q = twice(q) ~ value
        }

        parity[0][byte], parity[1][byte] = p, q
    }

    return true
}

// Missing data bits identify output buffers to reconstruct; present_parity bits
// identify received P/Q. Rejection changes no buffer. Success changes only the
// missing data. This repairs erasures, not corruption: callers validate a digest.
recover :: proc(data: [][]u8, parity: [2][]u8, missing, present_parity: u8) -> bool {
    if !valid(data, parity) || (u16(missing) >> uint(len(data))) != 0 || present_parity & 0xfc != 0 {
        return false
    }

    absent: [2]int
    count := 0

    for i in 0 ..< len(data) {
        if missing & (u8(1) << uint(i)) != 0 {
            if count == 2 {
                return false
            }

            absent[count] = i
            count += 1
        }
    }

    if count == 0 {
        return true
    }

    if present_parity == 0 || count == 2 && present_parity != 3 {
        return false
    }

    a := u8(1) << uint(absent[0])
    b := u8(1) << uint(absent[1])
    factor := count == 2 ? inverse(a ~ b) : inverse(a)
    divide, weight: [256]u8

    if count == 2 || present_parity & 1 == 0 {
        for i in 0 ..< 256 {
            divide[i] = mul(factor, u8(i))
            weight[i] = mul(b, u8(i))
        }
    }

    for byte in 0 ..< len(parity[0]) {
        p, q := u8(0), u8(0)

        for i := len(data) - 1; i >= 0; i -= 1 {
            value := u8(0)

            if missing & (u8(1) << uint(i)) == 0 && byte < len(data[i]) {
                value = data[i][byte]
            }

            p ~= value
            q = twice(q) ~ value
        }

        p ~= parity[0][byte]
        q ~= parity[1][byte]
        first := present_parity & 1 != 0 ? p : divide[q]

        if count == 2 {
            first = divide[q ~ weight[p]]
        }

        if byte < len(data[absent[0]]) {
            data[absent[0]][byte] = first
        }

        if count == 2 && byte < len(data[absent[1]]) {
            data[absent[1]][byte] = p ~ first
        }
    }

    return true
}
