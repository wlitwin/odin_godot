//gd:extends Node
//gd:class Game
package subpkg_main

// ----------------------------------------------------------------------------
// Game — the MODULE ROOT class of the script-subpackage spike (res://scripts ->
// libodinscripts.dylib). It imports both subpackages the module holds:
//
//   ui/   — a SCRIPT subpackage: `Hud` is annotated there and is attachable from
//           res://scripts/ui/hud.odin, registered through the import manifest in
//           the root's generated guard file.
//   util/ — a plain HELPER subpackage: no annotations, no generated file, and
//           imported by BOTH the root and ui/ (a sibling-import DAG edge).
//
// One dll holds all three packages, so `rt.script_of(node, ui.Hud)` is a typed,
// in-process read of another package's script struct — no engine round trip.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"
import "ui"
import "util"

Game :: struct {
	owner:      gd.Node,
	score:      gd.Int `gd:"export"`,
	ready_mark: gd.Int `gd:"export"`,
	ticks:      gd.Int `gd:"export"`,
}

game_ready :: proc(self: ^Game) {
	self.ready_mark = 1
}

game_process :: proc(self: ^Game, delta: f64) {
	self.ticks += 1
}

// The shared HELPER subpackage, reached from the module root (ui/ reads the same
// constant — the harness asserts both see 7).
@(gd_method)
game_step :: proc(self: ^Game) -> int {
	return util.STEP
}

// TYPED in-dll access to a SUBPACKAGE class: the `ui` package's struct is a real
// type here, so this is a direct field read. -1 when the node is not a Hud.
@(gd_method)
game_read_hud :: proc(self: ^Game, target: gd.Node) -> int {
	hud := rt.script_of(target, ui.Hud)
	if hud == nil {
		return -1
	}
	return int(hud.shown)
}

// The class check holds ACROSS packages: a Hud node read as Game must be nil,
// while the root class still resolves itself. Returns 1 when both hold.
@(gd_method)
game_probe :: proc(self: ^Game, target: gd.Node) -> int {
	cross := rt.script_of(target, Game) // a Hud node as Game -> must be nil
	own := rt.script_of(self.owner, Game) // own node -> must be non-nil
	if cross == nil && own != nil {
		return 1
	}
	return 0
}
