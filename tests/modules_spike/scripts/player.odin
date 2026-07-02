//gd:extends Node
//gd:class Player
package spike_main

// ----------------------------------------------------------------------------
// Player — the MAIN module (res://scripts -> libodinscripts.dylib) subject of the
// multi-module spike. Owns module-local shared state (`game_state_bonus`, the
// blackboard pattern) and talks to the enemies module ONLY through the engine
// (gd.object_call by method name) — script modules cannot import each other.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

// Module-local shared state ("game_state"): package globals live in exactly ONE dll.
// Mutated before the enemies-module reload and asserted after — the MAIN module's dll
// is never swapped, so this survives (in the single-dll world a reload would reset it).
game_state_bonus: int = 7

Player :: struct {
	owner:      gd.Node,
	score:      gd.Int `gd:"export"`,
	ready_mark: gd.Int `gd:"export"`,
	ticks:      gd.Int `gd:"export"`,
}

player_ready :: proc(self: ^Player) {
	self.ready_mark = 1
}

player_process :: proc(self: ^Player, delta: f64) {
	self.ticks += 1
}

// Main-module identity + the module-local blackboard value: 1000 + game_state_bonus.
@(gd_method)
player_get_brand :: proc(self: ^Player) -> int {
	return 1000 + game_state_bonus
}

// Mutate the module-local blackboard (proves the main dll's globals survive an
// enemies-module reload untouched).
@(gd_method)
player_add_bonus :: proc(self: ^Player, n: gd.Int) {
	game_state_bonus += int(n)
}

// CROSS-MODULE CALL VIA THE ENGINE: invoke "take_hit" on `target` (an enemies-module
// node) through Object::call — dynamic, name-based, no shared types required.
@(gd_method)
player_attack :: proc(self: ^Player, target: gd.Node, amount: gd.Int) {
	m := gd.new_string_name_cstring("take_hit", true)
	amt := amount
	v := gd.variant_from_int(&amt)
	_ = gd.object_call(cast(gd.Object)target, m, v)
}

// script_of semantics ACROSS modules: `target` carries the enemies module's Enemy
// script. The only script type this module can even NAME is Player (no cross-module
// imports), and the core's class check makes script_of(target, Player) nil for a
// non-Player instance — so typed cross-module access is nil BY CONSTRUCTION.
// Returns 1 when cross-access is (correctly) nil AND self-access works.
@(gd_method)
player_probe :: proc(self: ^Player, target: gd.Node) -> int {
	cross := rt.script_of(target, Player) // enemy node as Player -> must be nil
	self_ok := rt.script_of(self.owner, Player) // own node -> must be non-nil
	if cross == nil && self_ok != nil {
		return 1
	}
	return 0
}

// Hot-reload hook: MUST NOT fire when only the enemies module is swapped — the
// harness fails the test if this marker ever appears in the log.
player_reload :: proc(self: ^Player) {
	gd.print("PLAYER_RELOAD_FIRED")
}
