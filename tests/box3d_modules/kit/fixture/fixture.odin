package kit_module_fixture

// TEST ONLY. Called by a producer's protected Godot instance method. Nothing
// here registers a Node or transfers an Odin value between producer images.
import "base:runtime"
import "core:mem"
import b "godot:box3d"
import bg "godot:box3d/godot"
import bm "godot:box3d/godot/meter"
import net "godot:kit/net"
import p "godot:kit/physics"
import session "godot:kit/session"
import sim "godot:kit/sim"

Factory_Info :: struct {
	size, version:                                                         u32,
	key, tick, dump_bytes:                                                 u64,
	source_objects_live, managed_contexts_live, host_live, host_requested: u64,
}
Stats :: struct {
	source_objects_live, managed_contexts_live, host_live, host_requested: u64,
}
@(private)
totals: Stats
@(private)
Side :: struct {
	key:  b.Body_Key,
	tick: u64,
	rng:  u32,
}
@(private)
Proxy :: struct {
	pose: b.Pose,
	tick: u64,
}
@(private)
Source :: struct {
	lane:     ^sim.Lane,
	ses:      ^session.Session,
	provider: ^p.Instance(Side),
	proxy:    ^Proxy,
	desc:     net.Entity_Desc,
}

@(private)
advance :: proc(user: rawptr, tick: u64) {
	s := cast(^Source)user
	state := p.state(s.provider); assert(state != nil)
	state.tick = tick; state.rng = state.rng * 1664525 + 1013904223
}
@(private)
settle :: proc(user: rawptr, tick: u64) {
	s := cast(^Source)user
	state := p.state(s.provider); world, error := p.world(s.provider); assert(error == .Ok)
	body, status := b.body_resolve(world, state.key); assert(status == .Ok)
	s.proxy.pose, status = b.body_get_pose(body); assert(status == .Ok); s.proxy.tick = tick
}
@(private)
destroy_source :: proc(s: ^Source, a: mem.Allocator) {
	if s.provider != nil {_ = p.detach(s.provider)}
	if s.lane != nil && s.lane.ses != nil {sim.lane_destroy(s.lane)}
	if s.proxy != nil {free(s.proxy, a); totals.source_objects_live -= 1}
	if s.provider != nil {free(s.provider, a); totals.source_objects_live -= 1}
	if s.ses != nil {free(s.ses, a); totals.source_objects_live -= 1}
	if s.lane != nil {free(s.lane, a); totals.source_objects_live -= 1}
	free(s, a); totals.source_objects_live -= 1
}
@(private)
checkpoint :: proc() -> (sim.World_Checkpoint, u64, bg.Status) {
	m, meter_status := bm.create(bg.service_get(), bg.CATEGORY_KIT_CORE)
	if meter_status != bg.OK {return {}, 0, meter_status}
	defer {assert(bm.destroy(&m) == bg.OK)}
	lease := bm.data_lease(m)
	live, e := p.sdk_owner_create(true, lease); if e != .Ok {return {}, 0, bg.INCOMPATIBLE}
	defer {assert(sim.world_owner_drop(live) == .Ok)}
	detached, de := p.sdk_owner_create(false, lease); if de != .Ok {return {}, 0, bg.INCOMPATIBLE}
	defer {assert(sim.world_owner_drop(detached) == .Ok)}
	a := bm.allocator(m)
	context.allocator = a
	s, se := new(
		Source,
		a,
	); if se != nil || s == nil {return {}, 0, bg.OUT_OF_MEMORY}; totals.source_objects_live += 1
	defer destroy_source(s, a)
	s.lane, _ = new(
		sim.Lane,
		a,
	); if s.lane == nil {return {}, 0, bg.OUT_OF_MEMORY}; totals.source_objects_live += 1
	s.ses, _ = new(
		session.Session,
		a,
	); if s.ses == nil {return {}, 0, bg.OUT_OF_MEMORY}; totals.source_objects_live += 1
	s.provider, _ = new(
		p.Instance(Side),
		a,
	); if s.provider == nil {return {}, 0, bg.OUT_OF_MEMORY}; totals.source_objects_live += 1
	s.proxy, _ = new(
		Proxy,
		a,
	); if s.proxy == nil {return {}, 0, bg.OUT_OF_MEMORY}; totals.source_objects_live += 1
	provider_user, provider_error := p.sdk_user_owner_create(
		m,
		s.provider,
		u64(size_of(s.provider^)),
		s.provider,
		u64(size_of(s.provider^)),
	)
	if provider_error != .Ok {return {}, 0, bg.INCOMPATIBLE}
	defer p.sdk_user_owner_destroy(&provider_user)
	author_user, author_error := p.sdk_user_owner_create(
		m,
		s,
		u64(size_of(s^)),
		s,
		u64(size_of(s^)),
	)
	if author_error != .Ok {return {}, 0, bg.INCOMPATIBLE}
	defer p.sdk_user_owner_destroy(&author_user)
	s.ses.is_host = true; s.ses.me = 1
	sim.lane_init(s.lane, s.ses, 0, allocator = a)
	sim.lane_set_sim(s.lane, s, nil, advance)
	@(static) fields := []net.Field_Desc {
		{offset = offset_of(Proxy, pose), size = size_of(b.Pose), flags = {.Predicted}},
		{offset = offset_of(Proxy, tick), size = size_of(u64), flags = {.Predicted}},
	}
	s.desc = {
		fields = fields,
	}; sim.lane_track(s.lane, 1, s.proxy, &s.desc, 1)
	world, status := b.world_create(
		b.world_def_default(),
	); if status != .Ok {return {}, 0, bg.CAPACITY}
	defer {if world != 0 {_ = b.world_destroy(&world)}}
	def := b.body_def_default(); def.type = .Dynamic; def.pose.position = {0, 2, 0}
	body, bs := b.body_create(world, def); if bs != .Ok {return {}, 0, bg.CAPACITY}
	_, ss := b.shape_box(
		body,
		b.shape_def_default(),
		{.25, .25, .25},
	); if ss != .Ok {return {}, 0, bg.CAPACITY}
	key, ks := b.body_key(body); if ks != .Ok {return {}, 0, bg.CORRUPT}
	ae := p.attach(
		s.provider,
		s.lane,
		&world,
		Side{key = key, rng = 37},
		[]sim.World_Field_Type{sim.world_field_type(1, Proxy)},
		{
			asset_id = 0x4b49544341505331,
			owner = live,
			detached_owner = detached,
			allocator_context = m,
			provider_owner = provider_user.owner,
			provider_user = provider_user.user,
			author_owner = author_user.owner,
			author_user = author_user.user,
		},
		settle,
	)
	if ae != .Ok {return {}, 0, bg.INCOMPATIBLE}
	for _ in 0 ..< 4 {if sim.lane_frame(s.lane, 1.0 / 60) != 1 {return {}, 0, bg.CORRUPT}}
	cp, ce := sim.lane_world_checkpoint(s.lane, 4); if ce != .Ok {return {}, 0, bg.CAPACITY}
	return cp, u64(key), bg.OK
}

// On failure both outputs are unchanged. On success every source object has
// already been freed; only the owned checkpoint + managed allocator heap live.
// Must run in Core's protected originating instance callback (EXECUTE owner).
create :: proc "c" (out: ^bg.Capsule, info: ^Factory_Info) -> bg.Status {
	context = runtime.default_context()
	if out == nil || info == nil || out.user != nil {return bg.INVALID_ARGUMENT}
	cp, key, status := checkpoint(); if status != bg.OK {return status}
	defer {if cp.image != nil {_ = sim.world_checkpoint_destroy(&cp)}}
	required, de := p.checkpoint_dump(&cp, nil, Side); if de != .Ok {return bg.CORRUPT}
	result: bg.Capsule
	error := p.sdk_checkpoint_capsule(&cp, Side, &result); if error != .Ok {return bg.CAPACITY}
	refresh()
	out^ = result
	info^ = {
		size                  = u32(size_of(Factory_Info)),
		version               = 1,
		key                   = key,
		tick                  = 4,
		dump_bytes            = required,
		source_objects_live   = totals.source_objects_live,
		managed_contexts_live = totals.managed_contexts_live,
		host_live             = totals.host_live,
		host_requested        = totals.host_requested,
	}
	return bg.OK
}
stats :: proc "c" (out: ^Stats) -> bg.Status {
	if out == nil {return bg.INVALID_ARGUMENT}; refresh(); out^ = totals; return bg.OK
}

@(private)
refresh :: proc "contextless" () {values, status := bm.category_stats(bg.CATEGORY_KIT_CORE)
	if status != bg.OK {return}
	totals.managed_contexts_live = values.contexts
	totals.host_live = values.live_bytes
	totals.host_requested = values.requested_bytes}
