//gd:extends Node
//gd:class Contested
package modweb_enemies

// The enemies MODULE's claim on the class name "Contested" — the other half of the
// DELIBERATE cross-module collision with scripts/contested.odin. On web all modules
// share ONE registry, so exactly one of the two registrations survives (first wins)
// and the other is dropped with a loud duplicate-class Registration_Error that the
// core's error drain pushes to the browser console (drive.mjs asserts it). On native
// this same collision is rejected per-dll by the core's index_module_manifest instead.
// Never attached to a node — it exists purely to collide.

import gd "godot:godot"

Contested :: struct {
	owner: gd.Node,
}

@(gd_method)
contested_claim :: proc(self: ^Contested) -> int {
	return 2 // enemies module's brand
}
