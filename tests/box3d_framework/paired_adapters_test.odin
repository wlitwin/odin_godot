package framework_tests

import "core:mem"
import "core:testing"
import b3 "godot:box3d"
import r "godot:replay"
import ph "godot:replay/physics"
import kp "godot:kit/physics"
import sim "godot:kit/sim"
import net "godot:kit/net"
import session "godot:kit/session"
import model "godot:tests/box3d_framework/model"

Proxy :: struct {height: f32, tick: u64}
Kit_Context :: struct {
	lane: sim.Lane,
	session: session.Session,
	physics: kp.Instance(model.State),
	proxy: Proxy,
	desc: net.Entity_Desc,
	abort_tick: u64,
	current_input: model.Control,
	pending: model.Events,
	effects: u64,
}

proxy_desc :: proc() -> net.Entity_Desc {
	@(static) fields := [?]net.Field_Desc{
		{offset = offset_of(Proxy, height), size = size_of(f32), flags = {.Predicted}},
		{offset = offset_of(Proxy, tick), size = size_of(u64), flags = {.Predicted}},
	}
	return {fields = fields[:]}
}

kit_sample :: proc(user: rawptr, tick: u64, destination: rawptr) {
	ctx := cast(^Kit_Context)user
	input := model.control_at(tick)
	input.abort_after = tick == ctx.abort_tick
	(cast(^model.Control)destination)^ = input
}

kit_effect :: proc(user: rawptr, tick, key: u64, args: []u8) {
	ctx := cast(^Kit_Context)user
	assert(ctx.lane.world.presenting)
	ctx.effects += 1
}

kit_step :: proc(user: rawptr, tick: u64) {
	ctx := cast(^Kit_Context)user
	state := kp.state(&ctx.physics); assert(state != nil)
	world, error := kp.world(&ctx.physics); assert(error == .Ok)
	input, found := sim.lane_input_of(&ctx.lane, ctx.session.me, model.Control); assert(found)
	ctx.current_input = input
	operations := model.raw_operations(&world)
	ctx.pending, found = model.apply(state, input, operations)
	if !found {sim.lane_world_fail(&ctx.lane, .Step_Failed)}
}

kit_settle :: proc(user: rawptr, tick: u64) {
	ctx := cast(^Kit_Context)user
	state := kp.state(&ctx.physics); assert(state != nil)
	world, error := kp.world(&ctx.physics); assert(error == .Ok)
	if !model.settle(state, model.raw_operations(&world)) {sim.lane_world_fail(&ctx.lane, .Step_Failed); return}
	ctx.proxy = {state.last_y, state.tick}
	for &event in ctx.pending.values[:ctx.pending.count] {
		bytes := (cast([^]u8)&event)[:size_of(model.Event)]
		status := sim.lane_world_emit(&ctx.lane, model.event_key(event), kit_effect, ctx, bytes)
		assert(status == .Ok)
	}
	if ctx.current_input.abort_after {sim.lane_world_fail(&ctx.lane, .Step_Failed)}
}

kit_init :: proc(ctx: ^Kit_Context) -> sim.World_Error {
	ctx.session.is_host = true; ctx.session.me = 1
	sim.lane_init(&ctx.lane, &ctx.session, size_of(model.Control))
	sim.lane_set_sim(&ctx.lane, ctx, kit_sample, kit_step)
	ctx.desc = proxy_desc()
	sim.lane_track(&ctx.lane, 1, &ctx.proxy, &ctx.desc, ctx.session.me)
	world, state := model.initial()
	ctx.proxy = {state.last_y, state.tick}
	fields := [?]sim.World_Field_Type{sim.world_field_type(1, Proxy)}
	error := kp.attach(&ctx.physics, &ctx.lane, &world, state, fields[:], {asset_id = 0x4652414d45573231}, kit_settle)
	if error != .Ok {model.must(b3.world_destroy(&world))}
	return error
}

kit_destroy :: proc(ctx: ^Kit_Context) {
	sim.lane_destroy(&ctx.lane)
	assert(kp.detach(&ctx.physics) == .Ok)
}

kit_checkpoint :: proc(t: ^testing.T, ctx: ^Kit_Context) -> sim.World_Checkpoint {
	checkpoint, error := sim.lane_world_checkpoint(&ctx.lane, ctx.lane.ticker.tick)
	testing.expect_value(t, error, sim.World_Error.Ok)
	return checkpoint
}

kit_bytes :: proc(checkpoint: ^sim.World_Checkpoint) -> []u8 {
	size, error := kp.checkpoint_dump(checkpoint, nil, model.State)
	assert(error == .Ok)
	bytes := make([]u8, int(size))
	actual, result := kp.checkpoint_dump(checkpoint, bytes, model.State)
	assert(result == .Ok && actual == size)
	return bytes
}

@(test)
kit_and_replay_publish_the_same_complete_game_and_solver_state :: proc(t: ^testing.T) {
	kit: Kit_Context
	testing.expect_value(t, kit_init(&kit), sim.World_Error.Ok)
	world, state := model.initial()
	initial, error := ph.checkpoint_make(r.Frame(model.State){state = state}, model.Event, world, replay_config())
	testing.expect_value(t, error, r.Error.None)
	model.must(b3.world_destroy(&world))
	replay: Replay_Timeline
	testing.expect_value(t, r.init_complete(&replay, &initial, replay_step, {128, 4}), r.Error.None)
	r.complete_checkpoint_destroy(&initial)
	expected_effects := u64(0)
	for tick in u64(1)..=8 {
		testing.expect_value(t, sim.lane_frame(&kit.lane, 1.0 / 60.0), 1)
		testing.expect_value(t, sim.lane_world_status(&kit.lane), sim.World_Error.Ok)
		testing.expect_value(t, r.advance(&replay, model.control_at(tick)).error, r.Error.None)
		left := kit_checkpoint(t, &kit)
		right := replay_capture(t, &replay, tick)
		kit_state, side_error := kp.checkpoint_side(&left, model.State)
		testing.expect_value(t, side_error, sim.World_Error.Ok)
		testing.expect_value(t, kit_state, right.frame.state)
		testing.expect_value(t, kit.proxy.height, kit_state.last_y)
		testing.expect_value(t, kit.proxy.tick, tick)
		a := kit_bytes(&left); b := replay_bytes(&right)
		testing.expect(t, len(a) == len(b) && mem.compare(a, b) == 0)
		expected_effects = u64(kit_state.emitted)
		testing.expect_value(t, kit.effects, expected_effects)
		delete(a); delete(b)
		sim.world_checkpoint_destroy(&left); r.complete_checkpoint_destroy(&right)
	}

	// Both runtimes have accepted the same image at tick eight. A failed Kit
	// candidate must restore registered fields as well as native+Side and FX.
	before := kit_checkpoint(t, &kit)
	proxy_before := kit.proxy
	kit.abort_tick = 9
	testing.expect_value(t, sim.lane_frame(&kit.lane, 1.0 / 60.0), 0)
	testing.expect_value(t, sim.lane_world_status(&kit.lane), sim.World_Error.Step_Failed)
	testing.expect_value(t, kit.proxy, proxy_before)
	testing.expect_value(t, kit.effects, expected_effects)
	after := kit_checkpoint(t, &kit)
	equal, equal_error := sim.world_checkpoint_equal(&before, &after)
	testing.expect_value(t, equal_error, sim.World_Error.Ok)
	testing.expect(t, equal)
	sim.world_checkpoint_destroy(&before); sim.world_checkpoint_destroy(&after)
	kit_destroy(&kit); r.destroy(&replay)

	engine, engine_status := b3.engine_allocation_stats()
	owned, owned_status := b3.snapshot_allocation_stats()
	testing.expect_value(t, engine_status, b3.Status.Ok)
	testing.expect_value(t, owned_status, b3.Status.Ok)
	testing.expect_value(t, engine.live_bytes, u64(0))
	testing.expect_value(t, owned.live_bytes, u64(0))
	testing.expect_value(t, kp.owned_bytes(), u64(0))
	testing.expect_value(t, ph.allocation_stats().live_bytes, u64(0))
}
