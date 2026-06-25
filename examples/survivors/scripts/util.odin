package survivors_scripts

// ----------------------------------------------------------------------------
// util — small shared helpers used by several scripts. Like game_state.odin this file has NO
// owner-struct, so scriptgen skips it; it is plain package-level Odin.
//
// FEATURE: groups as a lightweight, decoupled "find that kind of thing" query — no node
// paths, no singletons. A node joins a group in its _ready (gd.add_to_group); any other
// script then finds the group's members through the SceneTree:
//   * find_player / find_game     — the single player / game-root, by group.
//   * nearest_enemy               — the closest "enemies" member to a point (auto-aim).
//   * damage_enemies_in_radius    — area damage for the Orbit / Aura weapons (typed).
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
	tree := gd.get_tree(from)
	if tree == nil {return nil}
	group := gd.new_string_name_cstring(GROUP_PLAYER, true)
	return cast(gd.Node2d)gd.scene_tree_get_first_node_in_group(tree, group)
}

// find_game returns the Game root node (it joins GROUP_GAME on _ready), or nil.
find_game :: proc "contextless" (from: gd.Object) -> gd.Node {
	tree := gd.get_tree(from)
	if tree == nil {return nil}
	group := gd.new_string_name_cstring(GROUP_GAME, true)
	return gd.scene_tree_get_first_node_in_group(tree, group)
}

// nearest_enemy scans GROUP_ENEMIES and returns the member closest to `origin` (squared
// distance, so no per-candidate sqrt), or (nil, false) when the group is empty.
nearest_enemy :: proc "contextless" (from: gd.Object, origin: gd.Vector2) -> (gd.Node2d, bool) {
	tree := gd.get_tree(from)
	if tree == nil {return nil, false}
	group := gd.new_string_name_cstring(GROUP_ENEMIES, true)
	nodes := gd.scene_tree_get_nodes_in_group(tree, group)
	count := gd.array_size(&nodes.untyped)

	best: gd.Node2d = nil
	best_dist := max(f32)
	found := false
	for i in 0 ..< count {
		v := gd.array_get(&nodes.untyped, i)
		obj := gd.variant_to_object(&v)
		if obj == nil {continue}
		pos := gd.node2d_get_global_position(cast(gd.Node2d)obj)
		dx := pos.x - origin.x
		dy := pos.y - origin.y
		d := dx * dx + dy * dy
		if d < best_dist {
			best_dist = d
			best = cast(gd.Node2d)obj
			found = true
		}
	}
	return best, found
}

// damage_enemies_in_radius deals `dmg` to every "enemies" member within `radius` of `center`
// (TYPED — it calls enemy_take_damage directly, no Variant marshaling). It is the strike of
// the Orbit and Aura weapons. Returns how many enemies it hit. Iterating the group SNAPSHOT
// is safe even though lethal hits queue_free enemies (the free is deferred, and a dead enemy
// ignores further damage).
// (a context-using proc — it calls enemy_take_damage, which is an ordinary, non-contextless
// proc; callers are weapon lifecycle procs, which run with the script context established.)
damage_enemies_in_radius :: proc(
	from: gd.Object,
	center: gd.Vector2,
	radius: f32,
	dmg: int,
) -> int {
	tree := gd.get_tree(from)
	if tree == nil {return 0}
	group := gd.new_string_name_cstring(GROUP_ENEMIES, true)
	nodes := gd.scene_tree_get_nodes_in_group(tree, group)
	count := gd.array_size(&nodes.untyped)
	r2 := radius * radius
	hit := 0
	for i in 0 ..< count {
		v := gd.array_get(&nodes.untyped, i)
		obj := gd.variant_to_object(&v)
		if obj == nil {continue}
		pos := gd.node2d_get_global_position(cast(gd.Node2d)obj)
		dx := pos.x - center.x
		dy := pos.y - center.y
		if dx * dx + dy * dy > r2 {continue}
		e := rt.script_of(obj, Enemy)
		if e == nil {continue}
		enemy_take_damage(e, dmg)
		hit += 1
	}
	return hit
}

// normalized returns `v` scaled to unit length (or zero if it is ~0).
normalized :: proc "contextless" (v: gd.Vector2) -> gd.Vector2 {
	length := math.sqrt(v.x * v.x + v.y * v.y)
	if length <= 0.00001 {return gd.Vector2{0, 0}}
	return gd.Vector2{v.x / length, v.y / length}
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
