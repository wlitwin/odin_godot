//gd:extends Node2D
//gd:class Spawner
package survivors_scripts

// ----------------------------------------------------------------------------
// Spawner — drips enemies into the arena from random edge positions on a fixed interval.
//
// FEATURES:
//   * @export of a PACKED SCENE  — `enemy_scene` is an enemy.tscn picker.
//   * @export tunable interval    — seconds between spawns.
//   * timed spawning              — a simple delta accumulator in _process (no Timer node /
//                                   signal wiring needed, and easy to read).
//   * gd.* instancing             — gd.instantiate + gd.add_child to drop a new enemy in.
//
// New enemies are parented to the Spawner's PARENT (the arena root), not the Spawner, so
// the scene tree stays flat and enemies are siblings of the player.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import "core:math/rand"

// Arena bounds enemies spawn along the edges of (matches the 640x360 viewport, with a small
// inset so they appear fully on-screen).
ARENA_W :: 640
ARENA_H :: 360
EDGE_INSET :: 16

Spawner :: struct {
	owner:       gd.Node2d,
	enemy_scene: ^gd.Resource `gd:"export,resource=PackedScene"`, // enemy.tscn
	new2_scene: ^gd.Resource `gd:"export,resource=PackedScene"`,
	interval:    f32          `gd:"export"`, // seconds between spawns

	accum: f32, // time accumulated since the last spawn
}

spawner_ready :: proc(self: ^Spawner) {
	if self.interval == 0 {self.interval = 1.2}
}

spawner_process :: proc(self: ^Spawner, delta: f64) {
	self.accum += f32(delta)
	if self.accum < self.interval {return}
	self.accum = 0
	spawner_spawn_one(self)
}

@(private = "file")
spawner_spawn_one :: proc(self: ^Spawner) {
	if self.enemy_scene == nil {return}
	arena := gd.get_parent(self.owner)
	if arena == nil {return}

	enemy := gd.instantiate(cast(gd.Packed_Scene)self.enemy_scene)
	if enemy == nil {return}
	gd.add_child(arena, enemy)
	gd.node2d_set_global_position(cast(gd.Node2d)enemy, random_edge_point())
}

// random_edge_point picks a random point on one of the four arena edges. (A normal proc,
// not "contextless", because core:math/rand uses the context's random state.)
@(private = "file")
random_edge_point :: proc() -> gd.Vector2 {
	switch rand.int31() % 4 {
	case 0:
		return gd.Vector2{rand.float32_range(0, ARENA_W), EDGE_INSET} // top
	case 1:
		return gd.Vector2{rand.float32_range(0, ARENA_W), ARENA_H - EDGE_INSET} // bottom
	case 2:
		return gd.Vector2{EDGE_INSET, rand.float32_range(0, ARENA_H)} // left
	case:
		return gd.Vector2{ARENA_W - EDGE_INSET, rand.float32_range(0, ARENA_H)} // right
	}
}
