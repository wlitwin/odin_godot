package box3d

// Snapshot is an owning exact-build native image and its geometry lease.
// Assignment aliases ownership. Use snapshot_clone for another independent owner,
// and snapshot_destroy exactly once for each owner. No automatic finalizer runs.
Snapshot :: struct {
    _handle: rawptr,
}

Snapshot_Metrics :: struct {
    image_used:     u64,
    image_capacity: u64,
    geometry_bytes: u64,
    geometry_count: u32,
}

// Storage associated with this immutable resource. Clones share the resource;
// repeated reports must not be summed as independent retained allocations.
Snapshot_Storage :: struct {
    normalized_bytes:       u64,
    wrapper_malloc_bytes:   u64,
    native_requested_bytes: u64,
}

// Combined immutable metadata, one full native seal and structural check.
Snapshot_Info :: struct {
    metrics: Snapshot_Metrics,
    storage: Snapshot_Storage,
}

snapshot_info :: proc(snapshot: ^Snapshot) -> (info: Snapshot_Info, status: Status) {
    if snapshot == nil || snapshot._handle == nil {
        return {}, .Invalid_Argument
    }

    status = native_version_check()

    if status != .Ok {
        return
    }

    status = c_snapshot_info(
        snapshot._handle,
        &info.metrics.image_used,
        &info.metrics.image_capacity,
        &info.metrics.geometry_bytes,
        &info.metrics.geometry_count,
        &info.storage.normalized_bytes,
        &info.storage.wrapper_malloc_bytes,
        &info.storage.native_requested_bytes,
    )
    return
}

// Coupled constructor result; the native constructor retains every full check
// before publishing this owner and its fresh metadata. No second getter needed.
snapshot_capture_info :: proc(world: World) -> (snapshot: Snapshot, info: Snapshot_Info, status: Status) {
    status = abi_check()

    if status != .Ok {
        return
    }

    status = c_snapshot_capture_info(
        world,
        &snapshot._handle,
        &info.metrics.image_used,
        &info.metrics.image_capacity,
        &info.metrics.geometry_bytes,
        &info.metrics.geometry_count,
        &info.storage.normalized_bytes,
        &info.storage.wrapper_malloc_bytes,
        &info.storage.native_requested_bytes,
    )
    return
}

snapshot_clone_info :: proc(source: ^Snapshot) -> (snapshot: Snapshot, info: Snapshot_Info, status: Status) {
    if source == nil || source._handle == nil {
        return {}, {}, .Invalid_Argument
    }

    status = native_version_check()

    if status != .Ok {
        return
    }

    status = c_snapshot_clone_info(
        source._handle,
        &snapshot._handle,
        &info.metrics.image_used,
        &info.metrics.image_capacity,
        &info.metrics.geometry_bytes,
        &info.metrics.geometry_count,
        &info.storage.normalized_bytes,
        &info.storage.wrapper_malloc_bytes,
        &info.storage.native_requested_bytes,
    )
    return
}

// These diagnostics describe the solver only. A complete framework comparison
// must also cover deterministic game side-state and fixed host configuration.
World_Digests :: struct {
    complete_solver_digest: u64,
    motion_digest:          u64,
}

SNAPSHOT_VERSION :: 2
STATE_DUMP_VERSION :: 4
STATE_COVERAGE_ID :: "ogb3-33626332-solver-v4"

snapshot_capture :: proc(world: World) -> (snapshot: Snapshot, status: Status) {
    status = abi_check()

    if status != .Ok {
        return
    }

    status = c_snapshot_capture(world, &snapshot._handle)
    return
}

snapshot_clone :: proc(source: ^Snapshot) -> (snapshot: Snapshot, status: Status) {
    if source == nil || source._handle == nil {
        return {}, .Invalid_Argument
    }

    status = native_version_check()

    if status != .Ok {
        return
    }

    status = c_snapshot_clone(source._handle, &snapshot._handle)
    return
}

// Empty destruction is harmless. Other copies of this owner's value become
// invalid after destruction; they must not be queried, cloned or released.
snapshot_destroy :: proc(snapshot: ^Snapshot) -> Status {
    if snapshot == nil {
        return .Invalid_Argument
    }

    if status := c_snapshot_release(snapshot._handle); status != .Ok {
        return status
    }

    snapshot^ = {}
    return .Ok
}

snapshot_is_empty :: proc(snapshot: ^Snapshot) -> bool {
    return snapshot == nil || snapshot._handle == nil
}

// Restore clears user data and completed physics outputs; future pending
// sensor/contact end queues are restored for delivery by the next fixed step. Rebind host associations
// and restore matching game state before publication. The destination retains
// its own geometry lease independently of the source snapshot after success.
snapshot_restore :: proc(world: World, snapshot: ^Snapshot) -> Status {
    if snapshot == nil || snapshot._handle == nil {
        return .Invalid_Argument
    }

    if status := native_version_check(); status != .Ok {
        return status
    }

    return c_snapshot_restore(world, snapshot._handle)
}

snapshot_metrics :: proc(snapshot: ^Snapshot) -> (metrics: Snapshot_Metrics, status: Status) {
    if snapshot == nil || snapshot._handle == nil {
        return {}, .Invalid_Argument
    }

    status = native_version_check()

    if status != .Ok {
        return
    }

    status = c_snapshot_metrics(
        snapshot._handle,
        &metrics.image_used,
        &metrics.image_capacity,
        &metrics.geometry_bytes,
        &metrics.geometry_count,
    )
    return
}

snapshot_storage :: proc(snapshot: ^Snapshot) -> (storage: Snapshot_Storage, status: Status) {
    if snapshot == nil || snapshot._handle == nil {
        return {}, .Invalid_Argument
    }

    status = native_version_check()

    if status != .Ok {
        return
    }

    status = c_snapshot_storage(
        snapshot._handle,
        &storage.normalized_bytes,
        &storage.wrapper_malloc_bytes,
        &storage.native_requested_bytes,
    )
    return
}

// Process-wide successful wrapper allocation totals, including snapshot owners,
// normalized bytes, registry slots, restored-world leases and temporary digest
// storage. Excludes caller buffers, flat-API geometry owners, engine allocations
// and allocator overhead. Read alongside engine_allocation_stats, not as RSS.
snapshot_allocation_stats :: proc() -> (stats: Allocation_Stats, status: Status) {
    status = c_snapshot_allocation_stats(&stats)
    return
}

// Pass an empty slice to obtain required capacity (.Ok). On .Capacity no partial
// dump is written. Allocate explicitly and retry at a settled boundary.
world_dump :: proc(world: World, bytes: []u8) -> (required: u64, status: Status) {
    data := raw_data(bytes)

    if len(bytes) == 0 {
        data = nil
    }

    status = native_version_check()

    if status != .Ok {
        return
    }

    status = c_state_dump(world, data, u64(len(bytes)), &required)
    return
}

world_digests :: proc(world: World) -> (digests: World_Digests, status: Status) {
    status = native_version_check()

    if status != .Ok {
        return
    }

    status = c_state_digest(world, &digests.complete_solver_digest, &digests.motion_digest)
    return
}

snapshot_dump :: proc(snapshot: ^Snapshot, bytes: []u8) -> (required: u64, status: Status) {
    if snapshot == nil || snapshot._handle == nil {
        return 0, .Invalid_Argument
    }

    data := raw_data(bytes)

    if len(bytes) == 0 {
        data = nil
    }

    status = native_version_check()

    if status != .Ok {
        return
    }

    status = c_snapshot_dump(snapshot._handle, data, u64(len(bytes)), &required)
    return
}

snapshot_digests :: proc(snapshot: ^Snapshot) -> (digests: World_Digests, status: Status) {
    if snapshot == nil || snapshot._handle == nil {
        return {}, .Invalid_Argument
    }

    status = native_version_check()

    if status != .Ok {
        return
    }

    status = c_snapshot_digest(snapshot._handle, &digests.complete_solver_digest, &digests.motion_digest)
    return
}

// Borrowed process-lifetime coverage text and native dump version. Verify these
// against the pinned coverage manifest before claiming complete solver equality.
state_coverage :: proc() -> cstring {
    return c_state_coverage()
}

state_version :: proc() -> u32 {
    return c_state_version()
}

// Immutable copied historical read. No mutable world/scratch execution is used.
snapshot_body_state :: proc(snapshot: ^Snapshot, key: Body_Key) -> (state: Body_State, status: Status) {
    if snapshot == nil || snapshot._handle == nil {
        return {}, .Invalid_Argument
    }

    status = native_version_check()

    if status != .Ok {
        return
    }

    status = c_snapshot_body_state(snapshot._handle, key, &state)
    return
}

snapshot_body_states :: proc(snapshot: ^Snapshot, states: []Body_State) -> (required: u32, status: Status) {
    if snapshot == nil || snapshot._handle == nil {
        return 0, .Invalid_Argument
    }

    if u64(len(states)) > u64(max(u32)) {
        return 0, .Capacity
    }

    data := raw_data(states)

    if len(states) == 0 {
        data = nil
    }

    status = native_version_check()

    if status != .Ok {
        return
    }

    status = c_snapshot_body_states(snapshot._handle, data, u32(len(states)), &required)
    return
}

// Owns one disposable execution. Assignment aliases ownership; do not copy.
World_Stage :: struct {
    world: World,
}

stage_open :: proc(snapshot: ^Snapshot) -> (stage: World_Stage, status: Status) {
    if snapshot == nil || snapshot._handle == nil {
        return {}, .Invalid_Argument
    }

    status = abi_check()

    if status != .Ok {
        return
    }

    stage.world, status = world_create(world_def_default())

    if status != .Ok {
        return
    }

    status = snapshot_restore(stage.world, snapshot)

    if status != .Ok {
        world_destroy(&stage.world)
    }

    return
}

stage_world :: proc(stage: ^World_Stage) -> (world: World, status: Status) {
    if stage == nil {
        return 0, .Invalid_Argument
    }

    valid, valid_status := world_valid(stage.world)

    if valid_status != .Ok {
        return 0, valid_status
    }

    if !valid {
        return 0, .Invalid_Handle
    }

    return stage.world, .Ok
}

// After success stage owns the retired published world. Publish typed game state
// at the same infallible boundary, then discard stage. This does no allocation.
stage_swap :: proc(published: ^World, stage: ^World_Stage) -> Status {
    if published == nil || stage == nil || published^ == stage.world {
        return .Invalid_Argument
    }

    a, as := world_valid(published^)

    if as != .Ok {
        return as
    }

    if !a {
        return .Invalid_Handle
    }

    _, ss := stage_world(stage)

    if ss != .Ok {
        return ss
    }

    old := published^
    published^ = stage.world
    stage.world = old
    return .Ok
}

stage_discard :: proc(stage: ^World_Stage) -> Status {
    if stage == nil {
        return .Invalid_Argument
    }

    if stage.world == 0 {
        return .Ok
    }

    return world_destroy(&stage.world)
}
