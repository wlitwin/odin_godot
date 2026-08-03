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

// Plain helper (not a lifecycle name, not @(gd_method)) -> scriptgen leaves it alone.
@(private = "file")
hud_refresh :: proc(self: ^Hud) {
	s := game_state_get()
	if s == self.shown {return}
	self.shown = s
	gd.set_text(self.owner, fmt.ctprintf("Score: %d", s))
}
