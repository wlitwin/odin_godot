package coop_arena

// ----------------------------------------------------------------------------
// util — shared, owner-less helpers for the co-op arena (no //gd:class, so scriptgen skips
// this file; it is plain package Odin compiled into the one scripts dll, shared by every
// arena script). Groups give a decoupled "find that kind of thing" query with no node paths.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"
import "core:math"

ARENA_W :: f32(640)
ARENA_H :: f32(360)

GROUP_GAME :: "arena_game"
GROUP_ENEMIES :: "arena_enemies"
GROUP_PAWNS :: "arena_pawns"

// find_game returns the ArenaGame root node (it joins GROUP_GAME on _ready), or nil.
find_game_node :: proc "contextless" (from: gd.Object) -> gd.Node {
	tree := gd.get_tree(from)
	if tree == nil {return nil}
	group := gd.new_string_name_cstring(GROUP_GAME, true)
	return gd.scene_tree_get_first_node_in_group(tree, group)
}

// find_game returns the ArenaGame SCRIPT on the root node, or nil — the typed handle the
// pawn/bullet use to reach the orchestrator (to broadcast fire/damage RPCs on a node whose
// path is identical on every peer).
find_game :: proc(from: gd.Object) -> ^ArenaGame {
	n := find_game_node(from)
	if n == nil {return nil}
	return rt.script_of(cast(gd.Object)n, ArenaGame)
}

// nearest_enemy scans GROUP_ENEMIES and returns the member closest to `origin` (squared
// distance), or (nil, false) when the group is empty.
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

// enemy_by_id finds the ArenaEnemy whose synced `id` matches, scanning GROUP_ENEMIES. Returns
// the node + its script, or (nil, nil). Used by the peer-authoritative damage RPC so every
// peer resolves the SAME enemy regardless of how the spawner named the node.
enemy_by_id :: proc(from: gd.Object, id: int) -> (gd.Node, ^ArenaEnemy) {
	tree := gd.get_tree(from)
	if tree == nil {return nil, nil}
	group := gd.new_string_name_cstring(GROUP_ENEMIES, true)
	nodes := gd.scene_tree_get_nodes_in_group(tree, group)
	count := gd.array_size(&nodes.untyped)
	for i in 0 ..< count {
		v := gd.array_get(&nodes.untyped, i)
		obj := gd.variant_to_object(&v)
		if obj == nil {continue}
		e := rt.script_of(obj, ArenaEnemy)
		if e != nil && e.id == id {return cast(gd.Node)obj, e}
	}
	return nil, nil
}

normalized :: proc "contextless" (v: gd.Vector2) -> gd.Vector2 {
	length := math.sqrt(v.x * v.x + v.y * v.y)
	if length <= 0.00001 {return gd.Vector2{0, 0}}
	return gd.Vector2{v.x / length, v.y / length}
}

// peer_color — a distinct colour per peer so the two avatars (and their bullets) read apart on
// both screens. Host (id 1) is blue; the others cycle through warm hues.
peer_color :: proc "contextless" (peer_id: int) -> gd.Color {
	switch peer_id % 4 {
	case 1:  return gd.Color{0.35, 0.65, 1.0, 1}     // host — blue
	case 2:  return gd.Color{1.0, 0.62, 0.2, 1}      // orange
	case 3:  return gd.Color{0.5, 0.9, 0.4, 1}       // green
	case:    return gd.Color{0.9, 0.45, 0.9, 1}      // magenta
	}
}
