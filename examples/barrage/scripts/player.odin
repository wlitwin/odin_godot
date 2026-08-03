//gd:extends CharacterBody2D
//gd:class Player
//gd:group player
package barrage_main

// ----------------------------------------------------------------------------
// Player — a CharacterBody2D in the MAIN module. Moves on the ui_* axes, auto-fires
// at the nearest enemy, takes hits from the BulletField (its `player_hit` signal is
// wired to `take_damage` in game.tscn — a SCENE-declared cross-module connection),
// and is the target of powerup effects (`apply_powerup`, called by name from the
// powerups module).
//
// FEATURES: exports w/ range+group, node-group discovery, by-name engine calls
// (gd.vcall) INTO an isolated module (BulletField), signal target of a scene
// [connection], invulnerability windows, every stat a powerup mutates.
// ----------------------------------------------------------------------------

import gd "godot:godot"

Player :: struct {
	owner: gd.Node2d,

	move_speed: f32 `gd:"export,range=100:600:10,group=Stats"`,
	fire_rate:  f32 `gd:"export,range=1:30:0.5"`, // shots/second (powerups raise it)
	shot_count: int `gd:"export,range=1:9:1"`, // bullets per volley (spread powerup)

	// The GameState autoload, auto-wired at READY (absolute onready path).
	gs: gd.Object `gd:"onready=/root/GameState"`,

	// runtime
	fire_cd:     f32,
	invuln:      f32, // seconds of post-hit / shield invulnerability left
	slow_factor: f32, // enemies module reads nothing here; kept by powerups on enemies
	field:       gd.Object, // BulletField, resolved from its group
}

@(private = "file")
axis_names_ready: bool
@(private = "file")
left_n, right_n, up_n, down_n: gd.String_Name

player_ready :: proc(self: ^Player) {
	// Zero-guards, not `default=`: game.tscn STORES these exports explicitly (at 0),
	// and a scene-stored value overrides a declared default — the guards must stay.
	// Group membership ("player") is declared by the `//gd:group` marker up top.
	if self.move_speed == 0 {self.move_speed = 320}
	if self.fire_rate == 0 {self.fire_rate = 6}
	if self.shot_count == 0 {self.shot_count = 1}
	gd.node2d_set_position(self.owner, gd.Vector2{480, 560})
}

player_physics_process :: proc(self: ^Player, delta: f64) {
	dt := f32(delta)
	if !axis_names_ready {
		axis_names_ready = true
		left_n = gd.new_string_name_cstring("ui_left", true)
		right_n = gd.new_string_name_cstring("ui_right", true)
		up_n = gd.new_string_name_cstring("ui_up", true)
		down_n = gd.new_string_name_cstring("ui_down", true)
	}
	input := gd.singleton_input()
	dir := gd.Vector2 {
		f32(gd.input_get_axis(input, left_n, right_n)),
		f32(gd.input_get_axis(input, up_n, down_n)),
	}
	pos := gd.node2d_get_position(self.owner)
	pos += dir * self.move_speed * dt
	pos.x = clamp(pos.x, 16, 944)
	pos.y = clamp(pos.y, 16, 704)
	gd.node2d_set_position(self.owner, pos)

	if self.invuln > 0 {self.invuln -= dt}

	// Auto-fire at the nearest enemy (bullet-hell convention: you always shoot).
	self.fire_cd -= dt
	if self.fire_cd <= 0 {
		self.fire_cd = 1.0 / self.fire_rate
		player_fire(self, pos)
	}
}

// player_field — the BulletField lives in an ISOLATED module, so only an engine
// Object handle, resolved from its group once and cached (this runs per shot).
@(private = "file")
player_field :: proc(self: ^Player) -> gd.Object {
	if self.field == nil {
		self.field = gd.first_in_group(self.owner, "bullet_field")
	}
	return self.field
}

@(private = "file")
player_fire :: proc(self: ^Player, pos: gd.Vector2) {
	field := player_field(self)
	if field == nil {return}
	// Aim at the first node in the "enemies" group; straight up when the field is clear.
	target := gd.Vector2{pos.x, pos.y - 100}
	if e := gd.first_in_group(self.owner, "enemies"); e != nil {
		target = gd.node2d_get_position(cast(gd.Node2d)e)
	}
	// Cross-module call by NAME through the engine — the modules contract, spelled
	// gd.vcall: every arg boxed to a Variant automatically, one line, not two per arg.
	// (shot_count bullets, speed 520, spread 0.35 rad, friendly, 1 damage)
	gd.vcall_void(field, "spawn_aimed", pos, target, self.shot_count, 520.0, 0.35, false, 1)
}

// take_damage — the game.tscn [connection] target for BulletField.player_hit. Also the
// enemies' contact-damage entry. Routes through the GameState autoload so score/hp stay
// in ONE place, whatever module dealt the hit.
@(gd_method)
player_take_damage :: proc(self: ^Player, amount: gd.Int) {
	if self.invuln > 0 {return}
	self.invuln = 1.0
	// Through the onready-wired autoload handle; vcall is a quiet no-op if it's absent.
	gd.vcall_void(self.gs, "damage_player", amount)
}

// apply_powerup — called by NAME from the powerups module (see pickup.odin).
// kind: 0=RapidFire 1=Spread 2=Shield (matches PowerupConfig's enum export).
@(gd_method)
player_apply_powerup :: proc(self: ^Player, kind: gd.Int, magnitude: f64) {
	switch int(kind) {
	case 0:
		self.fire_rate = min(self.fire_rate + f32(magnitude), 30)
	case 1:
		self.shot_count = min(self.shot_count + int(magnitude), 9)
	case 2:
		self.invuln = f32(magnitude) // shield: a fat invulnerability window...
		gd.vcall_void(player_field(self), "clear_hostile") // ...plus a screen wipe
	}
}

@(gd_method)
player_get_fire_rate :: proc(self: ^Player) -> f64 {return f64(self.fire_rate)}
