package replay_net

import "core:mem"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import sc "godot:replay/schema"

PHYSICS_CHECKPOINT_FINGERPRINT :: u64(0x524c504152433031)

// Archive v1 wraps the unchanged durable authority metadata and an independent
// complete canonical attachment. Neither policy_data nor logical dump bytes are
// used as an import format. Raw checkpoint_encode output belongs to its caller;
// use checkpoint_encode_owned when it should remain charged to this provider.
@(private)
checkpoint_encode_physics :: proc(
    cp: ^Checkpoint($S, $C, $A, $N),
    model: Model(S, C, A, $E, N),
    allocator: mem.Allocator,
    codec: ^Checkpoint_Codec,
) -> (
    []u8,
    Error,
) {
    if !checkpoint_valid(cp, model) {
        return nil, .Invalid_Checkpoint
    }

    if error := model.complete_codec.reserve(model.complete_codec.catalog, PHYSICS_SCHEMA_RESERVE); error != .None {
        return nil, error
    }

    defer model.complete_codec.release(model.complete_codec.catalog, PHYSICS_SCHEMA_RESERVE)
    value_model := model
    value_model.complete_state = false
    value := cp^
    value.complete = {}
    value.complete_charge = 0
    metadata, error := checkpoint_encode(&value, value_model, allocator, codec)

    if error != .None {
        return nil, error
    }

    defer delete(metadata, allocator)
    body_bytes := 16 + len(metadata) + len(cp.complete.bytes) + 32
    total := sc.HEADER_BYTES + body_bytes

    if total > MAX_CHECKPOINT_BYTES {
        return nil, .Capacity
    }

    if error := model.complete_codec.reserve(model.complete_codec.catalog, u64(total)); error != .None {
        return nil, error
    }

    defer model.complete_codec.release(model.complete_codec.catalog, u64(total))
    bytes, allocation_error := mem.alloc_bytes(total, allocator = allocator)

    if allocation_error != .None {
        return nil, .Capacity
    }

    body := bytes[sc.HEADER_BYTES:]
    copy(body[:8], "RPLARC01")
    complete_put32(body[8:12], u32(len(metadata)))
    complete_put32(body[12:16], u32(len(cp.complete.bytes)))
    copy(body[16:16 + len(metadata)], metadata)
    copy(body[16 + len(metadata):body_bytes - 32], cp.complete.bytes)
    digest := bd.hash_bytes(body[:body_bytes - 32])
    copy(body[body_bytes - 32:], digest[:])

    if sc.pack_bytes(PHYSICS_CHECKPOINT_FINGERPRINT, {kind = CHECKPOINT_KIND, epoch = cp.header.epoch, tick = cp.header.tick, content = cp.header.content}, body, bytes).error !=
       .None {
        delete(bytes, allocator)
        return nil, .Invalid_Checkpoint
    }

    return bytes, .None
}

checkpoint_encode_owned :: proc(
    cp: ^Checkpoint($S, $C, $A, $N),
    model: Model(S, C, A, $E, N),
    allocator := context.allocator,
    codec: ^Checkpoint_Codec = nil,
) -> (
    Complete_Data,
    Error,
) {
    bytes, error := checkpoint_encode(cp, model, allocator, codec)

    if error != .None {
        return {}, error
    }

    if !model.complete_state {
        return {bytes = bytes, allocator = allocator}, .None
    }

    if error := model.complete_codec.reserve(model.complete_codec.catalog, u64(len(bytes))); error != .None {
        delete(bytes, allocator)
        return {}, error
    }

    owned, owner_error := complete_data_adopt(bytes, allocator, model.complete_codec)

    if owner_error != .None {
        delete(bytes, allocator)
        model.complete_codec.release(model.complete_codec.catalog, u64(len(bytes)))
        return {}, owner_error
    }

    return owned, .None
}

@(private)
checkpoint_decode_physics :: proc(
    cp: ^Checkpoint($S, $C, $A, $N),
    incoming: []u8,
    model: Model(S, C, A, $E, N),
    content: u64,
    allocator: mem.Allocator,
    codec: ^Checkpoint_Codec,
    ownership: Container_Ownership,
) -> Error {
    if !checkpoint_empty(cp) {
        return .Wrong_Phase
    }

    bytes := incoming

    if !complete_codec_valid(model.complete_codec) ||
       len(bytes) < sc.HEADER_BYTES + 48 ||
       len(bytes) > MAX_CHECKPOINT_BYTES {
        return .Invalid_Checkpoint
    }

    outer, _, outer_report := sc.inspect(bytes)

    if outer_report.error != .None {
        return .Invalid_Checkpoint
    }

    _, body, body_report := sc.unpack_bytes(
        PHYSICS_CHECKPOINT_FINGERPRINT,
        bytes,
        {kind = CHECKPOINT_KIND, epoch = outer.epoch, content = content},
    )

    if body_report.error != .None || string(body[:8]) != "RPLARC01" {
        return .Invalid_Checkpoint
    }

    bytes = body
    a, b := int(complete_get32(bytes[8:12])), int(complete_get32(bytes[12:16]))

    if a < sc.HEADER_BYTES || b < COMPLETE_HEADER_BYTES + 32 || a + b != len(bytes) - 48 {
        return .Invalid_Checkpoint
    }

    digest := bd.hash_bytes(bytes[:len(bytes) - 32])

    if string(digest[:]) != string(bytes[len(bytes) - 32:]) {
        return .Invalid_Checkpoint
    }

    metadata, attachment := bytes[16:16 + a], bytes[16 + a:len(bytes) - 32]
    meta, _, report := sc.inspect(metadata)

    if report.error != .None || meta.epoch != outer.epoch || meta.tick != outer.tick || meta.content != outer.content {
        return .Invalid_Checkpoint
    }

    inspection, error := complete_inspect(attachment, model.complete_codec.identity, meta.epoch)

    if error != .None || inspection.purpose != .Archive || inspection.signature.tick != meta.tick {
        return .Invalid_Checkpoint
    }

    // Bound the existing metadata arrays before any count-driven allocation.
    charge :=
        u64(size_of(Checkpoint(S, C, A, N))) +
        u64(MAX_PEERS) *
            (u64(size_of(Checkpoint_Peer)) +
                    u64(ACTION_CAPACITY) * (u64(size_of(Checkpoint_Action(A))) + u64(size_of(Checkpoint_Outcome))) +
                    8 * u64(size_of(Checkpoint_Input(C)))) +
        64 * 32 +
        65536 +
        u64(b)

    if charge > 8 * 1024 * 1024 {
        return .Capacity
    }

    if error := model.complete_codec.reserve(model.complete_codec.catalog, charge); error != .None {
        return error
    }

    committed := false

    defer if !committed {
        model.complete_codec.release(model.complete_codec.catalog, charge)
    }

    if error := model.complete_codec.reserve(model.complete_codec.catalog, PHYSICS_SCHEMA_RESERVE); error != .None {
        return error
    }

    defer model.complete_codec.release(model.complete_codec.catalog, PHYSICS_SCHEMA_RESERVE)
    value_model := model
    value_model.complete_state = false
    temporary: Checkpoint(S, C, A, N)
    identity := model.complete_codec.identity

    if error := checkpoint_decode_protocol(
        &temporary,
        metadata,
        value_model,
        content,
        PROTOCOL_VERSION,
        allocator,
        codec,
        &identity,
        ownership,
    ); error != .None {
        return error
    }

    defer if !committed {
        checkpoint_destroy(&temporary)
    }

    storage, allocation_error := mem.alloc_bytes(b, allocator = allocator)

    if allocation_error != .None {
        return .Capacity
    }

    copy(storage, attachment)
    // Charge is transferred as the extra owner bytes; attachment is accounted in
    // the same reservation and therefore has no separate release callback.
    owned, owner_error := complete_data_adopt(storage, allocator, model.complete_codec)

    if owner_error != .None {
        delete(storage, allocator)
        return owner_error
    }

    temporary.complete = owned
    temporary.complete_charge = charge - u64(b)

    if !physics_receipts_valid(&temporary, inspection.metadata) {
        temporary.complete._release = nil
        temporary.complete_charge = 0
        return .Invalid_Checkpoint
    }

    image, image_error := checkpoint_complete_image(&temporary, model, allocator)

    if image_error != .None {
        // The deferred reservation owns the entire charge until transfer.
        temporary.complete._release = nil
        temporary.complete_charge = 0
        return image_error
    }

    r.complete_checkpoint_destroy(&image)
    cp^ = temporary
    committed = true
    return .None
}

@(private)
checkpoint_complete_image :: proc(
    cp: ^Checkpoint($S, $C, $A, $N),
    model: Model(S, C, A, $E, N),
    allocator: mem.Allocator,
) -> (
    r.Complete_Checkpoint(S, Net_Event(E)),
    Error,
) {
    inspection, error := complete_inspect(cp.complete.bytes, model.complete_codec.identity, cp.header.epoch)

    if error != .None || inspection.purpose != .Archive {
        return {}, .Invalid_Checkpoint
    }

    state, occurrence: sc.Schema
    defer sc.destroy(&state)
    defer sc.destroy(&occurrence)

    if sc.init(&state, S, allocator = allocator).error != .None ||
       sc.init(&occurrence, r.Occurrence(Net_Event(E)), allocator = allocator).error != .None {
        return {}, .Invalid_Schema
    }

    return complete_decode_image(model.complete_codec, inspection, cp.frame, &state, &occurrence, allocator)
}
