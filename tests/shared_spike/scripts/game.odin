//gd:extends Node
//gd:class Game
//gd:tool
package spike_shared_main

// ----------------------------------------------------------------------------
// Game — the MAIN module of the shared-vocabulary spike (res://scripts ->
// libodinscripts.dylib). It imports:
//
//   ../shared/ids — the project's SHARED vocabulary, also imported by the ui/
//                   subpackage and by the SEPARATE `enemies` module (another dll).
//   ui            — its own script subpackage (one dll, as always).
//
// It still may NOT import res://modules/enemies: the shared tree is the exemption,
// not a hole. Cross-module talk stays engine-mediated (game_attack below).
//
// `//gd:tool` is here for the RELOAD phase alone: in the editor a non-tool script is
// attached as a PLACEHOLDER instance, and a placeholder cannot be called into — so the
// driver could not read the shared constant back after the swap.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import ids "../shared/ids"
import "ui"

Game :: struct {
	owner:      gd.Node,
	ready_mark: gd.Int `gd:"export"`,
	ticks:      gd.Int `gd:"export"`,
}

game_ready :: proc(self: ^Game) {
	self.ready_mark = 1
}

game_process :: proc(self: ^Game, delta: f64) {
	self.ticks += 1
}

// The shared tuning constant, as this dll compiled it.
@(gd_method)
game_shared_step :: proc(self: ^Game) -> int {
	return ids.STEP
}

// The shared pure proc + enum, from this dll: brand(.Player) == 100 + STEP.
@(gd_method)
game_brand :: proc(self: ^Game) -> int {
	return ids.brand(.Player)
}

// The shared payload STRUCT, built here and scored by the shared proc.
@(gd_method)
game_pack :: proc(self: ^Game, amount: gd.Int) -> int {
	return ids.payload_code(ids.Payload{kind = .Player, amount = i32(amount)})
}

// The same vocabulary as the module's SUBPACKAGE sees it (`ui` reads ids too, and
// this is an in-dll read of its constant).
@(gd_method)
game_ui_gain :: proc(self: ^Game) -> int {
	return ui.GAIN
}

// CROSS-MODULE CALL VIA THE ENGINE — unchanged by the shared tree: the enemies
// module is another dll and another package, reachable only by name.
@(gd_method)
game_attack :: proc(self: ^Game, target: gd.Node, amount: gd.Int) {
	m := gd.new_string_name_cstring("take_hit", true)
	amt := amount
	v := gd.variant_from_int(&amt)
	_ = gd.object_call(cast(gd.Object)target, m, v)
}

// Hot-reload hook: fires when THIS module's dll is swapped (the reload phase asserts
// both modules swap after a shared edit).
game_reload :: proc(self: ^Game) {
	gd.print("GAME_RELOAD_FIRED")
}
