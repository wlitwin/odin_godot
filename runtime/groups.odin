package script_runtime

import gd "godot:godot"

// ----------------------------------------------------------------------------
// Typed group queries — the cross-script layer over the scene tree's group index.
//
// `gd.nodes_in_group` answers "which NODES are in the group"; these answer the question
// scripts actually ask: "which of MY SCRIPT STRUCTS are in the group". They compose the
// group query with `script_of`, so the results are class-checked: a member carrying a
// different script (or none) is skipped, never returned reinterpreted.
//
// POST-BOOT ONLY: unlike `register`, these call into the engine, so they belong in
// lifecycle procs / @(gd_method) bodies / signal handlers — anywhere script code already
// runs — and never in `@(init)`. Same main-thread contract as `script_of`.
// ----------------------------------------------------------------------------

// scripts_in_group returns every member of the named group whose attached Odin script is
// `S`, as direct struct pointers. The slice is allocated in `context.temp_allocator` by
// default (call-local — iterate now, don't stash; pass an allocator to keep the SLICE,
// though the pointers still die with their instances):
//
//     for p in rt.scripts_in_group(self.owner, "players", player) {
//         p.hp -= 1                                     // direct field access
//         pos := gd.node2d_get_global_position(p.owner) // engine calls via the owner
//     }
scripts_in_group :: proc(
	node: gd.Object,
	group: cstring,
	$S: typeid,
	allocator := context.temp_allocator,
) -> []^S {
	members := gd.nodes_in_group(node, group, context.temp_allocator)
	out := make([dynamic]^S, 0, len(members), allocator)
	for m in members {
		if s := script_of(m, S); s != nil {append(&out, s)}
	}
	return out[:]
}

// first_script_in_group returns the first group member carrying script `S`, or nil — the
// single-expected-object query (the game orchestrator, the world, the camera):
//
//     game := rt.first_script_in_group(self.owner, "game", Game)
//
// It scans past members with other scripts, so a mixed group can never hand back a wrong
// class — contrast with `gd.first_in_group` + `script_of`, which inspects only whichever
// node the engine lists first. Allocation-free.
first_script_in_group :: proc "contextless" (node: gd.Object, group: cstring, $S: typeid) -> ^S {
	tree := gd.node_get_tree(node)
	if tree == nil {return nil}
	g := gd.new_string_name_cstring(group, true)
	arr := gd.scene_tree_get_nodes_in_group(tree, g)
	defer gd.free_array(arr.untyped)
	n := gd.array_size(&arr.untyped)
	for i in 0 ..< n {
		v := gd.array_get(&arr.untyped, i)
		obj := gd.variant_to_object(&v)
		gd.variant_destroy(&v)
		if obj == nil {continue}
		if s := script_of(obj, S); s != nil {return s}
	}
	return nil
}
