package replay_schema

// Versioned message envelope around one canonical value. This is framing and
// accidental-corruption detection, NOT authentication or a migration protocol.
// The application/session authenticates transport identity and adjudicates ticks.
HEADER_BYTES :: 52

Envelope_Meta :: struct {
    kind:                 u16,
    epoch, tick, content: u64,
}

pack :: proc(s: ^Schema, value: $T, meta: Envelope_Meta, dst: []u8) -> Report {
    if !s.ready {
        return {error = .Not_Ready}
    }

    if meta.kind == 0 || meta.epoch == 0 {
        return {.Invalid_Header, "$header"}
    }

    if len(dst) < HEADER_BYTES + s.wire_size {
        return {error = .Wrong_Size}
    }

    // encode preflights the complete value, so failure cannot expose a partial
    // body or header. Once it succeeds, all remaining writes are infallible.
    body := dst[HEADER_BYTES:HEADER_BYTES + s.wire_size]

    if report := encode(s, value, body); report.error != .None {
        return report
    }

    return pack_bytes(s.fingerprint, meta, body, dst)
}

// Framing for bounded custom encodings (deltas and compact event batches).
// Fingerprint describes their negotiated logical schema; the message kind and
// protocol contract identify the custom body codec. Payload may alias dst's body.
pack_bytes :: proc(fingerprint: u64, meta: Envelope_Meta, payload, dst: []u8) -> Report {
    if meta.kind == 0 || meta.epoch == 0 {
        return {.Invalid_Header, "$header"}
    }

    if len(payload) > 1024 * 1024 || len(dst) < HEADER_BYTES + len(payload) {
        return {error = .Wrong_Size}
    }

    body := dst[HEADER_BYTES:HEADER_BYTES + len(payload)]
    copy(body, payload)
    dst[0], dst[1], dst[2], dst[3] = 'R', 'P', 'L', 'Y'
    write_bits(dst[4:6], FORMAT_VERSION, false)
    write_bits(dst[6:8], u64(meta.kind), false)
    write_bits(dst[8:16], meta.epoch, false)
    write_bits(dst[16:24], meta.tick, false)
    write_bits(dst[24:32], fingerprint, false)
    write_bits(dst[32:40], meta.content, false)
    write_bits(dst[40:44], u64(len(body)), false)
    checksum := digest(body, digest(dst[:44]))
    write_bits(dst[44:52], checksum, false)
    return {}
}

// Header can be inspected for routing, but is untrusted until unpack validates
// it. Exact packet length is checked before deriving the body slice.
inspect :: proc(src: []u8) -> (meta: Envelope_Meta, fingerprint: u64, report: Report) {
    if len(src) < HEADER_BYTES {
        return {}, 0, {error = .Wrong_Size}
    }

    if src[0] != 'R' ||
       src[1] != 'P' ||
       src[2] != 'L' ||
       src[3] != 'Y' ||
       read_bits(src[4:6], false) != FORMAT_VERSION {
        return {}, 0, {.Invalid_Header, "$header"}
    }

    size := read_bits(src[40:44], false)

    if size > 1024 * 1024 || u64(len(src) - HEADER_BYTES) != size {
        return {}, 0, {error = .Wrong_Size}
    }

    meta = {
        u16(read_bits(src[6:8], false)),
        read_bits(src[8:16], false),
        read_bits(src[16:24], false),
        read_bits(src[32:40], false),
    }

    if meta.kind == 0 || meta.epoch == 0 {
        return {}, 0, {.Invalid_Header, "$header"}
    }

    return meta, read_bits(src[24:32], false), {}
}

// Require exact message kind, authority epoch, and content contract. The tick is
// returned for application scheduling/range checks; expected.tick is unused.
// No destination state changes on ANY header/checksum/value failure.
unpack :: proc(s: ^Schema, dst: ^$T, src: []u8, expected: Envelope_Meta) -> (meta: Envelope_Meta, report: Report) {
    if !s.ready {
        return {}, {error = .Not_Ready}
    }

    payload: []u8
    meta, payload, report = unpack_bytes(s.fingerprint, src, expected)

    if report.error != .None {
        return {}, report
    }

    if report := decode(s, dst, payload); report.error != .None {
        return {}, report
    }

    return meta, {}
}

unpack_bytes :: proc(
    expected_fingerprint: u64,
    src: []u8,
    expected: Envelope_Meta,
) -> (
    meta: Envelope_Meta,
    payload: []u8,
    report: Report,
) {
    fingerprint: u64
    meta, fingerprint, report = inspect(src)

    if report.error != .None {
        return {}, nil, report
    }

    if fingerprint != expected_fingerprint {
        return {}, nil, {.Schema_Mismatch, "$header.schema"}
    }

    if meta.kind != expected.kind || meta.epoch != expected.epoch || meta.content != expected.content {
        return {}, nil, {.Context_Mismatch, "$header.context"}
    }

    checksum := digest(src[HEADER_BYTES:], digest(src[:44]))

    if read_bits(src[44:52], false) != checksum {
        return {}, nil, {.Checksum_Mismatch, "$header.checksum"}
    }

    return meta, src[HEADER_BYTES:], {}
}
