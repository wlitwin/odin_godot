package hello_game

import r "godot:replay"
import net "godot:replay/net"
import p "godot:replay/play"

Action :: struct {fire: bool}

network_model :: proc() -> net.Model(World, Controls, Action, Event, 2) {
	return {step = network_step, action = network_action, control_valid = network_controls_valid,
	        action_valid = network_action_valid, state_valid = network_state_valid, hold = network_hold}
}

network_step :: proc(w: ^World, controls: [2]Controls, joins, leaves: u64, ctx: ^r.Step(Event)) {
	for i in 0 ..< 2 {
		bit := u64(1) << uint(i)
		if leaves & bit != 0 {
			r.pool_remove(&w.actors, w.players[i])
			w.players[i] = {}
			w.fire[i] = {}
		}
		if joins & bit != 0 {
			if _, exists := r.pool_get(&w.actors, w.players[i]); !exists {
				w.players[i], _ = r.pool_insert(&w.actors, Actor{
					body = {position = {120 + f32(i) * 72, 180}, half_size = {8, 8}}, owner = u8(i),
				})
			}
		}
	}
	step(w, Input{players = controls}, ctx)
}

network_action :: proc(w: ^World, seat: u16, action: Action, ctx: ^r.Step(Event)) -> bool {
	i := int(seat - 1)
	actor, exists := r.pool_get(&w.actors, w.players[i])
	if !exists || !action.fire || !p.cooldown_ready(&w.fire[i]) {return false}
	position := actor.body.position
	_, spawned := r.pool_insert(&w.actors, Actor{kind = .Projectile, owner = u8(i), life = 60,
	                              body = {position = position, half_size = {3, 6}}})
	if !spawned {return false}
	w.shots += 1
	p.cooldown_arm(&w.fire[i], 12)
	r.emit(ctx, u64(seat), 1, Event{position, u8(i)})
	return true
}

network_controls_valid :: proc(control: Controls) -> bool {
	return control.move[0] >= -1 && control.move[0] <= 1 && control.move[1] >= -1 && control.move[1] <= 1
}
network_action_valid :: proc(action: Action) -> bool {return action.fire}
network_hold :: proc(control: Controls) -> Controls {return control}
network_state_valid :: proc(w: World) -> bool {
	count := u32(0)
	for actor, i in w.actors.values {
		if !w.actors.alive[i] {continue}
		count += 1
		if actor.owner >= 2 || w.actors.generations[i] == 0 {return false}
		if actor.kind == .Projectile && (actor.life == 0 || actor.life > 60) {return false}
	}
	if count != w.actors.count {return false}
	for id, i in w.players {
		if id.generation == 0 {continue}
		world := w
		actor, ok := r.pool_get(&world.actors, id)
		if !ok || actor.kind != .Player || actor.owner != u8(i) {return false}
	}
	return true
}
