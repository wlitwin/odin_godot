package survivors_scripts

// ----------------------------------------------------------------------------
// util — small shared helpers used by several scripts. Like game_state.odin this file has NO
// owner-struct, so scriptgen skips it; it is plain package-level Odin.
//
// FEATURE: groups as a lightweight, decoupled "find that kind of thing" query — no node
// paths, no singletons. A node declares its groups at the top of its file (`//gd:group`);
// any other script then finds the group's members through the SceneTree:
//   * find_player / find_game     — the single player / game-root, by group.
//   * damage_enemies_in_radius    — area damage for the Orbit / Aura weapons, built on the
//                                   radius query gd.nodes_in_group_within (typed via
//                                   rt.script_of).
// (Auto-aim's closest-member scan is a built-in now — the weapon calls gd.nearest_in_group
// directly — and so is unit-length math: gd.normalized.)
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"
import "core:math"
import "core:math/rand"

GROUP_PLAYER :: "player"
GROUP_ENEMIES :: "enemies"
GROUP_GAME :: "game"

// find_player returns the player node (it joins GROUP_PLAYER on _ready), or nil. `from` is
// any node in the tree — we only use it to reach the SceneTree.
find_player :: proc "contextless" (from: gd.Object) -> gd.Node2d {
	return gd.first_in_group(from, GROUP_PLAYER)
}

// find_game returns the Game root node (it joins GROUP_GAME on _ready), or nil.
find_game :: proc "contextless" (from: gd.Object) -> gd.Node {
	return gd.first_in_group(from, GROUP_GAME)
}

// damage_enemies_in_radius deals `dmg` to every "enemies" member within `radius` of `center`
// (TYPED — it calls enemy_take_damage directly, no Variant marshaling). It is the strike of
// the Orbit and Aura weapons: gd.nodes_in_group_within is the area-of-effect query, and
// rt.script_of makes each hit typed (a non-Enemy group member would be skipped, never
// reinterpreted). Returns how many enemies it hit. Iterating the SNAPSHOT is safe even
// though lethal hits queue_free enemies (the free is deferred, and a dead enemy ignores
// further damage).
// (a context-using proc — it calls enemy_take_damage, which is an ordinary, non-contextless
// proc; callers are weapon lifecycle procs, which run with the script context established.)
damage_enemies_in_radius :: proc(
	from: gd.Object,
	center: gd.Vector2,
	radius: f32,
	dmg: int,
) -> int {
	hit := 0
	for n in gd.nodes_in_group_within(from, GROUP_ENEMIES, center, radius) {
		e := rt.script_of(n, Enemy)
		if e == nil {continue}
		enemy_take_damage(e, dmg)
		hit += 1
	}
	return hit
}

// rotate2 rotates `v` by `radians` (used to fan out multishot bullets / orbit blades).
rotate2 :: proc "contextless" (v: gd.Vector2, radians: f32) -> gd.Vector2 {
	c := math.cos(radians)
	s := math.sin(radians)
	return gd.Vector2{v.x * c - v.y * s, v.x * s + v.y * c}
}

// rand_range — a plain (context-using) uniform in [lo, hi). Wrapped here so the call sites
// read cleanly.
rand_range :: proc(lo, hi: f32) -> f32 {return rand.float32_range(lo, hi)}
