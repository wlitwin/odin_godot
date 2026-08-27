//gd:extends Node
//gd:class Enemy
package spike_enemies

// ----------------------------------------------------------------------------
// Enemy — the `enemies` script MODULE (res://modules/enemies ->
// libodinscripts_enemies.dylib). Its OWN package in its OWN dll, with its own
// module-local global (`local_kills`). Versioned behavior (STEP) selected by the
// ENEMIES_V compile define so a per-module rebuild can stand in for an edit-save:
//   v1 (default):            STEP == 10
//   v2 (-define:ENEMIES_V=2): STEP == 100
// The struct LAYOUT is identical across versions, so the per-module reload takes the
// same-layout fast path — state (hp/position) preserved byte-for-byte.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

ENEMIES_V :: #config(ENEMIES_V, 1)

when ENEMIES_V == 2 {
	STEP :: 100
} else {
	STEP :: 10
}

// Module-local package global: THIS dll's own copy, never shared with the main module.
// Documented reload semantics: swapping this module resets it (fresh dll globals),
// while the main module's globals survive untouched.
local_kills: int

Enemy :: struct {
	owner:      gd.Node,
	hp:         gd.Int `gd:"export"`,
	position:   gd.Int `gd:"export"`,
	ready_mark: gd.Int `gd:"export"`,
	//TARGET_SCAN_FIELD
}

enemy_ready :: proc(self: ^Enemy) {
	self.ready_mark = 1
}

enemy_process :: proc(self: ^Enemy, delta: f64) {
	self.position += STEP
}

// Which build (v1/v2) is live — observed by the harness across the per-module reload.
@(gd_method)
enemy_get_step :: proc(self: ^Enemy) -> int {
	return STEP
}

// Engine-callable: the cross-module entry point Player invokes via Object::call.
@(gd_method)
enemy_take_hit :: proc(self: ^Enemy, amount: gd.Int) {
	self.hp -= amount
	local_kills += 1
}

@(gd_method)
enemy_get_kills :: proc(self: ^Enemy) -> int {
	return local_kills
}

// script_of semantics across modules, from THIS side: a Player-scripted node can never
// be a non-nil ^Enemy; self-access within the module works.
@(gd_method)
enemy_probe :: proc(self: ^Enemy, target: gd.Node) -> int {
	cross := rt.script_of(target, Enemy) // player node as Enemy -> must be nil
	self_ok := rt.script_of(self.owner, Enemy) // own node -> must be non-nil
	if cross == nil && self_ok != nil {
		return 1
	}
	return 0
}

// Hot-reload hook: MUST fire (with the NEW code) when this module is swapped.
enemy_reload :: proc(self: ^Enemy) {
	gd.print("ENEMY_RELOAD_FIRED")
}
