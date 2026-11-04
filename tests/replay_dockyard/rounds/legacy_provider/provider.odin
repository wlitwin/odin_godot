package replay_physics_abi1

import "core:mem"
import "core:time"
import "core:reflect"
import b "godot:box3d"
import r "godot:replay"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import "base:runtime"
import intrinsics "base:intrinsics"

IDENTITY :: u64(0x5245504c42334431)
MAX_ASSETS :: 8
IMAGE_BYTES_LIMIT :: 512 * 1024
RESERVATION_BYTES :: 2 * 1024 * 1024

Body_Key :: b.Body_Key
Shape_Key :: b.Shape_Key
Joint_Key :: b.Joint_Key

Asset_Kind :: enum u32 {
    Box,
    Sphere,
    Capsule,
    Hull,
    Mesh,
}

Asset :: struct {
    id:                               u32,
    kind:                             Asset_Kind,
    shape:                            b.Shape_Def,
    half_extents, center_a, center_b: b.Vec3,
    radius:                           f32,
}

// Asset/build IDs are trusted immutable declarations from the exact authored
// fixture/build manifest, not certification by counts or the motion fingerprint.
Config :: struct {
    asset_id, build_id:     u64,
    initial_dynamic_bodies: u32,
    asset_count:            u32,
    assets:                 [MAX_ASSETS]Asset,
}

// Process-wide requested Odin ownership, separate from native engine/wrapper
// counters. Includes retained game/container payload charges and temporary dump
// comparisons. Allocator headers/rounding, stack temporaries and RSS are outside.
Memory :: struct {
    live_bytes, high_water_bytes, total_bytes, total_calls: u64,
    observed_live_peak, largest_operation_requests:         u64,
    reservation_failures:                                   u64,
}

@(private)
memory: Memory

@(private)
Image :: struct {
    ownership:                            Owner_Context,
    snapshot:                             b.Snapshot,
    config:                               Config,
    contract, bytes:                      u64,
    allocator:                            mem.Allocator,
    sensor_count:                         u32,
    sensors:                              [70]Sensor_Event,
    catalog:                              b.Recovery_Catalog,
    catalog_identity:                     b.Recovery_Identity,
    native_required, normalized_required: u64,
}

@(private)
Working :: struct {
    ownership:                                    Owner_Context,
    stage:                                        b.World_Stage,
    config:                                       Config,
    allocator:                                    mem.Allocator,
    commands:                                     ^Command_Dispatch,
    sensor_count:                                 u32,
    sensors:                                      [70]Sensor_Event,
    catalog:                                      b.Recovery_Catalog,
    catalog_identity:                             b.Recovery_Identity,
    revision, admitted_revision, native_required: u64,
}

@(private)
Operation :: struct {
    engine, wrapper:       b.Allocation_Stats,
    owned_total, sdk_mark: u64,
}

config_default :: proc(asset_id, build_id: u64) -> Config {
    config := Config {
        asset_id               = asset_id,
        build_id               = build_id,
        initial_dynamic_bodies = 32,
        asset_count            = 2,
    }
    shape := b.shape_def_default()
    shape.enable_sensor_events = 1
    config.assets[0] = {
        id           = 1,
        kind         = .Box,
        shape        = shape,
        half_extents = {0.25, 0.25, 0.25},
    }
    config.assets[1] = {
        id     = 2,
        kind   = .Sphere,
        shape  = shape,
        radius = 0.25,
    }
    return config
}

allocation_stats :: proc() -> Memory {
    return memory
}

// Core value_supported intentionally accepts distinct integers. Physics State
// additionally excludes typed host-world handles, including nested/named forms.
// Explicit casts or new distinct-integer rewrapping erase native provenance in
// Odin reflection and remain the author's canonical-state duty.
state_supported :: proc(state: typeid) -> bool {
    return r.value_supported(state) && state_keys_only(type_info_of(state))
}

@(private)
state_keys_only :: proc(info: ^reflect.Type_Info) -> bool {
    if info == nil {
        return false
    }

    if info.id == b.World || info.id == b.Body || info.id == b.Shape || info.id == b.Joint || info.id == b.Host_Owner {
        return false
    }

    #partial switch value in info.variant {
    case reflect.Type_Info_Named:
        return state_keys_only(value.base)
    case reflect.Type_Info_Struct:
        for field in value.types[:value.field_count] {
            if !state_keys_only(field) {
                return false
            }
        }
    case reflect.Type_Info_Array:
        return state_keys_only(value.elem)
    case reflect.Type_Info_Enumerated_Array:
        return state_keys_only(value.elem)
    case reflect.Type_Info_Union:
        for variant in value.variants {
            if !state_keys_only(variant) {
                return false
            }
        }
    case reflect.Type_Info_Enum:
        return state_keys_only(value.base)
    case reflect.Type_Info_Bit_Set:
        return state_keys_only(value.underlying)
    }

    return true
}

// Stable Core service is installed only by the opt-in concrete module hook.
@(private)
host_service: bg.Service
@(private)
host_marks: [64]u64
@(private)
host_mark_count: int

@(private)
host_status :: proc(status: bg.Status) -> r.Error {
    if status == bg.OK {
        return .None
    }

    if status == bg.CAPACITY || status == bg.OUT_OF_MEMORY {
        return .Resource_Limit
    }

    return .External_State
}

@(private)
host_enabled :: proc() -> bool {
    return host_service.realm != 0
}

@(private)
charge :: proc(bytes: u64) -> r.Error {
    if bytes > max(u64) - memory.live_bytes || bytes > max(u64) - memory.total_bytes {
        return .Resource_Limit
    }

    // Requests are conservative charged ownership attempts (including precharges),
    // retained even when admission fails and a just-allocated object is freed.
    memory.total_bytes += bytes
    memory.total_calls += 1
    // Strict SDK allocations are observed by Meter; this legacy charge is local
    // diagnostic bookkeeping only and must not overwrite/double its category.

    memory.live_bytes += bytes
    memory.high_water_bytes = max(memory.high_water_bytes, memory.live_bytes)
    return .None
}

@(private)
uncharge :: proc(bytes: u64) {
    assert(memory.live_bytes >= bytes)

    memory.live_bytes -= bytes
}

@(private)
status_error :: proc(status: b.Status) -> r.Error {
    if status == .Ok {
        return .None
    }

    if status == .Capacity || status == .Out_Of_Memory {
        return .Resource_Limit
    }

    return .External_State
}

@(private)
memory_check :: proc(extra: u64 = 0, reserve: u64 = 0) -> r.Error {
    if extra > max(u64) - memory.live_bytes || reserve > max(u64) - extra {
        return .Resource_Limit
    }

    additional := memory.live_bytes + extra
    native_reserve := reserve

    if host_enabled() {
        // Under an outer ticket the declarative operation reserve is already held.
        // Proposed extra consumes that promise via Core, never another global sum.
        proposed := extra

        if host_mark_count == 0 {
            proposed += reserve
        }

        status := host_service.legacy_extra(host_service.user, 0, 0, proposed, &additional)

        if status != bg.OK {
            return host_status(status)
        }

        native_reserve = 0
    }

    observation, status := b.alpha_memory_check(additional, native_reserve)

    if status == .Ok {
        memory.observed_live_peak = max(memory.observed_live_peak, observation.live_bytes)
    }

    return status_error(status)
}

@(private)
budget_begin :: proc(bytes: u64) -> (mark: u64, error: r.Error) {
    if !host_enabled() {
        return 0, .None
    }

    if host_mark_count == len(host_marks) {
        return 0, .Resource_Limit
    }

    status := host_service.budget_begin(host_service.user, bytes, &mark)

    if status != bg.OK {
        return 0, host_status(status)
    }

    host_marks[host_mark_count] = mark
    host_mark_count += 1
    return
}

@(private)
budget_end :: proc(mark: ^u64) {
    if mark == nil || mark^ == 0 {
        return
    }

    old := mark^
    mark^ = 0
    assert(host_mark_count > 0 && host_marks[host_mark_count - 1] == old, "operation budget order")
    host_mark_count -= 1
    host_marks[host_mark_count] = 0
    status := host_service.budget_end(host_service.user, old)
    // Capacity still closes this exact child mark; never retry/pop the parent.
    assert(status == bg.OK || status == bg.CAPACITY, "operation budget end rejected")
}

@(private)
operation_end :: proc(operation: ^Operation) {
    if operation != nil {
        budget_end(&operation.sdk_mark)
    }
}

@(private)
begin :: proc() -> (operation: Operation, error: r.Error) {
    if host_enabled() {
        operation.sdk_mark, error = budget_begin(RESERVATION_BYTES)

        if error != .None {
            return
        }
    } else {
        error = memory_check(0, RESERVATION_BYTES)

        if error != .None {
            return
        }
    }

    status: b.Status
    operation.engine, status = b.engine_allocation_stats()

    if status != .Ok {
        operation_end(&operation)
        return {}, status_error(status)
    }

    operation.wrapper, status = b.snapshot_allocation_stats()

    if status != .Ok {
        operation_end(&operation)
        return {}, status_error(status)
    }

    operation.owned_total = memory.total_bytes
    return
}

@(private)
finish :: proc(operation: Operation) -> r.Error {
    engine, es := b.engine_allocation_stats()

    if es != .Ok {
        return status_error(es)
    }

    wrapper, ws := b.snapshot_allocation_stats()

    if ws != .Ok {
        return status_error(ws)
    }

    requests := engine.total_bytes - operation.engine.total_bytes
    wrapper_requests := wrapper.total_bytes - operation.wrapper.total_bytes
    owned_requests := memory.total_bytes - operation.owned_total

    if wrapper_requests > max(u64) - requests || owned_requests > max(u64) - requests - wrapper_requests {
        return .Resource_Limit
    }

    requests += wrapper_requests + owned_requests
    memory.largest_operation_requests = max(memory.largest_operation_requests, requests)

    if requests > RESERVATION_BYTES {
        memory.reservation_failures += 1
        return .Resource_Limit
    }

    if operation.sdk_mark != 0 {
        status := host_service.budget_reconcile(host_service.user, operation.sdk_mark)

        if status != bg.OK {
            return host_status(status)
        }
    }

    return memory_check()
}

@(private)
world_check :: proc(world: b.World, config: Config) -> r.Error {
    request := b.alpha_request_default()
    request.initial_dynamic_bodies = config.initial_dynamic_bodies
    request.additional_owned_bytes = memory.live_bytes

    if host_enabled() {
        status := host_service.legacy_extra(host_service.user, 0, 0, 0, &request.additional_owned_bytes)

        if status != bg.OK {
            return host_status(status)
        }
    }

    _, status := b.alpha_check(world, request)
    return status_error(status)
}

@(private)
fold :: proc(hash: ^u64, value: u64) {
    for shift in 0 ..< 8 {
        hash^ = (hash^ ~ ((value >> uint(shift * 8)) & 255)) * 0x100000001b3
    }
}

@(private)
fold_vec :: proc(hash: ^u64, value: b.Vec3) {
    fold(hash, u64(transmute(u32)value.x))
    fold(hash, u64(transmute(u32)value.y))
    fold(hash, u64(transmute(u32)value.z))
}

@(private)
config_contract :: proc(config: Config) -> u64 {
    config := config
    hash := u64(0xcbf29ce484222325)

    for value in ([?]u64 {
            config.asset_id,
            config.build_id,
            b.build_fingerprint(),
            u64(ODIN_OS),
            u64(ODIN_ARCH),
            b.STATE_DUMP_VERSION,
            u64(config.initial_dynamic_bodies),
            u64(config.asset_count),
        }) {
        fold(&hash, value)
    }

    for asset in config.assets[:config.asset_count] {
        fold(&hash, u64(asset.id))
        fold(&hash, u64(asset.kind))
        fold_vec(&hash, asset.half_extents)
        fold_vec(&hash, asset.center_a)
        fold_vec(&hash, asset.center_b)
        fold(&hash, u64(transmute(u32)asset.radius))
        s := asset.shape

        for value in ([?]u64 {
                s.category_bits,
                s.mask_bits,
                u64(transmute(u32)s.group_index),
                u64(transmute(u32)s.density),
                u64(transmute(u32)s.friction),
                u64(transmute(u32)s.restitution),
                u64(s.is_sensor),
                u64(s.enable_sensor_events),
                u64(s.enable_contact_events),
            }) {
            fold(&hash, value)
        }
    }

    return hash
}

@(private)
valid_config :: proc(config: Config) -> bool {
    config := config

    if config.asset_id == 0 ||
       config.build_id == 0 ||
       config.initial_dynamic_bodies > 32 ||
       config.asset_count > MAX_ASSETS {
        return false
    }

    for asset, index in config.assets[:config.asset_count] {
        if asset.id == 0 || asset.kind > .Mesh || asset.shape.is_sensor != 0 {
            return false
        }

        if asset.kind == .Mesh && asset.shape.enable_sensor_events != 0 {
            return false
        }

        for previous in config.assets[:index] {
            if previous.id == asset.id {
                return false
            }
        }
    }

    return true
}

@(private)
image_make :: proc(
    snapshot: b.Snapshot,
    config: Config,
    allocator: mem.Allocator,
    sensors: []Sensor_Event = nil,
    catalog: ^b.Recovery_Catalog = nil,
    native_required: u64 = 0,
    constructor_info: ^b.Snapshot_Info = nil,
    ownership: Owner_Context = {},
) -> (
    rawptr,
    u64,
    r.Error,
) {
    if error := ownership_check(ownership, allocator); error != .None {
        return nil, 0, error
    }

    if error := r.owner_retain(ownership.owner); error != .None {
        return nil, 0, error
    }

    lease := ownership.owner
    transferred := false

    defer if !transferred {
        r.owner_drop(&lease)
    }

    snapshot := snapshot
    info: b.Snapshot_Info
    status: b.Status

    if constructor_info == nil {
        info, status = b.snapshot_info(&snapshot)

        if status != .Ok {
            return nil, 0, status_error(status)
        }
    } else {
        info = constructor_info^
    }

    storage := info.storage

    if storage.native_requested_bytes > max(u64) - storage.wrapper_malloc_bytes ||
       storage.native_requested_bytes + storage.wrapper_malloc_bytes > IMAGE_BYTES_LIMIT - size_of(Image) {
        return nil, 0, .Resource_Limit
    }

    if info.metrics.image_used > b.RECOVERY_MAX_SOURCE_IMAGE_BYTES {
        return nil, 0, .Resource_Limit
    }

    catalog_owner: b.Recovery_Catalog
    catalog_identity: b.Recovery_Identity

    if catalog != nil && catalog._handle != nil {
        catalog_owner, status = b.recovery_catalog_clone(catalog)

        if status != .Ok {
            return nil, 0, status_error(status)
        }

        catalog_identity, status = b.recovery_catalog_identity(&catalog_owner)

        if status != .Ok {
            b.recovery_catalog_destroy(&catalog_owner)
            return nil, 0, status_error(status)
        }
    }

    bytes := storage.native_requested_bytes + storage.wrapper_malloc_bytes + size_of(Image)
    pointer, alloc_error := mem.alloc(size_of(Image), align_of(Image), allocator)

    if alloc_error != .None || pointer == nil {
        b.recovery_catalog_destroy(&catalog_owner)
        return nil, 0, .Resource_Limit
    }

    image := cast(^Image)pointer
    image^ = {
        ownership           = ownership,
        snapshot            = snapshot,
        config              = config,
        contract            = catalog_contract(config, catalog_identity),
        bytes               = bytes,
        allocator           = allocator,
        sensor_count        = u32(len(sensors)),
        catalog             = catalog_owner,
        catalog_identity    = catalog_identity,
        native_required     = native_required,
        normalized_required = storage.normalized_bytes,
    }
    copy(image.sensors[:], sensors)

    if error := charge(size_of(Image)); error != .None {
        b.recovery_catalog_destroy(&image.catalog)
        mem.free(image, allocator)
        return nil, 0, error
    }

    transferred = true
    return pointer, bytes, .None
}

@(private)
release :: proc(pointer: rawptr) {
    image := cast(^Image)pointer

    if r.owner_access(image.ownership.owner) != .None || b.domain_access_check() != .Ok {
        return
    }

    allocator := image.allocator
    owner := image.ownership.owner

    if b.snapshot_destroy(&image.snapshot) != .Ok {
        return
    }

    if b.recovery_catalog_destroy(&image.catalog) != .Ok {
        return
    }

    uncharge(size_of(Image))
    mem.free(image, allocator)
    r.owner_drop(&owner)
}

@(private)
clone :: proc(pointer: rawptr) -> (rawptr, r.Error) {
    image := cast(^Image)pointer

    if error := r.owner_access(image.ownership.owner); error != .None {
        return nil, error
    }

    operation, error := begin()

    if error != .None {
        return nil, error
    }

    defer operation_end(&operation)
    snapshot, info, status := b.snapshot_clone_info(&image.snapshot)

    if status != .Ok {
        return nil, status_error(status)
    }

    result, _, make_error := image_make(
        snapshot,
        image.config,
        image.allocator,
        image.sensors[:image.sensor_count],
        &image.catalog,
        image.native_required,
        &info,
        image.ownership,
    )

    if make_error != .None {
        b.snapshot_destroy(&snapshot)
        return nil, make_error
    }

    if error := finish(operation); error != .None {
        release(result)
        return nil, error
    }

    return result, .None
}

@(private)
open :: proc(pointer: rawptr) -> (rawptr, r.Error) {
    image := cast(^Image)pointer

    if error := r.owner_access(image.ownership.owner, .Execute); error != .None {
        return nil, error
    }

    if error := r.owner_retain(image.ownership.owner); error != .None {
        return nil, error
    }

    owner := image.ownership.owner
    transferred := false

    defer if !transferred {
        r.owner_drop(&owner)
    }

    operation, error := begin()

    if error != .None {
        return nil, error
    }

    defer operation_end(&operation)
    stage, status := b.stage_open(&image.snapshot)

    if status != .Ok {
        return nil, status_error(status)
    }

    pointer, allocation_error := mem.alloc(size_of(Working), align_of(Working), image.allocator)

    if allocation_error != .None || pointer == nil {
        b.stage_discard(&stage)
        return nil, .Resource_Limit
    }

    work := cast(^Working)pointer
    work^ = {
        ownership        = image.ownership,
        stage            = stage,
        config           = image.config,
        allocator        = image.allocator,
        commands         = &command_dispatch,
        sensor_count     = image.sensor_count,
        sensors          = image.sensors,
        catalog_identity = image.catalog_identity,
        native_required  = image.native_required,
    }

    if error := charge(size_of(Working)); error != .None {
        b.stage_discard(&stage)
        mem.free(work, image.allocator)
        return nil, error
    }

    transferred = true

    if image.catalog._handle != nil {
        work.catalog, status = b.recovery_catalog_clone(&image.catalog)

        if status != .Ok {
            close(work)
            return nil, status_error(status)
        }
    }

    if error := finish(operation); error != .None {
        close(work)
        return nil, error
    }

    if error := world_check(stage.world, work.config); error != .None {
        close(work)
        return nil, error
    }

    return work, .None
}

@(private)
close :: proc(pointer: rawptr) {
    work := cast(^Working)pointer

    if r.owner_access(work.ownership.owner) != .None || b.domain_access_check() != .Ok {
        return
    }

    allocator := work.allocator
    owner := work.ownership.owner
    status := b.stage_discard(&work.stage)
    assert(status == .Ok)
    b.recovery_catalog_destroy(&work.catalog)
    uncharge(size_of(Working))
    mem.free(work, allocator)
    r.owner_drop(&owner)
}

@(private)
capture :: proc(pointer: rawptr) -> (rawptr, u64, r.Error) {
    work := cast(^Working)pointer

    if error := catalog_admit(work); error != .None {
        return nil, 0, error
    }

    operation, error := begin()

    if error != .None {
        return nil, 0, error
    }

    defer operation_end(&operation)
    snapshot, info, status := b.snapshot_capture_info(work.stage.world)

    if status != .Ok {
        return nil, 0, status_error(status)
    }

    image, bytes, make_error := image_make(
        snapshot,
        work.config,
        work.allocator,
        work.sensors[:work.sensor_count],
        &work.catalog,
        work.native_required,
        &info,
        work.ownership,
    )

    if make_error != .None {
        b.snapshot_destroy(&snapshot)
        return nil, 0, make_error
    }

    if error := finish(operation); error != .None {
        release(image)
        return nil, 0, error
    }

    return image, bytes, .None
}

@(private)
equal :: proc(left, right: rawptr) -> (bool, r.Error) {
    a, z := cast(^Image)left, cast(^Image)right

    if error := r.owner_access(a.ownership.owner); error != .None {
        return false, error
    }

    if error := r.owner_access(z.ownership.owner); error != .None {
        return false, error
    }

    if a.contract != z.contract {
        return false, .External_State
    }

    if a.sensor_count != z.sensor_count {
        return false, .None
    }

    for event, index in a.sensors[:a.sensor_count] {
        other := z.sensors[index]

        if event.sensor != other.sensor || event.visitor != other.visitor || event.began != other.began {
            return false, .None
        }
    }

    n, ns := b.snapshot_dump(&a.snapshot, nil)

    if ns != .Ok {
        return false, status_error(ns)
    }

    m, ms := b.snapshot_dump(&z.snapshot, nil)

    if ms != .Ok {
        return false, status_error(ms)
    }

    if n != m {
        return false, .None
    }

    if n > IMAGE_BYTES_LIMIT || n > max(u64) / 2 {
        return false, .Resource_Limit
    }

    if error := memory_check(n * 2); error != .None {
        return false, error
    }

    bytes := make([]u8, int(n * 2), a.allocator)

    if error := charge(n * 2); error != .None {
        delete(bytes, a.allocator)
        return false, error
    }

    defer {
        delete(bytes, a.allocator)
        uncharge(n * 2)
    }

    _, first := b.snapshot_dump(&a.snapshot, bytes[:n])

    if first != .Ok {
        return false, status_error(first)
    }

    _, second := b.snapshot_dump(&z.snapshot, bytes[n:])

    if second != .Ok {
        return false, status_error(second)
    }

    return mem.compare(bytes[:n], bytes[n:]) == 0, .None
}

@(private)
reserve :: proc(image: rawptr, bytes: u64) -> r.Error {
    if error := memory_check(bytes); error != .None {
        return error
    }

    return charge(bytes)
}

@(private)
unreserve :: proc(bytes: u64) {
    uncharge(bytes)
}

@(private)
preflight :: proc(image: rawptr, usage: r.External_Usage) -> r.Error {
    return memory_check(usage.runtime_bytes, RESERVATION_BYTES)
}

@(private)
admit :: proc(pointer: rawptr, phase: r.External_Phase, usage: r.External_Usage) -> r.Error {
    work := cast(^Working)pointer
    return catalog_admit(work)
}

@(private)
clock :: proc() -> u64 {
    return u64(time.tick_now()._nsec)
}

@(private)
participant :: proc(
    config: Config,
    catalog_identity: b.Recovery_Identity = {},
    ownership: Owner_Context = {},
) -> r.External {
    return {
        owner = ownership.owner,
        owner_allocator_data = ownership.allocator_data,
        owner_user_data = ownership.user_data,
        identity = IDENTITY,
        contract = catalog_contract(config, catalog_identity),
        valid_value = state_supported,
        reserve = reserve,
        unreserve = unreserve,
        preflight = preflight,
        clone = clone,
        release = release,
        open = open,
        close = close,
        capture = capture,
        equal = equal,
        admit = admit,
        clock = clock,
        require_step = true,
        limits = {
            history_frames = 128,
            max_prediction_ticks = 8,
            max_repair_ticks = 8,
            max_audit_ticks = 127,
            max_bytes = b.ALPHA_RESOURCE_BYTES,
        },
    }
}

// Capture does not consume source world. Config and image own all needed data;
// the source world, Timeline and its provider variables may then be destroyed.
checkpoint_make :: proc(
    frame: r.Frame($S),
    $E: typeid,
    world: b.World,
    config: Config,
    epoch: u64 = 1,
    allocator := context.allocator,
    ownership: Owner_Context = {},
    catalog: ^b.Recovery_Catalog = nil,
) -> (
    r.Complete_Checkpoint(S, E),
    r.Error,
) {
    config := config // local addressable asset array; input value is unchanged

    if error := ownership_check(ownership, allocator, .Execute); error != .None {
        return {}, error
    }

    if !valid_config(config) {
        return {}, .Invalid_Config
    }

    catalog_identity: b.Recovery_Identity

    if catalog != nil {
        identity, status := b.recovery_catalog_identity(catalog)

        if status != .Ok {
            return {}, status_error(status)
        }

        catalog_identity = identity
    } else {
        for asset in config.assets[:config.asset_count] {
            if asset.kind == .Hull || asset.kind == .Mesh {
                return {}, .Invalid_Config
            }
        }
    }

    if b.state_version() != b.STATE_DUMP_VERSION {
        return {}, .External_State
    }

    if !state_supported(S) || !state_supported(E) {
        return {}, .Unsupported_Value
    }

    if error := world_check(world, config); error != .None {
        return {}, error
    }

    operation, error := begin()

    if error != .None {
        return {}, error
    }

    defer operation_end(&operation)
    snapshot, status := b.snapshot_capture(world)

    if status != .Ok {
        return {}, status_error(status)
    }

    states: [35]b.Body_State
    count, read_status := b.snapshot_body_states(&snapshot, states[:])

    if read_status != .Ok {
        b.snapshot_destroy(&snapshot)
        return {}, status_error(read_status)
    }

    dynamics: u32

    for state in states[:count] {
        if state.type == .Dynamic {
            dynamics += 1
        }
    }

    if dynamics != config.initial_dynamic_bodies {
        b.snapshot_destroy(&snapshot)
        return {}, .Resource_Limit
    }

    sensors: [70]Sensor_Event
    sensor_count, sensor_error := read_sensor_events(world, sensors[:])

    if sensor_error != .None {
        b.snapshot_destroy(&snapshot)
        return {}, sensor_error
    }

    image, bytes, make_error := image_make(
        snapshot,
        config,
        allocator,
        sensors[:sensor_count],
        catalog = catalog,
        ownership = ownership,
    )

    if make_error != .None {
        b.snapshot_destroy(&snapshot)
        return {}, make_error
    }

    if error := finish(operation); error != .None {
        release(image)
        return {}, error
    }

    checkpoint, adopt_error := r.complete_checkpoint_adopt(
        frame,
        E,
        participant(config, catalog_identity, ownership),
        image,
        bytes,
        epoch,
        allocator,
    )

    if adopt_error != .None {
        release(image)
    }

    return checkpoint, adopt_error
}

// Readonly historical poses use the native snapshot cache, never a live world.
body_state :: proc(checkpoint: ^r.Complete_Checkpoint($S, $E), key: Body_Key) -> (b.Body_State, r.Error) {
    pointer, error := r.complete_checkpoint_image(checkpoint, IDENTITY)

    if error != .None {
        return {}, error
    }

    image := cast(^Image)pointer
    state, status := b.snapshot_body_state(&image.snapshot, key)
    return state, status_error(status)
}

// One immutable cache read for pooled presentation. A short destination returns
// required count without partial writes; nil/zero is the native sizing query.
body_states :: proc(checkpoint: ^r.Complete_Checkpoint($S, $E), out: []b.Body_State) -> (u32, r.Error) {
    pointer, error := r.complete_checkpoint_image(checkpoint, IDENTITY)

    if error != .None {
        return 0, error
    }

    image := cast(^Image)pointer
    count, status := b.snapshot_body_states(&image.snapshot, out)

    if status == .Capacity {
        return count, .Output_Too_Small
    }

    return count, status_error(status)
}

dump :: proc(checkpoint: ^r.Complete_Checkpoint($S, $E), bytes: []u8) -> (u64, r.Error) {
    pointer, error := r.complete_checkpoint_image(checkpoint, IDENTITY)

    if error != .None {
        return 0, error
    }

    image := cast(^Image)pointer
    required, status := b.snapshot_dump(&image.snapshot, bytes)

    if status == .Capacity {
        return required, .Output_Too_Small
    }

    return required, status_error(status)
}

digests :: proc(checkpoint: ^r.Complete_Checkpoint($S, $E)) -> (b.World_Digests, r.Error) {
    pointer, error := r.complete_checkpoint_image(checkpoint, IDENTITY)

    if error != .None {
        return {}, error
    }

    image := cast(^Image)pointer
    values, status := b.snapshot_digests(&image.snapshot)
    return values, status_error(status)
}

@(private)
catalog_contract :: proc(config: Config, identity: b.Recovery_Identity) -> u64 {
    value := config_contract(config)

    if identity.profile != 0 {
        fold(&value, u64(identity.solver_format))
        fold(&value, u64(identity.recovery_format))
        fold(&value, identity.profile)

        for byte in identity.build_target {
            fold(&value, u64(byte))
        }

        for byte in identity.assets {
            fold(&value, u64(byte))
        }

        for byte in identity.solver_schema {
            fold(&value, u64(byte))
        }
    }

    return value
}

@(private)
catalog_admit :: proc(work: ^Working) -> r.Error {
    if error := r.owner_access(work.ownership.owner, .Execute); error != .None {
        return error
    }

    if error := world_check(work.stage.world, work.config); error != .None {
        return error
    }

    if work.catalog._handle == nil || work.revision == work.admitted_revision {
        return .None
    }

    additional := memory.live_bytes

    if host_enabled() {
        status := host_service.legacy_extra(host_service.user, 0, 0, 0, &additional)

        if status != bg.OK {
            return host_status(status)
        }
    }

    required, status := b.recovery_world_admit(&work.catalog, work.stage.world, additional)

    if status != .Ok {
        return status_error(status)
    }

    work.admitted_revision = work.revision
    work.native_required = required
    return .None
}

when b.BOX3D_REQUIRE_DOMAIN {
    @(init)
    host_module_register :: proc "contextless" () {
        if bg.module_add_hook(host_module_install) != bg.OK {
            intrinsics.trap()
        }
    }

    @(private)
    host_module_install :: proc "c" (service: ^bg.Service) -> bg.Status {
        context = runtime.default_context()

        if service == nil ||
           service.account == nil ||
           service.request_totals == nil ||
           service.budget_begin == nil ||
           service.budget_reconcile == nil ||
           service.budget_end == nil ||
           service.legacy_extra == nil {
            return bg.INCOMPATIBLE
        }

        if r.owner_realm_install(service.realm) != .None {
            return bg.INCOMPATIBLE
        }

        host_service = service^
        return bg.OK
    }
}

// Runtime-only ownership composition, excluded from game/config wire identity.
Owner_Context :: struct {
    owner:                     r.Owner,
    allocator_data, user_data: rawptr,
}

owner_context_create :: proc(
    data: bg.Data_Lease = {},
    allocator_data: rawptr = nil,
    user_data: rawptr = nil,
    require_live_instance: bool = true,
) -> (
    ownership: Owner_Context,
    error: r.Error,
) {
    if !host_enabled() {
        return {}, .External_State
    }

    if (data.user == nil && (data.retain != nil || data.drop != nil)) ||
       (data.user != nil && (data.retain == nil || data.drop == nil)) {
        return {}, .Invalid_Config
    }

    if allocator_data != nil && allocator_data != data.user {
        return {}, .Unsupported_Value
    }

    if user_data != nil && user_data != data.user {
        return {}, .Unsupported_Value
    }

    data := data
    owner: bg.Owner
    status := host_service.owner_create(host_service.user, u32(require_live_instance), &data, &owner)

    if status != bg.OK {
        return {}, host_status(status)
    }

    return {owner = owner, allocator_data = allocator_data, user_data = user_data}, .None
}

owner_context_destroy :: proc(ownership: ^Owner_Context) -> r.Error {
    if ownership == nil {
        return .Invalid_Config
    }

    error := r.owner_drop(&ownership.owner)

    if error == .None {
        ownership^ = {}
    }

    return error
}

@(private)
ownership_check :: proc(
    ownership: Owner_Context,
    allocator: mem.Allocator,
    access: r.Owner_Access = .Read,
) -> r.Error {
    when b.BOX3D_REQUIRE_DOMAIN {
        if r.owner_is_nil(ownership.owner) {
            return .Invalid_Config
        }

        if !meter.is_allocator(allocator) {
            return .Unsupported_Value
        }
    }

    if error := r.owner_access(ownership.owner, access); error != .None {
        return error
    }

    if !r.owner_is_nil(ownership.owner) {
        if allocator.data != nil && allocator.data != ownership.allocator_data {
            return .Unsupported_Value
        }

        if allocator.data == nil && !r.owner_builtin_allocator(allocator) {
            return .Unsupported_Value
        }
    }

    return .None
}

// Test/slice process-local capsule ABI. These opaque handles contain stable Core
// callbacks; they are not persistent/network data or typed Odin frame layouts.
PHYSICS_CAPSULE_BODY_STATE :: u32(0x100)
PHYSICS_CAPSULE_DUMP :: u32(0x101)
PHYSICS_CAPSULE_DIGESTS :: u32(0x102)
PHYSICS_CAPSULE_NATIVE_RESTORE :: u32(0x103)

Capsule_Body_State_Args :: struct {
    key: b.Body_Key,
    out: ^b.Body_State,
}

Capsule_Dump_Args :: struct {
    bytes:    [^]u8,
    capacity: u64,
    required: ^u64,
}

Capsule_Digests_Args :: struct {
    out: ^b.World_Digests,
}

// Restores native SOLVER state only. Typed Game/Side/events are not transferred
// or published by this operation; use canonical framework recovery for that.
Capsule_Native_Restore_Args :: struct {
    world:    b.World,
    reserved: u32,
}

@(private)
Checkpoint_Capsule_Payload :: struct($S, $E: typeid) {
    owner:      r.Owner,
    checkpoint: r.Complete_Checkpoint(S, E),
    allocator:  mem.Allocator,
    service:    bg.Service,
}

checkpoint_capsule_create :: proc(
    source: ^r.Complete_Checkpoint($S, $E),
    service: bg.Service,
    allocator := context.allocator,
) -> (
    capsule: bg.Capsule,
    error: r.Error,
) {
    if source == nil {
        return {}, .Incomplete_State
    }

    if r.owner_is_nil(source.owner) || service.realm != source.owner.realm || service.capsule_create == nil {
        return {}, .External_State
    }

    if error := r.owner_access(source.owner); error != .None {
        return {}, error
    }

    if error := r.owner_contexts_check(source._external, allocator); error != .None {
        return {}, error
    }

    if _, error := r.complete_checkpoint_image(source, IDENTITY); error != .None {
        return {}, error
    }

    owned, clone_error := r.complete_checkpoint_clone(source, allocator)

    if clone_error != .None {
        return {}, clone_error
    }

    committed := false

    defer if !committed {
        r.complete_checkpoint_destroy(&owned)
    }

    extra := u64(size_of(Checkpoint_Capsule_Payload(S, E))) - u64(size_of(r.Complete_Checkpoint(S, E)))

    if extra > max(u64) - owned._owned_bytes {
        return {}, .Resource_Limit
    }

    if limit := owned._external.limits.max_bytes; limit != 0 && owned._owned_bytes + extra > limit {
        return {}, .Resource_Limit
    }

    if owned._external.reserve != nil {
        if error := owned._external.reserve(owned._image, extra); error != .None {
            return {}, error
        }
    }

    owned._owned_bytes += extra
    pointer, allocation_error := mem.alloc(
        size_of(Checkpoint_Capsule_Payload(S, E)),
        align_of(Checkpoint_Capsule_Payload(S, E)),
        allocator,
    )

    if allocation_error != .None {
        return {}, .Resource_Limit
    }

    payload := cast(^Checkpoint_Capsule_Payload(S, E))pointer
    payload^ = {
        owner      = owned.owner,
        checkpoint = owned,
        allocator  = allocator,
        service    = service,
    }

    dispatch := proc "c" (data: rawptr, operation: u32, args: rawptr) -> bg.Status {
        context = runtime.default_context()
        payload := cast(^Checkpoint_Capsule_Payload(S, E))data

        if r.owner_access(payload.owner) != .None || b.domain_access_check() != .Ok {
            return bg.INCOMPATIBLE
        }

        if operation == bg.CAPSULE_DESTROY {
            owned := payload.checkpoint
            alloc := payload.allocator
            payload.checkpoint = {}
            mem.free(payload, alloc)

            if r.complete_checkpoint_destroy(&owned) != .None {
                return bg.INCOMPATIBLE
            }

            return bg.OK
        }

        if operation == bg.CAPSULE_CLONE {
            if args == nil {
                return bg.INVALID_ARGUMENT
            }

            output := cast(^bg.Capsule_Clone_Args)args

            if output.out == nil {
                return bg.INVALID_ARGUMENT
            }

            copy, error := checkpoint_capsule_create(&payload.checkpoint, payload.service, payload.allocator)

            if error != .None {
                return error == .Resource_Limit ? bg.CAPACITY : bg.INCOMPATIBLE
            }

            output.out^ = copy
            return bg.OK
        }

        pointer, error := r.complete_checkpoint_image(&payload.checkpoint, IDENTITY)

        if error != .None {
            return bg.INCOMPATIBLE
        }

        image := cast(^Image)pointer

        switch operation {
        case PHYSICS_CAPSULE_BODY_STATE:
            if args == nil {
                return bg.INVALID_ARGUMENT
            }

            request := cast(^Capsule_Body_State_Args)args

            if request.out == nil {
                return bg.INVALID_ARGUMENT
            }

            state, status := b.snapshot_body_state(&image.snapshot, request.key)

            if status == .Ok {
                request.out^ = state
            }

            return bg.Status(status)
        case PHYSICS_CAPSULE_DUMP:
            if args == nil {
                return bg.INVALID_ARGUMENT
            }

            request := cast(^Capsule_Dump_Args)args

            if request.required == nil ||
               request.capacity > u64(max(int)) ||
               (request.capacity != 0 && request.bytes == nil) {
                return bg.INVALID_ARGUMENT
            }

            bytes: []u8

            if request.capacity != 0 {
                bytes = request.bytes[:int(request.capacity)]
            }

            required, status := b.snapshot_dump(&image.snapshot, bytes)

            if status == .Ok || status == .Capacity {
                request.required^ = required
            }

            return bg.Status(status)
        case PHYSICS_CAPSULE_DIGESTS:
            if args == nil {
                return bg.INVALID_ARGUMENT
            }

            request := cast(^Capsule_Digests_Args)args

            if request.out == nil {
                return bg.INVALID_ARGUMENT
            }

            digest, status := b.snapshot_digests(&image.snapshot)

            if status == .Ok {
                request.out^ = digest
            }

            return bg.Status(status)
        case PHYSICS_CAPSULE_NATIVE_RESTORE:
            if args == nil {
                return bg.INVALID_ARGUMENT
            }

            request := cast(^Capsule_Native_Restore_Args)args

            if request.reserved != 0 {
                return bg.INVALID_ARGUMENT
            }

            operation, error := begin()

            if error != .None {
                return error == .Resource_Limit ? bg.CAPACITY : bg.UNSUPPORTED
            }

            defer operation_end(&operation)
            status := b.snapshot_restore(request.world, &image.snapshot)

            if status != .Ok {
                return bg.Status(status)
            }

            if error := finish(operation); error != .None {
                return error == .Resource_Limit ? bg.CAPACITY : bg.INCOMPATIBLE
            }

            return bg.OK
        case:
            return bg.UNSUPPORTED
        }
    }

    status := service.capsule_create(service.user, &payload.owner, payload, dispatch, &capsule)

    if status != bg.OK {
        payload.checkpoint = {}
        mem.free(payload, allocator)
        return {}, host_status(status)
    }

    owned = {}
    committed = true
    return capsule, .None
}
