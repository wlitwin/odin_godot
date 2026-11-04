package replay_physics_net_test

import "core:testing"
import net "godot:replay/net"
import r "godot:replay"
import sc "godot:replay/schema"
import bd "godot:box3d/diagnostics"
import f "godot:tests/replay_external/fixture"

Catalog :: struct {
    charged:      u64,
    decode_calls: u32,
    stats:        f.Stats,
}

reserve :: proc(pointer: rawptr, bytes: u64) -> net.Error {
    c := cast(^Catalog)pointer

    if bytes > net.COMPLETE_MAX_BYTES * 4 - c.charged {
        return .Capacity
    }

    c.charged += bytes
    return .None
}

release :: proc(pointer: rawptr, bytes: u64) {
    c := cast(^Catalog)pointer
    assert(c.charged >= bytes)
    c.charged -= bytes
}

part :: proc(
    pointer: rawptr,
    checkpoint: ^r.Complete_Checkpoint(f.Game, i64),
    kind: bd.Part,
    dst: []u8,
) -> (
    int,
    net.Error,
) {
    n := kind == .Solver ? 8 : kind == .Observations ? 2 : 0

    if len(dst) == 0 {
        return n, .None
    }

    if len(dst) < n {
        return n, .Capacity
    }

    if kind == .Solver {
        value := u64(f.value(checkpoint))

        for i in 0 ..< 8 {
            dst[i] = u8(value >> uint(i * 8))
        }
    }

    if kind == .Observations {
        dst[0] = 1
        dst[1] = 2
    }

    return n, .None
}

attachment_encode :: proc(
    pointer: rawptr,
    checkpoint: ^r.Complete_Checkpoint(f.Game, i64),
    dst: []u8,
) -> (
    int,
    net.Error,
) {
    return part(pointer, checkpoint, .Solver, dst)
}

attachment_decode :: proc(
    pointer: rawptr,
    frame: r.Frame(f.Game),
    epoch: u64,
    events: []r.Occurrence(i64),
    src: []u8,
) -> (
    r.Complete_Checkpoint(f.Game, i64),
    net.Error,
) {
    c := cast(^Catalog)pointer
    c.decode_calls += 1

    if len(src) != 8 {
        return {}, .Invalid_Frame
    }

    value: u64

    for byte, i in src {
        value |= u64(byte) << uint(i * 8)
    }

    base, owner := f.checkpoint(i64, &c.stats, i64(value), frame)
    defer f.owner_destroy(&owner)
    defer r.complete_checkpoint_destroy(&base)
    image, error := base._external.clone(base._image)

    if error != .None {
        return {}, .Capacity
    }

    result, adopt_error := r.complete_checkpoint_adopt(
        frame,
        i64,
        base._external,
        image,
        base._image_bytes,
        epoch,
        events,
    )

    if adopt_error != .None {
        base._external.release(image)
        return {}, .Invalid_Frame
    }

    return result, .None
}

wire_codec :: proc(c: ^Catalog, state, event: ^sc.Schema) -> net.Complete_Codec(f.Game, i64) {
    rules := bd.hash_bytes([]u8{7, 8, 9})
    game, _ := net.complete_game_schema(state, event, rules)
    id := bd.hash_bytes([]u8{1, 2, 3})
    return {
        identity = {
            solver_format = 1,
            recovery_format = 1,
            game_format = 1,
            observation_format = 1,
            profile = 1,
            build_target = id,
            assets = id,
            solver_schema = id,
            game_schema = game,
            observation_schema = id,
            input_schema = id,
        },
        game_rules = rules,
        catalog = c,
        max_attachment_bytes = 64,
        encode = attachment_encode,
        decode = attachment_decode,
        diagnostic_part = part,
        reserve = reserve,
        release = release,
    }
}

@(test)
complete_envelope_roundtrip_binds_game_solver_observations_and_occurrences :: proc(t: ^testing.T) {
    c: Catalog
    initial, owner := f.checkpoint(i64, &c.stats, 11, r.Frame(f.Game){tick = 3, state = {sum = 7, ticks = 3}})
    defer f.owner_destroy(&owner)
    defer r.complete_checkpoint_destroy(&initial)
    state, event: sc.Schema
    defer sc.destroy(&state)
    defer sc.destroy(&event)
    testing.expect_value(t, sc.init(&state, f.Game).error, sc.Error.None)
    testing.expect_value(t, sc.init(&event, r.Occurrence(i64)).error, sc.Error.None)
    codec := wire_codec(&c, &state, &event)
    data, error := net.complete_encode(codec, &initial, .Snapshot, []u8{1, 2}, &state, &event)
    testing.expect_value(t, error, net.Error.None)
    inspection, inspect_error := net.complete_inspect(data.bytes, codec.identity, 1)
    testing.expect_value(t, inspect_error, net.Error.None)
    decoded, decode_error := net.complete_decode_image(codec, inspection, initial.frame, &state, &event)
    testing.expect_value(t, decode_error, net.Error.None)
    testing.expect_value(t, f.value(&decoded), i64(11))
    r.complete_checkpoint_destroy(&decoded)
    before_calls := c.decode_calls
    data.bytes[len(data.bytes) - 1] ~= 1
    _, bad := net.complete_inspect(data.bytes, codec.identity, 1)
    testing.expect_value(t, bad, net.Error.Invalid_Frame)
    testing.expect_value(t, c.decode_calls, before_calls)
    net.complete_data_destroy(&data)
    testing.expect_value(t, c.charged, u64(0))
}

@(test)
valid_checksum_cannot_hide_a_semantically_different_decoded_solver :: proc(t: ^testing.T) {
    c: Catalog
    initial, owner := f.checkpoint(i64, &c.stats, 11, r.Frame(f.Game){tick = 3})
    defer f.owner_destroy(&owner)
    defer r.complete_checkpoint_destroy(&initial)
    state, event: sc.Schema
    defer sc.destroy(&state)
    defer sc.destroy(&event)
    _ = sc.init(&state, f.Game)
    _ = sc.init(&event, r.Occurrence(i64))
    codec := wire_codec(&c, &state, &event)
    data, error := net.complete_encode(codec, &initial, .Welcome, nil, &state, &event)
    testing.expect_value(t, error, net.Error.None)
    defer net.complete_data_destroy(&data)
    data.bytes[len(data.bytes) - 32 - 8] = 12
    checksum := bd.hash_bytes(data.bytes[:len(data.bytes) - 32])
    copy(data.bytes[len(data.bytes) - 32:], checksum[:])
    inspection, inspect_error := net.complete_inspect(data.bytes, codec.identity, 1)
    testing.expect_value(t, inspect_error, net.Error.None)
    decoded, decode_error := net.complete_decode_image(codec, inspection, initial.frame, &state, &event)
    testing.expect_value(t, decode_error, net.Error.Invalid_Frame)
    r.complete_checkpoint_destroy(&decoded)
    other := codec.identity
    other.profile += 1
    _, identity_error := net.complete_inspect(data.bytes, other, 1)
    testing.expect_value(t, identity_error, net.Error.Checkpoint_Contract)
}
