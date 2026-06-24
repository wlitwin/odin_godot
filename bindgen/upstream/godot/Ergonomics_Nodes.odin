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
