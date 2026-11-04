package box3d_test

import "core:slice"
import "core:testing"
import b "godot:box3d"

ok :: proc(t: ^testing.T, status: b.Status) {testing.expect_value(t, status, b.Status.Ok)}
new_world :: proc(t: ^testing.T) -> b.World {world, status := b.world_create(b.world_def_default())
	ok(t, status)
	return world}
new_box :: proc(t: ^testing.T, world: b.World, y: f32) -> b.Body {
	def := b.body_def_default(); def.type = .Dynamic; def.pose.position = {0, y, 0}
	body, status := b.body_create(world, def); ok(t, status)
	_, status = b.shape_box(body, b.shape_def_default(), {0.5, 0.5, 0.5}); ok(t, status)
	return body
}
dump :: proc(t: ^testing.T, world: b.World) -> []u8 {
	n, status := b.world_dump(
		world,
		nil,
	); ok(t, status); bytes := make([]u8, int(n)); actual, fill_status := b.world_dump(world, bytes); ok(t, fill_status); testing.expect_value(t, n, actual); return bytes
}

@(test)
owned_snapshot_survives_source_and_owner_destruction :: proc(t: ^testing.T) {
	source := new_world(t); body := new_box(t, source, 4)
	for _ in 0 ..< 30 {ok(t, b.world_step_fixed(source))}
	snapshot, captured_info, status := b.snapshot_capture_info(source); ok(t, status)
	clone, cloned_info, clone_status := b.snapshot_clone_info(&snapshot); ok(t, clone_status)
	testing.expect_value(t, captured_info, cloned_info)
	expected := dump(t, source); defer delete(expected)
	metrics, metrics_status := b.snapshot_metrics(&snapshot); ok(t, metrics_status)
	storage, storage_status := b.snapshot_storage(&snapshot); ok(t, storage_status)
	info, info_status := b.snapshot_info(&snapshot); ok(t, info_status)
	testing.expect_value(t, info, captured_info)
	testing.expect_value(t, info.metrics, metrics); testing.expect_value(t, info.storage, storage)

	testing.expect(
		t,
		metrics.image_used > 0 &&
		metrics.image_capacity >= metrics.image_used &&
		metrics.geometry_bytes > 0 &&
		metrics.geometry_count > 0,
	)
	snapshot_digests, digest_status := b.snapshot_digests(&snapshot); ok(t, digest_status)
	destination := new_world(t); defer b.world_destroy(&destination)
	ok(t, b.snapshot_restore(destination, &snapshot))
	ok(t, b.world_destroy(&source)); ok(t, b.snapshot_destroy(&snapshot))
	detached, detached_status := b.snapshot_info(&clone); ok(t, detached_status)
	testing.expect_value(t, detached, info)
	ok(t, b.snapshot_restore(destination, &clone)); ok(t, b.snapshot_destroy(&clone))
	actual := dump(
		t,
		destination,
	); defer delete(actual); testing.expect(t, slice.equal(expected, actual))
	digests, world_digest_status := b.world_digests(destination); ok(t, world_digest_status)
	testing.expect_value(
		t,
		digests.complete_solver_digest,
		snapshot_digests.complete_solver_digest,
	)
	testing.expect_value(t, digests.motion_digest, snapshot_digests.motion_digest)
	ok(t, b.world_step_fixed(destination))
	valid, valid_status := b.body_valid(body); ok(t, valid_status); testing.expect(t, !valid)
	testing.expect(t, b.snapshot_is_empty(&snapshot) && b.snapshot_is_empty(&clone))
	ok(t, b.snapshot_destroy(&clone))
}

@(test)
restore_reuses_future_handle_and_clears_events :: proc(t: ^testing.T) {
	world := new_world(t); defer b.world_destroy(&world)
	new_box(t, world, 3)
	snapshot, status := b.snapshot_capture(
		world,
	); ok(t, status); defer b.snapshot_destroy(&snapshot)
	future := new_box(t, world, 8)
	ok(t, b.world_step_fixed(world)); ok(t, b.snapshot_restore(world, &snapshot))
	valid, valid_status := b.body_valid(future); ok(t, valid_status); testing.expect(t, !valid)
	replacement := new_box(t, world, 10); testing.expect_value(t, replacement, future)
	ok(t, b.snapshot_restore(world, &snapshot))
	_, event_status := b.world_sensor_events(
		world,
		nil,
	); testing.expect(t, event_status == .Ok || event_status == .Capacity)
}

@(test)
complete_digest_detects_gravity_with_equal_motion :: proc(t: ^testing.T) {
	world := new_world(t); defer b.world_destroy(&world); new_box(t, world, 4)
	before, status := b.world_digests(world); ok(t, status)
	gravity, gravity_status := b.world_get_gravity(world); ok(t, gravity_status); gravity.y -= 1
	ok(t, b.world_set_gravity(world, gravity))
	after, after_status := b.world_digests(world); ok(t, after_status)
	testing.expect(t, before.complete_solver_digest != after.complete_solver_digest)
	testing.expect_value(t, before.motion_digest, after.motion_digest)
	testing.expect_value(t, b.state_version(), u32(b.STATE_DUMP_VERSION))
}

@(test)
independent_world_bytes_match_and_insufficient_dump_does_not_write :: proc(t: ^testing.T) {
	a := new_world(t); defer b.world_destroy(&a); new_box(t, a, 5)
	c := new_world(t); defer b.world_destroy(&c); new_box(t, c, 5)
	for _ in 0 ..< 90 {
		ok(t, b.world_step_fixed(a)); ok(t, b.world_step_fixed(c))
		aa := dump(
			t,
			a,
		); cc := dump(t, c); testing.expect(t, slice.equal(aa, cc)); delete(aa); delete(cc)
	}
	n, status := b.world_dump(
		a,
		nil,
	); ok(t, status); short := make([]u8, int(n) - 1); defer delete(short)
	for &v in short {v = 0xa5}
	required, short_status := b.world_dump(
		a,
		short,
	); testing.expect_value(t, short_status, b.Status.Capacity); testing.expect_value(t, required, n)
	for v in short {testing.expect_value(t, v, u8(0xa5))}
}

@(test)
owned_allocation_domain_includes_leases_and_digest_temporaries :: proc(t: ^testing.T) {
	before, status := b.snapshot_allocation_stats(); ok(t, status)
	world := new_world(t); new_box(t, world, 3)
	snapshot, capture_status := b.snapshot_capture(world); ok(t, capture_status)
	retained, retained_status := b.snapshot_allocation_stats(); ok(t, retained_status)
	testing.expect(t, retained.live_bytes > before.live_bytes)
	clone, clone_status := b.snapshot_clone(&snapshot); ok(t, clone_status)
	destination := new_world(t); ok(t, b.snapshot_restore(destination, &clone))
	_, digest_status := b.world_digests(destination); ok(t, digest_status)
	peak, peak_status := b.snapshot_allocation_stats(); ok(t, peak_status)
	testing.expect(t, peak.total_calls >= retained.total_calls + 3)
	testing.expect(
		t,
		peak.total_bytes > retained.total_bytes && peak.high_water_bytes >= peak.live_bytes,
	)
	ok(
		t,
		b.snapshot_destroy(&clone),
	); ok(t, b.snapshot_destroy(&snapshot)); ok(t, b.world_destroy(&world))
	leased, leased_status := b.snapshot_allocation_stats(
		
	); ok(t, leased_status); testing.expect(t, leased.live_bytes > before.live_bytes)
	ok(t, b.world_destroy(&destination))
	after, after_status := b.snapshot_allocation_stats(
		
	); ok(t, after_status); testing.expect_value(t, after.live_bytes, before.live_bytes)
}

@(test)
world_keys_historical_cache_and_stage_ownership :: proc(t: ^testing.T) {
	source := new_world(t); body := new_box(t, source, 5)
	key, status := b.body_key(body); ok(t, status)
	snapshot, capture_status := b.snapshot_capture(source); ok(t, capture_status)
	clone, clone_status := b.snapshot_clone(&snapshot); ok(t, clone_status)
	state, read_status := b.snapshot_body_state(
		&snapshot,
		key,
	); ok(t, read_status); testing.expect_value(t, state.pose.position.y, f32(5))
	n, size_status := b.snapshot_body_states(
		&snapshot,
		nil,
	); ok(t, size_status); testing.expect_value(t, n, u32(1))
	ok(t, b.world_destroy(&source)); ok(t, b.snapshot_destroy(&snapshot))
	state, read_status = b.snapshot_body_state(
		&clone,
		key,
	); ok(t, read_status); testing.expect_value(t, state.key, key)
	published := new_world(t); new_box(t, published, 12); old_world := published
	stage, open_status := b.stage_open(&clone); ok(t, open_status)
	execution, execution_status := b.stage_world(&stage); ok(t, execution_status)
	resolved, resolve_status := b.body_resolve(execution, key); ok(t, resolve_status)
	pose, pose_status := b.body_get_pose(
		resolved,
	); ok(t, pose_status); testing.expect_value(t, pose.position.y, f32(5))
	ok(
		t,
		b.snapshot_destroy(&clone),
	); ok(t, b.stage_swap(&published, &stage)); testing.expect_value(t, stage.world, old_world)
	ok(
		t,
		b.stage_discard(&stage),
	); ok(t, b.stage_discard(&stage)); ok(t, b.world_step_fixed(published)); ok(t, b.world_destroy(&published))
	stats, stats_status := b.snapshot_allocation_stats(
		
	); ok(t, stats_status); testing.expect_value(t, stats.live_bytes, u64(0))
}

@(test)
alpha_envelope_requires_explicit_ages_time_memory_and_actual_counts :: proc(t: ^testing.T) {
	world := new_world(t); defer b.world_destroy(&world); new_box(t, world, 5)
	request := b.alpha_request_default(
		
	); observation, status := b.alpha_check(world, request); ok(t, status); testing.expect_value(t, observation.counts.body_count, u32(1))
	request.prediction_ticks = 8; request.correction_ticks = 8; request.normal_work_ns = b.ALPHA_NORMAL_WORK_NS; request.correction_work_ns = b.ALPHA_CORRECTION_WORK_NS
	_, status = b.alpha_check(world, request); ok(t, status)
	request.prediction_ticks = 9; _, status = b.alpha_check(world, request); testing.expect_value(t, status, b.Status.Capacity)
	request = b.alpha_request_default(
		
	); request.correction_ticks = 9; _, status = b.alpha_check(world, request); testing.expect_value(t, status, b.Status.Capacity)
	request = b.alpha_request_default(
		
	); request.history_frames = 127; _, status = b.alpha_check(world, request); testing.expect_value(t, status, b.Status.Capacity)
	request = b.alpha_request_default(); request.normal_work_ns = b.ALPHA_NORMAL_WORK_NS + 1
	timed, timed_status := b.alpha_check(world, request); ok(t, timed_status)
	testing.expect(t, timed.normal_over_target && !timed.correction_over_target)
	request = b.alpha_request_default(
		
	); request.correction_work_ns = b.ALPHA_CORRECTION_WORK_NS + 1
	corrected, corrected_status := b.alpha_check(world, request); ok(t, corrected_status)
	testing.expect(t, corrected.correction_over_target && !corrected.normal_over_target)
	request = b.alpha_request_default(
		
	); request.initial_dynamic_bodies = 33; _, status = b.alpha_check(world, request); testing.expect_value(t, status, b.Status.Capacity)
	request = b.alpha_request_default(
		
	); request.additional_owned_bytes = max(u64); _, status = b.alpha_check(world, request); testing.expect_value(t, status, b.Status.Capacity)
	request = b.alpha_request_default(
		
	); request.reserved_bytes = u64(b.ALPHA_RESOURCE_BYTES) - observation.live_bytes; _, status = b.alpha_check(world, request); ok(t, status)
	request.reserved_bytes += 1; _, status = b.alpha_check(world, request); testing.expect_value(t, status, b.Status.Capacity)
	for _ in 0 ..< 35 {def := b.body_def_default(); def.type = .Dynamic; _, body_status := b.body_create(world, def); ok(t, body_status)}
	request = b.alpha_request_default(
		
	); _, status = b.alpha_check(world, request); testing.expect_value(t, status, b.Status.Capacity)
}

@(test)
detached_images_remain_budgeted_without_execution_world :: proc(t: ^testing.T) {
	world := new_world(t); new_box(t, world, 4)
	snapshot, status := b.snapshot_capture(world); ok(t, status)
	ok(t, b.world_destroy(&world))
	observed, observe_status := b.alpha_memory_check(); ok(t, observe_status)
	testing.expect(
		t,
		observed.live_bytes > 0,
	); testing.expect_value(t, observed.counts.body_count, u32(0))
	_, overflow_status := b.alpha_memory_check(
		max(u64),
	); testing.expect_value(t, overflow_status, b.Status.Capacity)
	_, reserve_status := b.alpha_memory_check(
		0,
		u64(b.ALPHA_RESOURCE_BYTES) - observed.live_bytes + 1,
	); testing.expect_value(t, reserve_status, b.Status.Capacity)
	clone, clone_status := b.snapshot_clone(&snapshot); ok(t, clone_status)
	ok(t, b.snapshot_destroy(&snapshot)); ok(t, b.snapshot_destroy(&clone))
	after, after_status := b.alpha_memory_check(
		
	); ok(t, after_status); testing.expect_value(t, after.live_bytes, u64(0))
}

@(test)
retired_sensor_shape_ids_decode_without_claiming_liveness :: proc(t: ^testing.T) {
	world := new_world(t); body := new_box(t, world, 5)
	shape, status := b.shape_sphere(body, b.shape_def_default(), .25); ok(t, status)
	key, key_status := b.shape_key(shape); ok(t, key_status); retired := shape
	ok(
		t,
		b.shape_destroy(&shape),
	); _, live_status := b.shape_key(retired); testing.expect_value(t, live_status, b.Status.Invalid_Handle)
	ok(t, b.world_destroy(&world))
	decoded, decode_status := b.shape_key_from_handle(
		retired,
	); ok(t, decode_status); testing.expect_value(t, decoded, key)
}

@(test)
post_step_destroyed_sensor_delivers_pending_end_once_after_restore :: proc(t: ^testing.T) {
	def := b.world_def_default(); def.gravity = {0, 0, 0}
	source, status := b.world_create(def); ok(t, status)
	body_def := b.body_def_default(
		
	); sensor, sensor_status := b.body_create(source, body_def); ok(t, sensor_status)
	shape_def := b.shape_def_default(); shape_def.is_sensor = 1; shape_def.enable_sensor_events = 1
	sensor_shape, sensor_shape_status := b.shape_box(
		sensor,
		shape_def,
		{1, 1, 1},
	); ok(t, sensor_shape_status)
	sensor_key, sensor_key_status := b.shape_key(sensor_shape); ok(t, sensor_key_status)
	body_def.type = .Dynamic; visitor, visitor_status := b.body_create(source, body_def); ok(t, visitor_status)
	shape_def.is_sensor = 0; visitor_shape, visitor_shape_status := b.shape_sphere(visitor, shape_def, .25); ok(t, visitor_shape_status)
	visitor_key, visitor_key_status := b.shape_key(visitor_shape); ok(t, visitor_key_status)
	ok(t, b.world_step_fixed(source)); ok(t, b.body_destroy(&sensor))
	snapshot, capture_status := b.snapshot_capture(source); ok(t, capture_status)
	clone, clone_status := b.snapshot_clone(&snapshot); ok(t, clone_status)
	ok(t, b.world_step_fixed(source)); events: [8]b.Sensor_Event
	count, events_status := b.world_sensor_events(
		source,
		events[:],
	); ok(t, events_status); testing.expect_value(t, count, u32(1)); testing.expect_value(t, events[0].began, u32(0))
	ok(t, b.world_destroy(&source)); ok(t, b.snapshot_destroy(&snapshot))
	restored, restored_status := b.world_create(
		def,
	); ok(t, restored_status); defer b.world_destroy(&restored)
	ok(t, b.snapshot_restore(restored, &clone)); ok(t, b.snapshot_destroy(&clone))
	before, before_status := b.world_sensor_events(
		restored,
		events[:],
	); ok(t, before_status); testing.expect_value(t, before, u32(0))
	ok(
		t,
		b.world_step_fixed(restored),
	); after, after_status := b.world_sensor_events(restored, events[:]); ok(t, after_status); testing.expect_value(t, after, u32(1)); testing.expect_value(t, events[0].began, u32(0))
	actual_sensor, decode_sensor_status := b.shape_key_from_handle(
		events[0].sensor,
	); ok(t, decode_sensor_status); testing.expect_value(t, actual_sensor, sensor_key)
	actual_visitor, decode_visitor_status := b.shape_key_from_handle(
		events[0].visitor,
	); ok(t, decode_visitor_status); testing.expect_value(t, actual_visitor, visitor_key)
	ok(
		t,
		b.world_step_fixed(restored),
	); next, next_status := b.world_sensor_events(restored, events[:]); ok(t, next_status); testing.expect_value(t, next, u32(0))
}

@(test)
atomic_snapshot_info_default_and_invalid_constructors :: proc(t: ^testing.T) {
	world := new_world(t); defer b.world_destroy(&world)
	snapshot, info, status := b.snapshot_capture_info(
		world,
	); ok(t, status); defer b.snapshot_destroy(&snapshot)
	checked, cs := b.snapshot_info(&snapshot); ok(t, cs); testing.expect_value(t, checked, info)
	invalid, invalid_info, is := b.snapshot_capture_info(
		b.World(0),
	); testing.expect_value(t, is, b.Status.Invalid_Handle); testing.expect(t, b.snapshot_is_empty(&invalid)); testing.expect_value(t, invalid_info, b.Snapshot_Info{})
	clone, clone_info, cst := b.snapshot_clone_info(
		nil,
	); testing.expect_value(t, cst, b.Status.Invalid_Argument); testing.expect(t, b.snapshot_is_empty(&clone)); testing.expect_value(t, clone_info, b.Snapshot_Info{})
}
