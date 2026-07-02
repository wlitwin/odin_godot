//gd:extends Node
//gd:class GameState
package barrage_main

// ----------------------------------------------------------------------------
// GameState — the AUTOLOAD (project.godot [autoload]) and the neutral meeting point
// the isolated script modules share: every module can reach /root/GameState through
// the engine, so score/health/run-state live here instead of leaking package imports
// across dll boundaries (docs/modules.md: talk through the engine).
//
// FEATURES: autoload lifecycle, typed signal fields (Signal1/Signal2/Signal0),
// @(gd_method)s called cross-module by name, exports for Inspector debugging.
// ----------------------------------------------------------------------------

import "core:os"
import gd "godot:godot"

GameState :: struct {
	owner: gd.Node,

	score_changed: gd.Signal1(int) `gd:"args=score"`,
	hp_changed:    gd.Signal2(int, int) `gd:"args=hp,max_hp"`,
	player_died:   gd.Signal0,

	max_hp: int `gd:"export,range=1:20:1"`,

	// runtime (untagged -> private)
	score:   int,
	hp:      int,
	cleared: bool, // boss defeated (game_over.odin shows CLEARED vs GAME OVER)
}

game_state_ready :: proc(self: ^GameState) {
	if self.max_hp == 0 {self.max_hp = 5}
	game_state_reset(self)
}

@(gd_method)
game_state_reset :: proc(self: ^GameState) {
	self.score = 0
	self.hp = self.max_hp
	self.cleared = false
}

@(gd_method)
game_state_add_score :: proc(self: ^GameState, amount: gd.Int) {
	self.score += int(amount)
	game_state_emit_score_changed(self, i64(self.score))
}

@(gd_method)
game_state_damage_player :: proc(self: ^GameState, amount: gd.Int) {
	if self.hp <= 0 {return}
	self.hp -= int(amount)
	game_state_emit_hp_changed(self, i64(self.hp), i64(self.max_hp))
	if self.hp <= 0 {
		game_state_emit_player_died(self)
	}
}

@(gd_method)
game_state_set_cleared :: proc(self: ^GameState) {
	self.cleared = true
}

// ---- getters (the cross-module READ API; HUD/game-over poll these) ----
@(gd_method)
game_state_get_score :: proc(self: ^GameState) -> gd.Int {return gd.Int(self.score)}
@(gd_method)
game_state_get_hp :: proc(self: ^GameState) -> gd.Int {return gd.Int(self.hp)}
@(gd_method)
game_state_get_max_hp :: proc(self: ^GameState) -> gd.Int {return gd.Int(self.max_hp)}
@(gd_method)
game_state_is_cleared :: proc(self: ^GameState) -> gd.Bool {return gd.Bool(self.cleared)}

// BARRAGE_TEST=1 (the suite driver) compresses every timing so the whole run fits in a
// few headless seconds. Scripts read this ONE flag through GameState so the knob is in
// one place. @(gd_method) so the ISOLATED modules can ask through the engine too.
@(gd_method)
game_state_is_test :: proc(self: ^GameState) -> gd.Bool {
	return gd.Bool(os.get_env("BARRAGE_TEST", context.temp_allocator) == "1")
}
