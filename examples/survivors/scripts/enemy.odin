//gd:extends Area2D
//gd:class Enemy
//gd:signal died()
package survivors_scripts

// ----------------------------------------------------------------------------
// Enemy — an Area2D that reads its stats from an EnemyConfig resource, chases the player,
// takes damage from bullets, and damages the player on contact.
//
// It is the densest feature showcase in the project:
//   * @export of a CUSTOM RESOURCE  — `config` is an EnemyConfig picker slot.
//   * typed cross-script READ        — rt.script_of(config, EnemyConfig) reads the data asset
//                                       with no Variant marshaling.
//   * groups                         — joins "enemies" so the player's auto-aim can find it.
//   * lifecycle _physics_process     — chases the player every physics tick.
//   * custom @(gd_method) take_damage — bullets call this (typed, see bullet.odin).
//   * @(gd_connect) signal wiring     — body_entered auto-connects to `on_body`.
//   * typed cross-script WRITE        — on contact it calls the player's take_damage typed.
//   * script-declared signal          — emits `died` so listeners (e.g. VFX) can react.
//
// Why an Area2D (not a CharacterBody2D)? An Area2D gives us `body_entered` (fires for the
// player's CharacterBody2D) for contact damage, and is itself detected by the bullet's
// `area_entered`. We still move it ourselves in _physics_process — a "kinematic" chase.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

// Damage dealt to the player each time an enemy touches it.
CONTACT_DAMAGE :: 10

Enemy :: struct {
	owner:  gd.Area2d,
	config: ^gd.Resource `gd:"export,resource=EnemyConfig"`, // an EnemyConfig .tres slot

	// runtime state, copied from `config` on _ready (untagged -> private per-instance):
	hp:     int,
	speed:  f32,
	points: int,
	dead:   bool, // guard so take_damage only kills (frees) us once
}

enemy_ready :: proc(self: ^Enemy) {
	// Default stats, in case no config was assigned in the Inspector.
	self.hp = 3
	self.speed = 60
	self.points = 1

	// Typed cross-script READ: turn the assigned Resource into a real ^EnemyConfig and read
	// its fields directly. `self.config`'s bits ARE the resource object pointer, so we hand
	// it to rt.script_of as an Object. nil if the slot is empty / not an EnemyConfig.
	cfg := rt.script_of(cast(gd.Object)self.config, EnemyConfig)
	if cfg != nil {
		self.hp = int(cfg.hp)
		self.speed = cfg.speed
		self.points = int(cfg.points)
		// Tint the body Polygon2D to the config's color.
		body := gd.get_node(self.owner, "Body")
		if body != nil {
			gd.polygon2d_set_color(cast(gd.Polygon2d)body, cfg.color)
		}
	}

	// Join the "enemies" group so the player's auto-aim (util.nearest_enemy) can find us.
	gd.add_to_group(self.owner, GROUP_ENEMIES)
}

// Chase the player every physics tick: step our position toward the player's by speed*delta.
enemy_physics_process :: proc(self: ^Enemy, delta: f64) {
	if self.dead {return}
	player := find_player(self.owner)
	if player == nil {return}

	me := gd.node2d_get_global_position(self.owner)
	target := gd.node2d_get_global_position(player)
	dir := normalized(gd.Vector2{target.x - me.x, target.y - me.y})
	me.x += dir.x * self.speed * f32(delta)
	me.y += dir.y * self.speed * f32(delta)
	gd.node2d_set_global_position(self.owner, me)
}

// take_damage — a custom method. Bullets call it TYPED (enemy_take_damage(enemy, dmg)) for
// zero-overhead dispatch; it is also a @(gd_method) so it is callable from GDScript/tools.
// On lethal damage it banks the score, emits `died`, and frees itself.
@(gd_method)
enemy_take_damage :: proc(self: ^Enemy, amount: int) {
	if self.dead {return}
	self.hp -= amount
	if self.hp <= 0 {
		self.dead = true
		game_state_add_score(gd.Int(self.points)) // shared-module write
		enemy_emit_died(self) // generated from //gd:signal died()
		gd.node_queue_free(self.owner)
	}
}

// on_body — wired to our own `body_entered` by `@(gd_connect="body_entered")` (scriptgen
// emits the connect on _ready; no manual wiring). When the player's body overlaps us, hand
// it CONTACT_DAMAGE through a TYPED ^Player reference (typed cross-script WRITE).
@(gd_method, gd_connect = "body_entered")
enemy_on_body :: proc(self: ^Enemy, body: gd.Node2d) {
	if self.dead {return}
	player := rt.script_of(body, Player)
	if player != nil {
		player_take_damage(player, CONTACT_DAMAGE)
	}
}
