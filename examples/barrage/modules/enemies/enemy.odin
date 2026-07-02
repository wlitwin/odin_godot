//gd:extends Node2D
//gd:class Enemy
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
import rt "godot:runtime"

Enemy :: struct {
	owner: gd.Node2d,

	hp:        int `gd:"export,range=1:60:1"`,
	fire_ivl:  f32 `gd:"export,range=0.2:5:0.1"`, // seconds between volleys
	radius:    f32 `gd:"export,range=6:40:1"`,
	drift:     f32 `gd:"export,range=10:200:5"`, // px/s downward drift

	fire_cd:   f32,
	slow:      f32, // debuff multiplier applied by the powerups module (1 = normal)
	field:     gd.Object,
}

enemy_ready :: proc(self: ^Enemy) {
	if self.hp == 0 {self.hp = 6}
	if self.fire_ivl == 0 {self.fire_ivl = 1.4}
	if self.radius == 0 {self.radius = 14}
	if self.drift == 0 {self.drift = 40}
	self.slow = 1
	self.fire_cd = self.fire_ivl * 0.5
	grp := gd.new_string_name_cstring("enemies", true)
	gd.node_add_to_group(cast(gd.Node)self.owner, grp, false)
	enemy_subscribe_slow(self)
}

// ---- the SlowEnemies debuff, over the Spawner's pure-Odin event ------------

@(private = "file")
enemy_on_slow :: proc(ctx: rawptr, factor: f64) {
	self := cast(^Enemy)ctx
	self.slow = f32(factor) // stretches this enemy's whole timeline (see physics_process)
}

// find_spawner — SAME-module publisher lookup (group + typed script_of; both scripts
// live in this dll, so the direct struct pointer is legal — never do this across
// modules, see docs/events.md).
@(private = "file")
find_spawner :: proc(self: ^Enemy) -> ^Spawner {
	tree := gd.node_get_tree(cast(gd.Node)self.owner)
	if tree == nil {return nil}
	grp := gd.new_string_name_cstring("spawner", true)
	sp := gd.scene_tree_get_first_node_in_group(tree, grp)
	if sp == nil {return nil}
	return rt.script_of(cast(gd.Object)sp, Spawner)
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
		events.unsubscribe_owner(&sp.slow_changed, u64(gd.object_get_instance_id(cast(gd.Object)self.owner)))
	}
}

@(private)
find_field :: proc(node: gd.Node, cache: ^gd.Object) -> gd.Object {
	if cache^ == nil {
		if tree := gd.node_get_tree(node); tree != nil {
			grp := gd.new_string_name_cstring("bullet_field", true)
			cache^ = cast(gd.Object)gd.scene_tree_get_first_node_in_group(tree, grp)
		}
	}
	return cache^
}

@(private)
find_player_pos :: proc(node: gd.Node) -> (gd.Vector2, bool) {
	if tree := gd.node_get_tree(node); tree != nil {
		grp := gd.new_string_name_cstring("player", true)
		if p := gd.scene_tree_get_first_node_in_group(tree, grp); p != nil {
			return gd.node2d_get_position(cast(gd.Node2d)p), true
		}
	}
	return {}, false
}

enemy_physics_process :: proc(self: ^Enemy, delta: f64) {
	dt := f32(delta) * self.slow // the slow debuff stretches this enemy's whole timeline
	pos := gd.node2d_get_position(self.owner)
	pos.y += self.drift * dt
	if pos.y > 780 {pos.y = -40} // wrap: keeps the pressure up without despawn logic
	gd.node2d_set_position(self.owner, pos)

	field := find_field(cast(gd.Node)self.owner, &self.field)
	if field == nil {return}

	// Re-register with the field (id = the engine-wide instance id; update-or-add).
	id := gd.object_get_instance_id(cast(gd.Object)self.owner)
	m := gd.sname("register_enemy")
	idv := gd.Int(id)
	iv := gd.variant_from(&idv)
	pv := gd.variant_from(&pos)
	r := f64(self.radius)
	rv := gd.variant_from(&r)
	_ = gd.object_call(field, m, iv, pv, rv)

	self.fire_cd -= dt
	if self.fire_cd <= 0 {
		self.fire_cd = self.fire_ivl
		if target, ok := find_player_pos(cast(gd.Node)self.owner); ok {
			am := gd.sname("spawn_aimed")
			apv := gd.variant_from(&pos)
			tv := gd.variant_from(&target)
			n := gd.Int(3)
			nv := gd.variant_from(&n)
			spd := f64(180)
			sv := gd.variant_from(&spd)
			spread := f64(0.5)
			spv := gd.variant_from(&spread)
			hostile := gd.Bool(true)
			hv := gd.variant_from(&hostile)
			dmg := gd.Int(1)
			dv := gd.variant_from(&dmg)
			_ = gd.object_call(field, am, apv, tv, nv, sv, spv, hv, dv)
		}
	}
}

// take_hit — routed here by the Spawner from BulletField.enemy_hit. Score + drop
// happen in the Spawner (it owns progression); this just does hp + death.
@(gd_method)
enemy_take_hit :: proc(self: ^Enemy, damage: gd.Int) -> gd.Bool {
	self.hp -= int(damage)
	if self.hp <= 0 {
		if field := find_field(cast(gd.Node)self.owner, &self.field); field != nil {
			m := gd.sname("unregister_enemy")
			id := gd.Int(gd.object_get_instance_id(cast(gd.Object)self.owner))
			iv := gd.variant_from(&id)
			_ = gd.object_call(field, m, iv)
		}
		gd.node_queue_free(cast(gd.Node)self.owner)
		return true // died — the Spawner scores it + may drop a powerup
	}
	return false
}

