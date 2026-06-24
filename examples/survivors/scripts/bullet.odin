//gd:extends Area2D
//gd:class Bullet
package survivors_scripts

// ----------------------------------------------------------------------------
// Bullet — an Area2D projectile the player fires. It flies in a straight line set at spawn,
// damages the first Enemy it overlaps, then frees itself; it also self-destructs after a
// short lifetime so stray shots do not accumulate.
//
// FEATURES:
//   * @export damage / speed             — tunable per scene in the Inspector.
//   * lifecycle _physics_process          — integrates position each tick.
//   * @(gd_connect="area_entered")        — auto-wires the overlap signal to `on_hit`.
//   * typed cross-script (rt.script_of)   — identifies an Enemy and calls its take_damage
//                                           directly, with no Variant marshaling.
//
// `dir` is plain runtime state (not exported): the player sets it TYPED right after spawn
// (bullet.dir = aim) — see player.odin.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

// How long (seconds) a bullet lives before despawning if it hits nothing.
BULLET_LIFETIME :: 1.5

Bullet :: struct {
	owner:  gd.Area2d,
	damage: int `gd:"export"`,
	speed:  f32 `gd:"export"`,

	// runtime state:
	dir:  gd.Vector2, // unit travel direction, set by the player at spawn
	life: f32, // seconds alive so far
}

bullet_ready :: proc(self: ^Bullet) {
	if self.damage == 0 {self.damage = 1}
	if self.speed == 0 {self.speed = 420}
}

bullet_physics_process :: proc(self: ^Bullet, delta: f64) {
	pos := gd.node2d_get_global_position(self.owner)
	pos.x += self.dir.x * self.speed * f32(delta)
	pos.y += self.dir.y * self.speed * f32(delta)
	gd.node2d_set_global_position(self.owner, pos)

	self.life += f32(delta)
	if self.life >= BULLET_LIFETIME {
		gd.node_queue_free(self.owner)
	}
}

// on_hit — wired to our own `area_entered` by `@(gd_connect="area_entered")`. The other
// area is whatever we overlapped; if it carries an Odin Enemy script we damage it (TYPED)
// and free ourselves. Non-enemies (e.g. another bullet) yield a nil ^Enemy and are ignored,
// so a bullet only ever dies on a real hit.
@(gd_method, gd_connect = "area_entered")
bullet_on_hit :: proc(self: ^Bullet, area: gd.Area2d) {
	enemy := rt.script_of(area, Enemy)
	if enemy == nil {return}
	enemy_take_damage(enemy, self.damage) // typed cross-script METHOD call
	gd.node_queue_free(self.owner)
}
