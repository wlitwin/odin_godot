package replay_net

import "core:mem"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import sc "godot:replay/schema"
import tf "godot:replay/transfer"

COMPLETE_WIRE_VERSION :: u32(1)
COMPLETE_MAX_BYTES :: 1024 * 1024
COMPLETE_PART_BYTES :: 32 * 1024

// Optional native-free adapter surface. Context is an immutable retained codec/
// asset catalog, never live simulation state or Model.user. Decode validates and
// returns a NEW owned checkpoint without mutating an existing Timeline.
Complete_Codec :: struct($State, $Event: typeid) {
    ownership:            Container_Ownership, // runtime only; not bd.Identity or wire
    identity:             bd.Identity,
    game_rules:           bd.Digest,
    transfer_budget:      tf.Budget,
    catalog:              rawptr,
    max_attachment_bytes: u32,
    encode:               proc(
        catalog: rawptr,
        checkpoint: ^r.Complete_Checkpoint(State, Event),
        dst: []u8,
    ) -> (
        int,
        Error,
    ),
    decode:               proc(
        catalog: rawptr,
        frame: r.Frame(State),
        epoch: u64,
        events: []r.Occurrence(Event),
        src: []u8,
    ) -> (
        r.Complete_Checkpoint(State, Event),
        Error,
    ),
    // Solver is logical normalized comparison bytes, not the recovery envelope.
    // Observations includes the provider's completed same-tick cache.
    diagnostic_part:      proc(
        catalog: rawptr,
        checkpoint: ^r.Complete_Checkpoint(State, Event),
        part: bd.Part,
        dst: []u8,
    ) -> (
        int,
        Error,
    ),
    reserve:              proc(catalog: rawptr, bytes: u64) -> Error,
    release:              proc(catalog: rawptr, bytes: u64),
    // Runtime leases protect immutable callback/schema catalogs. Detached byte
    // owner release must remain contextless and usable after this lease ends.
    attach:               proc(
        catalog: rawptr,
        source: ^r.Complete_Checkpoint(State, Event),
    ) -> (
        r.Complete_Checkpoint(State, Event),
        Error,
    ),
    acquire:              proc(catalog: rawptr) -> Error,
    drop:                 proc(catalog: rawptr),
}

Complete_View :: struct {
    lifetime:  Container_Lifetime,
    frame:     bd.Frame_View,
    storage:   []u8,
    allocator: mem.Allocator,
    _release:  proc(_: rawptr, _: u64),
    _catalog:  rawptr,
    _charge:   u64,
}

complete_view_destroy :: proc(view: ^Complete_View) -> Error {
    if view == nil {
        return .None
    }

    if error := container_access(&view.lifetime); error != .None {
        return error
    }

    life := view.lifetime

    if !life.cleanup {
        delete(view.storage, view.allocator)

        if view._release != nil {
            view._release(view._catalog, view._charge)
        }
    }

    view^ = {}

    if error := container_drop(&life); error != .None {
        life.cleanup = true
        view.lifetime = life
        return error
    }

    return .None
}

complete_game_schema :: proc(state, occurrence: ^sc.Schema, game_rules: bd.Digest) -> (bd.Digest, Error) {
    if state == nil || occurrence == nil || !state.ready || !occurrence.ready || game_rules == (bd.Digest{}) {
        return {}, .Invalid_Model
    }

    rules := game_rules
    fields := [?]bd.Descriptor {
        {tag = "fields", bytes = nil},
        {tag = "game_rules", bytes = rules[:]},
        {tag = "occurrences", bytes = occurrence.canonical[:]},
        {tag = "side", bytes = nil},
        {tag = "state", bytes = state.canonical[:]},
    }
    digest, error := bd.hash_descriptors("odin-godot.replay.complete-game.v1", fields[:])
    return digest, error == .None ? Error.None : Error.Invalid_Model
}

complete_input_schema :: proc(accepted, control, action, decisions: ^sc.Schema) -> (bd.Digest, Error) {
    if accepted == nil ||
       control == nil ||
       action == nil ||
       decisions == nil ||
       !accepted.ready ||
       !control.ready ||
       !action.ready ||
       !decisions.ready {
        return {}, .Invalid_Model
    }

    fields := [?]bd.Descriptor {
        {tag = "accepted_batch", bytes = accepted.canonical[:]},
        {tag = "actions", bytes = action.canonical[:]},
        {tag = "controls", bytes = control.canonical[:]},
        {tag = "decisions", bytes = decisions.canonical[:]},
        {
            tag = "wire",
            bytes = transmute([]u8)string(
                "accepted-v1;scope(epoch,generation,serial,seat,incarnation);first-control-exact-repeat;action-sequence-exact-repeat;receipts-v1;known-accepted-only;unknown-remote-hold",
            ),
        },
    }
    digest, error := bd.hash_descriptors("odin-godot.replay.accepted-input.v1", fields[:])
    return digest, error == .None ? Error.None : Error.Invalid_Model
}

@(private)
complete_codec_valid :: proc(codec: Complete_Codec($S, $E)) -> bool {
    if complete_codec_owner_check(codec) != .None {
        return false
    }

    if (codec.acquire == nil) != (codec.drop == nil) {
        return false
    }

    if codec.game_rules == (bd.Digest{}) ||
       codec.encode == nil ||
       codec.decode == nil ||
       codec.diagnostic_part == nil ||
       codec.reserve == nil ||
       codec.release == nil ||
       codec.max_attachment_bytes == 0 ||
       codec.max_attachment_bytes > COMPLETE_MAX_BYTES {
        return false
    }

    one := [?]u8{0}
    frame := bd.Frame_View {
        identity = codec.identity,
        epoch = 1,
        parts = {.Solver = one[:], .Game = nil, .Side = nil, .Observations = nil, .Occurrences = nil},
    }
    _, error := bd.sign(frame)
    return error == .None
}

// Uses canonical schema bytes for all typed state and semantic occurrence IDs.
// Side/registered fields are empty because Replay's full State owns those values.
complete_view :: proc(
    codec: Complete_Codec($S, $E),
    checkpoint: ^r.Complete_Checkpoint(S, E),
    state, occurrence: ^sc.Schema,
    allocator := context.allocator,
) -> (
    Complete_View,
    Error,
) {
    life: Container_Lifetime

    if error := container_acquire(
        &life,
        codec.ownership,
        allocator,
        codec.catalog,
        #config(BOX3D_REQUIRE_DOMAIN, false),
    ); error != .None {
        container_drop(&life)
        return {}, error
    }

    committed_owner := false

    defer if !committed_owner {
        container_drop(&life)
    }

    if !complete_codec_valid(codec) ||
       checkpoint == nil ||
       r.complete_checkpoint_identity(checkpoint) == 0 ||
       state == nil ||
       occurrence == nil ||
       !state.ready ||
       !occurrence.ready {
        return {}, .Invalid_Model
    }

    game_identity, identity_error := complete_game_schema(state, occurrence, codec.game_rules)

    if identity_error != .None || game_identity != codec.identity.game_schema {
        return {}, .Checkpoint_Contract
    }

    solver_bytes, solver_error := codec.diagnostic_part(codec.catalog, checkpoint, .Solver, nil)

    if solver_error != .None || solver_bytes <= 0 {
        return {}, solver_error == .None ? Error.Invalid_Frame : solver_error
    }

    observation_bytes, observation_error := codec.diagnostic_part(codec.catalog, checkpoint, .Observations, nil)

    if observation_error != .None || observation_bytes < 0 {
        return {}, observation_error == .None ? Error.Invalid_Frame : observation_error
    }

    if len(checkpoint.events) > WIRE_EVENTS ||
       solver_bytes > COMPLETE_MAX_BYTES ||
       observation_bytes > COMPLETE_MAX_BYTES ||
       state.wire_size > COMPLETE_MAX_BYTES ||
       occurrence.wire_size > COMPLETE_MAX_BYTES {
        return {}, .Capacity
    }

    occurrence_bytes := 4 + len(checkpoint.events) * occurrence.wire_size
    total := solver_bytes + observation_bytes + state.wire_size + occurrence_bytes

    if total > COMPLETE_MAX_BYTES {
        return {}, .Capacity
    }

    if error := codec.reserve(codec.catalog, u64(total)); error != .None {
        return {}, error
    }

    storage, allocation_error := mem.alloc_bytes(total, allocator = allocator)

    if allocation_error != .None || len(storage) != total {
        if len(storage) != 0 {
            delete(storage, allocator)
        }

        codec.release(codec.catalog, u64(total))
        return {}, .Capacity
    }

    view := Complete_View {
        lifetime = life,
        frame = {identity = codec.identity, epoch = checkpoint.epoch, tick = checkpoint.frame.tick},
        storage = storage,
        allocator = allocator,
        _release = codec.release,
        _catalog = codec.catalog,
        _charge = u64(total),
    }
    committed_owner = true
    committed := false

    defer if !committed {
        complete_view_destroy(&view)
    }

    at := 0
    view.frame.parts[.Solver] = storage[at:at + solver_bytes]
    at += solver_bytes
    view.frame.parts[.Game] = storage[at:at + state.wire_size]
    at += state.wire_size
    view.frame.parts[.Observations] = storage[at:at + observation_bytes]
    at += observation_bytes
    view.frame.parts[.Occurrences] = storage[at:at + occurrence_bytes]
    _, fill_solver := codec.diagnostic_part(codec.catalog, checkpoint, .Solver, view.frame.parts[.Solver])

    if fill_solver != .None {
        return {}, fill_solver
    }

    _, fill_observations := codec.diagnostic_part(
        codec.catalog,
        checkpoint,
        .Observations,
        view.frame.parts[.Observations],
    )

    if fill_observations != .None {
        return {}, fill_observations
    }

    if sc.encode(state, checkpoint.frame.state, view.frame.parts[.Game]).error != .None {
        return {}, .Invalid_Frame
    }

    events := view.frame.parts[.Occurrences]

    for byte in 0 ..< 4 {
        events[byte] = u8(u32(len(checkpoint.events)) >> uint(byte * 8))
    }

    for event, index in checkpoint.events {
        start := 4 + index * occurrence.wire_size

        if sc.encode(occurrence, event, events[start:start + occurrence.wire_size]).error != .None {
            return {}, .Invalid_Frame
        }
    }

    committed = true
    committed_owner = true
    return view, .None
}

@(private)
complete_codec_owner_check :: proc(codec: Complete_Codec($S, $E)) -> Error {
    strict :: #config(BOX3D_REQUIRE_DOMAIN, false)

    if strict && r.owner_is_nil(codec.ownership.allocator.owner) {
        return .Invalid_Model
    }

    if r.owner_access(codec.ownership.allocator.owner) != .None {
        return .Invalid_Model
    }

    return owned_context_check(codec.ownership.data_context, codec.catalog, strict, .Read)
}
