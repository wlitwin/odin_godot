//gd:extends Control
//gd:class GameOver
package barrage_ui

// ----------------------------------------------------------------------------
// GameOver — end screen (ui MODULE): CLEARED (boss down) vs GAME OVER (hp zero), the
// final score from GameState (onready-wired autoload, read via gd.vcall — the
// cross-module interface's spelling), and two [connection]-wired buttons: retry ->
// game.tscn, menu -> title.tscn (scene loading again, via gd.change_scene).
// ----------------------------------------------------------------------------

import "core:fmt"
import gd "godot:godot"

GameOver :: struct {
	owner: gd.Control,

	// Labels auto-wired at READY — @onready refs (no manual get_node).
	result_label: gd.Node `gd:"onready=Result"`,
	score_label:  gd.Node `gd:"onready=Score"`,
	// The GameState autoload (absolute onready path), resolved before _ready runs.
	gs: gd.Object `gd:"onready=/root/GameState"`,
}

game_over_ready :: proc(self: ^GameOver) {
	if self.gs == nil {return}
	score := gd.vcall_int(self.gs, "get_score")
	cleared := gd.vcall_bool(self.gs, "is_cleared")
	if self.result_label != nil {
		gd.set_text(self.result_label, cleared ? "CLEARED!" : "GAME OVER")
	}
	if self.score_label != nil {
		gd.set_text(self.score_label, fmt.ctprintf("final score %d", score))
	}
	// The suite's game-over sentinel (only under BARRAGE_TEST — see game_state.odin).
	if gd.vcall_bool(self.gs, "is_test") {
		gd.print_str(fmt.tprintf("BARRAGE_GAMEOVER cleared=%v score=%d", cleared, score))
	}
}

@(gd_method)
game_over_retry :: proc(self: ^GameOver) {
	gd.vcall_void(self.gs, "reset")
	gd.change_scene(self.owner, "res://game.tscn")
}

@(gd_method)
game_over_to_menu :: proc(self: ^GameOver) {
	gd.change_scene(self.owner, "res://title.tscn")
}
