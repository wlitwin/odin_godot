package kit_box3d_test

import "core:fmt"
import "core:testing"
import "core:time"
import b3 "godot:box3d"
import net "godot:kit/net"
import physics "godot:kit/physics"
import session "godot:kit/session"
import sim "godot:kit/sim"
import fixture "godot:tests/replay_physics/fixture" // test-only accepted geometry

ACCEPT_TIMING :: #config(KIT_PHYSICS_ACCEPT_TIMING, false)
Envelope :: struct {
	lane:    sim.Lane,
	ses:     session.Session,
	p:       physics.Instance(fixture.Game),
	actors:  [32]Actor,
	desc:    net.Entity_Desc,
	effects: int,
}
envelope_sample :: proc(user: rawptr, tick: u64, dst: rawptr) {
	(cast(^fixture.Input)dst)^ = {
		spawn   = tick == 20 ? 1 : 0,
		despawn = tick == 80,
		sleep   = tick == 120,
		wake    = tick == 121,
		impulse = tick % 30 == 0 ? .1 : 0,
	}
}
envelope_fx :: proc(user: rawptr, tick, key: u64, args: []u8) {e := cast(^Envelope)user
	e.effects += 1}
envelope_step :: proc(user: rawptr, tick: u64) {
	e := cast(^Envelope)user; s := physics.state(&e.p); world, error := physics.world(&e.p); assert(error == .Ok)
	input, found := sim.lane_input_of(&e.lane, e.ses.me, fixture.Input); assert(found)
	s.tick = tick; x := s.rng; x ~= x << 13; x ~= x >> 17; x ~= x << 5; s.rng = x
	if input.impulse !=
	   0 {body, status := b3.body_resolve(world, s.bodies[0]); assert(status == .Ok); assert(b3.body_apply_impulse(body, {input.impulse, .1, 0}) == .Ok)}
	if input.spawn != 0 {
		def := b3.body_def_default(); def.type = .Dynamic; def.pose.position = {.1, 7, .1}
		body, status := b3.body_create(world, def); assert(status == .Ok)
		shape := b3.shape_def_default(); shape.enable_sensor_events = 1
		_, status = b3.shape_sphere(body, shape, .25); assert(status == .Ok)
		s.bodies[s.initial], status = b3.body_key(body); assert(status == .Ok)
		s.alive[s.initial] = true; s.generation[s.initial] += 1; s.births += 1
	}
	if input.despawn {body, status := b3.body_resolve(world, s.bodies[s.initial]); assert(status == .Ok); assert(b3.body_destroy(&body) == .Ok); s.alive[s.initial] = false; s.bodies[s.initial] = 0; s.deaths += 1}
	if input.sleep ||
	   input.wake {body, status := b3.body_resolve(world, s.bodies[0]); assert(status == .Ok); assert(b3.body_set_awake(body, input.wake) == .Ok)}
	assert(sim.lane_world_emit(&e.lane, 1, envelope_fx, e) == .Ok)
}
envelope_settle :: proc(user: rawptr, tick: u64) {
	e := cast(^Envelope)user; s := physics.state(&e.p); world, error := physics.world(&e.p); assert(error == .Ok)
	events: [70]b3.Sensor_Event
	count, status := b3.world_sensor_events(world, events[:]); assert(status == .Ok)
	for event in events[:count] {if event.began != 0 {s.begins += 1} else {s.ends += 1}}
	if tick % 4 ==
	   0 {shapes: [35]b3.Shape; hits, status := b3.query_overlap_aabb(world, {-3, -1, -3}, {3, 6, 3}, b3.QUERY_FILTER_ALL, shapes[:]); assert(status == .Ok); s.queries += u64(hits)}
	for i in 0 ..< 32 {
		body, status := b3.body_resolve(world, s.bodies[i]); assert(status == .Ok)
		e.actors[i].pose, status = b3.body_get_pose(
			body,
		); assert(status == .Ok); e.actors[i].tick = tick
	}
}

@(test)
measured_32_body_history_and_eight_tick_transaction :: proc(t: ^testing.T) {
	e := new(Envelope); defer free(e)
	e.ses.is_host = true; e.ses.me = 1; e.desc = actor_desc()
	sim.lane_init(
		&e.lane,
		&e.ses,
		size_of(fixture.Input),
	); sim.lane_set_sim(&e.lane, e, envelope_sample, envelope_step)
	fields: [32]sim.World_Field_Type
	for &actor, i in e.actors {sim.lane_track(&e.lane, sim.Net_Id(i + 1), &actor, &e.desc, e.ses.me); fields[i] = sim.world_field_type(sim.Net_Id(i + 1), Actor)}
	world, initial, config := fixture.world(32)
	error := physics.attach(
		&e.p,
		&e.lane,
		&world,
		initial,
		fields[:],
		{asset_id = config.asset_id, additional_owned_bytes = u64(size_of(Envelope))},
		envelope_settle,
	)
	testing.expect_value(t, error, sim.World_Error.Ok)
	normal_max, correction_max: u64
	for tick in 1 ..= 160 {
		started := time.tick_now(
			
		); advanced := sim.lane_frame(&e.lane, 1.0 / 60); wall := u64(time.tick_since(started))
		testing.expect_value(
			t,
			advanced,
			1,
		); testing.expect_value(t, sim.lane_world_status(&e.lane), sim.World_Error.Ok)
		work := sim.lane_world_work_stats(
			&e.lane,
		); normal_max = max(normal_max, work.normal_latest_ns)
		fmt.printf(
			"KIT_PHYSICS_SAMPLE metric=normal tick=%d core_ns=%d call_ns=%d\n",
			tick,
			work.normal_latest_ns,
			wall,
		)
		if tick >= 128 {
			before, be := sim.lane_world_checkpoint(
				&e.lane,
				u64(tick),
			); testing.expect_value(t, be, sim.World_Error.Ok)
			base, ba := sim.lane_world_checkpoint(
				&e.lane,
				u64(tick - 8),
			); testing.expect_value(t, ba, sim.World_Error.Ok)
			effects := e.effects
			started = time.tick_now(
				
			); result := sim.lane_world_reconcile(&e.lane, &base); wall = u64(time.tick_since(started))
			testing.expect_value(
				t,
				result.error,
				sim.World_Error.Ok,
			); testing.expect_value(t, result.steps, 8)
			work = sim.lane_world_work_stats(
				&e.lane,
			); correction_max = max(correction_max, work.correction_latest_ns)
			fmt.printf(
				"KIT_PHYSICS_SAMPLE metric=correction tick=%d depth=8 core_ns=%d call_ns=%d\n",
				tick,
				work.correction_latest_ns,
				wall,
			)
			after, ae := sim.lane_world_checkpoint(
				&e.lane,
				u64(tick),
			); testing.expect_value(t, ae, sim.World_Error.Ok)
			equal, ee := sim.world_checkpoint_equal(
				&before,
				&after,
			); testing.expect_value(t, ee, sim.World_Error.Ok); testing.expect(t, equal)
			testing.expect_value(t, e.effects, effects)
			sim.world_checkpoint_destroy(
				&before,
			); sim.world_checkpoint_destroy(&base); sim.world_checkpoint_destroy(&after)
		}
	}
	observed, oe := physics.observe(&e.p); testing.expect_value(t, oe, sim.World_Error.Ok)
	profile := physics.allocation_stats()
	fmt.printf(
		"KIT_PHYSICS_ENVELOPE bodies=32 history=128 repair=8 normal_samples=160 correction_samples=33 observed_live_peak=%d staged_live_peak=%d live_at_end=%d engine_component_high=%d wrapper_component_high=%d largest_operation_requests=%d reservation_bytes=%d reservation_failures=%d normal_max_ns=%d correction_max_ns=%d\n",
		profile.observed_live_peak,
		profile.staged_live_peak,
		observed.live_bytes,
		observed.engine.high_water_bytes,
		observed.wrapper.high_water_bytes,
		profile.largest_operation_requests,
		e.p.config.reservation_bytes,
		profile.reservation_failures,
		normal_max,
		correction_max,
	)
	testing.expect(
		t,
		profile.observed_live_peak <= b3.ALPHA_RESOURCE_BYTES &&
		profile.staged_live_peak <= b3.ALPHA_RESOURCE_BYTES &&
		profile.largest_operation_requests <= e.p.config.reservation_bytes &&
		profile.reservation_failures == 0,
	)
	when ACCEPT_TIMING {testing.expect(
			t,
			normal_max <= b3.ALPHA_NORMAL_WORK_NS && correction_max <= b3.ALPHA_CORRECTION_WORK_NS,
			"observed integrated core timing target exceeded",
		)}
	sim.lane_destroy(&e.lane); testing.expect_value(t, physics.detach(&e.p), sim.World_Error.Ok)
	engine, es := b3.engine_allocation_stats(); wrapper, ws := b3.snapshot_allocation_stats()
	fmt.printf(
		"KIT_PHYSICS_TEARDOWN engine_live=%d native_wrapper_live=%d provider_live=%d checkpoint_live=%d\n",
		engine.live_bytes,
		wrapper.live_bytes,
		physics.owned_bytes(),
		sim.world_checkpoint_owned_bytes(),
	)
	testing.expect(
		t,
		es == .Ok &&
		ws == .Ok &&
		engine.live_bytes == 0 &&
		wrapper.live_bytes == 0 &&
		physics.owned_bytes() == 0 &&
		sim.world_checkpoint_owned_bytes() == 0,
	)
}
