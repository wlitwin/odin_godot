package framework_tests

import "core:mem"
import "core:testing"
import b3 "godot:box3d"
import r "godot:replay"
import ph "godot:replay/physics"
import model "godot:tests/box3d_framework/model"

Replay_Timeline :: r.Timeline(model.State, model.Control, model.Event)
Replay_Checkpoint :: r.Complete_Checkpoint(model.State, model.Event)

replay_operations :: proc(capability: ^r.Execution) -> model.Operations {
	return {
		user = capability,
		spawn = proc(user: rawptr, position: b3.Vec3) -> (b3.Body_Key, bool) {
			def := b3.body_def_default(); def.type = .Dynamic; def.pose.position = position
			key, error := ph.spawn((cast(^r.Execution)user)^, 2, def)
			return key, error == .None
		},
		remove = proc(user: rawptr, key: b3.Body_Key) -> bool {
			return ph.body_destroy((cast(^r.Execution)user)^, key) == .None
		},
		impulse = proc(user: rawptr, key: b3.Body_Key, amount: b3.Vec3) -> bool {
			return ph.body_impulse((cast(^r.Execution)user)^, key, amount) == .None
		},
		pose = proc(user: rawptr, key: b3.Body_Key) -> (b3.Pose, bool) {
			value, error := ph.body_pose((cast(^r.Execution)user)^, key)
			return value, error == .None
		},
	}
}

replay_step :: proc(state: ^model.State, input: model.Control, ctx: ^r.Step(model.Event)) {
	operations := replay_operations(&ctx.execution)
	events, valid := model.apply(state, input, operations)
	if !valid || ph.step(ctx.execution) != .None || !model.settle(state, operations) {
		r.abort(ctx); return
	}
	for event in events.values[:events.count] {r.emit(ctx, 1, model.event_key(event), event)}
	if input.abort_after {r.abort(ctx)}
}

replay_config :: proc() -> ph.Config {
	config := ph.config_default(0x4652414d45573231, 1)
	config.initial_dynamic_bodies = 1
	config.assets[1].radius = 0.2
	return config
}

replay_capture :: proc(t: ^testing.T, timeline: ^Replay_Timeline, tick: u64) -> Replay_Checkpoint {
	checkpoint, error := r.capture_complete(timeline, tick)
	testing.expect_value(t, error, r.Error.None)
	return checkpoint
}

replay_bytes :: proc(checkpoint: ^Replay_Checkpoint) -> []u8 {
	count, error := ph.dump(checkpoint, nil); assert(error == .None)
	bytes := make([]u8, int(count))
	written, result := ph.dump(checkpoint, bytes); assert(result == .None && written == count)
	return bytes
}

replay_matches_reference :: proc(t: ^testing.T, timeline: ^Replay_Timeline, world: b3.World, state: model.State) {
	values, found := r.current_values(timeline)
	testing.expect(t, found)
	testing.expect_value(t, values.state, state)
	checkpoint := replay_capture(t, timeline, values.tick)
	defer r.complete_checkpoint_destroy(&checkpoint)
	actual := replay_bytes(&checkpoint); defer delete(actual)
	expected := model.solver_bytes(world); defer delete(expected)
	testing.expect(t, len(actual) == len(expected) && mem.compare(actual, expected) == 0,
		"managed solver and typed game state match an independent world")
	pose, pose_error := ph.body_state(&checkpoint, state.actor)
	testing.expect_value(t, pose_error, r.Error.None)
	testing.expect_value(t, pose.pose.position.y, state.last_y)
}

@(test)
replay_real_physics_revision_abort_wrap_and_detached_resume :: proc(t: ^testing.T) {
	source, initial := model.initial()
	checkpoint, error := ph.checkpoint_make(r.Frame(model.State){state = initial}, model.Event, source, replay_config())
	testing.expect_value(t, error, r.Error.None)
	model.must(b3.world_destroy(&source))
	timeline: Replay_Timeline
	testing.expect_value(t, r.init_complete(&timeline, &checkpoint, replay_step, {128, 4}), r.Error.None)
	r.complete_checkpoint_destroy(&checkpoint)
	reference, reference_state := model.initial()
	raw_four: b3.Snapshot
	state_four: model.State
	saved_four: Replay_Checkpoint
	for tick in u64(1)..=8 {
		input := model.control_at(tick)
		_, valid := model.step(&reference_state, input, reference); testing.expect(t, valid)
		testing.expect_value(t, r.advance(&timeline, input).error, r.Error.None)
		replay_matches_reference(t, &timeline, reference, reference_state)
		if tick == 4 {
			status: b3.Status
			raw_four, status = b3.snapshot_capture(reference); model.must(status)
			state_four = reference_state
			saved_four = replay_capture(t, &timeline, 4)
		}
	}

	// Change an old accepted control and independently reconstruct its suffix.
	changed := model.control_at(5); changed.push = 2
	testing.expect_value(t, r.revise_input(&timeline, 5, changed).error, r.Error.None)
	model.must(b3.snapshot_restore(reference, &raw_four)); reference_state = state_four
	for tick in u64(5)..=8 {
		_, valid := model.step(&reference_state, tick == 5 ? changed : model.control_at(tick), reference)
		testing.expect(t, valid)
	}
	replay_matches_reference(t, &timeline, reference, reference_state)
	testing.expect_value(t, r.confirm_through(&timeline, 8), r.Error.None)

	before := replay_capture(t, &timeline, 8)
	before_bytes := replay_bytes(&before)
	failed := r.advance(&timeline, model.Control{push = 1, spawn = true, abort_after = true})
	testing.expect_value(t, failed.error, r.Error.Aborted)
	testing.expect_value(t, timeline.head, u64(8))
	after := replay_capture(t, &timeline, 8)
	after_bytes := replay_bytes(&after)
	testing.expect_value(t, after.frame.state, before.frame.state)
	testing.expect(t, mem.compare(before_bytes, after_bytes) == 0)
	delete(before_bytes); delete(after_bytes)
	r.complete_checkpoint_destroy(&before); r.complete_checkpoint_destroy(&after)

	for tick in u64(9)..=150 {
		input := model.control_at(tick)
		_, valid := model.step(&reference_state, input, reference); testing.expect(t, valid)
		testing.expect_value(t, r.advance(&timeline, input).error, r.Error.None)
		testing.expect_value(t, r.confirm_through(&timeline, tick), r.Error.None)
	}
	replay_matches_reference(t, &timeline, reference, reference_state)
	_, retained := r.read_values(&timeline, 1); testing.expect(t, !retained)
	r.destroy(&timeline)
	model.must(b3.world_destroy(&reference))

	// Exported complete state remains usable after original runtime/world death.
	detached, clone_error := r.complete_checkpoint_clone(&saved_four)
	testing.expect_value(t, clone_error, r.Error.None)
	r.complete_checkpoint_destroy(&saved_four)
	testing.expect_value(t, r.init_complete(&timeline, &detached, replay_step, {128, 4}), r.Error.None)
	testing.expect_value(t, r.advance(&timeline, model.control_at(5)).error, r.Error.None)
	values, found := r.current_values(&timeline)
	testing.expect(t, found && values.tick == 5 && values.state.tick == 5)
	r.destroy(&timeline); r.complete_checkpoint_destroy(&detached)
	model.must(b3.snapshot_destroy(&raw_four))

	engine, engine_status := b3.engine_allocation_stats()
	wrapper, wrapper_status := b3.snapshot_allocation_stats()
	testing.expect_value(t, engine_status, b3.Status.Ok)
	testing.expect_value(t, wrapper_status, b3.Status.Ok)
	testing.expect_value(t, engine.live_bytes, u64(0))
	testing.expect_value(t, wrapper.live_bytes, u64(0))
	testing.expect_value(t, ph.allocation_stats().live_bytes, u64(0))
}
