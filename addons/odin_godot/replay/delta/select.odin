package replay_delta

Encoding :: enum {
    Sparse,
    Lz4,
}

// Select the smallest existing encoding that fits dst, preferring Sparse on a
// tie. Output bytes match encoding both candidates fully and taking the winner.
// Failure leaves dst unchanged. A nil workspace selects sparse-only operation.
// No new dictionary, allocation, wire format or decoder is introduced.
encode_smallest :: proc(base, target, dst: []u8, work: ^Lz4_Workspace = nil) -> (size: int, kind: Encoding, ok: bool) {
    if len(base) != len(target) || len(base) > 65535 || overlaps(dst, base) || overlaps(dst, target) {
        return
    }

    if work == nil {
        size, ok = encode_bounded(base, target, dst, len(dst))
        return
    }

    scratch := (cast([^]u8)work)[:size_of(Lz4_Workspace)]

    if overlaps(scratch, base) || overlaps(scratch, target) || overlaps(scratch, dst) {
        return
    }

    // Every LZ4 byte accounts for at most 255 decoded bytes. A sparse encoding
    // no larger than this bound wins even a tie, so a tiny trial can skip LZ4.
    lower := max(1, (len(base) + 254) / 255)

    if n, small := encode_bounded(base, target, dst, min(lower, len(dst))); small {
        return n, .Sparse, true
    }

    // Stage LZ4 until the winner is known, so a smaller sparse winner does
    // not leave discarded candidate bytes beyond its returned extent.
    n := lz4_encode_pass(base, target, work.encoded[:], work, true)
    lz4 := n <= len(dst)
    budget := len(dst)

    if lz4 {
        budget = n
    }

    if count, sparse := encode_bounded(base, target, dst, budget); sparse {
        return count, .Sparse, true
    }

    if lz4 {
        copy(dst[:n], work.encoded[:n])
        return n, .Lz4, true
    }

    return
}
