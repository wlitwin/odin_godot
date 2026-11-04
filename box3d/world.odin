package box3d

FIXED_HZ :: 60
FIXED_SECONDS: f32 : 1.0 / FIXED_HZ
FIXED_SUBSTEPS: u32 : 4

// Default constructors are infallible for the supported ABI. A mismatch fails
// loudly before C writes to a POD. Object operations return native statuses.
world_def_default :: proc() -> (def: World_Def) {
	require_abi()
	status := c_world_def_default(&def)
	if status != .Ok {panic("Box3D native default initialization failed")}
	return
}

@(private)
require_abi :: proc() {
	if abi_check() != .Ok {panic("Box3D C/Odin ABI mismatch")}
}

world_create :: proc(def: World_Def) -> (world: World, status: Status) {
	def := def
	status = abi_check()
	if status != .Ok {return}
	status = c_world_create(&def, &world)
	return
}

world_destroy :: proc(world: ^World) -> Status {
	if world == nil {return .Invalid_Argument}
	status := c_world_destroy(world^)
	if status == .Ok {world^ = 0}
	return status
}

world_valid :: proc(world: World) -> (valid: bool, status: Status) {
	value: u32
	status = native_version_check(); if status != .Ok {return}
	status = c_world_valid(world, &value)
	valid = value != 0
	return
}

world_step :: proc(world: World, seconds: f32, substeps: u32) -> Status {
	if status := native_version_check(); status != .Ok {return status}
	return c_world_step(world, seconds, substeps)
}

world_step_fixed :: proc(world: World) -> Status {
	if status := native_version_check(); status != .Ok {return status}
	return c_world_step_fixed(world)
}

world_get_gravity :: proc(world: World) -> (gravity: Vec3, status: Status) {
	status = c_world_get_gravity(world, &gravity)
	return
}

world_set_gravity :: proc(world: World, gravity: Vec3) -> Status {
	gravity := gravity
	return c_world_set_gravity(world, &gravity)
}

// Process-wide Box3D allocator totals. Wrapper allocations and snapshot owner
// mallocs are excluded; these counters alone are not total backend memory.
engine_allocation_stats :: proc() -> (stats: Allocation_Stats, status: Status) {
	status = c_engine_allocation_stats(&stats)
	return
}

world_counters :: proc(world: World) -> (counts: World_Counters, status: Status) {
	status = native_version_check(); if status != .Ok {return}
	status = c_world_get_counters(world, &counts); return
}

ALPHA_INITIAL_DYNAMIC_BODIES :: 32
ALPHA_TOTAL_BODIES :: 35
ALPHA_SHAPES :: 35
ALPHA_CONTACTS :: 147
ALPHA_JOINTS :: 1
ALPHA_HISTORY_FRAMES :: 128
ALPHA_MAX_PREDICTION_TICKS :: 8
ALPHA_MAX_CORRECTION_TICKS :: 8
ALPHA_NORMAL_WORK_NS :: 4_000_000
ALPHA_CORRECTION_WORK_NS :: 4_000_000
ALPHA_RESOURCE_BYTES :: 64 * 1024 * 1024

Alpha_Request :: struct {
	initial_dynamic_bodies, history_frames, prediction_ticks, correction_ticks: u32,
	additional_owned_bytes, reserved_bytes, normal_work_ns, correction_work_ns: u64,
}
Alpha_Observation :: struct {
	counts:                                     World_Counters,
	engine, wrapper:                            Allocation_Stats,
	additional_owned_bytes, live_bytes:         u64,
	normal_work_ns, correction_work_ns:         u64,
	normal_over_target, correction_over_target: bool,
}
alpha_request_default :: proc() -> Alpha_Request {return{
		initial_dynamic_bodies = ALPHA_INITIAL_DYNAMIC_BODIES,
		history_frames = ALPHA_HISTORY_FRAMES,
	}}
// Process-global engine + snapshot wrapper requested live bytes. Additional
// game/history/staging allocations and future reservations must be explicit.
@(private)
alpha_memory_observe :: proc(
	additional_owned_bytes: u64,
) -> (
	observation: Alpha_Observation,
	status: Status,
) {
	status = native_version_check(); if status != .Ok {return}
	observation.engine, status = engine_allocation_stats(); if status != .Ok {return}
	observation.wrapper, status = snapshot_allocation_stats(); if status != .Ok {return}
	observation.additional_owned_bytes = additional_owned_bytes
	if observation.engine.live_bytes >
	   max(u64) - observation.wrapper.live_bytes {return observation, .Capacity}
	total := observation.engine.live_bytes + observation.wrapper.live_bytes
	if total > max(u64) - additional_owned_bytes {return observation, .Capacity}
	observation.live_bytes = total + additional_owned_bytes; return
}
// Detached checkpoints remain budgeted after every execution/provider is gone.
// Counts are zero because this observation has no associated live world.
alpha_memory_check :: proc(
	additional_owned_bytes: u64 = 0,
	reserved_bytes: u64 = 0,
) -> (
	observation: Alpha_Observation,
	status: Status,
) {
	observation, status = alpha_memory_observe(additional_owned_bytes); if status != .Ok {return}
	if observation.live_bytes > ALPHA_RESOURCE_BYTES ||
	   reserved_bytes >
		   ALPHA_RESOURCE_BYTES - observation.live_bytes {return observation, .Capacity}
	return
}
alpha_observe :: proc(
	world: World,
	additional_owned_bytes: u64 = 0,
) -> (
	observation: Alpha_Observation,
	status: Status,
) {
	counts, count_status := world_counters(world); if count_status != .Ok {return {}, count_status}
	observation, status = alpha_memory_observe(
		additional_owned_bytes,
	); observation.counts = counts; return
}
alpha_check :: proc(
	world: World,
	request: Alpha_Request,
) -> (
	observation: Alpha_Observation,
	status: Status,
) {
	observation, status = alpha_observe(
		world,
		request.additional_owned_bytes,
	); if status != .Ok {return}
	observation.normal_work_ns = request.normal_work_ns
	observation.correction_work_ns = request.correction_work_ns
	observation.normal_over_target = request.normal_work_ns > ALPHA_NORMAL_WORK_NS
	observation.correction_over_target = request.correction_work_ns > ALPHA_CORRECTION_WORK_NS
	c := observation.counts
	if request.initial_dynamic_bodies > ALPHA_INITIAL_DYNAMIC_BODIES ||
	   request.history_frames != ALPHA_HISTORY_FRAMES ||
	   request.prediction_ticks > ALPHA_MAX_PREDICTION_TICKS ||
	   request.correction_ticks > ALPHA_MAX_CORRECTION_TICKS ||
	   c.body_count > ALPHA_TOTAL_BODIES ||
	   c.shape_count > ALPHA_SHAPES ||
	   c.contact_count > ALPHA_CONTACTS ||
	   c.joint_count > ALPHA_JOINTS ||
	   observation.live_bytes > ALPHA_RESOURCE_BYTES ||
	   request.reserved_bytes >
		   ALPHA_RESOURCE_BYTES - observation.live_bytes {return observation, .Capacity}
	return
}
