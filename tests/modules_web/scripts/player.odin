//gd:extends Node
//gd:class Player
package modweb_main

// ----------------------------------------------------------------------------
// Player — the MAIN module (res://scripts) of the MULTI-MODULE WEB test. On web every
// script module is AOT-composed into ONE wasm SIDE_MODULE (build/build_web.sh), so this
// package and the enemies module share one process, one registry, one manifest. The
// test proves the main-module class runs in a real browser (MODWEB_MAIN_RAN) and that a
// cross-module call THROUGH THE ENGINE (attack -> Enemy.take_hit by name) works there.
// (Trimmed copy of tests/modules_spike's Player — the two tests stay independent.)
// ----------------------------------------------------------------------------

import gd "godot:godot"

Player :: struct {
	owner:      gd.Node,
	ready_mark: gd.Int `gd:"export"`,
}

player_ready :: proc(self: ^Player) {
	self.ready_mark = 1
	modweb_print("MODWEB_MAIN_RAN")
}

// CROSS-MODULE CALL VIA THE ENGINE: invoke "take_hit" on `target` (an enemies-module
// node) through Object::call — dynamic, name-based, no shared types required (script
// modules cannot import each other).
@(gd_method)
player_attack :: proc(self: ^Player, target: gd.Node, amount: gd.Int) {
	m := gd.new_string_name_cstring("take_hit", true)
	amt := amount
	v := gd.variant_from_int(&amt)
	_ = gd.object_call(cast(gd.Object)target, m, v)
}

// Print a line through Godot (-> browser console). Not a `^Player` method, so
// scriptgen ignores it.
modweb_print :: proc(s: string) {
	gs := gd.new_string_odin(s)
	v := gd.variant_from_string(&gs)
	gd.gd_print(v)
}
