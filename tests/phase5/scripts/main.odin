//gd:extends Node
//gd:class Main
package phase5_scripts

// The Phase 5 EXPORT sentinel script. Attached (via the res://main.odin resource
// stub) to the Main node of main.tscn, which is the project's run/main_scene. In the
// EXPORTED game its `ready` lifecycle runs real Odin code AOT-compiled at export
// time, prints the sentinels the harness greps for, and quits the headless run.

import gd "godot:godot"
import "core:fmt"

Main :: struct {
	owner: gd.Node,
}

main_ready :: proc(self: ^Main) {
	fmt.println("EXPORT_RAN")
	if main_add(self, 2, 3) == 5 {
		fmt.println("EXPORT_ASSERT_OK")
	} else {
		fmt.println("EXPORT_ASSERT_FAIL")
	}
	// End the headless run from inside the game.
	tree := gd.node_get_tree(self.owner)
	if tree != nil {
		gd.scene_tree_quit(tree, 0)
	}
}

@(gd_method)
main_add :: proc(self: ^Main, a, b: int) -> int {
	return a + b
}
