package survivors_scripts

// ----------------------------------------------------------------------------
// util — small shared helpers used by several scripts. Like game_state.odin, this file has
// NO owner-struct, so scriptgen skips it; it is plain package-level Odin code.
//
// These wrap two common gameplay queries on top of the `gd.*` ergonomics + the generated
// scene-tree bindings:
//   * find_player    — the single player, located by GROUP membership ("player").
//   * nearest_enemy  — the closest node in the "enemies" GROUP to a point (for auto-aim).
//
// FEATURE: groups as a lightweight, decoupled "find that kind of thing" query — no node
// paths, no singletons. Add a node to a group in its _ready (gd.add_to_group), then any
// other script can find the group's members through the SceneTree.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import "core:math"

// GROUP_PLAYER / GROUP_ENEMIES — the two group names, declared once so writers (add_to_group)
// and readers (these queries) can never drift apart on a typo.
GROUP_PLAYER :: "player"
GROUP_ENEMIES :: "enemies"

// find_player returns the player node (it adds itself to GROUP_PLAYER on _ready), or nil if
// there is none yet. `from` is any node in the tree — we only use it to reach the SceneTree.
find_player :: proc "contextless" (from: gd.Object) -> gd.Node2d {
	tree := gd.get_tree(from)
	if tree == nil {return nil}
	group := gd.new_string_name_cstring(GROUP_PLAYER, true)
	return cast(gd.Node2d)gd.scene_tree_get_first_node_in_group(tree, group)
}

// nearest_enemy scans the GROUP_ENEMIES group and returns the member closest to `origin`
// (and `true`), or `(nil, false)` when the group is empty. Distance is compared squared, so
// there is no per-candidate sqrt. This is the player's auto-aim target query.
nearest_enemy :: proc "contextless" (from: gd.Object, origin: gd.Vector2) -> (gd.Node2d, bool) {
	tree := gd.get_tree(from)
	if tree == nil {return nil, false}
	group := gd.new_string_name_cstring(GROUP_ENEMIES, true)

	// get_nodes_in_group returns a Typed_Array(Node); `.untyped` is the plain Array it wraps,
	// which array_size / array_get operate on.
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

// normalized returns `v` scaled to unit length (or a zero vector if it is ~0). Vector2's
// components are `Real` (f32 in the default single-precision build), so this is plain f32 math.
normalized :: proc "contextless" (v: gd.Vector2) -> gd.Vector2 {
	length := math.sqrt(v.x * v.x + v.y * v.y)
	if length <= 0.00001 {return gd.Vector2{0, 0}}
	return gd.Vector2{v.x / length, v.y / length}
}
