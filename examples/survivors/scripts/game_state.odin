package survivors_scripts

// ----------------------------------------------------------------------------
// game_state — the shared cross-script "module" (the global game state).
//
// FEATURE: shared-module pattern. This file has NO owner-struct, so scriptgen ignores it
// entirely — it is just an ordinary Odin source compiled INTO the scripts dll. Because the
// whole game compiles into ONE Odin package, EVERY script shares these package globals.
// That is an "autoload-style" singleton with zero Godot/GDScript glue:
//
//   * an enemy that dies calls `game_state_add_score(points)`        (writer)
//   * the player on death calls `game_state_set_game_over()`         (writer)
//   * the HUD reads `game_state_get_score()` / `..._is_game_over()`  (reader)
//
// None of those scripts know about each other — they only share this module. Use this
// pattern for truly global state; use typed cross-script refs (rt.script_of, see enemy.odin)
// when you have a specific other node to talk to.
// ----------------------------------------------------------------------------

import gd "godot:godot"

// File-private backing state — reachable only through the package procs below.
@(private = "file")
score: gd.Int
@(private = "file")
game_over: bool

// add to the shared score (an enemy calls this when it dies).
game_state_add_score :: proc "contextless" (amount: gd.Int) {
	score += amount
}

// read the shared score (the HUD calls this each frame).
game_state_get_score :: proc "contextless" () -> gd.Int {
	return score
}

// flag that the run is over (the player calls this on death).
game_state_set_game_over :: proc "contextless" () {
	game_over = true
}

// read the game-over flag (the HUD calls this each frame).
game_state_is_game_over :: proc "contextless" () -> bool {
	return game_over
}

// reset for a fresh run (the player calls this on _ready).
game_state_reset :: proc "contextless" () {
	score = 0
	game_over = false
}
