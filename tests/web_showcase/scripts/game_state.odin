package showcase_scripts

// ----------------------------------------------------------------------------
// game_state — the shared cross-script "module".
//
// This file has NO owner-struct, so scriptgen skips it: it is just an ordinary Odin
// source compiled INTO the scripts dll. Because the whole showcase compiles into ONE
// Odin package, every script shares these package globals. That is the "autoload-style
// shared module" the coin writes (`game_state_add`) and the HUD reads (`game_state_get`),
// demonstrating cross-script state without any GDScript glue or a Godot singleton node.
// ----------------------------------------------------------------------------

import gd "godot:godot"

// File-private backing state; reachable only through the package procs below.
@(private = "file")
score: gd.Int

// Add to the shared score (called by a coin when it is collected).
game_state_add :: proc "contextless" (amount: gd.Int) {
	score += amount
}

// Read the shared score (called by the HUD each frame).
game_state_get :: proc "contextless" () -> gd.Int {
	return score
}

// Reset the score (called by the player on _ready, so a fresh run starts at 0).
game_state_reset :: proc "contextless" () {
	score = 0
}
