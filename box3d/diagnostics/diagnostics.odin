// Native-free confirmed-frame diagnostics. These hashes are not authentication.
package box3d_diagnostics

import "core:crypto/sha2"

Digest :: [32]u8
FORMAT_VERSION :: 1
SIGNATURE_BYTES :: 480

Part :: enum u8 {
    Solver,
    Game,
    Side,
    Observations,
    Occurrences,
}

Difference :: enum u8 {
    Match,
    Identity,
    Frame,
    Solver,
    Game,
    Side,
    Observations,
    Occurrences,
}

Error :: enum {
    None,
    Invalid,
    Limit,
    Capacity,
    Checksum,
    Incompatible,
    No_Mismatch,
    Already_Captured,
    Out_Of_Memory,
}

// Hash canonical descriptors, never local typeid values or native struct bytes.
// build_target binds source, patches, compiler, private ABI and FP/SIMD policy.
Identity :: struct {
    solver_format, recovery_format, game_format, observation_format:                    u32,
    profile:                                                                            u64,
    build_target, assets, solver_schema, game_schema, observation_schema, input_schema: Digest,
}

Frame_View :: struct {
    identity:    Identity,
    epoch, tick: u64,
    parts:       [Part][]u8,
}

Signature :: struct {
    identity:    Identity,
    epoch, tick: u64,
    lengths:     [Part]u64,
    digests:     [Part]Digest,
    complete:    Digest,
}

Limits :: struct {
    max_part_bytes, max_frame_bytes, max_input_bytes: int,
}

DEFAULT_LIMITS :: Limits{1024 * 1024, 2 * 1024 * 1024, 64 * 1024}

hash_bytes :: proc(bytes: []u8) -> Digest {
    h: sha2.Context_256
    sha2.init_256(&h)
    sha2.update(&h, bytes)
    result: Digest
    sha2.final(&h, result[:])
    return result
}

@(private)
valid_limits :: proc(l: Limits) -> bool {
    return(
        l.max_part_bytes > 0 &&
        l.max_part_bytes <= 2 * 1024 * 1024 &&
        l.max_frame_bytes >= l.max_part_bytes &&
        l.max_frame_bytes <= 4 * 1024 * 1024 &&
        l.max_input_bytes >= 0 &&
        l.max_input_bytes <= 256 * 1024 \
    )
}

@(private)
valid_identity :: proc(id: Identity) -> bool {
    return(
        id.solver_format != 0 &&
        id.recovery_format != 0 &&
        id.game_format != 0 &&
        id.observation_format != 0 &&
        id.profile != 0 &&
        id.build_target != Digest{} &&
        id.assets != Digest{} &&
        id.solver_schema != Digest{} &&
        id.game_schema != Digest{} &&
        id.observation_schema != Digest{} &&
        id.input_schema != Digest{} \
    )
}

@(private)
valid_lengths :: proc(sig: Signature, limits: Limits) -> Error {
    if !valid_limits(limits) || !valid_identity(sig.identity) || sig.epoch == 0 || sig.lengths[.Solver] == 0 {
        return .Invalid
    }

    total: u64

    for n in sig.lengths {
        if n > u64(limits.max_part_bytes) || n > u64(limits.max_frame_bytes) - total {
            return .Limit
        }

        total += n
    }

    return .None
}

// Caller supplies canonical bytes covering every admitted deterministic field.
// In particular Solver includes future pending events, and Observations contains
// same-tick provider outputs. A pose or motion digest cannot replace Solver.
sign :: proc(frame: Frame_View, limits := DEFAULT_LIMITS) -> (Signature, Error) {
    sig := Signature {
        identity = frame.identity,
        epoch    = frame.epoch,
        tick     = frame.tick,
    }

    for p in Part {
        sig.lengths[p] = u64(len(frame.parts[p]))
    }

    if err := valid_lengths(sig, limits); err != .None {
        return {}, err
    }

    for p in Part {
        sig.digests[p] = hash_bytes(frame.parts[p])
    }

    bytes: [SIGNATURE_BYTES]u8
    write_signature(sig, bytes[:])
    sig.complete = hash_bytes(bytes[:SIGNATURE_BYTES - 32])
    return sig, .None
}

// Compare signatures produced by sign or validated by signature_decode.
// A raw native Signature struct received from outside is never a wire value.
compare :: proc(expected, actual: Signature) -> Difference {
    if expected.identity != actual.identity {
        return .Identity
    }

    if expected.epoch != actual.epoch || expected.tick != actual.tick {
        return .Frame
    }

    for p in Part {
        if expected.lengths[p] != actual.lengths[p] || expected.digests[p] != actual.digests[p] {
            return Difference(int(Difference.Solver) + int(p))
        }
    }

    return .Match
}

// Empty dst queries required capacity; a short nonempty dst is untouched.
signature_encode :: proc(sig: Signature, dst: []u8, limits := DEFAULT_LIMITS) -> (int, Error) {
    if err := validate_signature(sig, limits); err != .None {
        return 0, err
    }

    if len(dst) == 0 {
        return SIGNATURE_BYTES, .None
    }

    if len(dst) < SIGNATURE_BYTES {
        return SIGNATURE_BYTES, .Capacity
    }

    write_signature(sig, dst[:SIGNATURE_BYTES])
    return SIGNATURE_BYTES, .None
}

signature_decode :: proc(src: []u8, limits := DEFAULT_LIMITS) -> (Signature, Error) {
    if len(src) != SIGNATURE_BYTES || string(src[:8]) != "OGB3SIG1" {
        return {}, .Invalid
    }

    at := 8

    if read_u32(src, &at) != FORMAT_VERSION || read_u32(src, &at) != 0 {
        return {}, .Incompatible
    }

    sig: Signature
    sig.identity = read_identity(src, &at)
    sig.epoch = read_u64(src, &at)
    sig.tick = read_u64(src, &at)

    for p in Part {
        sig.lengths[p] = read_u64(src, &at)
        copy(sig.digests[p][:], src[at:at + 32])
        at += 32
    }

    copy(sig.complete[:], src[at:at + 32])

    if err := validate_signature(sig, limits); err != .None {
        return {}, err
    }

    return sig, .None
}

@(private)
validate_signature :: proc(sig: Signature, limits: Limits) -> Error {
    if err := valid_lengths(sig, limits); err != .None {
        return err
    }

    bytes: [SIGNATURE_BYTES]u8
    write_signature(sig, bytes[:])

    if sig.complete != hash_bytes(bytes[:SIGNATURE_BYTES - 32]) {
        return .Checksum
    }

    return .None
}

@(private)
write_signature :: proc(sig: Signature, dst: []u8) {
    sig := sig
    copy(dst[:8], "OGB3SIG1")
    at := 8
    write_u32(dst, &at, FORMAT_VERSION)
    write_u32(dst, &at, 0)
    write_identity(dst, &at, sig.identity)
    write_u64(dst, &at, sig.epoch)
    write_u64(dst, &at, sig.tick)

    for p in Part {
        write_u64(dst, &at, sig.lengths[p])
        copy(dst[at:at + 32], sig.digests[p][:])
        at += 32
    }

    copy(dst[at:at + 32], sig.complete[:])
}

@(private)
write_identity :: proc(dst: []u8, at: ^int, id: Identity) {
    write_u32(dst, at, id.solver_format)
    write_u32(dst, at, id.recovery_format)
    write_u32(dst, at, id.game_format)
    write_u32(dst, at, id.observation_format)
    write_u64(dst, at, id.profile)

    for h in ([6]Digest {
            id.build_target,
            id.assets,
            id.solver_schema,
            id.game_schema,
            id.observation_schema,
            id.input_schema,
        }) {
        h := h
        copy(dst[at^:at^ + 32], h[:])
        at^ += 32
    }
}

@(private)
read_identity :: proc(src: []u8, at: ^int) -> Identity {
    id: Identity
    id.solver_format = read_u32(src, at)
    id.recovery_format = read_u32(src, at)
    id.game_format = read_u32(src, at)
    id.observation_format = read_u32(src, at)
    id.profile = read_u64(src, at)

    for h in ([6]^Digest {
            &id.build_target,
            &id.assets,
            &id.solver_schema,
            &id.game_schema,
            &id.observation_schema,
            &id.input_schema,
        }) {
        copy(h[:], src[at^:at^ + 32])
        at^ += 32
    }

    return id
}

@(private)
write_u32 :: proc(dst: []u8, at: ^int, v: u32) {
    for i in 0 ..< 4 {
        dst[at^ + i] = u8(v >> uint(8 * i))
    }

    at^ += 4
}

@(private)
write_u64 :: proc(dst: []u8, at: ^int, v: u64) {
    for i in 0 ..< 8 {
        dst[at^ + i] = u8(v >> uint(8 * i))
    }

    at^ += 8
}

@(private)
read_u32 :: proc(src: []u8, at: ^int) -> u32 {
    v: u32

    for i in 0 ..< 4 {
        v |= u32(src[at^ + i]) << uint(8 * i)
    }

    at^ += 4
    return v
}

@(private)
read_u64 :: proc(src: []u8, at: ^int) -> u64 {
    v: u64

    for i in 0 ..< 8 {
        v |= u64(src[at^ + i]) << uint(8 * i)
    }

    at^ += 8
    return v
}
