//gd:extends Node
//gd:class Widget
package reload_exports_scripts

// ----------------------------------------------------------------------------
// Widget — the subject of the "show on save" reload test (tests/reload_exports).
//
// It starts with ONE `@export` (`speed`). The headless driver edits THIS file in place to
// add a second `@export new_field` (replacing the //NEW_FIELD_HERE marker below), then
// triggers the same rebuild+reload path the editor runs on save, and asserts that the new
// export appears in a node's property list WITHOUT restarting the process.
//
// Non-tool (no //gd:tool): in the editor it gets a PlaceHolderScriptInstance, so this also
// exercises the placeholder property-list refresh — the realistic Inspector case.
// ----------------------------------------------------------------------------

import gd "godot:godot"

// First field MUST be the owner Object pointer (the core writes it at offset 0).
Widget :: struct {
	owner: gd.Node,
	speed: gd.Float `gd:"export"`,
	//NEW_FIELD_HERE
}

// A trivial method so the class is a complete, realistic example (also lets a driver call in).
@(gd_method)
widget_get_speed :: proc(self: ^Widget) -> f64 {
	return self.speed
}
