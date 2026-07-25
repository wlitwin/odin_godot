//gd:extends Node
//gd:class Enemy
//gd:tool
package spike_shared_enemies

// ----------------------------------------------------------------------------
// Enemy — the `enemies` script MODULE (res://modules/enemies ->
// libodinscripts_enemies.dylib): its OWN package in its OWN dll, importing the SAME
// shared vocabulary as the main module through `../../shared/ids`.
//
// That is the whole point of the shared tree: two dlls, one vocabulary, and no shared
// STATE to fork — the values below must agree with the main module's exactly.
//
// `//gd:tool` is for the RELOAD phase only (a non-tool script attaches as a PLACEHOLDER
// in the editor, and a placeholder cannot be called into).
// ----------------------------------------------------------------------------

import gd "godot:godot"
import ids "../../shared/ids"

// A module-local package global — the thing that would fork if `ids` carried state.
// It lives HERE, in exactly one module, which is where mutable state belongs.
local_hits: int

Enemy :: struct {
	owner:      gd.Node,
	hp:         gd.Int `gd:"export"`,
	ready_mark: gd.Int `gd:"export"`,
}

enemy_ready :: proc(self: ^Enemy) {
	self.ready_mark = 1
}

// The shared tuning constant, as THIS dll compiled it — must equal the main module's.
@(gd_method)
enemy_shared_step :: proc(self: ^Enemy) -> int {
	return ids.STEP
}

// brand(.Enemy) == 200 + STEP, from the shared pure proc in the other dll's copy.
@(gd_method)
enemy_brand :: proc(self: ^Enemy) -> int {
	return ids.brand(.Enemy)
}

// The shared payload struct, built on this side.
@(gd_method)
enemy_pack :: proc(self: ^Enemy, amount: gd.Int) -> int {
	return ids.payload_code(ids.Payload{kind = .Enemy, amount = i32(amount)})
}

// The cross-module entry point the main module invokes via Object::call.
@(gd_method)
enemy_take_hit :: proc(self: ^Enemy, amount: gd.Int) {
	self.hp -= amount
	local_hits += 1
}

@(gd_method)
enemy_hits :: proc(self: ^Enemy) -> int {
	return local_hits
}

// Hot-reload hook: fires when THIS module's dll is swapped — a shared edit must swap
// both modules, so both hooks fire.
enemy_reload :: proc(self: ^Enemy) {
	gd.print("ENEMY_RELOAD_FIRED")
}
