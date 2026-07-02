//gd:extends Node2D
//gd:class Spawner
package barrage_enemies

// ----------------------------------------------------------------------------
// Spawner — enemies-module progression: waves of Enemy scenes, then the Boss. It is
// the game.tscn [connection] target for BulletField.enemy_hit and routes damage to
// its children by instance id — the id-keyed contract that keeps the bullets module
// blind to what an "enemy" is. Deaths score through the GameState autoload and roll
// a powerup drop (by name into the powerups module, which is ALSO isolated).
//
// FEATURES: PackedScene exports + runtime instancing, scene [connection] target,
// engine-mediated calls into TWO other modules, wave pacing driven by the shared
// BARRAGE_TEST flag, and a pure-Odin `events.Event` (slow_changed) fanning the
// SlowEnemies debuff out to every live enemy at direct-call cost — the canonical
// shape: the cross-module edge (pickup -> here) is ONE engine call, the
// intra-module one-to-many is the Event (docs/events.md).
// ----------------------------------------------------------------------------

import events "godot:events"
import gd "godot:godot"

Spawner :: struct {
	owner: gd.Node2d,

	enemy_scene: ^gd.Resource `gd:"export,resource=PackedScene"`,
	boss_scene:  ^gd.Resource `gd:"export,resource=PackedScene"`,
	waves_before_boss: int `gd:"export,range=1:10:1"`,
	wave_size:         int `gd:"export,range=1:12:1"`,
	wave_interval:     f32 `gd:"export,range=1:20:0.5"`,

	wave:       int,
	wave_cd:    f32,
	boss:       gd.Object, // nil until spawned
	boss_spawned: bool,
	fast:       bool,
	first_kill: bool, // one-shot console sentinel (web smoke test)
	rng:        u64,

	// Pure-Odin observer: enemies subscribe at spawn (enemy.odin), the powerups module
	// triggers slow_all_enemies with ONE engine call, and the fan-out is direct typed
	// calls — no per-enemy Variant boxing. Same-module only (docs/events.md).
	slow_changed: events.Event(f64),
}

spawner_ready :: proc(self: ^Spawner) {
	if self.waves_before_boss == 0 {self.waves_before_boss = 3}
	if self.wave_size == 0 {self.wave_size = 4}
	if self.wave_interval == 0 {self.wave_interval = 6}
	self.rng = 0x9e3779b97f4a7c15
	grp := gd.new_string_name_cstring("spawner", true)
	gd.node_add_to_group(cast(gd.Node)self.owner, grp, false)
	gs := gd.node_get_node(cast(gd.Node)self.owner, gd.new_node_path_cstring("/root/GameState"))
	if gs != nil {
		m := gd.sname("is_test")
		v := gd.object_call(cast(gd.Object)gs, m)
		self.fast = bool(gd.variant_to_bool(&v))
	}
	if self.fast {self.wave_interval = 0.7}
	self.wave_cd = 0.2
}

@(private = "file")
next_rand :: proc(self: ^Spawner) -> f32 {
	// xorshift* — deterministic drops keep the suite reproducible.
	x := self.rng
	x ~= x >> 12
	x ~= x << 25
	x ~= x >> 27
	self.rng = x
	return f32((x * 0x2545F4914F6CDD1D) >> 40) / f32(1 << 24)
}

spawner_physics_process :: proc(self: ^Spawner, delta: f64) {
	if self.boss_spawned {return}
	self.wave_cd -= f32(delta)
	if self.wave_cd > 0 {return}
	self.wave_cd = self.wave_interval

	if self.wave >= self.waves_before_boss {
		spawner_spawn_boss(self)
		return
	}
	self.wave += 1
	for k in 0 ..< self.wave_size {
		spawner_spawn_enemy(self, gd.Vector2{120 + f32(k) * (720 / f32(self.wave_size)), -30 - 40 * next_rand(self)})
	}
}

@(private = "file")
instance_scene :: proc(scene: ^gd.Resource, parent: gd.Node) -> gd.Node {
	if scene == nil {return nil}
	inst := gd.instantiate(cast(gd.Packed_Scene)scene)
	if inst == nil {return nil}
	// Deferred: waves spawn from _physics_process, where immediate tree adds are illegal.
	gd.add_child_deferred(parent, inst)
	return inst
}

@(private = "file")
spawner_spawn_enemy :: proc(self: ^Spawner, pos: gd.Vector2) {
	if inst := instance_scene(self.enemy_scene, cast(gd.Node)self.owner); inst != nil {
		gd.node2d_set_position(cast(gd.Node2d)inst, pos)
	}
}

@(private = "file")
spawner_spawn_boss :: proc(self: ^Spawner) {
	self.boss_spawned = true
	if inst := instance_scene(self.boss_scene, cast(gd.Node)self.owner); inst != nil {
		self.boss = cast(gd.Object)inst
	}
}

// on_enemy_hit — game.tscn [connection] target for BulletField.enemy_hit(enemy_id,
// damage). Finds the child with that instance id, applies typed damage, scores kills,
// rolls drops, and detects the boss kill (game clear).
@(gd_method)
spawner_on_enemy_hit :: proc(self: ^Spawner, enemy_id: gd.Int, damage: gd.Int) {
	target := gd.gd_instance_from_id(enemy_id)
	if target == nil {return}
	is_boss := self.boss != nil && target == self.boss
	pos := gd.node2d_get_position(cast(gd.Node2d)target)

	m := gd.sname("take_hit")
	d := damage
	dv := gd.variant_from(&d)
	died_v := gd.object_call(cast(gd.Object)target, m, dv)
	if !bool(gd.variant_to_bool(&died_v)) {return}

	// First confirmed kill sentinel: proves the full id round-trip (register -> collide
	// -> enemy_hit signal -> gd_instance_from_id -> take_hit). The web smoke test waits
	// for it — instance ids are 64-bit, and an `int`-typed registry truncated them on
	// wasm32 (enemies were unkillable ONLY on web; ids must stay i64 end to end).
	if !self.first_kill {
		self.first_kill = true
		gd.print_str("BARRAGE_FIRST_KILL")
	}

	gs := gd.node_get_node(cast(gd.Node)self.owner, gd.new_node_path_cstring("/root/GameState"))
	if gs != nil {
		am := gd.sname("add_score")
		pts := gd.Int(is_boss ? 1000 : 50)
		pv := gd.variant_from(&pts)
		_ = gd.object_call(cast(gd.Object)gs, am, pv)
		if is_boss {
			cm := gd.sname("set_cleared")
			_ = gd.object_call(cast(gd.Object)gs, cm)
		}
	}
	if is_boss {
		self.boss = nil
		return
	}
	// 35% powerup drop — into the powerups module, by name via its group.
	if next_rand(self) < 0.35 {
		if tree := gd.node_get_tree(cast(gd.Node)self.owner); tree != nil {
			grp := gd.new_string_name_cstring("powerup_manager", true)
			if mgr := gd.scene_tree_get_first_node_in_group(tree, grp); mgr != nil {
				dm := gd.sname("spawn_drop")
				posv := gd.variant_from(&pos)
				_ = gd.object_call(cast(gd.Object)mgr, dm, posv)
			}
		}
	}
}

// get_boss_phase — the HUD's and the suite driver's window into the fight (0 = no boss
// yet; the Boss's own phase after that).
@(gd_method)
spawner_get_boss_phase :: proc(self: ^Spawner) -> gd.Int {
	if self.boss == nil {return 0}
	m := gd.sname("get_phase")
	v := gd.object_call(self.boss, m)
	return gd.Int(gd.variant_to_int(&v))
}

// slow_all_enemies — the ONE cross-module engine entry for the SlowEnemies powerup
// (pickup.odin calls it by name). The per-enemy fan-out happens on the pure-Odin
// slow_changed event: direct typed calls into every subscribed Enemy, zero boxing.
@(gd_method)
spawner_slow_all_enemies :: proc(self: ^Spawner, factor: f64) {
	events.emit(&self.slow_changed, factor)
}

// The publisher owns the subscriber list — free it when the spawner leaves the tree
// (scene switch / game over). Enemies unsubscribe themselves first (their exit_tree
// runs as the same teardown drains), but destroy is safe regardless.
spawner_exit_tree :: proc(self: ^Spawner) {
	events.destroy(&self.slow_changed)
}
