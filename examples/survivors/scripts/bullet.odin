//gd:extends Area2D
//gd:class Bullet
package survivors_scripts

// ----------------------------------------------------------------------------
// Bullet — an Area2D projectile a Projectile weapon fires. It flies straight (direction set
// at spawn), damages enemies it overlaps, and can PIERCE several before despawning; it also
// self-destructs after a short lifetime so stray shots do not accumulate.
//
// FEATURES: `@export` damage/speed/pierce; lifecycle `_physics_process`; `@(gd_connect)` on
// area_entered; typed cross-script (rt.script_of -> Enemy) so it only damages real enemies.
//
// `dir`, `damage`, `speed` and `pierce` are all set TYPED by the weapon right after spawn.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

BULLET_LIFETIME :: 1.4

Bullet :: struct {
	owner:  gd.Area2d,
	damage: int `gd:"export"`,
	speed:  f32 `gd:"export"`,
	pierce: int `gd:"export"`, // extra enemies this bullet passes through before dying

	// runtime state:
	dir:  gd.Vector2, // unit travel direction, set by the weapon at spawn
	life: f32,
}

bullet_ready :: proc(self: ^Bullet) {
	if self.damage == 0 {self.damage = 1}
	if self.speed == 0 {self.speed = 460}
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

// on_hit — wired to our own `area_entered` by `@(gd_connect)`. Damage a real Enemy (typed),
// then spend one pierce; out of pierce -> despawn. Non-enemies (another bullet, a gem) yield
// nil and are ignored.
@(gd_method, gd_connect = "area_entered")
bullet_on_hit :: proc(self: ^Bullet, area: gd.Area2d) {
	enemy := rt.script_of(area, Enemy)
	if enemy == nil {return}
	enemy_take_damage(enemy, self.damage)
	if self.pierce <= 0 {
		gd.node_queue_free(self.owner)
		return
	}
	self.pierce -= 1
}
