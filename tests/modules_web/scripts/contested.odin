//gd:extends Node
//gd:class Contested
package modweb_main

// The MAIN module's claim on the class name "Contested". modules/enemies/contested.odin
// claims the SAME name — a DELIBERATE cross-module class-name collision. On web both
// packages register into the ONE shared registry, so the runtime's duplicate detection
// (runtime/runtime.odin register) must keep the first registration and surface a loud
// duplicate-class error on the browser console (asserted by drive.mjs). Never attached
// to a node — it exists purely to collide.

import gd "godot:godot"

Contested :: struct {
	owner: gd.Node,
}

@(gd_method)
contested_claim :: proc(self: ^Contested) -> int {
	return 1 // main module's brand
}
