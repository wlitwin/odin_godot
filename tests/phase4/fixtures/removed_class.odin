//gd:extends Node
//gd:class RemovedClass
package phase4_scripts

// Deleted before the second reload while one instance remains live. That instance
// must keep its exact old generation until Godot frees it.

import gd "godot:godot"

RemovedClass :: struct {
	owner: gd.Node,
}

@(gd_method)
removed_class_value :: proc(self: ^RemovedClass) -> int {
	return 4242
}
