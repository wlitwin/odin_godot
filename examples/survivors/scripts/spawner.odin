//gd:extends Node2D
//gd:class Spawner
package survivors_scripts

// ----------------------------------------------------------------------------
// Spawner — streams enemies in from the arena edges, RAMPING with elapsed run-time: the spawn
// interval shrinks over time, and the enemy-type MIX shifts from weak/fast toward tough/varied
// as the run goes on (a weighted pick over four EnemyConfigs).
//
// FEATURES:
//   * @export PackedScene + four EnemyConfig slots — the spawn template + the type pool.
//   * difficulty scaling                            — interval_at(t) / weights from game_state's
//                                                      run_time (the shared module).
//   * typed spawn (rt.spawn_scripted)                — poke-before-add: assigns the chosen
//                                                      config onto the fresh enemy BEFORE
//                                                      add_child, so its _ready reads the
//                                                      right stats.
//   * play.every                                     — the spawn cadence accumulator as one
//                                                      call (period = the live curve).
//   * @(gd_method) interval_at                        — exposes the difficulty curve so the test
//                                                       can assert it scales.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"
import play "godot:play"
import "core:math"
import "core:math/rand"

ARENA_W :: 640
ARENA_H :: 360
EDGE_INSET :: 16

Spawner :: struct {
	owner:       gd.Node2d,
	enemy_scene: ^gd.Resource `gd:"export,resource=PackedScene"`, // enemy.tscn
	swarmer:     ^gd.Resource `gd:"export,resource=EnemyConfig,group=Enemy Pool"`,
	grunt:       ^gd.Resource `gd:"export,resource=EnemyConfig"`,
	brute:       ^gd.Resource `gd:"export,resource=EnemyConfig"`,
	tank:        ^gd.Resource `gd:"export,resource=EnemyConfig"`,

	accum: f32, // play.every's accumulator (plain untagged field — private, not exported)
}

// interval_at — seconds between spawns at run-time `t`. Starts ~0.9s and ramps down toward a
// floor of 0.16s, so the swarm thickens. A pure function of t -> the test asserts it shrinks.
@(gd_method)
spawner_interval_at :: proc(self: ^Spawner, t: f64) -> f64 {
	base := 0.9
	v := base - f64(t) * 0.006
	if v < 0.16 {v = 0.16}
	return v
}

spawner_process :: proc(self: ^Spawner, delta: f64) {
	if game_state_get_state() != .Playing {return}
	t := game_state_get_run_time()
	// play.every collapses the accumulate/compare/reset dance to one call; the period (the
	// live difficulty curve) may change between calls, and the remainder carries so a long
	// frame doesn't lose spawn time.
	if play.every(&self.accum, f32(delta), f32(spawner_interval_at(self, t))) {
		spawner_spawn_one(self, t)
	}
}

// weighted enemy pick. `t` (seconds) shifts the mix: swarmers/grunts dominate early; brutes
// and tanks grow more common as the run goes on.
@(private = "file")
spawner_pick_config :: proc(self: ^Spawner, t: f64) -> ^gd.Resource {
	tf := f32(t)
	w_swarm := math.max(f32(0), 4.0 - tf * 0.02)
	w_grunt := f32(3.0)
	w_brute := math.min(f32(5), tf * 0.02)
	w_tank := math.min(f32(4), math.max(f32(0), (tf - 45.0) * 0.02))
	total := w_swarm + w_grunt + w_brute + w_tank
	r := rand.float32_range(0, total)
	if r < w_swarm && self.swarmer != nil {return self.swarmer}
	r -= w_swarm
	if r < w_grunt && self.grunt != nil {return self.grunt}
	r -= w_grunt
	if r < w_brute && self.brute != nil {return self.brute}
	if self.tank != nil {return self.tank}
	if self.grunt != nil {return self.grunt}
	return self.swarmer
}

@(private = "file")
spawner_spawn_one :: proc(self: ^Spawner, t: f64) {
	if self.enemy_scene == nil {return}
	arena := gd.get_parent(self.owner)
	if arena == nil {return}

	// Typed spawn, poke-BEFORE-add: rt.spawn_scripted resolves the typed ref WITHOUT
	// parenting, so the chosen EnemyConfig is assigned before the enemy enters the tree —
	// its _ready reads the right stats.
	enemy, es := rt.spawn_scripted(cast(gd.Packed_Scene)self.enemy_scene, Enemy)
	if enemy == nil {return}
	cfg := spawner_pick_config(self, t)
	if cfg != nil && es != nil {es.config = cfg}

	gd.add_child(arena, enemy)
	gd.node2d_set_global_position(cast(gd.Node2d)enemy, random_edge_point())
}

@(private = "file")
random_edge_point :: proc() -> gd.Vector2 {
	switch rand.int31() % 4 {
	case 0:
		return gd.Vector2{rand.float32_range(0, ARENA_W), EDGE_INSET}
	case 1:
		return gd.Vector2{rand.float32_range(0, ARENA_W), ARENA_H - EDGE_INSET}
	case 2:
		return gd.Vector2{EDGE_INSET, rand.float32_range(0, ARENA_H)}
	case:
		return gd.Vector2{ARENA_W - EDGE_INSET, rand.float32_range(0, ARENA_H)}
	}
}
