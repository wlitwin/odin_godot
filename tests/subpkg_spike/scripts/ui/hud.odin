//gd:extends Node
//gd:class Hud
package subpkg_ui

// ----------------------------------------------------------------------------
// Hud — an ANNOTATED script living in a SUBPACKAGE (res://scripts/ui). It gets the
// whole engine-native surface: `//gd:extends`/`//gd:class`, lifecycles, `gd:"export"`
// fields, @(gd_method) trampolines and typed signals. What it may NOT declare is any
// kit wiring (replicate/command/tick/entity/...) — that is the MODULE's wire contract
// and lives in the module root; scriptgen refuses it here by name (run.sh phase 2).
//
// scriptgen emits `ui/odin_godot_scripts.gen.odin` for this dir; the boot shim and the
// staleness guard stay in the root, and the guard's `import _ "ui"` manifest line is
// what links this package's generated `@(init)` registration into the module's one dll.
//
// Versioned behavior (GAIN) selected by the HUD_V compile define so a rebuild can stand
// in for an edit-save: v1 GAIN == 10, v2 (-define:HUD_V=2) GAIN == 100. The struct
// LAYOUT is identical across versions, so the reload takes the same-layout fast path
// and instance state is preserved byte-for-byte.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import "../util"

HUD_V :: #config(HUD_V, 1)

when HUD_V == 2 {
	GAIN :: 100
} else {
	GAIN :: 10
}

// A SUBPACKAGE-local package global. It lives in the module's one dll like every other
// package global, so a reload of this module resets it (asserted by the harness).
hud_updates: int

Hud :: struct {
	owner:      gd.Node,
	shown:      gd.Int `gd:"export"`,
	ready_mark: gd.Int `gd:"export"`,
	// A typed signal declared in a subpackage — the emit helper is generated into
	// ui/odin_godot_scripts.gen.odin like every other section.
	bumped:     gd.Signal1(int) `gd:"args=value"`,
}

hud_ready :: proc(self: ^Hud) {
	self.ready_mark = 1
}

@(gd_method)
hud_bump :: proc(self: ^Hud) -> int {
	self.shown += GAIN
	hud_updates += 1
	hud_emit_bumped(self, self.shown)
	return int(self.shown)
}

// Which build (v1/v2) is live — observed by the harness across the reload.
@(gd_method)
hud_gain :: proc(self: ^Hud) -> int {
	return GAIN
}

// The shared HELPER subpackage, reached from a SIBLING subpackage (`../util`).
@(gd_method)
hud_base :: proc(self: ^Hud) -> int {
	return util.STEP
}

@(gd_method)
hud_updates_count :: proc(self: ^Hud) -> int {
	return hud_updates
}
