package survivors_scripts

// ----------------------------------------------------------------------------
// game_state — the shared cross-script "module": the whole run's global state (time, kills,
// score, level, XP curve, the run state machine, and the game-over flag).
//
// FEATURE: shared-module pattern. This file has NO owner-struct, so scriptgen ignores it — it
// is plain Odin compiled INTO the one scripts dll. Because every script in the project is the
// same Odin package, they all share these package globals with zero Godot glue:
//
//   * an xp gem the player collects calls `game_state_add_xp(value)`   (writer)
//   * an enemy that dies calls `game_state_add_kill(points)`           (writer)
//   * game.odin advances `run_time` each frame + reads the state       (writer/reader)
//   * the HUD reads level / xp / time / kills / score every frame      (reader)
//
// This is the decoupled global-state path; for talking to a SPECIFIC node use a typed
// cross-script ref (rt.script_of) instead (see enemy.odin / player.odin).
// ----------------------------------------------------------------------------

// The run's state machine. game.odin drives it; the HUD/test read it.
Game_State :: enum int {
	Playing  = 0,
	LevelUp  = 1, // a level-up choice is open and the tree is paused
	GameOver = 2,
}

@(private = "file")
state: Game_State
@(private = "file")
run_time: f64 // seconds survived this run
@(private = "file")
kills: int
@(private = "file")
score: int
@(private = "file")
level: int = 1
@(private = "file")
xp: int // XP banked toward the NEXT level
@(private = "file")
xp_to_next: int = 5
@(private = "file")
pending_levelups: int // level-up menus still owed (you can gain several levels at once)

// xp_curve — XP required to go from `lvl` to `lvl+1`. A gentle ramp so early levels come
// fast and later ones take longer.
@(private = "file")
xp_curve :: proc "contextless" (lvl: int) -> int {
	return 5 + (lvl - 1) * 4
}

// add_xp banks `n` XP and rolls over as many level-ups as it funds. Returns true if at least
// one level was gained (each gained level also bumps `pending_levelups`, so the menu can be
// shown once per level).
game_state_add_xp :: proc "contextless" (n: int) -> bool {
	xp += n
	leveled := false
	for xp >= xp_to_next {
		xp -= xp_to_next
		level += 1
		pending_levelups += 1
		xp_to_next = xp_curve(level)
		leveled = true
	}
	return leveled
}

// add_kill — an enemy died: count it and bank its score.
game_state_add_kill :: proc "contextless" (points: int) {
	kills += 1
	score += points
}

game_state_advance_time :: proc "contextless" (delta: f64) {run_time += delta}

// ---- readers --------------------------------------------------------------
game_state_get_state :: proc "contextless" () -> Game_State {return state}
game_state_set_state :: proc "contextless" (s: Game_State) {state = s}
game_state_get_run_time :: proc "contextless" () -> f64 {return run_time}
game_state_get_kills :: proc "contextless" () -> int {return kills}
game_state_get_score :: proc "contextless" () -> int {return score}
game_state_get_level :: proc "contextless" () -> int {return level}
game_state_get_xp :: proc "contextless" () -> int {return xp}
game_state_get_xp_to_next :: proc "contextless" () -> int {return xp_to_next}
game_state_get_pending :: proc "contextless" () -> int {return pending_levelups}

// consume_levelup — the menu calls this after the player picks: one owed menu is settled.
// Returns how many remain (so the menu knows whether to show another choice).
game_state_consume_levelup :: proc "contextless" () -> int {
	if pending_levelups > 0 {pending_levelups -= 1}
	return pending_levelups
}

game_state_is_game_over :: proc "contextless" () -> bool {return state == .GameOver}

// reset — start a fresh run (the Game node calls this in _ready).
game_state_reset :: proc "contextless" () {
	state = .Playing
	run_time = 0
	kills = 0
	score = 0
	level = 1
	xp = 0
	xp_to_next = xp_curve(1)
	pending_levelups = 0
}
