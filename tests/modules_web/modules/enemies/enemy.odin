//gd:extends Node
//gd:class Enemy
package modweb_enemies

// ----------------------------------------------------------------------------
// Enemy — the `enemies` SCRIPT MODULE (res://modules/enemies) of the multi-module web
// test: its own package, composed into the same single wasm as the main module by
// build/build_web.sh. Proves a MODULE class runs in a real browser (MODWEB_MODULE_RAN)
// and is callable cross-module through the engine (take_hit, invoked by name from the
// main module's Player.attack).
// (Trimmed copy of tests/modules_spike's Enemy — the two tests stay independent.)
// ----------------------------------------------------------------------------

import gd "godot:godot"

Enemy :: struct {
	owner:      gd.Node,
	hp:         gd.Int `gd:"export"`,
	ready_mark: gd.Int `gd:"export"`,
}

enemy_ready :: proc(self: ^Enemy) {
	self.ready_mark = 1
	modweb_module_print("MODWEB_MODULE_RAN")
}

// Engine-callable: the cross-module entry point Player invokes via Object::call.
@(gd_method)
enemy_take_hit :: proc(self: ^Enemy, amount: gd.Int) {
	self.hp -= amount
}

// Print a line through Godot (-> browser console). Not a `^Enemy` method, so
// scriptgen ignores it.
modweb_module_print :: proc(s: string) {
	gs := gd.new_string_odin(s)
	v := gd.variant_from_string(&gs)
	gd.gd_print(v)
}
