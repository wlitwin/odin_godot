package replay_recipes

import replay "godot:replay"
import play "godot:replay/play"

// Gameplay composition uses ordinary owned substructures. This model has no
// engine dependencies; authored Gun_Def values are copied in at admission.
Component_Health :: struct {
	current, maximum: u16,
}
Component_Motor :: struct {
	position, velocity: [2]f32,
}
Component_Actor :: struct {
	health:     Component_Health,
	motor:      Component_Motor,
	weapon:     play.Gun_State,
	definition: play.Gun_Def,
}
Component_Input :: struct {
	move: [2]f32,
	fire: bool,
}
Component_Event :: struct {
	shot:     bool,
	position: [2]f32,
}

component_motor_step :: proc(motor: ^Component_Motor, input: [2]f32) {
	motor.velocity = input * 120
	motor.position += motor.velocity / 60
}

component_actor_step :: proc(actor: ^Component_Actor, input: Component_Input, ctx: ^replay.Step(Component_Event)) {
	if actor.health.current == 0 {
		return
	}
	component_motor_step(&actor.motor, input.move)
	play.gun_tick(&actor.weapon, actor.definition)
	if input.fire {
		shot := play.gun_pull(&actor.weapon, actor.definition)
		if shot.error == .None && shot.pull == .Fired {
			replay.emit(ctx, 1, 1, Component_Event{shot = true, position = actor.motor.position})
		}
	}
}
