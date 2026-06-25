//gd:extends Label
//gd:class Hud
package showcase_scripts

// ----------------------------------------------------------------------------
// Hud — a Label that displays the shared score. Each frame it reads `game_state_get()`
// and, when the value changed, updates its text. This is the read side of the
// cross-script game-state module: the coin writes the score, the HUD reflects it, and
// neither knows about the other — they only share the `game_state` package.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import "core:fmt"
import "core:math/rand"

Hud :: struct {
	owner:     gd.Label,
	shown:     gd.Int, // last score we rendered (avoids rebuilding the string every frame)
	last_roll: gd.Int, // most recent per-frame rand value (regression coverage, see below)
}

hud_ready :: proc(self: ^Hud) {
	self.shown = -1 // force a first paint
	hud_refresh(self)
}

hud_process :: proc(self: ^Hud, delta: f64) {
	hud_refresh(self)
	// REGRESSION COVERAGE: call core:math/rand EVERY frame, exactly like the survivors game
	// does in its main loop. On freestanding_wasm32 a missing context.random_generator seed
	// made this trap with `unreachable executed` every frame (the bug this guards). It must
	// run cleanly in the browser now; hud_roll() lets the driver read advancing values.
	self.last_roll = gd.Int(rand.int31())
}

// get_score() — expose the shared game_state score to the driver directly (no fmt, no
// dependence on _process running). Lets the in-browser driver assert the cross-script
// shared score incremented, independent of the Label text rendering. (This is the only
// addition over the headless showcase's hud.odin, so the browser driver can read the
// shared state without simulating keyboard input.)
@(gd_method)
hud_get_score :: proc(self: ^Hud) -> gd.Int {
	return game_state_get()
}

// roll() — draw a fresh random value via core:math/rand. The browser driver calls this
// twice and asserts both succeed (no wasm trap) and advance, proving the web script context
// installs a working, persistent random_generator. This is the regression guard for the
// "rand traps with `unreachable executed` on web" bug.
@(gd_method)
hud_roll :: proc(self: ^Hud) -> gd.Int {
	return gd.Int(rand.int31())
}

// panic_test() — OPT-IN deliberate panic, called by the browser driver ONLY in its panic
// phase (never in the normal run, so the suite stays green). On freestanding wasm the default
// panic handler traps silently (a bare `unreachable executed`); the web script context now
// installs an assertion_failure_proc that prints a readable message first. The driver asserts
// the recognizable text ("odin web panic sentinel") reaches the browser console.
@(gd_method)
hud_panic_test :: proc(self: ^Hud) {
	panic("odin web panic sentinel")
}

// Plain helper (not a lifecycle name, not @(gd_method)) -> scriptgen leaves it alone.
@(private = "file")
hud_refresh :: proc(self: ^Hud) {
	s := game_state_get()
	if s == self.shown {return}
	self.shown = s
	text := fmt.ctprintf("Score: %d", s)
	gd.label_set_text(self.owner, gd.new_string_cstring(text))
}
