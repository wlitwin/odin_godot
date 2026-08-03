//gd:extends Node2D
//gd:class Spawner
//gd:group spawner
package barrage_enemies

// ----------------------------------------------------------------------------
// Spawner — enemies-module progression: waves of Enemy scenes, then the Boss. It is
// the game.tscn [connection] target for BulletField.enemy_hit and routes damage to
// its children by instance id — the id-keyed contract that keeps the bullets module
// blind to what an "enemy" is. Deaths score through the GameState autoload and roll
// a powerup drop (by name into the powerups module, which is ALSO isolated).
//
// FEATURES: PackedScene exports + typed spawning (rt.spawn_as_deferred — Enemy/Boss
// live in THIS module, so the spawn comes back as a struct pointer), scene
// [connection] target, gd.vcall by-name calls into TWO other modules, wave pacing on
// play.every driven by the shared BARRAGE_TEST flag, and a pure-Odin `events.Event`
// (slow_changed) fanning the SlowEnemies debuff out to every live enemy at
// direct-call cost — the canonical shape: the cross-module edge (pickup -> here) is
// ONE engine call, the intra-module one-to-many is the Event (docs/events.md).
// ----------------------------------------------------------------------------

import events "godot:events"
import gd "godot:godot"
import "godot:play"
import rt "godot:runtime"

Spawner :: struct {
	owner: gd.Node2d,

	enemy_scene: ^gd.Resource `gd:"export,resource=PackedScene"`,
	boss_scene:  ^gd.Resource `gd:"export,resource=PackedScene"`,
	waves_before_boss: int `gd:"export,range=1:10:1"`,
	wave_size:         int `gd:"export,range=1:12:1"`,
	wave_interval:     f32 `gd:"export,range=1:20:0.5"`,

	// The GameState autoload, auto-wired ONCE at READY (absolute onready path).
	gs: gd.Object `gd:"onready=/root/GameState"`,

	wave:       int,
	wave_cd:    f32, // play.every accumulator (counts UP toward wave_interval)
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
	// Zero-guards, not `default=`: game.tscn STORES these exports explicitly (at 0),
	// and a scene-stored value overrides a declared default — the guards must stay.
	if self.waves_before_boss == 0 {self.waves_before_boss = 3}
	if self.wave_size == 0 {self.wave_size = 4}
	if self.wave_interval == 0 {self.wave_interval = 6}
	self.rng = 0x9e3779b97f4a7c15
	// Group membership ("spawner") is declared by the `//gd:group` marker up top.
	self.fast = gd.vcall_bool(self.gs, "is_test")
	if self.fast {self.wave_interval = 0.7}
	// Seed the accumulator so the FIRST wave lands 0.2s in (play.every fires when the
	// accumulated dt reaches wave_interval).
	self.wave_cd = self.wave_interval - 0.2
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
	// Wave cadence: the subtract/compare/reset accumulator, as one play.every line.
	if !play.every(&self.wave_cd, f32(delta), self.wave_interval) {return}

	if self.wave >= self.waves_before_boss {
		spawner_spawn_boss(self)
		return
	}
	self.wave += 1
	for k in 0 ..< self.wave_size {
		spawner_spawn_enemy(self, gd.Vector2{120 + f32(k) * (720 / f32(self.wave_size)), -30 - 40 * next_rand(self)})
	}
}

// Enemy and Boss are THIS module's classes, so spawning is typed: rt.spawn_as_deferred
// instantiates, parents via add_child_deferred (waves spawn from _physics_process,
// where immediate tree adds are illegal), and hands back the script struct — position
// pokes land before the deferred _ready runs.

@(private = "file")
spawner_spawn_enemy :: proc(self: ^Spawner, pos: gd.Vector2) {
	if e := rt.spawn_as_deferred(self.owner, cast(gd.Packed_Scene)self.enemy_scene, Enemy); e != nil {
		gd.node2d_set_position(e.owner, pos)
	}
}

@(private = "file")
spawner_spawn_boss :: proc(self: ^Spawner) {
	self.boss_spawned = true
	if b := rt.spawn_as_deferred(self.owner, cast(gd.Packed_Scene)self.boss_scene, Boss); b != nil {
		self.boss = b.owner
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

	if !gd.vcall_bool(target, "take_hit", damage) {return}

	// First confirmed kill sentinel: proves the full id round-trip (register -> collide
	// -> enemy_hit signal -> gd_instance_from_id -> take_hit). The web smoke test waits
	// for it — instance ids are 64-bit, and an `int`-typed registry truncated them on
	// wasm32 (enemies were unkillable ONLY on web; ids must stay i64 end to end).
	if !self.first_kill {
		self.first_kill = true
		gd.print_str("BARRAGE_FIRST_KILL")
	}

	// Score through the autoload (onready-cached handle; vcall is nil-quiet).
	gd.vcall_void(self.gs, "add_score", is_boss ? 1000 : 50)
	if is_boss {
		gd.vcall_void(self.gs, "set_cleared")
		self.boss = nil
		return
	}
	// 35% powerup drop — into the powerups module, by name via its group.
	if next_rand(self) < 0.35 {
		if mgr := gd.first_in_group(self.owner, "powerup_manager"); mgr != nil {
			gd.vcall_void(mgr, "spawn_drop", pos)
		}
	}
}

// get_boss_phase — the HUD's and the suite driver's window into the fight (0 = no boss
// yet: vcall on a nil handle is a quiet zero, so the pre-spawn state needs no guard).
@(gd_method)
spawner_get_boss_phase :: proc(self: ^Spawner) -> gd.Int {
	return gd.Int(gd.vcall_int(self.boss, "get_phase"))
}

// slow_all_enemies — the ONE cross-module engine entry for the SlowEnemies powerup
// (pickup.odin vcalls it by name). The per-enemy fan-out happens on the pure-Odin
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
