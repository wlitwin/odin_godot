package godot

// Ergonomic helpers for Node tree operations — hand-written and owned here (binding
// regeneration only rewrites *.gen.odin).
//
// Object handles (Node2d, Area2d, …) are all type-aliases up to `Object`, so these helpers
// take `Object`/`Node` and accept any node handle (e.g. a script's `self.owner`) with no
// cast, and a returned `Node` assigns to any handle var.
//
// Group names are interned as STATIC StringNames — pass string literals only (see the
// interning note in Ergonomics.odin). Scene PATHS may be dynamic: they go through refcounted
// String/NodePath temporaries that are freed here.

// get_node resolves a child of `node` by scene path (collapses NodePath + node_get_node).
// `path` may be a dynamically built cstring; the temporary NodePath is freed here:
//
//     hud := gd.get_node(self.owner, "Hud")
get_node :: proc "contextless" (node: Object, path: cstring) -> Node {
	np := new_node_path_cstring(path)
	defer free_node_path(np)
	return node_get_node(node, np)
}

// add_child parents `child` under `parent`, hiding the force_readable_name + internal-mode
// args that `node_add_child` exposes:
//
//     gd.add_child(self.owner, child)
add_child :: proc "contextless" (parent: Object, child: Object) {
	node_add_child(parent, child, false, Node_Internal_Mode(0))
}

// add_child_deferred parents `child` under `parent` on the NEXT idle frame (via
// Object.call_deferred). Use it when you spawn a physics node (an Area2D/body) from inside a
// physics callback — e.g. dropping a pickup during another area's `area_entered` — where adding
// it immediately would toggle monitoring "while flushing queries". Set the child's LOCAL
// position before calling (it is not in the tree yet):
//
//     gd.node2d_set_position(gem, world_pos) // arena is at the origin -> local == world
//     gd.add_child_deferred(arena, gem)
add_child_deferred :: proc "contextless" (parent: Object, child: Object) {
	m := new_string_name_cstring("add_child", true)
	c := child
	// call_deferred copies its argument Variants, so destroy ours after the call (an Object
	// Variant can hold a reference when the target is RefCounted).
	cv := variant_from_object(&c)
	defer variant_destroy(&cv)
	object_call_deferred(parent, m, cv)
}

// get_parent returns `node`'s parent (nil at the scene root).
get_parent :: proc "contextless" (node: Object) -> Node {
	return node_get_parent(node)
}

// get_tree returns the Scene_Tree `node` belongs to (nil when not in a tree).
get_tree :: proc "contextless" (node: Object) -> Scene_Tree {
	return node_get_tree(node)
}

// add_to_group adds `node` to the named group. `persistent` defaults to false (matches the
// transient grouping you usually want at runtime).
add_to_group :: proc "contextless" (node: Object, group: cstring, persistent := false) {
	g := new_string_name_cstring(group, true)
	node_add_to_group(node, g, persistent)
}

// remove_from_group removes `node` from the named group.
remove_from_group :: proc "contextless" (node: Object, group: cstring) {
	g := new_string_name_cstring(group, true)
	node_remove_from_group(node, g)
}

// is_in_group reports whether `node` is currently in the named group.
is_in_group :: proc "contextless" (node: Object, group: cstring) -> bool {
	g := new_string_name_cstring(group, true)
	return node_is_in_group(node, g)
}

// ---- Group queries ----
//
// The scene tree's group index is the decoupled "find that kind of thing" query — no node
// paths, no hand-kept registries. These wrap `SceneTree.get_nodes_in_group` and hide the
// typed-array/Variant unpacking (Ergonomics_Arrays.odin). For "which of my SCRIPT structs
// are in the group", see the runtime package's `rt.scripts_in_group` /
// `rt.first_script_in_group`, which compose these with `rt.script_of`.

// nodes_in_group returns the live members of the named group, allocated in
// `context.temp_allocator` by default (call-local — iterate now, don't stash; pass an
// allocator to keep the slice). Members freed this frame are dropped rather than returned
// as nils, so it is safe to `queue_free` members while iterating the result. Empty when
// `node` is not in a tree:
//
//     for n in gd.nodes_in_group(self.owner, "enemies") {
//         gd.node2d_set_x(n, 0)   // n is gd.Node — passes to any helper with no cast
//     }
nodes_in_group :: proc(node: Object, group: cstring, allocator := context.temp_allocator) -> []Node {
	tree := node_get_tree(node)
	if tree == nil {return nil}
	g := new_string_name_cstring(group, true)
	arr := scene_tree_get_nodes_in_group(tree, g)
	defer free_array(arr.untyped)
	n := int(array_size(&arr.untyped))
	out := make([dynamic]Node, 0, n, allocator)
	for i in 0 ..< n {
		v := array_get(&arr.untyped, Int(i))
		if obj := variant_to_object(&v); obj != nil {
			append(&out, obj)
		}
		variant_destroy(&v)
	}
	return out[:]
}

// first_in_group returns one member of the named group (the engine's first), or nil when
// the group is empty or `node` is not in a tree — the single-expected-node query:
//
//     game := gd.first_in_group(self.owner, "game")
first_in_group :: proc "contextless" (node: Object, group: cstring) -> Node {
	tree := node_get_tree(node)
	if tree == nil {return nil}
	g := new_string_name_cstring(group, true)
	return scene_tree_get_first_node_in_group(tree, g)
}

// nearest_in_group returns the group member (as a Node2d) closest to `origin` by
// squared distance — auto-aim's query, promoted from the identical helper two example
// games hand-rolled. `ok` is false when the group is empty (or `node` is out of tree).
// Members must be CanvasItem-derived (their global position is what's compared).
//
//     if target, ok := gd.nearest_in_group(self.owner, "enemies", pos); ok { ... }
nearest_in_group :: proc(node: Object, group: cstring, origin: Vector2) -> (best: Node2d, ok: bool) {
	best_d := max(f32)
	for n in nodes_in_group(node, group) {
		p := node2d_get_global_position(cast(Node2d)n)
		dx := p.x - origin.x
		dy := p.y - origin.y
		d := dx * dx + dy * dy
		if d < best_d {
			best_d = d
			best = cast(Node2d)n
			ok = true
		}
	}
	return
}

// nodes_in_group_within returns the group members (as Node2d) within `radius` of
// `origin` — the area-of-effect query (aura/orbit damage, blast waves). Temp-allocated
// by default, like nodes_in_group; compose with rt.script_of for typed hits.
nodes_in_group_within :: proc(node: Object, group: cstring, origin: Vector2, radius: f32, allocator := context.temp_allocator) -> []Node2d {
	r2 := radius * radius
	out := make([dynamic]Node2d, 0, 8, allocator)
	for n in nodes_in_group(node, group) {
		p := node2d_get_global_position(cast(Node2d)n)
		dx := p.x - origin.x
		dy := p.y - origin.y
		if dx * dx + dy * dy <= r2 {
			append(&out, cast(Node2d)n)
		}
	}
	return out[:]
}

// ---- SceneTree one-liners ----
//
// The `tree := gd.get_tree(owner); if tree != nil { one call }` dance, collapsed — 18
// sites across the examples wrapped exactly one SceneTree method each. All are nil-safe
// no-ops when `node` is not in a tree.

// pause pauses/unpauses the whole tree (menus, game-over screens).
pause :: proc "contextless" (node: Object, paused: bool) {
	if tree := node_get_tree(node); tree != nil {
		scene_tree_set_pause(tree, paused)
	}
}

// is_paused reports the tree's pause state (false when out of tree).
is_paused :: proc "contextless" (node: Object) -> bool {
	if tree := node_get_tree(node); tree != nil {
		return bool(scene_tree_is_paused(tree))
	}
	return false
}

// change_scene switches to the scene at `path` (deferred by the engine to frame end).
//
//     gd.change_scene(self.owner, "res://gameover.tscn")
change_scene :: proc "contextless" (node: Object, path: cstring) -> Error {
	tree := node_get_tree(node)
	if tree == nil {return .Failed}
	p := new_string_cstring(path)
	defer free_string(p)
	return scene_tree_change_scene_to_file(tree, p)
}

// quit exits the game loop with `code` (deferred to frame end, like GDScript quit()).
quit :: proc "contextless" (node: Object, code := i64(0)) {
	if tree := node_get_tree(node); tree != nil {
		scene_tree_quit(tree, Int(code))
	}
}

// ---- Node2D position-component setters ----
//
// Setting ONE component of a Node2D's position ("snap x to 100, keep y") otherwise needs the
// get -> modify -> set round-trip, since a `Vector2` component can't be written across the engine
// boundary on its own. These close that gap. For DELTAS (`pos.x += d`) prefer `node2d_translate`
// / `node2d_move_local_x`, which skip the read entirely.

// node2d_set_x sets the X of a Node2D's LOCAL position, keeping Y.
node2d_set_x :: proc "contextless" (node: Node2d, x: Real) {
	p := node2d_get_position(node)
	p.x = x
	node2d_set_position(node, p)
}

// node2d_set_y sets the Y of a Node2D's LOCAL position, keeping X.
node2d_set_y :: proc "contextless" (node: Node2d, y: Real) {
	p := node2d_get_position(node)
	p.y = y
	node2d_set_position(node, p)
}

// node2d_set_global_x sets the X of a Node2D's WORLD (global) position, keeping Y.
node2d_set_global_x :: proc "contextless" (node: Node2d, x: Real) {
	p := node2d_get_global_position(node)
	p.x = x
	node2d_set_global_position(node, p)
}

// node2d_set_global_y sets the Y of a Node2D's WORLD (global) position, keeping X.
node2d_set_global_y :: proc "contextless" (node: Node2d, y: Real) {
	p := node2d_get_global_position(node)
	p.y = y
	node2d_set_global_position(node, p)
}

// ---- Node3D position-component setters (same idea, Vector3) ----

// node3d_set_x / _y / _z set one component of a Node3D's LOCAL position, keeping the others.
node3d_set_x :: proc "contextless" (node: Node3d, x: Real) {
	p := node3d_get_position(node)
	p.x = x
	node3d_set_position(node, p)
}
node3d_set_y :: proc "contextless" (node: Node3d, y: Real) {
	p := node3d_get_position(node)
	p.y = y
	node3d_set_position(node, p)
}
node3d_set_z :: proc "contextless" (node: Node3d, z: Real) {
	p := node3d_get_position(node)
	p.z = z
	node3d_set_position(node, p)
}

// node3d_set_global_x / _y / _z set one component of a Node3D's WORLD position.
node3d_set_global_x :: proc "contextless" (node: Node3d, x: Real) {
	p := node3d_get_global_position(node)
	p.x = x
	node3d_set_global_position(node, p)
}
node3d_set_global_y :: proc "contextless" (node: Node3d, y: Real) {
	p := node3d_get_global_position(node)
	p.y = y
	node3d_set_global_position(node, p)
}
node3d_set_global_z :: proc "contextless" (node: Node3d, z: Real) {
	p := node3d_get_global_position(node)
	p.z = z
	node3d_set_global_position(node, p)
}

// ---- Control position / size component setters ----
//
// Control's set_position/set_size take a `keep_offsets` flag; these pass `false` (the common
// case — let the offsets follow). For anchor-driven layouts you'll still want the raw setters.

// control_set_x / _y set one component of a Control's position, keeping the other.
control_set_x :: proc "contextless" (node: Control, x: Real) {
	p := control_get_position(node)
	p.x = x
	control_set_position(node, p, false)
}
control_set_y :: proc "contextless" (node: Control, y: Real) {
	p := control_get_position(node)
	p.y = y
	control_set_position(node, p, false)
}

// control_set_width / _height set one component of a Control's size, keeping the other.
control_set_width :: proc "contextless" (node: Control, w: Real) {
	s := control_get_size(node)
	s.x = w
	control_set_size(node, s, false)
}
control_set_height :: proc "contextless" (node: Control, h: Real) {
	s := control_get_size(node)
	s.y = h
	control_set_size(node, s, false)
}

// control_set_global_x / _y set one component of a Control's WORLD position.
control_set_global_x :: proc "contextless" (node: Control, x: Real) {
	p := control_get_global_position(node)
	p.x = x
	control_set_global_position(node, p, false)
}
control_set_global_y :: proc "contextless" (node: Control, y: Real) {
	p := control_get_global_position(node)
	p.y = y
	control_set_global_position(node, p, false)
}
