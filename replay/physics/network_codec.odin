package replay_physics

import "core:mem"
import b "godot:box3d"
import bg "godot:box3d/godot"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import net "godot:replay/net"
import sc "godot:replay/schema"
import tf "godot:replay/transfer"

OBSERVATION_FORMAT :: u32(1)

Network_Codec :: struct($State, $Control, $Action, $Event: typeid, $Seats: int) {
    context_ownership, ownership:                                               Owner_Context, // fixed protected prefix before typed schemas
    budget_live:                                                                u64,
    value:                                                                      net.Complete_Codec(
        State,
        net.Net_Event(Event),
    ),
    catalog:                                                                    b.Recovery_Catalog,
    config:                                                                     Config,
    native_identity:                                                            b.Recovery_Identity,
    allocator:                                                                  mem.Allocator,
    state, occurrence, accepted, controls, actions, decisions, provider_config: sc.Schema,
    ready:                                                                      bool,
    runtime_leases:                                                             u32,
    owned_bytes:                                                                u64,
    profile_clock:                                                              r.Profile_Clock,
    native_decode:                                                              r.Timing,
    last_native_status:                                                         b.Status,
    last_native_diagnostic:                                                     b.Recovery_Diagnostic,
}

network_codec_init :: proc(
    c: ^Network_Codec($S, $C, $A, $E, $N),
    catalog: ^b.Recovery_Catalog,
    config: Config,
    game_rules: bd.Digest,
    allocator := context.allocator,
    ownership: Owner_Context = {},
    context_ownership: Owner_Context = {},
) -> net.Error {
    if error := codec_context_access(c, true); error != .None {
        return .Wrong_Phase
    }

    if error := ownership_check(ownership, allocator); error != .None {
        return .Invalid_Model
    }

    when b.BOX3D_REQUIRE_DOMAIN {
        if r.owner_is_nil(context_ownership.owner) {
            return .Invalid_Model
        }
    }

    if error := r.owner_access(context_ownership.owner); error != .None {
        return .Invalid_Model
    }

    if !r.owner_is_nil(context_ownership.owner) && context_ownership.user_data != rawptr(c) {
        return .Invalid_Model
    }

    if c.ready ||
       game_rules == (bd.Digest{}) ||
       !valid_config(config) ||
       !state_supported(S) ||
       !state_supported(C) ||
       !state_supported(A) ||
       !state_supported(E) {
        return .Invalid_Model
    }

    identity, status := b.recovery_catalog_identity(catalog)

    if status != .Ok {
        return .Checkpoint_Contract
    }

    if error := memory_check(u64(size_of(Network_Codec(S, C, A, E, N))) + net.PHYSICS_SCHEMA_RESERVE); error != .None {
        return .Capacity
    }

    if r.owner_retain(context_ownership.owner) != .None {
        return .Wrong_Phase
    }

    if r.owner_retain(ownership.owner) != .None {
        temporary := context_ownership.owner
        r.owner_drop(&temporary)
        return .Wrong_Phase
    }

    c.context_ownership = context_ownership
    c.ownership = ownership
    c.allocator = allocator
    c.config = config
    c.native_identity = identity

    for &asset, index in c.config.assets {
        if index >= int(config.asset_count) {
            asset = {}
        }
    }

    c.catalog, status = b.recovery_catalog_clone(catalog)

    if status != .Ok {
        a, b := c.context_ownership.owner, c.ownership.owner
        c^ = {}
        r.owner_drop(&b)
        r.owner_drop(&a)
        return .Checkpoint_Contract
    }

    c.owned_bytes = u64(size_of(Network_Codec(S, C, A, E, N))) + net.PHYSICS_SCHEMA_RESERVE

    if error := charge(c.owned_bytes); error != .None {
        b.recovery_catalog_destroy(&c.catalog)
        a, z := c.context_ownership.owner, c.ownership.owner
        c^ = {}
        r.owner_drop(&z)
        r.owner_drop(&a)
        return .Capacity
    }

    committed := false

    defer if !committed {
        network_codec_destroy(c)
    }

    if sc.init(&c.state, S, allocator = allocator).error != .None ||
       sc.init(&c.occurrence, r.Occurrence(net.Net_Event(E)), allocator = allocator).error != .None ||
       sc.init(&c.accepted, net.Accepted_Input(C, A, N), allocator = allocator).error != .None ||
       sc.init(&c.controls, C, allocator = allocator).error != .None ||
       sc.init(&c.actions, A, allocator = allocator).error != .None ||
       sc.init(&c.decisions, net.Accepted_Decisions(N), allocator = allocator).error != .None ||
       sc.init(&c.provider_config, Config, allocator = allocator).error != .None {
        return .Invalid_Schema
    }

    bound_rules, binding_error := network_bound_rules(c, game_rules)

    if binding_error != .None {
        return binding_error
    }

    metadata :=
        net.complete_schema_owned_bytes(&c.provider_config) +
        net.complete_schema_owned_bytes(&c.state) +
        net.complete_schema_owned_bytes(&c.occurrence) +
        net.complete_schema_owned_bytes(&c.accepted) +
        net.complete_schema_owned_bytes(&c.controls) +
        net.complete_schema_owned_bytes(&c.actions) +
        net.complete_schema_owned_bytes(&c.decisions)

    if metadata > net.PHYSICS_SCHEMA_RESERVE {
        return .Capacity
    }

    uncharge(net.PHYSICS_SCHEMA_RESERVE - metadata)
    c.owned_bytes -= net.PHYSICS_SCHEMA_RESERVE - metadata
    game, ge := net.complete_game_schema(&c.state, &c.occurrence, bound_rules)

    if ge != .None {
        return ge
    }

    inputs, ie := net.complete_input_schema(&c.accepted, &c.controls, &c.actions, &c.decisions)

    if ie != .None {
        return ie
    }

    observation_descriptor := transmute([]u8)string(
        "replay-completed-sensors:v1;count:u32le;ordered(sensor:key64le,visitor:key64le,began:u8);max70;no-padding",
    )
    c.value = {
        ownership = {allocator = {c.ownership.owner, c.allocator.data}, data_context = {c.context_ownership.owner, c}},
        identity = {
            solver_format = identity.solver_format,
            recovery_format = identity.recovery_format,
            profile = identity.profile,
            game_format = 1,
            observation_format = OBSERVATION_FORMAT,
            build_target = identity.build_target,
            assets = identity.assets,
            solver_schema = identity.solver_schema,
            game_schema = game,
            input_schema = inputs,
            observation_schema = bd.hash_bytes(observation_descriptor),
        },
        game_rules = bound_rules,
        transfer_budget = tf.Budget{user = c, reserve = proc(pointer: rawptr, bytes: u64) -> bool {
                return codec_reserve(cast(^Network_Codec(S, C, A, E, N))pointer, bytes) == .None
            }, release = proc(pointer: rawptr, bytes: u64) {
                codec_unreserve(cast(^Network_Codec(S, C, A, E, N))pointer, bytes)
            }, acquire = proc(pointer: rawptr) -> bool {
                return codec_acquire(cast(^Network_Codec(S, C, A, E, N))pointer) == .None
            }, drop = proc(pointer: rawptr) {
                codec_drop(cast(^Network_Codec(S, C, A, E, N))pointer)
            }},
        catalog = c,
        max_attachment_bytes = b.RECOVERY_MAX_BYTES + 24 + 4 + 70 * 17,
        encode = proc(
            pointer: rawptr,
            checkpoint: ^r.Complete_Checkpoint(S, net.Net_Event(E)),
            dst: []u8,
        ) -> (
            int,
            net.Error,
        ) {
            ctx := cast(^Network_Codec(S, C, A, E, N))pointer

            if codec_context_access(ctx) != .None {
                return 0, .Wrong_Phase
            }

            image_pointer, error := r.complete_checkpoint_image(checkpoint, IDENTITY)

            if error != .None {
                return 0, .Invalid_Frame
            }

            image := cast(^Image)image_pointer

            if config_contract(image.config) != config_contract(ctx.config) ||
               (image.catalog_identity.profile != 0 && image.catalog_identity != ctx.native_identity) {
                return 0, .Checkpoint_Contract
            }

            native_bytes := image.native_required

            if native_bytes == 0 || image.catalog_identity != ctx.native_identity {
                if error := memory_check(0, b.RECOVERY_WRITE_RESERVE_BYTES); error != .None {
                    return 0, .Capacity
                }

                status: b.Status
                diagnostic: b.Recovery_Diagnostic
                native_bytes, status, diagnostic = codec_native_write(&ctx.catalog, &image.snapshot, nil)
                ctx.last_native_status = status
                ctx.last_native_diagnostic = diagnostic

                if status != .Ok {
                    return 0,
                        status == .Capacity || status == .Out_Of_Memory ? net.Error.Capacity : net.Error.Invalid_Frame
                }

                if error := memory_check(); error != .None {
                    return 0, .Capacity
                }
            }

            observations := 4 + int(image.sensor_count) * 17
            total := 24 + observations + int(native_bytes)

            if total > int(ctx.value.max_attachment_bytes) {
                return 0, .Capacity
            }

            if len(dst) == 0 {
                return total, .None
            }

            if len(dst) < total {
                return total, .Capacity
            }

            copy(dst[:8], "RPOBS001")
            obs_put32(dst[8:12], OBSERVATION_FORMAT)
            obs_put32(dst[12:16], u32(observations))
            obs_put32(dst[16:20], u32(native_bytes))
            obs_put32(dst[20:24], 0)
            _, oe := observations_write(image, dst[24:24 + observations])

            if oe != .None {
                return 0, oe
            }

            if error := memory_check(0, b.RECOVERY_WRITE_RESERVE_BYTES); error != .None {
                return 0, .Capacity
            }

            written, write_status, _ := codec_native_write(&ctx.catalog, &image.snapshot, dst[24 + observations:total])

            if write_status != .Ok || written != native_bytes {
                return 0,
                    write_status == .Capacity || write_status == .Out_Of_Memory ? net.Error.Capacity : net.Error.Invalid_Frame
            }

            if error := memory_check(); error != .None {
                return 0, .Capacity
            }

            return total, .None
        },
        decode = proc(
            pointer: rawptr,
            frame: r.Frame(S),
            epoch: u64,
            events: []r.Occurrence(net.Net_Event(E)),
            src: []u8,
        ) -> (
            r.Complete_Checkpoint(S, net.Net_Event(E)),
            net.Error,
        ) {
            ctx := cast(^Network_Codec(S, C, A, E, N))pointer

            if codec_context_access(ctx) != .None {
                return {}, .Wrong_Phase
            }

            if len(src) < 28 ||
               len(src) > int(ctx.value.max_attachment_bytes) ||
               string(src[:8]) != "RPOBS001" ||
               obs_get32(src[8:12]) != OBSERVATION_FORMAT ||
               obs_get32(src[20:24]) != 0 {
                return {}, .Invalid_Frame
            }

            observation_bytes, native_bytes := int(obs_get32(src[12:16])), int(obs_get32(src[16:20]))

            if observation_bytes < 4 ||
               observation_bytes > 4 + 70 * 17 ||
               native_bytes < 1 ||
               native_bytes > b.RECOVERY_MAX_BYTES ||
               len(src) != 24 + observation_bytes + native_bytes {
                return {}, .Invalid_Frame
            }

            observations: [70]Sensor_Event
            count, oe := observations_read(src[24:24 + observation_bytes], observations[:])

            if oe != .None {
                return {}, oe
            }

            started, timed := r.profile_read(ctx.profile_clock)
            snapshot, info, status := codec_native_read(&ctx.catalog, src[24 + observation_bytes:])
            r.timing_finish(&ctx.native_decode, ctx.profile_clock, started, timed)

            if status != .Ok {
                return {},
                    status == .Capacity || status == .Out_Of_Memory ? net.Error.Capacity : net.Error.Invalid_Frame
            }

            image, bytes, make_error := image_make(
                snapshot,
                ctx.config,
                ctx.allocator,
                observations[:count],
                &ctx.catalog,
                u64(native_bytes),
                &info,
                ctx.ownership,
            )

            if make_error != .None {
                b.snapshot_destroy(&snapshot)
                return {}, .Capacity
            }

            checkpoint, adopt_error := r.complete_checkpoint_adopt(
                frame,
                net.Net_Event(E),
                participant(ctx.config, ctx.native_identity, ctx.ownership),
                image,
                bytes,
                epoch,
                events,
                ctx.allocator,
            )

            if adopt_error != .None {
                release(image)
                return {}, .Capacity
            }

            return checkpoint, .None
        },
        diagnostic_part = proc(
            pointer: rawptr,
            checkpoint: ^r.Complete_Checkpoint(S, net.Net_Event(E)),
            part: bd.Part,
            dst: []u8,
        ) -> (
            int,
            net.Error,
        ) {
            ctx := cast(^Network_Codec(S, C, A, E, N))pointer

            if codec_context_access(ctx) != .None {
                return 0, .Wrong_Phase
            }

            image_pointer, error := r.complete_checkpoint_image(checkpoint, IDENTITY)

            if error != .None {
                return 0, .Invalid_Frame
            }

            image := cast(^Image)image_pointer

            if config_contract(image.config) != config_contract(ctx.config) ||
               (image.catalog_identity.profile != 0 && image.catalog_identity != ctx.native_identity) {
                return 0, .Checkpoint_Contract
            }

            if part == .Solver {
                if len(dst) == 0 {
                    return int(image.normalized_required), .None
                }

                required, status := b.snapshot_dump(&image.snapshot, dst)

                if status != .Ok {
                    return int(required), .Invalid_Frame
                }

                return int(required), .None
            }

            if part == .Observations {
                return observations_write(image, dst)
            }

            return 0, .Invalid_Frame
        },
        reserve = proc(pointer: rawptr, bytes: u64) -> net.Error {
            return codec_reserve(cast(^Network_Codec(S, C, A, E, N))pointer, bytes)
        },
        release = proc(pointer: rawptr, bytes: u64) {
            codec_unreserve(cast(^Network_Codec(S, C, A, E, N))pointer, bytes)
        },
        attach = proc(
            pointer: rawptr,
            source: ^r.Complete_Checkpoint(S, net.Net_Event(E)),
        ) -> (
            r.Complete_Checkpoint(S, net.Net_Event(E)),
            net.Error,
        ) {
            return network_attach_checkpoint(cast(^Network_Codec(S, C, A, E, N))pointer, source)
        },
        acquire = proc(pointer: rawptr) -> net.Error {
            return codec_acquire(cast(^Network_Codec(S, C, A, E, N))pointer)
        },
        drop = proc(pointer: rawptr) {
            codec_drop(cast(^Network_Codec(S, C, A, E, N))pointer)
        },
    }
    c.ready = true
    committed = true
    return .None
}

network_codec_destroy :: proc(c: ^Network_Codec($S, $C, $A, $E, $N)) -> net.Error {
    if codec_context_access(c) != .None || r.owner_access(c.ownership.owner) != .None {
        return .Wrong_Phase
    }

    if c.runtime_leases != 0 || c.budget_live != 0 {
        return .Wrong_Phase
    }

    if c.catalog._handle != nil {
        if b.recovery_catalog_destroy(&c.catalog) != .Ok {
            return .Wrong_Phase
        }

        uncharge(c.owned_bytes)
    }

    sc.destroy(&c.state)
    sc.destroy(&c.occurrence)
    sc.destroy(&c.accepted)
    sc.destroy(&c.controls)
    sc.destroy(&c.actions)
    sc.destroy(&c.decisions)
    sc.destroy(&c.provider_config)
    a, z := c.context_ownership.owner, c.ownership.owner
    c^ = {}
    r.owner_drop(&z)
    r.owner_drop(&a)
    return .None
}

@(private)
observations_write :: proc(image: ^Image, dst: []u8) -> (int, net.Error) {
    n := 4 + int(image.sensor_count) * 17

    if len(dst) == 0 {
        return n, .None
    }

    if len(dst) < n {
        return n, .Capacity
    }

    obs_put32(dst[:4], image.sensor_count)
    at := 4

    for event in image.sensors[:image.sensor_count] {
        obs_put64(dst[at:at + 8], u64(event.sensor))
        obs_put64(dst[at + 8:at + 16], u64(event.visitor))
        dst[at + 16] = u8(event.began)
        at += 17
    }

    return n, .None
}

@(private)
observations_read :: proc(src: []u8, out: []Sensor_Event) -> (int, net.Error) {
    if len(src) < 4 {
        return 0, .Invalid_Frame
    }

    count := int(obs_get32(src[:4]))

    if count > 70 || count > len(out) || len(src) != 4 + count * 17 {
        return 0, .Invalid_Frame
    }

    at := 4

    for i in 0 ..< count {
        sensor, visitor := obs_get64(src[at:at + 8]), obs_get64(src[at + 8:at + 16])

        if !canonical_key(sensor) || !canonical_key(visitor) || src[at + 16] > 1 {
            return 0, .Invalid_Frame
        }

        out[i] = {b.Shape_Key(sensor), b.Shape_Key(visitor), src[at + 16] != 0}
        at += 17
    }

    return count, .None
}

@(private)
canonical_key :: proc(value: u64) -> bool {
    return u32(value) > 0 && u32(value) <= u32(max(i32)) && value >> 32 <= u64(max(u16))
}

@(private)
obs_put32 :: proc(dst: []u8, value: u32) {
    for i in 0 ..< 4 {
        dst[i] = u8(value >> uint(i * 8))
    }
}

@(private)
obs_put64 :: proc(dst: []u8, value: u64) {
    for i in 0 ..< 8 {
        dst[i] = u8(value >> uint(i * 8))
    }
}

@(private)
obs_get32 :: proc(src: []u8) -> u32 {
    value: u32

    for byte, i in src {
        value |= u32(byte) << uint(i * 8)
    }

    return value
}

@(private)
obs_get64 :: proc(src: []u8) -> u64 {
    value: u64

    for byte, i in src {
        value |= u64(byte) << uint(i * 8)
    }

    return value
}

@(private)
network_bound_rules :: proc(
    c: ^Network_Codec($S, $C, $A, $E, $N),
    application_rules: bd.Digest,
) -> (
    bd.Digest,
    net.Error,
) {
    values, allocation_error := mem.alloc_bytes(c.provider_config.wire_size, allocator = c.allocator)

    if allocation_error != .None {
        return {}, .Capacity
    }

    defer delete(values, c.allocator)

    if sc.encode(&c.provider_config, c.config, values).error != .None {
        return {}, .Invalid_Model
    }

    app := application_rules
    digest, error := bd.hash_descriptors(
        "odin-godot.replay.physics-rules.v1",
        []bd.Descriptor {
            {tag = "application", bytes = app[:]},
            {tag = "provider_schema", bytes = c.provider_config.canonical[:]},
            {tag = "provider_values", bytes = values},
        },
    )
    return digest, error == .None ? net.Error.None : net.Error.Invalid_Model
}

// Entering network mode is an explicit detached ownership/contract transition.
// An unbound P2 checkpoint remains unchanged and valid for standalone use.
network_attach_checkpoint :: proc(
    c: ^Network_Codec($S, $C, $A, $E, $N),
    source: ^r.Complete_Checkpoint(S, net.Net_Event(E)),
) -> (
    r.Complete_Checkpoint(S, net.Net_Event(E)),
    net.Error,
) {
    if c == nil {
        return {}, .Wrong_Phase
    }

    if codec_context_access(c) != .None || !c.ready {
        return {}, .Wrong_Phase
    }

    pointer, error := r.complete_checkpoint_image(source, IDENTITY)

    if error != .None {
        return {}, .Incomplete_State
    }

    original := cast(^Image)pointer

    if config_contract(original.config) != config_contract(c.config) ||
       (original.catalog_identity.profile != 0 && original.catalog_identity != c.native_identity) {
        return {}, .Checkpoint_Contract
    }

    if original.catalog_identity == c.native_identity {
        checkpoint, clone_error := r.complete_checkpoint_clone(source, c.allocator)
        return checkpoint, clone_error == .None ? net.Error.None : net.Error.Capacity
    }

    operation, begin_error := begin()

    if begin_error != .None {
        return {}, .Capacity
    }

    defer operation_end(&operation)
    snapshot, status := b.snapshot_clone(&original.snapshot)

    if status != .Ok {
        return {}, .Capacity
    }

    image, bytes, make_error := image_make(
        snapshot,
        c.config,
        c.allocator,
        original.sensors[:original.sensor_count],
        &c.catalog,
        ownership = c.ownership,
    )

    if make_error != .None {
        b.snapshot_destroy(&snapshot)
        return {}, .Capacity
    }

    committed := false

    defer if !committed {
        release(image)
    }

    work_pointer, open_error := open(image)

    if open_error != .None {
        return {}, .Capacity
    }

    work := cast(^Working)work_pointer
    required: u64
    required, status = b.recovery_world_admit(&work.catalog, work.stage.world, memory.live_bytes)
    (cast(^Image)image).native_required = required
    close(work)

    if status != .Ok {
        return {}, status == .Capacity || status == .Out_Of_Memory ? net.Error.Capacity : net.Error.Checkpoint_Contract
    }

    if error := finish(operation); error != .None {
        return {}, .Capacity
    }

    checkpoint, adopt_error := r.complete_checkpoint_adopt(
        source.frame,
        net.Net_Event(E),
        participant(c.config, c.native_identity, c.ownership),
        image,
        bytes,
        source.epoch,
        source.events,
        c.allocator,
    )

    if adopt_error != .None {
        return {}, .Capacity
    }

    committed = true
    return checkpoint, .None
}

@(private)
codec_acquire :: proc(c: ^Network_Codec($S, $C, $A, $E, $N)) -> net.Error {
    if codec_context_access(c) != .None {
        return .Wrong_Phase
    }

    if !c.ready || c.runtime_leases == max(u32) {
        return .Wrong_Phase
    }

    if r.owner_retain(c.context_ownership.owner) != .None {
        return .Wrong_Phase
    }

    c.runtime_leases += 1
    return .None
}

@(private)
codec_drop :: proc(c: ^Network_Codec($S, $C, $A, $E, $N)) {
    assert(codec_context_access(c) == .None && c.runtime_leases > 0)
    owner := c.context_ownership.owner
    c.runtime_leases -= 1
    r.owner_drop(&owner)
}

@(private)
codec_reserve :: proc(c: ^Network_Codec($S, $C, $A, $E, $N), bytes: u64) -> net.Error {
    // Standalone detached byte release remains contextless after codec destruction.
    if !host_enabled() {
        if memory_check(bytes) != .None || charge(bytes) != .None {
            return .Capacity
        }

        return .None
    }

    if codec_context_access(c) != .None || !c.ready {
        return .Wrong_Phase
    }

    if bytes > max(u64) - c.budget_live {
        return .Capacity
    }

    retained := c.budget_live == 0 && bytes != 0

    if retained && r.owner_retain(c.context_ownership.owner) != .None {
        return .Wrong_Phase
    }

    if error := memory_check(bytes); error != .None {
        if retained {
            owner := c.context_ownership.owner
            r.owner_drop(&owner)
        }

        return .Capacity
    }

    if error := charge(bytes); error != .None {
        if retained {
            owner := c.context_ownership.owner
            r.owner_drop(&owner)
        }

        return .Capacity
    }

    c.budget_live += bytes
    return .None
}

@(private)
codec_unreserve :: proc(c: ^Network_Codec($S, $C, $A, $E, $N), bytes: u64) {
    if !host_enabled() {
        uncharge(bytes)
        return
    }

    assert(codec_context_access(c) == .None && c.budget_live >= bytes)
    owner := c.context_ownership.owner
    prior := c.budget_live
    c.budget_live -= bytes
    uncharge(bytes)

    if prior != 0 && c.budget_live == 0 {
        r.owner_drop(&owner)
    }
}

@(private)
codec_native_write :: proc(
    catalog: ^b.Recovery_Catalog,
    snapshot: ^b.Snapshot,
    dst: []u8,
) -> (
    required: u64,
    status: b.Status,
    diagnostic: b.Recovery_Diagnostic,
) {
    mark, error := budget_begin(b.RECOVERY_WRITE_RESERVE_BYTES)

    if error != .None {
        return 0, error == .Resource_Limit ? b.Status.Capacity : b.Status.Incompatible, {}
    }

    defer budget_end(&mark)

    if error := memory_check(0, b.RECOVERY_WRITE_RESERVE_BYTES); error != .None {
        return 0, .Capacity, {}
    }

    required, status, diagnostic = b.recovery_write_diagnostic(catalog, snapshot, dst)

    if status != .Ok {
        return
    }

    if mark != 0 {
        checked := host_service.budget_reconcile(host_service.user, mark)

        if checked != bg.OK {
            return 0, checked == bg.CAPACITY ? b.Status.Capacity : b.Status.Incompatible, {}
        }
    }

    if memory_check() != .None {
        return 0, .Capacity, {}
    }

    return
}

@(private)
codec_native_read :: proc(
    catalog: ^b.Recovery_Catalog,
    src: []u8,
) -> (
    snapshot: b.Snapshot,
    info: b.Snapshot_Info,
    status: b.Status,
) {
    // Operation bound uses the public2MiB DTO maximum plus4MiB staging.
    // Unknown lower catalogDTO: exclude ONLY the guaranteed4MiB implicit floor,
    // never another promised byte. C adds its actual DTO+staging in full.
    implicit := u64(6 * 1024 * 1024)
    mark, error := budget_begin(implicit)

    if error != .None {
        return {}, {}, error == .Resource_Limit ? b.Status.Capacity : b.Status.Incompatible
    }

    defer budget_end(&mark)
    extra := memory.live_bytes

    if host_enabled() {
        checked := host_service.legacy_extra(host_service.user, mark, u64(4 * 1024 * 1024), 0, &extra)

        if checked != bg.OK {
            return {}, {}, checked == bg.CAPACITY ? b.Status.Capacity : b.Status.Incompatible
        }
    }

    snapshot, info, status = b.recovery_read_info(catalog, src, extra)

    if status != .Ok {
        return
    }

    if mark != 0 {
        checked := host_service.budget_reconcile(host_service.user, mark)

        if checked != bg.OK {
            b.snapshot_destroy(&snapshot)
            return {}, {}, checked == bg.CAPACITY ? b.Status.Capacity : b.Status.Incompatible
        }
    }

    return
}

@(private)
codec_context_access :: proc(c: ^Network_Codec($S, $C, $A, $E, $N), allow_empty: bool = false) -> r.Error {
    if c == nil {
        return .Invalid_Config
    }

    when b.BOX3D_REQUIRE_DOMAIN {
        if !allow_empty && r.owner_is_nil(c.context_ownership.owner) {
            return .Invalid_Config
        }
    }

    return r.owner_access(c.context_ownership.owner)
}
