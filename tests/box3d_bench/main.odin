package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:time"
import b3 "godot:box3d"

MAX_ENTITIES :: 520
EXTRA_ENTITIES :: 16

Game :: struct {
	tick: u64,
	rng, previous_buttons: u32,
	births, deaths, sensor_begins, sensor_ends, query_hits: u64,
	bodies: [MAX_ENTITIES]b3.Body,
	generation: [MAX_ENTITIES]u32,
	alive: [MAX_ENTITIES]bool,
}

Simulation :: struct {world: b3.World, joint: b3.Joint, game: Game, initial_bodies, history_frames: int}
History :: struct {tick: u64, valid: bool, game: Game, snapshot: b3.Snapshot, metrics: b3.Snapshot_Metrics, storage: b3.Snapshot_Storage}
Reference :: struct {tick: u64, valid: bool, dump: []u8, side_digest: u64, game: Game}
Counters :: struct {
	compared, rollbacks, replayed, branches, branch_compared: u64,
	min_depth, max_depth: int,
	snapshot_used_peak, snapshot_capacity_peak, geometry_sum_peak, reference_bytes_peak: u64,
	native_history_peak, wrapper_history_peak, normalized_cache_peak: u64,
	save_alloc_calls, restore_alloc_calls, step_alloc_calls: u64,
}

check :: proc(status: b3.Status) {
	if status != .Ok {panic(fmt.tprintf("Box3D status: %v", status))}
}
random :: proc(state: ^u32) -> u32 {
	x := state^; x ~= x << 13; x ~= x >> 17; x ~= x << 5; state^ = x; return x
}
sample :: proc(metric: string, ns: i64, phase: string) {fmt.printf("BOX3D_BENCH_SAMPLE metric=%s ns=%d phase=%s\n", metric, max(ns, 0), phase)}
forward_phase :: proc(sim: ^Simulation) -> string {
	return sim.game.tick == 0 ? "initial" : sim.game.tick < u64(sim.history_frames) ? "fill" : "steady"
}
allocations :: proc() -> b3.Allocation_Stats {value, status := b3.engine_allocation_stats(); check(status); return value}

spawn :: proc(sim: ^Simulation, slot: int, position: b3.Vec3, sphere := false) {
	assert(!sim.game.alive[slot])
	def := b3.body_def_default(); def.type = .Dynamic; def.pose.position = position
	body, status := b3.body_create(sim.world, def); check(status)
	shape_def := b3.shape_def_default(); shape_def.enable_sensor_events = 1
	shape: b3.Shape
	if sphere {shape, status = b3.shape_sphere(body, shape_def, 0.25)}
	else {shape, status = b3.shape_box(body, shape_def, {0.25, 0.25, 0.25})}
	check(status); assert(shape != 0)
	sim.game.bodies[slot] = body; sim.game.alive[slot] = true
	sim.game.generation[slot] += 1; sim.game.births += 1
}

create_simulation :: proc(bodies: int, seed: u32, history: int) -> Simulation {
	world, status := b3.world_create(b3.world_def_default()); check(status)
	sim := Simulation{world = world, initial_bodies = bodies, history_frames = history, game = {rng = seed}}
	static_def := b3.body_def_default()
	floor, floor_status := b3.body_create(world, static_def); check(floor_status)
	vertices := [?]b3.Vec3{{-7, 0, -7}, {7, 0, -7}, {7, 0, 7}, {-7, 0, 7}}
	indices := [?]u32{0, 2, 1, 0, 3, 2}
	geometry, geometry_status := b3.geometry_mesh(vertices[:], indices[:]); check(geometry_status)
	_, shape_status := b3.shape_geometry(floor, b3.shape_def_default(), &geometry); check(shape_status)
	check(b3.geometry_destroy(&geometry))
	static_def.pose.position = {0, 1, 0}
	sensor, sensor_status := b3.body_create(world, static_def); check(sensor_status)
	sensor_def := b3.shape_def_default(); sensor_def.is_sensor = 1; sensor_def.enable_sensor_events = 1
	_, sensor_shape_status := b3.shape_box(sensor, sensor_def, {1.5, 1, 1.5}); check(sensor_shape_status)
	for i in 0..<bodies {
		spawn(&sim, i, {f32(i % 5 - 2) * 0.6, 0.45 + f32(i / 25) * 0.55, f32(i / 5 % 5 - 2) * 0.6})
	}
	hinge_def := b3.hinge_def_default(); hinge_def.body_a = floor; hinge_def.body_b = sim.game.bodies[0]
	hinge_def.local_frame_a.position = {-1.2, 0.45, -1.2}
	hinge_def.enable_limit = 1; hinge_def.lower_angle = -0.5; hinge_def.upper_angle = 0.5
	hinge_def.enable_motor = 1; hinge_def.max_motor_torque = 2
	sim.joint, status = b3.joint_hinge_create(world, hinge_def); check(status)
	return sim
}

advance :: proc(sim: ^Simulation, counters: ^Counters = nil) {
	sim.game.tick += 1
	tick := sim.game.tick
	value := random(&sim.game.rng)
	sim.game.previous_buttons = value & 15
	selected := int(value % u32(sim.initial_bodies))
	if tick % 30 == 0 {
		check(b3.body_apply_impulse(sim.game.bodies[selected], {f32(i32(value % 7) - 3) * 0.1, 0.4, 0.1}))
	}
	if tick % 240 == 120 {check(b3.body_set_awake(sim.game.bodies[selected], false))}
	if tick % 240 == 121 {check(b3.body_set_awake(sim.game.bodies[selected], true))}
	if tick % 120 == 20 {
		slot := sim.initial_bodies + int(tick / 120 % EXTRA_ENTITIES)
		spawn(sim, slot, {0.1, 7, 0.1}, true)
	}
	if tick % 120 == 80 {
		slot := sim.initial_bodies + int(tick / 120 % EXTRA_ENTITIES)
		assert(sim.game.alive[slot]); check(b3.body_destroy(&sim.game.bodies[slot]))
		sim.game.alive[slot] = false; sim.game.deaths += 1
	}
	if tick % 300 == 0 {check(b3.joint_hinge_set_motor(sim.joint, true, tick / 300 % 2 == 0 ? 0.75 : -0.75, 2))}
	before: b3.Allocation_Stats
	if counters != nil {before = allocations()}
	started := time.tick_now(); check(b3.world_step_fixed(sim.world)); elapsed := i64(time.tick_since(started))
	if counters != nil {
		sample("step", elapsed, forward_phase(sim)); after := allocations(); counters.step_alloc_calls += after.total_calls - before.total_calls
	}
	events: [2048]b3.Sensor_Event
	count, event_status := b3.world_sensor_events(sim.world, events[:]); check(event_status)
	assert(count <= u32(len(events)))
	for event in events[:count] {
		if event.began != 0 {sim.game.sensor_begins += 1} else {sim.game.sensor_ends += 1}
	}
	if tick % 60 == 0 {
		hits: [MAX_ENTITIES + 8]b3.Shape
		available, query_status := b3.query_overlap_aabb(sim.world, {-2, 0, -2}, {2, 4, 2}, b3.QUERY_FILTER_ALL, hits[:]); check(query_status)
		sim.game.query_hits += u64(available)
		rays: [MAX_ENTITIES + 8]b3.Ray_Hit
		ray_count, ray_status := b3.query_ray(sim.world, {0, 12, 0}, {0, -20, 0}, b3.QUERY_FILTER_ALL, rays[:]); check(ray_status)
		sim.game.query_hits += u64(ray_count)
	}
}

fold :: proc(hash: ^u64, value: u64) {
	for shift in 0..<8 {hash^ = (hash^ ~ ((value >> uint(shift * 8)) & 255)) * 0x100000001b3}
}

game_digest :: proc(game: ^Game) -> u64 {
	hash := u64(0xcbf29ce484222325)
	values := [?]u64{game.tick, u64(game.rng), u64(game.previous_buttons), game.births, game.deaths, game.sensor_begins, game.sensor_ends, game.query_hits}
	for value in values {fold(&hash, value)}
	for live, slot in game.alive {
		fold(&hash, u64(slot)); fold(&hash, u64(live)); fold(&hash, u64(game.generation[slot]))
		if live {
			index, generation, status := b3.body_identity(game.bodies[slot]); check(status)
			fold(&hash, u64(index)); fold(&hash, u64(generation))
		}
	}
	return hash
}

dump :: proc(world: b3.World) -> []u8 {
	size, status := b3.world_dump(world, nil); check(status)
	assert(size > 0 && size <= 64 * 1024 * 1024)
	bytes := make([]u8, int(size))
	actual, result := b3.world_dump(world, bytes); check(result); assert(actual == size)
	return bytes
}

remember_reference :: proc(history: []Reference, sim: ^Simulation) {
	slot := &history[sim.game.tick % u64(len(history))]
	delete(slot.dump)
	slot^ = {tick = sim.game.tick, valid = true, dump = dump(sim.world), side_digest = game_digest(&sim.game), game = sim.game}
}

diagnostic_failure :: proc(expected_bytes, actual_bytes: []u8, expected_game, actual_game: ^Game, output, label: string, depth: int, head: u64) {
	assert(os.write_entire_file(fmt.tprintf("%s/%s-expected.bin", output, label), expected_bytes) == nil)
	assert(os.write_entire_file(fmt.tprintf("%s/%s-actual.bin", output, label), actual_bytes) == nil)
	assert(os.write_entire_file(fmt.tprintf("%s/%s-expected-game.local.bin", output, label), (cast([^]u8)expected_game)[:size_of(Game)]) == nil)
	assert(os.write_entire_file(fmt.tprintf("%s/%s-actual-game.local.bin", output, label), (cast([^]u8)actual_game)[:size_of(Game)]) == nil)
	// Historical reference handles may no longer be live at the current head.
	// Diagnostic output must not query them while explaining an earlier mismatch.
	details := fmt.tprintf("case=%s tick=%d expected_tick=%d head=%d rewind_depth=%d game_size=%d expected_rng=%d actual_rng=%d expected_births=%d actual_births=%d expected_deaths=%d actual_deaths=%d\n", label, actual_game.tick, expected_game.tick, head, depth, size_of(Game), expected_game.rng, actual_game.rng, expected_game.births, actual_game.births, expected_game.deaths, actual_game.deaths)
	assert(os.write_entire_file(fmt.tprintf("%s/%s-context.txt", output, label), transmute([]u8)details) == nil)
	fmt.eprintf("Box3D %s tick=%d head=%d depth=%d expected_bytes=%d actual_bytes=%d\n", label, actual_game.tick, head, depth, len(expected_bytes), len(actual_bytes))
	panic("complete solver/game-state check failed; diagnostic artifacts retained")
}

compare :: proc(history: []Reference, sim: ^Simulation, counters: ^Counters, output: string, replay := false, depth := 0, head: u64 = 0) {
	expected := &history[sim.game.tick % u64(len(history))]
	assert(expected.valid && expected.tick == sim.game.tick)
	started := time.tick_now(); actual := dump(sim.world); elapsed := i64(time.tick_since(started))
	defer delete(actual)
	sample("dump", elapsed, replay ? "replay" : forward_phase(sim))
	side := game_digest(&sim.game)
	if len(actual) != len(expected.dump) || mem.compare(actual, expected.dump) != 0 || side != expected.side_digest {
		diagnostic_failure(expected.dump, actual, &expected.game, &sim.game, output, replay ? "replay-mismatch" : "forward-mismatch", depth, head)
	}
	counters.compared += 1
}

remember :: proc(history: []History, sim: ^Simulation, counters: ^Counters, replay := false) -> i64 {
	before := allocations(); started := time.tick_now()
	snapshot, status := b3.snapshot_capture(sim.world); check(status)
	slot := &history[sim.game.tick % u64(len(history))]
	check(b3.snapshot_destroy(&slot.snapshot))
	slot^ = {tick = sim.game.tick, valid = true, game = sim.game, snapshot = snapshot}
	elapsed := i64(time.tick_since(started)); after := allocations()
	sample("save", elapsed, replay ? "replay" : forward_phase(sim)); counters.save_alloc_calls += after.total_calls - before.total_calls
	metrics, metrics_status := b3.snapshot_metrics(&snapshot); check(metrics_status); slot.metrics = metrics
	storage, storage_status := b3.snapshot_storage(&snapshot); check(storage_status); slot.storage = storage
	used, capacity, geometry, native_bytes, wrapper_bytes, normalized: u64
	for frame in history {if frame.valid {
		used += frame.metrics.image_used; capacity += frame.metrics.image_capacity; geometry += frame.metrics.geometry_bytes
		native_bytes += frame.storage.native_requested_bytes; wrapper_bytes += frame.storage.wrapper_malloc_bytes; normalized += frame.storage.normalized_bytes
	}}
	counters.snapshot_used_peak = max(counters.snapshot_used_peak, used)
	counters.snapshot_capacity_peak = max(counters.snapshot_capacity_peak, capacity)
	counters.geometry_sum_peak = max(counters.geometry_sum_peak, geometry)
	counters.native_history_peak = max(counters.native_history_peak, native_bytes)
	counters.wrapper_history_peak = max(counters.wrapper_history_peak, wrapper_bytes)
	counters.normalized_cache_peak = max(counters.normalized_cache_peak, normalized)
	return elapsed
}

restore :: proc(sim: ^Simulation, frame: ^History, counters: ^Counters, branch := false) {
	assert(frame.valid)
	before := allocations(); started := time.tick_now()
	check(b3.snapshot_restore(sim.world, &frame.snapshot))
	elapsed := i64(time.tick_since(started)); after := allocations()
	sim.game = frame.game
	sample("restore", elapsed, branch ? "branch" : "replay"); counters.restore_alloc_calls += after.total_calls - before.total_calls
}

branch_check :: proc(candidate: ^Simulation, frame: ^History, reference: []Reference, counters: ^Counters, output: string, depth: int, head: u64) {
	advance(candidate)
	check(b3.body_apply_impulse(candidate.game.bodies[0], {0, 0.125, 0}))
	branch_game := candidate.game
	branch_dump := dump(candidate.world); defer delete(branch_dump)
	expected := &reference[candidate.game.tick % u64(len(reference))]
	if len(branch_dump) == len(expected.dump) && mem.compare(branch_dump, expected.dump) == 0 {
		diagnostic_failure(expected.dump, branch_dump, &expected.game, &branch_game, output, "branch-not-distinct", depth, head)
	}
	branch, branch_status := b3.snapshot_capture(candidate.world); check(branch_status)
	clone, clone_status := b3.snapshot_clone(&branch); check(clone_status)
	check(b3.snapshot_destroy(&branch))
	// Move to a distinct state before clone restore; a no-op restore must fail.
	restore(candidate, frame, counters, true)
	check(b3.snapshot_restore(candidate.world, &clone)); candidate.game = branch_game
	actual := dump(candidate.world)
	if len(actual) != len(branch_dump) || mem.compare(actual, branch_dump) != 0 || game_digest(&candidate.game) != game_digest(&branch_game) {
		diagnostic_failure(branch_dump, actual, &branch_game, &candidate.game, output, "branch-roundtrip", depth, head)
	}
	delete(actual); counters.branch_compared += 1
	// Resume the same branch in another execution world and compare its next tick.
	world, world_status := b3.world_create(b3.world_def_default()); check(world_status)
	oracle := Simulation{world = world, game = branch_game, initial_bodies = candidate.initial_bodies, history_frames = candidate.history_frames}
	check(b3.snapshot_restore(oracle.world, &clone))
	for live, slot in oracle.game.alive {
		if live {body, status := b3.body_retarget(oracle.world, oracle.game.bodies[slot]); check(status); oracle.game.bodies[slot] = body}
	}
	joint, joint_status := b3.joint_retarget(oracle.world, candidate.joint); check(joint_status); oracle.joint = joint
	check(b3.snapshot_destroy(&clone))
	advance(candidate); advance(&oracle)
	left := dump(candidate.world); right := dump(oracle.world)
	if len(left) != len(right) || mem.compare(left, right) != 0 || game_digest(&candidate.game) != game_digest(&oracle.game) {
		diagnostic_failure(right, left, &oracle.game, &candidate.game, output, "branch-nextstep", depth, head)
	}
	delete(left); delete(right); check(b3.world_destroy(&oracle.world))
	counters.branch_compared += 1
	restore(candidate, frame, counters, true)
}

number :: proc(index: int) -> u64 {value, ok := strconv.parse_uint(os.args[index]); assert(ok); return u64(value)}

main :: proc() {
	assert(len(os.args) == 7, "bodies seed ticks history rewind_max output_dir")
	bodies, seed, ticks, capacity, max_rewind := int(number(1)), u32(number(2)), int(number(3)), int(number(4)), int(number(5))
	assert(bodies > 0 && bodies <= 500 && capacity > max_rewind + 1 && max_rewind >= 1 && max_rewind <= 30 && ticks >= 64 && seed != 0)
	output := os.args[6]
	assert(b3.abi_check() == .Ok)
	fmt.printf("BOX3D_BENCH_META bodies=%d seed=%d ticks=%d history=%d rewind_max=%d hz=60 substeps=4 dump_version=%d coverage=%s\n", bodies, seed, ticks, capacity, max_rewind, b3.state_version(), b3.state_coverage())
	baseline := create_simulation(bodies, seed, capacity); defer check(b3.world_destroy(&baseline.world))
	candidate := create_simulation(bodies, seed, capacity); defer check(b3.world_destroy(&candidate.world))
	retained := make([]History, capacity); defer {for &frame in retained {check(b3.snapshot_destroy(&frame.snapshot))}; delete(retained)}
	reference := make([]Reference, capacity); defer {for frame in reference {delete(frame.dump)}; delete(reference)}
	counters := Counters{min_depth = max(int)}
	remember_reference(reference, &baseline); remember(retained, &candidate, &counters)
	compare(reference, &candidate, &counters, output)
	rewind_rng := seed ~ 0x9e3779b9; if rewind_rng == 0 {rewind_rng = 1}
	for tick in 1..=ticks {
		advance(&baseline); remember_reference(reference, &baseline)
		advance(&candidate, &counters); compare(reference, &candidate, &counters, output)
		remember(retained, &candidate, &counters)
		bytes: u64; for frame in reference {bytes += u64(len(frame.dump))}; counters.reference_bytes_peak = max(counters.reference_bytes_peak, bytes)
		if tick % 32 != 0 {continue}
		depth := counters.rollbacks % 8 == 0 ? 1 : counters.rollbacks % 8 == 1 ? max_rewind : int(random(&rewind_rng) % u32(max_rewind)) + 1
		counters.min_depth = min(counters.min_depth, depth); counters.max_depth = max(counters.max_depth, depth)
		base := u64(tick - depth); frame := &retained[base % u64(capacity)]
		assert(frame.valid && frame.tick == base)
		checked_started := time.tick_now()
		restore(&candidate, frame, &counters)
		if counters.rollbacks % 4 == 0 {
			branch_check(&candidate, frame, reference, &counters, output, depth, u64(tick))
			counters.branches += 1
		}
		replay_ns := i64(0)
		for _ in 0..<depth {
			started := time.tick_now(); advance(&candidate); replay_ns += i64(time.tick_since(started))
			compare(reference, &candidate, &counters, output, true, depth, u64(tick))
			replay_ns += remember(retained, &candidate, &counters, true)
			counters.replayed += 1
		}
		checked_ns := i64(time.tick_since(checked_started))
		branching := counters.rollbacks % 4 == 0
		sample("replay", replay_ns, "replay"); sample("checked_rewind", checked_ns, branching ? "branch" : "replay")
		fmt.printf("BOX3D_BENCH_REWIND tick=%d depth=%d branch=%d\n", tick, depth, u32(branching))
		counters.rollbacks += 1
	}
	final, final_status := b3.world_digests(candidate.world); check(final_status)
	stats := allocations()
	wrappers, wrapper_status := b3.snapshot_allocation_stats(); check(wrapper_status)
	fmt.printf("BOX3D_BENCH_CHECK compared=%d rollbacks=%d replayed=%d branches=%d branch_compared=%d mismatches=0 min_depth=%d max_depth=%d final_solver_digest=%d final_side_digest=%d\n", counters.compared, counters.rollbacks, counters.replayed, counters.branches, counters.branch_compared, counters.min_depth, counters.max_depth, final.complete_solver_digest, game_digest(&candidate.game))
	fmt.printf("BOX3D_BENCH_MEMORY snapshot_used_peak=%d snapshot_capacity_peak=%d geometry_bytes_sum_peak=%d baseline_dump_bytes_peak=%d side_history_bytes=%d engine_live_bytes=%d engine_high_water_bytes=%d native_history_requested_peak=%d wrapper_history_peak=%d normalized_cache_peak=%d wrapper_live_bytes=%d wrapper_high_water_bytes=%d history_metadata_bytes=%d reference_metadata_bytes=%d fixed_simulation_bytes=%d\n", counters.snapshot_used_peak, counters.snapshot_capacity_peak, counters.geometry_sum_peak, counters.reference_bytes_peak, u64(capacity * size_of(Game)), stats.live_bytes, stats.high_water_bytes, counters.native_history_peak, counters.wrapper_history_peak, counters.normalized_cache_peak, wrappers.live_bytes, wrappers.high_water_bytes, u64(capacity * (size_of(History) - size_of(Game))), u64(capacity * size_of(Reference)), 3 * size_of(Simulation))
	fmt.printf("BOX3D_BENCH_ALLOCATIONS engine_total_calls=%d engine_total_bytes=%d save_calls=%d restore_calls=%d step_calls=%d wrapper_total_calls=%d wrapper_total_bytes=%d\n", stats.total_calls, stats.total_bytes, counters.save_alloc_calls, counters.restore_alloc_calls, counters.step_alloc_calls, wrappers.total_calls, wrappers.total_bytes)
	fmt.println("BOX3D_BENCH_DONE ok=1")
}
