package godot

// Ergonomic helpers for Node tree operations — hand-written, mirrored in
// bindgen/upstream/godot/ so they survive binding regeneration.
//
// Object handles (Node2d, Area2d, …) are all type-aliases up to `Object`, so these helpers
// take `Object`/`Node` and accept any node handle (e.g. a script's `self.owner`) with no
// cast, and a returned `Node` assigns to any handle var.

// get_node resolves a child of `node` by scene path (collapses NodePath + node_get_node):
//
//     hud := gd.get_node(self.owner, "Hud")
get_node :: proc "contextless" (node: Object, path: cstring) -> Node {
	np := new_node_path_cstring(path)
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
	cv := variant_from_object(&c)
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
