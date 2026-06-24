//gd:extends Label
//gd:class Hud
package survivors_scripts

// ----------------------------------------------------------------------------
// Hud — a Label showing "Score" + the player's "HP" (and "GAME OVER" when the run ends).
//
// It pulls its two values from two different odin_godot mechanisms, on purpose:
//   * SCORE / game-over : read from the shared game_state MODULE every frame (the decoupled
//                         global-state path).
//   * HP                : received via the player's `health_changed` SIGNAL, wired with a
//                         TYPED cross-script connect (gd.connect_to) in _ready. The HUD reads
//                         the player's starting HP once (typed, rt.script_of) to seed itself,
//                         then just listens.
//
// So the HUD never polls the player for HP — it reacts to the signal — and the player never
// knows the HUD exists. That is the point of signals + a shared module.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"
import "core:fmt"

Hud :: struct {
	owner:        gd.Label,
	hp:           int, // last HP we were told about (via the signal)
	shown_score:  gd.Int, // last score we rendered (avoids rebuilding the string each frame)
	shown_hp:     int,
	shown_over:   bool,
	initialized:  bool,
}

hud_ready :: proc(self: ^Hud) {
	// Find the player by group and seed our HP from it (typed read), then subscribe to its
	// health_changed signal so every later change pushes straight to us.
	player := find_player(self.owner)
	if player != nil {
		p := rt.script_of(player, Player)
		if p != nil {self.hp = p.health}
		// TYPED cross-script CONNECT: player.health_changed -> this.on_health_changed.
		gd.connect_to(player, "health_changed", self.owner, "on_health_changed")
	}
	self.shown_score = -1 // force a first paint
	hud_refresh(self)
}

hud_process :: proc(self: ^Hud, delta: f64) {
	hud_refresh(self)
}

// on_health_changed — the signal target. Connected via gd.connect_to above; it must be a
// @(gd_method) so the engine can dispatch the signal to it. `value` is the player's new HP.
@(gd_method)
hud_on_health_changed :: proc(self: ^Hud, value: int) {
	self.hp = value
}

// hud_refresh rebuilds the label text only when something actually changed.
@(private = "file")
hud_refresh :: proc(self: ^Hud) {
	score := game_state_get_score()
	over := game_state_is_game_over()
	if self.initialized && score == self.shown_score && self.hp == self.shown_hp && over == self.shown_over {
		return
	}
	self.shown_score = score
	self.shown_hp = self.hp
	self.shown_over = over
	self.initialized = true

	text: cstring
	if over {
		text = fmt.ctprintf("GAME OVER\nScore: %d", score)
	} else {
		text = fmt.ctprintf("Score: %d\nHP: %d", score, self.hp)
	}
	gd.label_set_text(self.owner, gd.new_string_cstring(text))
}
