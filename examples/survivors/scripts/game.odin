//gd:extends Node2D
//gd:class Game
//gd:group game
package survivors_scripts

// ----------------------------------------------------------------------------
// Game — the root orchestrator + state machine (Playing / LevelUp-paused / GameOver). It:
//   * resets the run and binds WASD onto the ui_* actions on _ready (its "game" group
//     membership is declared with //gd:group above — no add_to_group boilerplate);
//   * advances the shared run-time clock each frame while Playing;
//   * listens (declarative @(gd_connect)) to the player's `leveled_up` -> opens the upgrade
//     menu + PAUSES the tree, and `died` -> shows the game-over screen;
//   * settles each owed level-up after the player picks (multiple levels => sequential menus);
//   * exposes @(gd_method) accessors (get_level / get_kills / …) so the headless test can
//     observe the shared module's state from GDScript.
//
// FEATURES: SCRIPT-RESOLVING @onready refs (`^LevelupMenu` / `^GameOver` — the node AND its
// typed script struct in one declaration, no rt.script_of at the use sites); the gd.pause
// one-liner; the Input ergonomics (gd.action_add_key) to bind WASD; declarative //gd:group
// membership; typed cross-script calls into the menus/player.
// ----------------------------------------------------------------------------

import gd "godot:godot"

Game :: struct {
	owner:      gd.Node2d,
	player:     gd.Node `gd:"onready=Player"`,
	spawner:    gd.Node `gd:"onready=Spawner"`,
	// Script-resolving onready: resolved to the node's TYPED script struct before _ready
	// (nil + a loud error if the node lacks the script — never a wrong cast).
	levelup:    ^LevelupMenu `gd:"onready=LevelUpMenu"`,
	gameover:   ^GameOver    `gd:"onready=GameOver"`,
}

game_ready :: proc(self: ^Game) {
	game_state_reset()

	// A fresh scene must start unpaused (restart reloads while paused).
	gd.pause(self.owner, false)

	// Bind WASD onto the default ui_* movement actions (arrows already map to them).
	gd.action_add_key("ui_left", i64(gd.Key.A))
	gd.action_add_key("ui_right", i64(gd.Key.D))
	gd.action_add_key("ui_up", i64(gd.Key.W))
	gd.action_add_key("ui_down", i64(gd.Key.S))

	// The player's signals are wired declaratively: @(gd_connect="Player:...") on the
	// handlers below — the path-qualified form reaches another emitter, so no manual
	// connect_to here anymore.
}

game_process :: proc(self: ^Game, delta: f64) {
	if game_state_get_state() == .Playing {
		game_state_advance_time(delta)
	}
}

// on_level_up — the player crossed a level boundary. Enter the LevelUp state, pause the tree,
// and open the upgrade menu (which keeps running because its process_mode is Always).
// Auto-wired to the child Player's declared signal (path-qualified @(gd_connect)).
@(gd_method, gd_connect = "Player:leveled_up")
game_on_level_up :: proc(self: ^Game) {
	if game_state_get_state() != .Playing {return} // already showing a menu
	game_state_set_state(.LevelUp)
	gd.pause(self.owner, true)
	game_present_levelup(self)
}

// game_after_pick — the menu calls this (typed) after the player chooses. Settle one owed
// level-up; if more are owed show the next choice, otherwise resume play.
game_after_pick :: proc(self: ^Game) {
	remaining := game_state_consume_levelup()
	if remaining > 0 {
		game_present_levelup(self)
		return
	}
	if self.levelup != nil {gd.set_bool(self.levelup.owner, "visible", false)}
	game_state_set_state(.Playing)
	gd.pause(self.owner, false)
}

@(private = "file")
game_present_levelup :: proc(self: ^Game) {
	// self.levelup is already the TYPED menu struct (script-resolving onready) — call straight in.
	if self.levelup != nil {levelup_menu_present(self.levelup)}
}

// on_player_died — show the game-over screen and pause.
@(gd_method, gd_connect = "Player:died")
game_on_player_died :: proc(self: ^Game) {
	game_state_set_state(.GameOver)
	gd.pause(self.owner, true)
	if self.gameover != nil {game_over_present(self.gameover)}
}

// game_restart — the game-over menu calls this (typed): reset state and reload the scene.
// (reload_current_scene has no one-liner wrapper, so this keeps the explicit get_tree.)
game_restart :: proc(self: ^Game) {
	gd.pause(self.owner, false)
	game_state_reset()
	if tree := gd.get_tree(self.owner); tree != nil {
		gd.scene_tree_reload_current_scene(tree)
	}
}

// ---- @(gd_method) accessors: let GDScript / the test read the shared module's state ----
@(gd_method)
game_get_state :: proc(self: ^Game) -> int {return int(game_state_get_state())}
@(gd_method)
game_get_level :: proc(self: ^Game) -> int {return game_state_get_level()}
@(gd_method)
game_get_kills :: proc(self: ^Game) -> int {return game_state_get_kills()}
@(gd_method)
game_get_score :: proc(self: ^Game) -> int {return game_state_get_score()}
@(gd_method)
game_get_xp :: proc(self: ^Game) -> int {return game_state_get_xp()}
@(gd_method)
game_get_run_time :: proc(self: ^Game) -> f64 {return game_state_get_run_time()}
@(gd_method)
game_get_pending :: proc(self: ^Game) -> int {return game_state_get_pending()}
