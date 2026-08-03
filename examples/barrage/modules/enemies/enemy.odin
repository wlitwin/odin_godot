//gd:extends Node2D
//gd:class Enemy
//gd:group enemies
package barrage_enemies

// ----------------------------------------------------------------------------
// Enemy — a drifting shooter (enemies MODULE). No physics body: it re-registers its
// position with the BulletField every physics tick (the field does the circle math),
// drifts toward the player's half of the screen, and fires aimed volleys on a timer.
// Damage arrives from the Spawner (which owns the field's `enemy_hit` signal) via
// the typed `take_hit` @(gd_method). The SlowEnemies debuff arrives on the Spawner's
// pure-Odin `slow_changed` event (docs/events.md) — subscribed at ready, unsubscribed
// at exit_tree (covers death), resubscribed in the reload hook.
// ----------------------------------------------------------------------------

import events "godot:events"
import gd "godot:godot"
import "godot:play"
import rt "godot:runtime"

Enemy :: struct {
	owner:    gd.Node2d,
	hp:       int `gd:"export,range=1:60:1"`,
	fire_ivl: f32 `gd:"export,range=0.2:5:0.1"`, // seconds between volleys
	radius:   f32 `gd:"export,range=6:40:1"`,
	drift:    f32 `gd:"export,range=10:200:5"`, // px/s downward drift
	fire_cd:  f32,
	slow:     f32, // debuff multiplier applied by the powerups module (1 = normal)
	field:    gd.Object,
}

enemy_ready :: proc(self: ^Enemy) {
	// Zero-guards, not `default=`: enemy.tscn STORES these exports explicitly (at 0), and
	// a scene-stored value overrides a declared default — the guards must stay.
	if self.hp == 0 {self.hp = 6}
	if self.fire_ivl == 0 {self.fire_ivl = 1.4}
	if self.radius == 0 {self.radius = 14}
	if self.drift == 0 {self.drift = 40}
	self.slow = 1
	// Group membership is declarative (`//gd:group enemies` up top). Seed the fire
	// accumulator half an interval in so the first volley comes at fire_ivl/2.
	self.fire_cd = self.fire_ivl * 0.5
	enemy_subscribe_slow(self)
}

// ---- the SlowEnemies debuff, over the Spawner's pure-Odin event ------------

@(private = "file")
enemy_on_slow :: proc(ctx: rawptr, factor: f64) {
	self := cast(^Enemy)ctx
	self.slow = f32(factor) // stretches this enemy's whole timeline (see physics_process)
}

// find_spawner — SAME-module publisher lookup: the typed group query. Both scripts live
// in this dll, so the direct struct pointer is legal — never do this across modules,
// see docs/events.md.
@(private = "file")
find_spawner :: proc(self: ^Enemy) -> ^Spawner {
	return rt.first_script_in_group(self.owner, "spawner", Spawner)
}

// The documented resubscribe pattern (events.odin header): owner-tagged, idempotent,
// shared by ready AND the hot-reload hook so a dll swap refreshes the proc pointers.
@(private = "file")
enemy_subscribe_slow :: proc(self: ^Enemy) {
	sp := find_spawner(self)
	if sp == nil {return}
	id := u64(gd.object_get_instance_id(cast(gd.Object)self.owner))
	events.unsubscribe_owner(&sp.slow_changed, id)
	events.subscribe(&sp.slow_changed, self, enemy_on_slow, id)
}

enemy_reload :: proc(self: ^Enemy) {
	enemy_subscribe_slow(self)
}

// exit_tree covers every way an enemy dies (take_hit's queue_free, scene switch):
// the subscription holds a raw pointer to THIS struct, so it must not outlive it.
enemy_exit_tree :: proc(self: ^Enemy) {
	if sp := find_spawner(self); sp != nil {
		events.unsubscribe_owner(
			&sp.slow_changed,
			u64(gd.object_get_instance_id(cast(gd.Object)self.owner)),
		)
	}
}

// find_field — the CROSS-module lookup (BulletField lives in another dll, so only an
// engine Object handle, never a typed struct). Cached per instance: this runs every
// physics tick, so pay the group query once, not per frame.
@(private)
find_field :: proc(node: gd.Node, cache: ^gd.Object) -> gd.Object {
	if cache^ == nil {
		cache^ = gd.first_in_group(node, "bullet_field")
	}
	return cache^
}

@(private)
find_player_pos :: proc(node: gd.Node) -> (gd.Vector2, bool) {
	if p := gd.first_in_group(node, "player"); p != nil {
		return gd.node2d_get_position(cast(gd.Node2d)p), true
	}
	return {}, false
}

enemy_physics_process :: proc(self: ^Enemy, delta: f64) {
	dt := f32(delta) * self.slow // the slow debuff stretches this enemy's whole timeline
	pos := gd.node2d_get_position(self.owner)
	pos.y += self.drift * dt
	if pos.y > 780 {pos.y = -40} 	// wrap: keeps the pressure up without despawn logic
	gd.node2d_set_position(self.owner, pos)

	field := find_field(self.owner, &self.field)
	if field == nil {return}

	// Re-register with the field (id = the engine-wide instance id; update-or-add).
	// Cross-module call by NAME: gd.vcall converts each Odin arg to a Variant for us.
	id := gd.object_get_instance_id(self.owner)
	gd.vcall_void(field, "register_enemy", gd.Int(id), pos, f64(self.radius))

	// Fire cadence: play.every accumulates dt (here pre-scaled by the slow debuff) and
	// fires once per fire_ivl, carrying the remainder.
	if play.every(&self.fire_cd, dt, self.fire_ivl) {
		if target, ok := find_player_pos(self.owner); ok {
			// n=3 bullets, speed 180, spread 0.5 rad, hostile, 1 damage.
			gd.vcall_void(field, "spawn_aimed", pos, target, 3, 180.0, 0.5, true, 1)
		}
	}
}

// take_hit — routed here by the Spawner from BulletField.enemy_hit. Score + drop
// happen in the Spawner (it owns progression); this just does hp + death.
@(gd_method)
enemy_take_hit :: proc(self: ^Enemy, damage: gd.Int) -> gd.Bool {
	self.hp -= int(damage)
	if self.hp <= 0 {
		if field := find_field(self.owner, &self.field); field != nil {
			gd.vcall_void(field, "unregister_enemy", gd.Int(gd.object_get_instance_id(self.owner)))
		}
		gd.node_queue_free(self.owner)
		return true // died — the Spawner scores it + may drop a powerup
	}
	return false
}

