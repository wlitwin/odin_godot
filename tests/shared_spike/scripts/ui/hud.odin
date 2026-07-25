//gd:extends Node
//gd:class Hud
package spike_shared_ui

// ----------------------------------------------------------------------------
// Hud — an annotated class in a SCRIPT SUBPACKAGE (res://scripts/ui) that imports the
// shared vocabulary from one level deeper: `../../shared/ids`. The exemption is about
// where the import RESOLVES, not how many `..` segments it takes to get there.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import ids "../../shared/ids"

// A subpackage constant DERIVED from the shared one — proof this package compiled
// against the same vocabulary the module root did.
GAIN :: ids.STEP * 2

Hud :: struct {
	owner:      gd.Node,
	shown:      gd.Int `gd:"export"`,
	ready_mark: gd.Int `gd:"export"`,
}

hud_ready :: proc(self: ^Hud) {
	self.ready_mark = 1
}

@(gd_method)
hud_shared_step :: proc(self: ^Hud) -> int {
	return ids.STEP
}

@(gd_method)
hud_brand :: proc(self: ^Hud) -> int {
	return ids.brand(.None)
}

@(gd_method)
hud_gain :: proc(self: ^Hud) -> int {
	return GAIN
}
