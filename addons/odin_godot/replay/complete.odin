package replay

import "core:mem"
import "base:runtime"
import bg "godot:box3d/godot"

// An owning complete checkpoint is separate from the plain, pointer-free game
// Frame. Clone explicitly; assignment aliases the native image and event owner.
Complete_Checkpoint :: struct($State, $Event: typeid) {
    owner:        Owner, // fixed prefix checked before producer-specific generic layout
    frame:        Frame(State),
    epoch:        u64,
    events:       []Occurrence(Event),
    allocator:    mem.Allocator,
    _external:    External,
    _image:       rawptr,
    _image_bytes: u64,
    _owned_bytes: u64,
}

// Provider factory: takes ownership of image only on success. The caller must
// retain/release its image on failure. All images/configuration must be detached.
complete_checkpoint_adopt :: proc {
    complete_checkpoint_adopt_plain,
    complete_checkpoint_adopt_events,
}

@(private)
complete_checkpoint_adopt_plain :: proc(
    frame: Frame($S),
    $E: typeid,
    external: External,
    image: rawptr,
    image_bytes: u64,
    epoch: u64 = 1,
    allocator := context.allocator,
) -> (
    Complete_Checkpoint(S, E),
    Error,
) {
    events: []Occurrence(E)
    return complete_checkpoint_adopt_events(frame, E, external, image, image_bytes, epoch, events, allocator)
}

@(private)
complete_checkpoint_adopt_events :: proc(
    frame: Frame($S),
    $E: typeid,
    external: External,
    image: rawptr,
    image_bytes: u64,
    epoch: u64,
    events: []Occurrence(E),
    allocator := context.allocator,
) -> (
    Complete_Checkpoint(S, E),
    Error,
) {
    if error := owner_contexts_check(external, allocator); error != .None {
        return {}, error
    }

    if error := owner_retain(external.owner); error != .None {
        return {}, error
    }

    owner := external.owner
    owner_transferred := false

    defer if !owner_transferred {
        owner_drop(&owner)
    }

    if !value_supported(S) || !value_supported(E) {
        return {}, .Unsupported_Value
    }

    if external.valid_value != nil && (!external.valid_value(S) || !external.valid_value(E)) {
        return {}, .Unsupported_Value
    }

    if !external_valid(external) || image == nil || epoch == 0 {
        return {}, .Invalid_Config
    }

    for event, i in events {
        if event.id.epoch != epoch || event.id.tick != frame.tick {
            return {}, .Invalid_Event
        }

        for previous in events[:i] {
            if event.id == previous.id {
                return {}, .Duplicate_Event
            }
        }
    }

    if u64(len(events)) > (max(u64) - u64(size_of(Complete_Checkpoint(S, E)))) / u64(size_of(Occurrence(E))) {
        return {}, .Resource_Limit
    }

    owned_bytes := u64(size_of(Complete_Checkpoint(S, E))) + u64(len(events)) * u64(size_of(Occurrence(E)))

    if external.limits.max_bytes != 0 && owned_bytes > external.limits.max_bytes {
        return {}, .Resource_Limit
    }

    if external.reserve != nil {
        if err := external.reserve(image, owned_bytes); err != .None {
            return {}, err
        }
    }

    copy_events := make([]Occurrence(E), len(events), allocator)
    copy(copy_events, events)
    owner_transferred = true
    return {
            owner = external.owner,
            frame = frame,
            epoch = epoch,
            events = copy_events,
            allocator = allocator,
            _external = external,
            _image = image,
            _image_bytes = image_bytes,
            _owned_bytes = owned_bytes,
        },
        .None
}

complete_checkpoint_destroy :: proc(checkpoint: ^Complete_Checkpoint($S, $E)) -> Error {
    if checkpoint == nil {
        return .None
    }

    if error := owner_access(checkpoint.owner); error != .None {
        return error
    }

    owner := checkpoint.owner

    if checkpoint._image != nil {
        if checkpoint._external.unreserve != nil {
            checkpoint._external.unreserve(checkpoint._owned_bytes)
        }

        checkpoint._external.release(checkpoint._image)
    }

    delete(checkpoint.events, checkpoint.allocator)
    checkpoint^ = {}
    error := owner_drop(&owner)

    // A declining final managed-data drop retains only its cleanup lease. Never
    // run image/event destructors twice; a later protected destroy retries drop.
    if error != .None {
        checkpoint.owner = owner
    }

    return error
}

complete_checkpoint_clone :: proc(
    source: ^Complete_Checkpoint($S, $E),
    allocator := context.allocator,
) -> (
    Complete_Checkpoint(S, E),
    Error,
) {
    if source == nil {
        return {}, .Incomplete_State
    }

    if error := owner_access(source.owner); error != .None {
        return {}, error
    }

    if error := owner_contexts_check(source._external, allocator); error != .None {
        return {}, error
    }

    if source._image == nil {
        return {}, .Incomplete_State
    }

    image, err := source._external.clone(source._image)

    if err != .None {
        if image != nil {
            source._external.release(image)
        }

        return {}, err
    }

    if image == nil {
        return {}, .External_State
    }

    result, adopt_err := complete_checkpoint_adopt(
        source.frame,
        E,
        source._external,
        image,
        source._image_bytes,
        source.epoch,
        source.events,
        allocator,
    )

    if adopt_err != .None {
        source._external.release(image)
    }

    return result, adopt_err
}

complete_checkpoint_identity :: proc(checkpoint: ^Complete_Checkpoint($S, $E)) -> u64 {
    if checkpoint == nil || owner_access(checkpoint.owner) != .None {
        return 0
    }

    return checkpoint._image != nil ? checkpoint._external.identity : 0
}

// Provider-specific readonly snapshot queries may inspect this borrowed image.
// It must not be mutated, released or retained beyond the checkpoint owner.
complete_checkpoint_image :: proc(checkpoint: ^Complete_Checkpoint($S, $E), identity: u64) -> (rawptr, Error) {
    if checkpoint == nil {
        return nil, .Incomplete_State
    }

    if error := owner_access(checkpoint.owner); error != .None {
        return nil, error
    }

    if checkpoint._image == nil {
        return nil, .Incomplete_State
    }

    if identity == 0 || checkpoint._external.identity != identity {
        return nil, .External_State
    }

    return checkpoint._image, .None
}

init_complete :: proc(
    t: ^Timeline($S, $I, $E),
    initial: ^Complete_Checkpoint(S, E),
    step: proc(_: ^S, _: I, _: ^Step(E)),
    cfg := DEFAULT_CONFIG,
    allocator := context.allocator,
    user: rawptr = nil,
    user_owner: Owner = {},
    user_data: rawptr = nil,
) -> Error {
    if error := owner_access(t.owner, .Execute); error != .None {
        return error
    }

    if len(t.records) == 0 && (t.owner_retained || t.user_owner_retained) {
        return .Already_Initialized
    }

    if len(t.records) != 0 {
        return .Already_Initialized
    }

    if initial == nil {
        return .Incomplete_State
    }

    if error := owner_access(initial.owner, .Execute); error != .None {
        return error
    }

    if initial._image == nil || !external_valid(initial._external) {
        return .Incomplete_State
    }

    if error := owner_contexts_check(initial._external, allocator); error != .None {
        return error
    }

    if error := owner_access(user_owner, .Execute); error != .None {
        return error
    }

    if !owner_is_nil(initial.owner) && user != nil {
        if owner_is_nil(user_owner) || user != user_data {
            return .Unsupported_Value
        }
    }

    if !owner_is_nil(user_owner) && user != nil && user != user_data {
        return .Unsupported_Value
    }

    if initial._external.valid_value != nil &&
       (!initial._external.valid_value(S) || !initial._external.valid_value(I) || !initial._external.valid_value(E)) {
        return .Unsupported_Value
    }

    if initial._external.limits.history_frames != 0 && cfg.history_frames != initial._external.limits.history_frames {
        return .Invalid_Config
    }

    if cfg.history_frames < 2 || cfg.history_frames > 4096 || cfg.events_per_tick < 0 || cfg.events_per_tick > 4096 {
        return .Invalid_Config
    }

    if len(initial.events) > cfg.events_per_tick {
        return .Event_Capacity
    }

    // Check both existing rings and both event arenas before init allocates them.
    // A large fixed-value type is valid State but need not fit this participant.
    runtime_bytes, sizing_error := complete_storage_bytes(S, I, E, cfg)

    if sizing_error != .None {
        return sizing_error
    }

    limit := initial._external.limits.max_bytes

    if limit != 0 && (runtime_bytes > limit || initial._image_bytes > limit - runtime_bytes) {
        return .Resource_Limit
    }

    if initial._external.preflight != nil {
        if err := initial._external.preflight(initial._image, {runtime_bytes, initial._image_bytes, 0}); err != .None {
            return err
        }
    }

    reserved := false

    if initial._external.reserve != nil {
        if err := initial._external.reserve(initial._image, runtime_bytes); err != .None {
            return err
        }

        reserved = true
    }

    transferred := false

    defer if reserved && !transferred {
        initial._external.unreserve(runtime_bytes)
    }

    tmp: Timeline(S, I, E)
    committed := false

    defer if !committed {
        destroy(&tmp)
    }

    // Own both contexts before init allocates its first ring/event container.
    if error := owner_retain(initial.owner); error != .None {
        return error
    }

    tmp.owner = initial.owner
    tmp.owner_retained = !owner_is_nil(initial.owner)

    if error := owner_retain(user_owner); error != .None {
        return error
    }

    tmp.user_owner = user_owner
    tmp.user_owner_retained = !owner_is_nil(user_owner)

    if err := init(&tmp, initial.frame, step, cfg, initial.epoch, allocator, user); err != .None {
        return err
    }

    tmp.external = initial._external
    tmp.runtime_bytes = runtime_bytes
    base := &tmp.records[initial.frame.tick % u64(len(tmp.records))]
    image, err := tmp.external.clone(initial._image)

    if err != .None {
        if image != nil {
            tmp.external.release(image)
        }

        return err
    }

    if image == nil {
        return .External_State
    }

    base.image, base.image_bytes = image, initial._image_bytes
    tmp.image_bytes = base.image_bytes
    copy(base.events, initial.events)
    base.count = len(initial.events)

    if begin_err := external_begin(&tmp, base.image, .Initial); begin_err != .None {
        return begin_err
    }

    if prepare_err := external_prepare(&tmp); prepare_err != .None {
        return prepare_err
    }

    external_publish(&tmp)
    tmp.runtime_reserved = reserved
    t^ = tmp
    transferred = true
    committed = true
    return .None
}

capture_complete :: proc(
    t: ^Timeline($S, $I, $E),
    tick: u64,
    allocator := context.allocator,
) -> (
    Complete_Checkpoint(S, E),
    Error,
) {
    if err := available(t, .Read); err != .None {
        return {}, err
    }

    if !external_enabled(t) {
        return {}, .Incomplete_State
    }

    record := record_at(t, tick)

    if record == nil {
        return {}, .History_Missing
    }

    if record.image == nil {
        return {}, .Incomplete_State
    }

    image, err := t.external.clone(record.image)

    if err != .None {
        if image != nil {
            t.external.release(image)
        }

        return {}, err
    }

    if image == nil {
        return {}, .External_State
    }

    checkpoint, adopt_err := complete_checkpoint_adopt(
        record.frame,
        E,
        t.external,
        image,
        record.image_bytes,
        t.epoch,
        record.events[:record.count],
        allocator,
    )

    if adopt_err != .None {
        t.external.release(image)
        return {}, adopt_err
    }

    usage := External_Usage {
        t.runtime_bytes + u64(size_of(checkpoint) + len(checkpoint.events) * size_of(checkpoint.events[0])),
        t.image_bytes + record.image_bytes,
        0,
    }
    run := External_Run {
        external = t.external,
        value    = t.execution,
        phase    = .Export,
        usage    = usage,
    }

    if admission_err := external_usage_check(&run, .Export); admission_err != .None {
        complete_checkpoint_destroy(&checkpoint)
        return {}, admission_err
    }

    return checkpoint, .None
}

@(private)
clone_record_complete :: proc(
    record: ^Record($S, $I, $E),
    external: External,
    epoch: u64,
    allocator: mem.Allocator,
) -> (
    Complete_Checkpoint(S, E),
    Error,
) {
    if error := owner_access(external.owner); error != .None {
        return {}, error
    }

    if record == nil || record.image == nil {
        return {}, .Incomplete_State
    }

    image, error := external.clone(record.image)

    if error != .None {
        if image != nil {
            external.release(image)
        }

        return {}, error
    }

    if image == nil {
        return {}, .External_State
    }

    result, adopt_error := complete_checkpoint_adopt(
        record.frame,
        E,
        external,
        image,
        record.image_bytes,
        epoch,
        record.events[:record.count],
        allocator,
    )

    if adopt_error != .None {
        external.release(image)
    }

    return result, adopt_error
}

correct_complete :: proc {
    correct_complete_plain,
    correct_complete_rewrite,
}

@(private)
correct_complete_plain :: proc(t: ^Timeline($S, $I, $E), truth: ^Complete_Checkpoint(S, E)) -> Result {
    rewrite: Input_Rewrite(I)
    return correct_complete_rewrite(t, truth, rewrite)
}

@(private)
correct_complete_rewrite :: proc(
    t: ^Timeline($S, $I, $E),
    truth: ^Complete_Checkpoint(S, E),
    rewrite: Input_Rewrite(I),
) -> Result {
    if truth == nil {
        return {error = .Incomplete_State}
    }

    if error := owner_access(truth.owner, .Read); error != .None {
        return {error = error}
    }

    if truth._image == nil || !external_enabled(t) {
        return {error = .Incomplete_State}
    }

    if truth.epoch != t.epoch || !external_compatible(truth._external, t.external) {
        return {error = .External_State, tick = truth.frame.tick}
    }

    return correct_impl(t, truth.frame, truth.events, rewrite, nil, truth._image, truth._image_bytes, true)
}

reset_complete :: proc(t: ^Timeline($S, $I, $E), checkpoint: ^Complete_Checkpoint(S, E), epoch: u64) -> Error {
    if err := available(t); err != .None {
        return err
    }

    if checkpoint == nil {
        return .Incomplete_State
    }

    if error := owner_access(checkpoint.owner, .Read); error != .None {
        return error
    }

    if checkpoint._image == nil || !external_enabled(t) {
        return .Incomplete_State
    }

    if !external_compatible(checkpoint._external, t.external) {
        return .External_State
    }

    if epoch == 0 || epoch < t.epoch || epoch < checkpoint.epoch {
        return .Invalid_Epoch
    }

    if epoch == t.epoch && checkpoint.frame.tick < t.confirmed {
        return .Committed
    }

    if len(checkpoint.events) > len(t.records[0].events) {
        return .Event_Capacity
    }

    t.busy = true
    defer t.busy = false

    if err := external_begin(t, checkpoint._image, .Reset); err != .None {
        return err
    }

    defer external_finish(t)
    image, err := t.external.clone(checkpoint._image)

    if err != .None {
        if image != nil {
            t.external.release(image)
        }

        return err
    }

    if image == nil {
        return .External_State
    }

    dst := &t.staged[0]
    external_release_record(t, dst)
    dst.image, dst.image_bytes = image, checkpoint._image_bytes

    if checkpoint._image_bytes > max(u64) - t.image_bytes {
        dst.image_bytes = 0
        return .Resource_Limit
    }

    t.image_bytes += checkpoint._image_bytes
    dst.valid = true
    dst.has_input = false
    dst.input = {}
    dst.frame = checkpoint.frame
    dst.count = len(checkpoint.events)
    copy(dst.events, checkpoint.events)

    // Epoch changes rebase occurrence identities while preserving semantic keys.
    for &event in dst.events[:dst.count] {
        event.id.epoch = epoch
    }

    if prepare_err := external_prepare(t); prepare_err != .None {
        return prepare_err
    }

    for &record in t.records {
        external_release_record(t, &record)
        record.valid = false
        record.count = 0
    }

    commit(t, dst)
    external_publish(t)
    t.epoch, t.head, t.confirmed = epoch, checkpoint.frame.tick, checkpoint.frame.tick
    return .None
}

// Explicitly game-only views for presentation. These values cannot initialize a
// complete physics branch or be used as a solver correction/recovery image.
read_values :: proc(t: ^Timeline($S, $I, $E), tick: u64) -> (Frame(S), bool) {
    if owner_access(t.owner, .Read) != .None {
        return {}, false
    }

    record := record_at(t, tick)
    return record != nil ? record.frame : Frame(S){}, record != nil
}

current_values :: proc(t: ^Timeline($S, $I, $E)) -> (Frame(S), bool) {
    return read_values(t, t.head)
}

// Checked arithmetic avoids overflow and allocation before envelope admission.
@(private)
complete_storage_bytes :: proc($S, $I, $E: typeid, cfg: Config) -> (u64, Error) {
    history := u64(cfg.history_frames)
    events := u64(cfg.events_per_tick)
    record_bytes := u64(size_of(Record(S, I, E)))
    event_bytes := u64(size_of(Occurrence(E)))
    total := u64(size_of(Timeline(S, I, E)))

    if history > max(u64) / 2 || record_bytes > max(u64) / (history * 2) {
        return 0, .Resource_Limit
    }

    rings := history * 2 * record_bytes

    if total > max(u64) - rings {
        return 0, .Resource_Limit
    }

    total += rings

    if events != 0 {
        if history > max(u64) / events ||
           history * events > max(u64) / 2 ||
           event_bytes > max(u64) / (history * events * 2) {
            return 0, .Resource_Limit
        }

        storage := history * events * 2 * event_bytes

        if total > max(u64) - storage {
            return 0, .Resource_Limit
        }

        total += storage
    }

    return total, .None
}

// Read the first participant failure in this borrowed callback scope. Adapters
// use it to preserve a concrete resource/handle failure when authored code also
// aborts its game callback. It never exposes or retains the execution pointer.
execution_status :: proc(capability: Execution) -> Error {
    run := execution_run(capability)

    if run == nil {
        return .Stale_Execution
    }

    return run.error
}

// Origin-owned typed capsule. Only fixed C-shaped capsule handles cross modules;
// all generic Frame/Event/type/allocator access remains in this producer thunk.
@(private)
Complete_Capsule_Payload :: struct($S, $E: typeid) {
    owner:      Owner,
    checkpoint: Complete_Checkpoint(S, E),
    allocator:  mem.Allocator,
    service:    bg.Service,
}

complete_capsule_create :: proc(
    source: ^Complete_Checkpoint($S, $E),
    service: bg.Service,
    allocator := context.allocator,
) -> (
    capsule: bg.Capsule,
    error: Error,
) {
    if source == nil {
        return {}, .Incomplete_State
    }

    if owner_is_nil(source.owner) || service.realm != source.owner.realm || service.capsule_create == nil {
        return {}, .External_State
    }

    if error := owner_access(source.owner); error != .None {
        return {}, error
    }

    if error := owner_contexts_check(source._external, allocator); error != .None {
        return {}, error
    }

    copy, clone_error := complete_checkpoint_clone(source, allocator)

    if clone_error != .None {
        return {}, clone_error
    }

    committed := false

    defer if !committed {
        complete_checkpoint_destroy(&copy)
    }

    extra := u64(size_of(Complete_Capsule_Payload(S, E))) - u64(size_of(Complete_Checkpoint(S, E)))

    if extra > max(u64) - copy._owned_bytes {
        return {}, .Resource_Limit
    }

    if limit := copy._external.limits.max_bytes; limit != 0 && copy._owned_bytes + extra > limit {
        return {}, .Resource_Limit
    }

    if copy._external.reserve != nil {
        if error := copy._external.reserve(copy._image, extra); error != .None {
            return {}, error
        }
    }

    copy._owned_bytes += extra
    pointer, allocation_error := mem.alloc(
        size_of(Complete_Capsule_Payload(S, E)),
        align_of(Complete_Capsule_Payload(S, E)),
        allocator,
    )

    if allocation_error != .None {
        return {}, .Resource_Limit
    }

    payload := cast(^Complete_Capsule_Payload(S, E))pointer
    payload^ = {
        owner      = copy.owner,
        checkpoint = copy,
        allocator  = allocator,
        service    = service,
    }

    dispatch := proc "c" (data: rawptr, operation: u32, args: rawptr) -> bg.Status {
        context = runtime.default_context()
        // Stable Core has already entered/pinned the producer origin. The prefix
        // check still rejects invalid local realm before any typed field access.
        payload := cast(^Complete_Capsule_Payload(S, E))data

        if owner_access(payload.owner) != .None {
            return bg.INCOMPATIBLE
        }

        switch operation {
        case bg.CAPSULE_DESTROY:
            owned := payload.checkpoint
            alloc := payload.allocator
            payload.checkpoint = {}
            // The checkpoint retains allocator data until ALL event cleanup finishes;
            // the capsule separately pins its Owner through this complete thunk return.
            mem.free(payload, alloc)

            if complete_checkpoint_destroy(&owned) != .None {
                return bg.INCOMPATIBLE
            }

            return bg.OK
        case bg.CAPSULE_CLONE:
            if args == nil {
                return bg.INVALID_ARGUMENT
            }

            output := cast(^bg.Capsule_Clone_Args)args

            if output.out == nil {
                return bg.INVALID_ARGUMENT
            }

            clone, error := complete_capsule_create(&payload.checkpoint, payload.service, payload.allocator)

            if error != .None {
                return error == .Resource_Limit ? bg.CAPACITY : bg.INCOMPATIBLE
            }

            output.out^ = clone
            return bg.OK
        case:
            return bg.UNSUPPORTED
        }
    }

    status := service.capsule_create(service.user, &payload.owner, payload, dispatch, &capsule)

    if status != bg.OK {
        payload.checkpoint = {}
        mem.free(payload, allocator)
        return {}, status == bg.CAPACITY ? Error.Resource_Limit : Error.External_State
    }

    copy = {}
    committed = true
    return capsule, .None
}
