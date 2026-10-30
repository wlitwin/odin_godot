package hello_game

import r "godot:replay"
import p "godot:replay/play"

CAPACITY :: 32
Kind :: enum u8 {Player, Projectile}
Actor :: struct {
	body: p.Body2,
	kind: Kind,
	owner: u8,
	life: u32,
}
World :: struct {
	actors: r.Pool(Actor, CAPACITY),
	players: [2]r.Handle(Actor),
	fire: [2]p.Cooldown,
	shots: u32,
}
Controls :: struct {move: [2]i8, fire: bool}
Input :: struct {players: [2]Controls}
Event :: struct {position: [2]f32, player: u8}
Timeline :: r.Timeline(World, Input, Event)

// Scene geometry's immutable simulation representation. Bounds plus one crate.
WALLS :: [5]p.Aabb2{
	{min = {-20, -20}, max = {0, 380}},
	{min = {640, -20}, max = {660, 380}},
	{min = {0, -20}, max = {640, 0}},
	{min = {0, 360}, max = {640, 380}},
	{min = {300, 125}, max = {340, 235}},
}

initial :: proc() -> World {
	w: World
	for i in 0 ..< 2 {
		w.players[i], _ = r.pool_insert(&w.actors, Actor{
			body = {position = {120 + f32(i) * 72, 180}, half_size = {8, 8}},
			owner = u8(i),
		})
	}
	return w
}

step :: proc(w: ^World, input: Input, ctx: ^r.Step(Event)) {
	walls := WALLS
	for &actor, i in w.actors.values {
		if !w.actors.alive[i] || actor.kind != .Projectile {continue}
		actor.body.position[1] -= 4
		actor.life -= 1
		if actor.life == 0 {
			r.pool_remove(&w.actors, r.Handle(Actor){u32(i), w.actors.generations[i]})
		}
	}
	for control, i in input.players {
		actor, ok := r.pool_get(&w.actors, w.players[i])
		if !ok {continue}
		p.cooldown_tick(&w.fire[i])
		delta := [2]f32{f32(clamp(control.move[0], -1, 1)), f32(clamp(control.move[1], -1, 1))}
		if delta[0] != 0 && delta[1] != 0 {delta *= 0.70710678}
		p.move(&actor.body, delta * (160.0 / 60.0), walls[:])
		if control.fire && p.cooldown_ready(&w.fire[i]) {
			position := actor.body.position
			_, spawned := r.pool_insert(&w.actors, Actor{
				kind = .Projectile, owner = u8(i), life = 60,
				body = {position = position, half_size = {3, 6}},
			})
			if spawned {
				w.shots += 1
				p.cooldown_arm(&w.fire[i], 12)
				r.emit(ctx, u64(i + 1), 1, Event{position, u8(i)})
			}
		}
	}
}
