package presentation_native_test

import b "godot:box3d"
import p "godot:box3d/presentation"
import kn "godot:kit/net"
import kp "godot:kit/physics"
import ks "godot:kit/session"
import k "godot:kit/sim"
import r "godot:replay"
import ph "godot:replay/physics"

Game :: struct {
	tick, serial: u64,
	body:         b.Body_Key,
	lifetime:     u64,
	alive:        bool,
}
Input :: struct {
	impulse:        f32,
	abort, replace: bool,
}
Event :: struct {
	entity, lifetime, serial: u64,
    impulse: f32,
}
project :: proc(game: Game, out: []p.Binding) -> (u32, p.Error) {
	if len(out) < 1 {return 1, .Capacity}
	out[0] = {
		id    = {1, game.lifetime},
		body  = p.Body_Key(game.body),
		asset = 1,
		seat  = 1,
		alive = game.alive,
	}
	return 1, .None
}
world :: proc() -> (b.World, Game) {
	w, status := b.world_create(b.world_def_default()); assert(status == .Ok)
	def := b.body_def_default(); def.pose.position = {0, -1, 0}
	ground, gs := b.body_create(w, def); assert(gs == .Ok)
	_, ss := b.shape_box(ground, b.shape_def_default(), {4, 1, 4}); assert(ss == .Ok)
	def.type = .Dynamic; def.pose.position = {0, 2, 0}
	body, bs := b.body_create(w, def); assert(bs == .Ok)
	_, ss = b.shape_box(body, b.shape_def_default(), {.25, .25, .25}); assert(ss == .Ok)
	key, key_status := b.body_key(body); assert(key_status == .Ok)
	return w, Game{body = key, lifetime = 1, alive = true}
}
replay_step :: proc(game: ^Game, input: Input, ctx: ^r.Step(Event)) {
	game.tick += 1
	if input.replace {
		if ph.body_destroy(ctx.execution, game.body) != .None {r.abort(ctx); return}
		def := b.body_def_default(); def.type = .Dynamic; def.pose.position = {0, 3, 0}
		key, error := ph.spawn(ctx.execution, 2, def); if error != .None {r.abort(ctx); return}
		game.body = key; game.lifetime += 1
	}
	if input.impulse !=
	   0 {if ph.body_impulse(ctx.execution, game.body, {input.impulse, 0, 0}) != .None {r.abort(ctx); return}}
	if ph.step(ctx.execution) != .None {r.abort(ctx); return}
	game.serial += 1; r.emit(ctx, 1, game.serial, Event{1, game.lifetime, game.serial, input.impulse})
	if input.abort {r.abort(ctx)}
}
initial :: proc() -> (r.Complete_Checkpoint(Game, Event), r.Error) {
	w, g := world(); defer b.world_destroy(&w)
	cfg := ph.config_default(0x50524553454e5431, 1); cfg.initial_dynamic_bodies = 1
	return ph.checkpoint_make(r.Frame(Game){state = g}, Event, w, cfg)
}
effect_project :: proc(event: Event) -> (p.Identity, bool) {return {event.entity, event.lifetime},
		event.serial != 0}

Kit_Actor :: struct {
	pose: b.Pose,
}
Kit_Fixture :: struct {
	lane:         k.Lane,
	ses:          ks.Session,
	physics:      kp.Instance(Game),
	actor:        Kit_Actor,
	desc:         kn.Entity_Desc,
	impulse_tick: u64,
	impulse:      f32,
	effects:      u32,
	last:         p.Effect_Observation,
}
kit_sample :: proc(user: rawptr, tick: u64, out: rawptr) {f := cast(^Kit_Fixture)user
	(cast(^Input)out)^ = {
		impulse = tick == f.impulse_tick ? f.impulse : 0,
	}}
kit_effect :: proc(user: rawptr, tick, key: u64, args: []u8) {
	f := cast(^Kit_Fixture)user
	assert(k.lane_live(&f.lane))
	f.effects += 1
	side, found := kp.read(&f.physics); assert(found)
	observation, ok := kp.presentation_effect(
		k.lane_world_epoch(&f.lane),
		tick,
		1,
		key,
		{1, side.lifetime},
	); assert(ok)
	f.last = observation
}
kit_step :: proc(user: rawptr, tick: u64) {
	f := cast(^Kit_Fixture)user; s := kp.state(&f.physics); assert(s != nil)
	w, error := kp.world(&f.physics); assert(error == .Ok)
	input, found := k.lane_input_of(&f.lane, 1, Input); assert(found)
	if input.impulse !=
	   0 {body, status := b.body_resolve(w, s.body); assert(status == .Ok); assert(b.body_apply_impulse(body, {input.impulse, 0, 0}) == .Ok)}
	s.tick = tick; s.serial += 1
	assert(k.lane_world_emit(&f.lane, s.serial, kit_effect, f) == .Ok)
}
kit_settle :: proc(user: rawptr, tick: u64) {
	f := cast(^Kit_Fixture)user; s := kp.state(&f.physics); w, error := kp.world(&f.physics); assert(error == .Ok)
	body, status := b.body_resolve(w, s.body); assert(status == .Ok)
	f.actor.pose, status = b.body_get_pose(body); assert(status == .Ok)
}
kit_init :: proc(f: ^Kit_Fixture, impulse_tick: u64 = 0, impulse: f32 = 0) -> k.World_Error {
	f.ses.is_host = true; f.ses.me = 1; f.impulse_tick = impulse_tick; f.impulse = impulse
	k.lane_init(&f.lane, &f.ses, size_of(Input)); k.lane_set_sim(&f.lane, f, kit_sample, kit_step)
	@(static) fields := [1]kn.Field_Desc {
		{offset = offset_of(Kit_Actor, pose), size = size_of(b.Pose), flags = {.Predicted}},
	}
	f.desc = {
		fields = fields[:],
	}; k.lane_track(&f.lane, 1, &f.actor, &f.desc, 1)
	types := [1]k.World_Field_Type{k.world_field_type(1, Kit_Actor)}
	w, game := world()
	error := kp.attach(
		&f.physics,
		&f.lane,
		&w,
		game,
		types[:],
		{asset_id = 0x50524553454e5431},
		kit_settle,
	)
	if error != .Ok {b.world_destroy(&w)}
	return error
}
kit_destroy :: proc(f: ^Kit_Fixture) {k.lane_destroy(&f.lane); assert(
		kp.detach(&f.physics) == .Ok,
	)}
