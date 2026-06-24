//gd:extends CharacterBody2D
//gd:class Player
//gd:signal health_changed(value: int)
//gd:signal died()
package survivors_scripts

// ----------------------------------------------------------------------------
// Player — the hero. Arrow keys move it; it auto-fires at the nearest enemy; contact with
// an enemy hurts it; at 0 HP the run ends.
//
// FEATURES:
//   * INPUT          — reads the real ui_left/right/up/down axes (Input.get_axis) in _process.
//   * @export incl. a PACKED SCENE  — speed (range hint), max_health, fire_rate, and a
//                                     bullet_scene PackedScene picker.
//   * gd.* instancing               — instantiates bullet_scene and parents it into the arena.
//   * groups + typed cross-script   — finds the nearest "enemies" member (util.nearest_enemy)
//                                     and aims a bullet at it, setting bullet.dir TYPED.
//   * custom @(gd_method)           — take_damage, called TYPED by an enemy on contact.
//   * script-declared signals       — health_changed(value) and died(), consumed by the HUD.
//   * shared module                 — resets game_state on _ready, ends it on death.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

Player :: struct {
	owner:        gd.Node2d, // base is CharacterBody2D (a Node2d)
	speed:        f32          `gd:"export,range=60:400:10"`, // move speed (px/s)
	max_health:   int          `gd:"export"`, // starting / maximum HP
	fire_rate:    f32          `gd:"export"`, // seconds between shots
	bullet_scene: ^gd.Resource `gd:"export,resource=PackedScene"`, // bullet.tscn

	// runtime state:
	health:   int,
	cooldown: f32, // seconds until we may fire again
}

// ---- cached input action names (StringNames are interned once, like in the showcase) ----
@(private = "file")
left_name: gd.String_Name
@(private = "file")
right_name: gd.String_Name
@(private = "file")
up_name: gd.String_Name
@(private = "file")
down_name: gd.String_Name
@(private = "file")
names_ready: bool

@(private = "file")
ensure_names :: proc "contextless" () {
	if names_ready {return}
	left_name = gd.new_string_name_cstring("ui_left", true)
	right_name = gd.new_string_name_cstring("ui_right", true)
	up_name = gd.new_string_name_cstring("ui_up", true)
	down_name = gd.new_string_name_cstring("ui_down", true)
	names_ready = true
}

player_ready :: proc(self: ^Player) {
	if self.speed == 0 {self.speed = 200}
	if self.max_health == 0 {self.max_health = 100}
	if self.fire_rate == 0 {self.fire_rate = 0.35}

	self.health = self.max_health
	self.cooldown = 0

	// Fresh run: zero the shared score + clear the game-over flag.
	game_state_reset()

	// Join the "player" group so enemies (enemy.odin) and the HUD can find us by group.
	gd.add_to_group(self.owner, GROUP_PLAYER)
}

player_process :: proc(self: ^Player, delta: f64) {
	ensure_names()

	// ---- movement: read the real input axes and translate (a kinematic move) ----
	input := gd.singleton_input()
	dx := f32(gd.input_get_axis(input, left_name, right_name))
	dy := f32(gd.input_get_axis(input, up_name, down_name))
	pos := gd.node2d_get_position(self.owner)
	pos.x += dx * self.speed * f32(delta)
	pos.y += dy * self.speed * f32(delta)
	gd.node2d_set_position(self.owner, pos)

	// ---- auto-fire at the nearest enemy, gated by fire_rate ----
	if self.cooldown > 0 {self.cooldown -= f32(delta)}
	if self.cooldown <= 0 && self.health > 0 {
		origin := gd.node2d_get_global_position(self.owner)
		target, ok := nearest_enemy(self.owner, origin)
		if ok {
			player_fire(self, target)
			self.cooldown = self.fire_rate
		}
	}
}

// player_fire instantiates bullet_scene into the arena (the player's parent, so bullets do
// not move with the player), places it on the player, and aims it at `target` by setting the
// bullet's `dir` field TYPED. (A plain helper — no @(gd_method) — so scriptgen leaves it be.)
@(private = "file")
player_fire :: proc(self: ^Player, target: gd.Node2d) {
	if self.bullet_scene == nil {return}
	arena := gd.get_parent(self.owner)
	if arena == nil {return}

	bullet := gd.instantiate(cast(gd.Packed_Scene)self.bullet_scene)
	if bullet == nil {return}
	gd.add_child(arena, bullet)

	origin := gd.node2d_get_global_position(self.owner)
	aim := gd.node2d_get_global_position(target)
	gd.node2d_set_global_position(cast(gd.Node2d)bullet, origin)

	// Typed cross-script WRITE: aim the bullet by setting its struct field directly.
	bs := rt.script_of(bullet, Bullet)
	if bs != nil {
		bs.dir = normalized(gd.Vector2{aim.x - origin.x, aim.y - origin.y})
	}
}

// take_damage — custom method; an enemy calls it TYPED on contact (enemy.odin). Emits
// health_changed every hit; on reaching 0 HP it emits `died` and ends the run.
@(gd_method)
player_take_damage :: proc(self: ^Player, amount: int) {
	if self.health <= 0 {return} // already dead — ignore further hits
	self.health -= amount
	if self.health < 0 {self.health = 0}
	player_emit_health_changed(self, i64(self.health)) // generated typed emitter
	if self.health == 0 {
		player_emit_died(self)
		game_state_set_game_over() // shared-module write
	}
}
