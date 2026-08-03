//gd:extends CanvasLayer
//gd:class GameOverMenu
package survivors_scripts

// ----------------------------------------------------------------------------
// GameOverMenu — shown when the player dies: time survived / level reached / kills, and a
// Restart button. Restart asks the Game to reset the shared state and reload the scene. Its
// process_mode is Always, so the button works while the tree is paused.
//
// FEATURES: `@onready` refs; reading the shared game_state module for the summary; the
// path-qualified `@(gd_connect = "Panel/Restart:pressed")` wiring the Button declaratively
// (the emitter is a static child — no _ready connect call, no field to hold it); a typed
// cross-script call into the Game found by group (rt.first_script_in_group).
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"
import "core:fmt"

GameOver :: struct {
	owner: gd.Node,
	stats: gd.Node `gd:"onready=Panel/Stats"`,
}

game_over_ready :: proc(self: ^GameOver) {
	gd.set_bool(self.owner, "visible", false)
	// (The Restart button's `pressed` is wired declaratively — see game_over_on_restart.)
}

// present — fill in the run summary and show the screen (called by the Game on death).
game_over_present :: proc(self: ^GameOver) {
	if self.stats != nil {
		t := int(game_state_get_run_time())
		mm := t / 60
		ss := t % 60
		text := fmt.ctprintf(
			"GAME OVER\n\nTime  %02d:%02d\nLevel %d\nKills %d\nScore %d",
			mm,
			ss,
			game_state_get_level(),
			game_state_get_kills(),
			game_state_get_score(),
		)
		gd.set_string(self.stats, "text", text)
	}
	gd.set_bool(self.owner, "visible", true)
}

// on_restart — the Restart button's handler, auto-wired by the path-qualified @(gd_connect)
// above the proc. Reset + reload via the Game (typed, found by group).
@(gd_method, gd_connect = "Panel/Restart:pressed")
game_over_on_restart :: proc(self: ^GameOver) {
	g := rt.first_script_in_group(self.owner, GROUP_GAME, Game)
	if g != nil {game_restart(g)}
}
