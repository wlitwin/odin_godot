//gd:extends CanvasLayer
//gd:class GameOverMenu
package survivors_scripts

// ----------------------------------------------------------------------------
// GameOverMenu — shown when the player dies: time survived / level reached / kills, and a
// Restart button. Restart asks the Game to reset the shared state and reload the scene. Its
// process_mode is Always, so the button works while the tree is paused.
//
// FEATURES: `@onready` refs; reading the shared game_state module for the summary; `gd.connect_to`
// wiring the Button's `pressed` to a @(gd_method); a typed cross-script call into the Game.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"
import "core:fmt"

GameOver :: struct {
	owner:   gd.Node,
	stats:   gd.Node `gd:"onready=Panel/Stats"`,
	restart: gd.Node `gd:"onready=Panel/Restart"`,
}

game_over_ready :: proc(self: ^GameOver) {
	gd.set_bool(self.owner, "visible", false)
	if self.restart != nil {gd.connect_to(self.restart, "pressed", self.owner, "on_restart")}
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

// on_restart — the Restart button's handler. Reset + reload via the Game.
@(gd_method)
game_over_on_restart :: proc(self: ^GameOver) {
	game := find_game(self.owner)
	if game == nil {return}
	g := rt.script_of(game, Game)
	if g != nil {game_restart(g)}
}
