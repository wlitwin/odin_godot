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

Hud :: struct {
	owner: gd.Label,
	shown: gd.Int, // last score we rendered (avoids rebuilding the string every frame)
}

hud_ready :: proc(self: ^Hud) {
	self.shown = -1 // force a first paint
	hud_refresh(self)
}

hud_process :: proc(self: ^Hud, delta: f64) {
	hud_refresh(self)
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

// Plain helper (not a lifecycle name, not @(gd_method)) -> scriptgen leaves it alone.
@(private = "file")
hud_refresh :: proc(self: ^Hud) {
	s := game_state_get()
	if s == self.shown {return}
	self.shown = s
	text := fmt.ctprintf("Score: %d", s)
	gd.label_set_text(self.owner, gd.new_string_cstring(text))
}
