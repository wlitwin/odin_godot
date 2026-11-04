package framework_model

// The same pointer-free game rules drive the independent Kit and Replay
// transaction tests. Framework wrappers own publication, events and failure.
import "core:fmt"
import b3 "godot:box3d"

State :: struct {
	tick: u64,
	rng: u32,
	floor, actor, spawned: b3.Body_Key,
	spawned_live: bool,
	next_entity, spawned_entity, next_event: u64,
	births, removals, impulses, emitted: u32,
	last_y: f32,
}

Control :: struct {
	push: i8,
	spawn, remove, abort_after, bad_key: bool,
}

Event_Kind :: enum u8 {Born, Removed, Impulse}
Event :: struct {kind: Event_Kind, entity, sequence: u64}
Events :: struct {values: [4]Event, count: int}
event_key :: proc(event: Event) -> u64 {
	// The framework already scopes this key by tick. Prefix changes must not
	// renumber unrelated later effects through the diagnostic sequence counter.
	return (u64(event.kind) + 1) << 56 | event.entity
}
Operations :: struct {
	user: rawptr,
	spawn: proc(rawptr, b3.Vec3) -> (b3.Body_Key, bool),
	remove: proc(rawptr, b3.Body_Key) -> bool,
	impulse: proc(rawptr, b3.Body_Key, b3.Vec3) -> bool,
	pose: proc(rawptr, b3.Body_Key) -> (b3.Pose, bool),
}

must :: proc(status: b3.Status) {
	if status != .Ok {panic(fmt.tprintf("fixture native status: %v", status))}
}

body :: proc(world: b3.World, position: b3.Vec3, is_dynamic: bool, radius: f32) -> b3.Body {
	def := b3.body_def_default()
	def.type = is_dynamic ? .Dynamic : .Static
	def.pose.position = position
	result, status := b3.body_create(world, def); must(status)
	shape_def := b3.shape_def_default()
	if is_dynamic {shape_def.enable_sensor_events = 1}
	if is_dynamic {
		_, shape_status := b3.shape_sphere(result, shape_def, radius); must(shape_status)
	} else {
		_, shape_status := b3.shape_box(result, shape_def, {4, 0.5, 4}); must(shape_status)
	}
	return result
}

initial :: proc(seed: u32 = 7) -> (world: b3.World, state: State) {
	assert(seed != 0)
	status: b3.Status
	world, status = b3.world_create(b3.world_def_default()); must(status)
	floor := body(world, {0, -0.5, 0}, false, 0)
	actor := body(world, {0, 1.5, 0}, true, 0.25)
	state.rng = seed; state.next_entity = 2; state.last_y = 1.5
	state.floor, status = b3.body_key(floor); must(status)
	state.actor, status = b3.body_key(actor); must(status)
	return
}

emit :: proc(state: ^State, events: ^Events, kind: Event_Kind, entity: u64) {
	assert(events.count < len(events.values))
	state.next_event += 1
	events.values[events.count] = {kind, entity, state.next_event}
	events.count += 1
	state.emitted += 1
}

control_at :: proc(tick: u64) -> Control {
	return {push = i8(tick % 5) - 2, spawn = tick % 9 == 1, remove = tick % 9 == 7}
}

// Failure deliberately occurs after mutable solver/game work and event
// generation. A correct participant must discard all of that unpublished work.
apply :: proc(state: ^State, input: Control, operations: Operations) -> (events: Events, ok: bool) {
	state.tick += 1
	x := state.rng; x ~= x << 13; x ~= x >> 17; x ~= x << 5; state.rng = x
	if input.spawn && !state.spawned_live {
		key, created := operations.spawn(operations.user, {0.5, 2, 0})
		if !created {return events, false}
		state.spawned = key; state.spawned_live = true
		state.spawned_entity = state.next_entity; state.next_entity += 1
		state.births += 1; emit(state, &events, .Born, state.spawned_entity)
	}
	if input.remove && state.spawned_live {
		if !operations.remove(operations.user, state.spawned) {return events, false}
		state.spawned = 0; state.spawned_live = false; state.removals += 1
		emit(state, &events, .Removed, state.spawned_entity)
	}
	if input.push != 0 {
		if !operations.impulse(operations.user, state.actor, {f32(input.push) * 0.02, 0.05, 0}) {return events, false}
		state.impulses += 1; emit(state, &events, .Impulse, 1)
	}
	if input.bad_key {
		_, valid := operations.pose(operations.user, 0)
		assert(!valid)
		return events, false
	}
	return events, true
}

settle :: proc(state: ^State, operations: Operations) -> bool {
	pose, valid := operations.pose(operations.user, state.actor)
	if !valid {return false}
	state.last_y = pose.position.y
	return true
}

raw_operations :: proc(world: ^b3.World) -> Operations {
	return {
		user = world,
		spawn = proc(user: rawptr, position: b3.Vec3) -> (b3.Body_Key, bool) {
			target := body((cast(^b3.World)user)^, position, true, 0.2)
			key, status := b3.body_key(target); return key, status == .Ok
		},
		remove = proc(user: rawptr, key: b3.Body_Key) -> bool {
			target, status := b3.body_resolve((cast(^b3.World)user)^, key)
			if status != .Ok {return false}
			return b3.body_destroy(&target) == .Ok
		},
		impulse = proc(user: rawptr, key: b3.Body_Key, amount: b3.Vec3) -> bool {
			target, status := b3.body_resolve((cast(^b3.World)user)^, key)
			if status != .Ok {return false}
			return b3.body_apply_impulse(target, amount) == .Ok
		},
		pose = proc(user: rawptr, key: b3.Body_Key) -> (b3.Pose, bool) {
			target, status := b3.body_resolve((cast(^b3.World)user)^, key)
			if status != .Ok {return {}, false}
			value, result := b3.body_get_pose(target); return value, result == .Ok
		},
	}
}

step :: proc(state: ^State, input: Control, world: b3.World) -> (events: Events, ok: bool) {
	world := world
	operations := raw_operations(&world)
	events, ok = apply(state, input, operations)
	if !ok || b3.world_step_fixed(world) != .Ok {return events, false}
	return events, settle(state, operations) && !input.abort_after
}

solver_bytes :: proc(world: b3.World) -> []u8 {
	required, status := b3.world_dump(world, nil); must(status)
	assert(required != 0 && required <= 1024 * 1024)
	bytes := make([]u8, int(required))
	written, result := b3.world_dump(world, bytes); must(result)
	assert(written == required)
	return bytes
}

snapshot_bytes :: proc(snapshot: ^b3.Snapshot) -> []u8 {
	required, status := b3.snapshot_dump(snapshot, nil); must(status)
	bytes := make([]u8, int(required))
	written, result := b3.snapshot_dump(snapshot, bytes); must(result)
	assert(written == required)
	return bytes
}
