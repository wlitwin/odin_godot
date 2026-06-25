//gd:extends Node2D
//gd:class Game
package survivors_scripts

// ----------------------------------------------------------------------------
// Game — the root orchestrator + state machine (Playing / LevelUp-paused / GameOver). It:
//   * resets the run, binds WASD onto the ui_* actions, and joins the "game" group on _ready;
//   * advances the shared run-time clock each frame while Playing;
//   * listens (typed cross-script CONNECT) to the player's `leveled_up` -> opens the upgrade
//     menu + PAUSES the tree, and `died` -> shows the game-over screen;
//   * settles each owed level-up after the player picks (multiple levels => sequential menus);
//   * exposes @(gd_method) accessors (get_level / get_kills / …) so the headless test can
//     observe the shared module's state from GDScript.
//
// FEATURES: @onready child refs; tree PAUSE via gd.scene_tree_set_pause; the Input ergonomics
// (gd.action_add_key) to bind WASD; typed cross-script connects + calls into the menus/player.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

Game :: struct {
	owner:      gd.Node2d,
	player:     gd.Node `gd:"onready=Player"`,
	spawner:    gd.Node `gd:"onready=Spawner"`,
	levelup:    gd.Node `gd:"onready=LevelUpMenu"`,
	gameover:   gd.Node `gd:"onready=GameOver"`,
}

game_ready :: proc(self: ^Game) {
	game_state_reset()
	gd.add_to_group(self.owner, GROUP_GAME)

	// A fresh scene must start unpaused (restart reloads while paused).
	tree := gd.get_tree(self.owner)
	if tree != nil {gd.scene_tree_set_pause(tree, false)}

	// Bind WASD onto the default ui_* movement actions (arrows already map to them).
	gd.action_add_key("ui_left", i64(gd.Key.A))
	gd.action_add_key("ui_right", i64(gd.Key.D))
	gd.action_add_key("ui_up", i64(gd.Key.W))
	gd.action_add_key("ui_down", i64(gd.Key.S))

	// Wire the player's signals to us (typed cross-script connect: the emitter is the player,
	// not our own owner, so connect_to rather than @(gd_connect)).
	if self.player != nil {
		gd.connect_to(self.player, "leveled_up", self.owner, "on_level_up")
		gd.connect_to(self.player, "died", self.owner, "on_player_died")
	}
}

game_process :: proc(self: ^Game, delta: f64) {
	if game_state_get_state() == .Playing {
		game_state_advance_time(delta)
	}
}

// on_level_up — the player crossed a level boundary. Enter the LevelUp state, pause the tree,
// and open the upgrade menu (which keeps running because its process_mode is Always).
@(gd_method)
game_on_level_up :: proc(self: ^Game) {
	if game_state_get_state() != .Playing {return} // already showing a menu
	game_state_set_state(.LevelUp)
	tree := gd.get_tree(self.owner)
	if tree != nil {gd.scene_tree_set_pause(tree, true)}
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
	if self.levelup != nil {gd.set_bool(self.levelup, "visible", false)}
	game_state_set_state(.Playing)
	tree := gd.get_tree(self.owner)
	if tree != nil {gd.scene_tree_set_pause(tree, false)}
}

@(private = "file")
game_present_levelup :: proc(self: ^Game) {
	if self.levelup == nil {return}
	m := rt.script_of(self.levelup, LevelupMenu)
	if m != nil {levelup_menu_present(m)}
}

// on_player_died — show the game-over screen and pause.
@(gd_method)
game_on_player_died :: proc(self: ^Game) {
	game_state_set_state(.GameOver)
	tree := gd.get_tree(self.owner)
	if tree != nil {gd.scene_tree_set_pause(tree, true)}
	if self.gameover != nil {
		go := rt.script_of(self.gameover, GameOver)
		if go != nil {game_over_present(go)}
	}
}

// game_restart — the game-over menu calls this (typed): reset state and reload the scene.
game_restart :: proc(self: ^Game) {
	tree := gd.get_tree(self.owner)
	if tree == nil {return}
	gd.scene_tree_set_pause(tree, false)
	game_state_reset()
	gd.scene_tree_reload_current_scene(tree)
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
