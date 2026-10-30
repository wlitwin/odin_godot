package replay_scrapyard

import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import game "../shared/game"

// Physical holds continue through overlays. Discard pending edges while blocked
// so closing a menu with Shift held cannot create another dash press.
sample_gameplay_input :: proc(self: ^ReplayScrapyard, typing: bool) -> game.Control {
	seat := rgd.session_seat(self.session)
	prior, available := rgd.session_state(self.session)
	r.buttons_set(
		&self.buttons,
		(gd.is_action_pressed("rsy_dash") ? u64(1) : 0) | (gd.is_action_pressed("rsy_fire") ? u64(2) : 0),
	)

	outside_yard := available && (seat == 0 || !prior.state.players[seat - 1].in_yard)
	blocked := typing || self.menu_open || self.menu_input_guard || outside_yard
	if blocked {
		r.buttons_consume(&self.buttons)
		self.dash_next = false
		net.intent_cancel(&self.dash_intent[0])
		net.intent_cancel(&self.turret_intent[0])
	}
	if blocked || !available || seat == 0 || !prior.state.players[seat - 1].in_yard {
		return {}
	}

	mouse := gd.canvas_item_get_global_mouse_position(self.owner)
	control, mouse_blocked := sample_player_controls(self, &prior.state, seat, mouse)
	apply_automated_controls(self, &prior.state, seat, &control)
	control.aim = unit(control.aim)

	if !self.manual {
		capture_gameplay_actions(self, &prior.state, seat, mouse, control.aim, mouse_blocked)
	}
	if !self.dash_intent[0].captured && (self.dash_next || self.buttons.pressed & 1 != 0) {
		direction := control.move == ([2]f32{}) ? control.aim : control.move
		net.intent_capture(&self.dash_intent[0], game.Action{kind = .Dash, aim = direction})
	}
	return control
}

sample_player_controls :: proc(
	self: ^ReplayScrapyard,
	world: ^game.World,
	seat: u16,
	mouse: gd.Vector2,
) -> (
	control: game.Control,
	mouse_blocked: bool,
) {
	if self.manual {
		control.move = self.manual_move
	} else {
		if gd.is_action_pressed("rsy_left") {
			control.move[0] -= 1
		}
		if gd.is_action_pressed("rsy_right") {
			control.move[0] += 1
		}
		if gd.is_action_pressed("rsy_up") {
			control.move[1] -= 1
		}
		if gd.is_action_pressed("rsy_down") {
			control.move[1] += 1
		}
	}

	aim_origin := world.players[seat - 1].position
	if handle, mounted := game.turret_for(world, seat); mounted {
		turret, _ := r.pool_get(&world.turrets, handle)
		aim_origin = turret.position
	}
	control.aim = [2]f32{mouse.x, mouse.y} - aim_origin
	if self.manual {
		control.aim = self.manual_aim
	}
	control.revive = self.manual ? self.manual_revive : gd.is_action_pressed("rsy_revive")
	mouse_blocked = shop_wants_mouse(self) || social_wants_mouse(self)
	control.fire =
		self.manual ? self.manual_fire : (!mouse_blocked && (gd.is_action_pressed("rsy_fire") || self.buttons.pressed & 2 != 0))
	return
}

// Development drivers override the same sampled control used by normal play.
// Navigation wins over combat movement; auto_walk wins over auto_gate.
apply_automated_controls :: proc(self: ^ReplayScrapyard, world: ^game.World, seat: u16, control: ^game.Control) {
	if self.auto_combat {
		scene := self.bot_scene[0]
		scene.players[seat - 1] = world.players[seat - 1]
		control^ = combat_intent(scene, seat)
	}
	if self.auto_gate {
		control.move = bot_path(&world.layout, world.players[seat - 1].position, game.GATE)
		control.fire = false
	}
	if self.auto_walk {
		control.move = bot_path(&world.layout, world.players[seat - 1].position, self.walk_target)
		control.fire = false
	}
}

capture_gameplay_actions :: proc(
	self: ^ReplayScrapyard,
	world: ^game.World,
	seat: u16,
	mouse: gd.Vector2,
	aim: [2]f32,
	mouse_blocked: bool,
) {
	if world.stage == .Clear {
		capture_shop_shortcuts(self)
	}
	if mouse_blocked {
		return
	}

	if gd.is_action_just_pressed("rsy_turret") {
		turret_intent_capture(self, world, seat)
	}
	if gd.is_action_just_pressed("rsy_cast0") {
		issue(self, game.Action{kind = .Cast, slot = 0, aim = {mouse.x, mouse.y}, aim_is_point = true})
	}
	if gd.is_action_just_pressed("rsy_cast1") {
		issue(self, game.Action{kind = .Cast, slot = 1, aim = aim})
	}
	if gd.is_action_just_pressed("rsy_ping") {
		replay_scrapyard_ping(self, gd.Float(mouse.x), gd.Float(mouse.y))
	}
}
