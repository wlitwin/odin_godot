//gd:extends CanvasLayer
//gd:class Hud
package survivors_scripts

// ----------------------------------------------------------------------------
// Hud — the heads-up display: an XP ProgressBar, a Health ProgressBar, and an info Label
// (Level / Time mm:ss / Kills / Score). It is a CanvasLayer so it draws over the arena.
//
// It pulls its values from two odin_godot mechanisms, on purpose:
//   * XP / level / time / kills / score : read from the shared game_state MODULE each frame.
//   * HP                                : received via the player's `health_changed` SIGNAL.
//     The player is found by GROUP at runtime — no static path — so declarative
//     @(gd_connect) cannot reach it; `gd.connect_to` from _ready is the documented
//     escape hatch for runtime-resolved emitters.
//
// FEATURES: `@onready` auto-wired child refs (no manual get_node in _ready); property helpers
// (gd.set_float / gd.set_string) to drive the bars + label; the typed group query
// (rt.first_script_in_group) + manual cross-script signal CONNECT.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"
import "core:fmt"

Hud :: struct {
	owner:      gd.Node,
	xp_bar:     gd.Node `gd:"onready=XPBar"`,
	health_bar: gd.Node `gd:"onready=HealthBar"`,
	info:       gd.Node `gd:"onready=Info"`,

	hp:     int, // last HP we were told about (via the signal)
	max_hp: int,
}

hud_ready :: proc(self: ^Hud) {
	// Typed, class-checked group lookup — one call replaces the find-node + rt.script_of pair.
	p := rt.first_script_in_group(self.owner, GROUP_PLAYER, Player)
	if p != nil {
		self.hp = p.health
		self.max_hp = p.max_health
		// TYPED cross-script CONNECT: player.health_changed -> this.on_health_changed.
		// Manual on purpose — a group-resolved emitter has no static path for @(gd_connect).
		gd.connect_to(p.owner, "health_changed", self.owner, "on_health_changed")
	}
	if self.health_bar != nil {
		gd.set_float(self.health_bar, "max_value", f64(self.max_hp))
		gd.set_float(self.health_bar, "value", f64(self.hp))
	}
}

hud_process :: proc(self: ^Hud, delta: f64) {
	xp := game_state_get_xp()
	xp_next := game_state_get_xp_to_next()
	if self.xp_bar != nil {
		gd.set_float(self.xp_bar, "max_value", f64(xp_next))
		gd.set_float(self.xp_bar, "value", f64(xp))
	}
	if self.health_bar != nil {
		gd.set_float(self.health_bar, "max_value", f64(self.max_hp))
		gd.set_float(self.health_bar, "value", f64(self.hp))
	}
	if self.info != nil {
		t := int(game_state_get_run_time())
		mm := t / 60
		ss := t % 60
		text := fmt.ctprintf(
			"Lv %d   %02d:%02d\nKills %d   Score %d",
			game_state_get_level(),
			mm,
			ss,
			game_state_get_kills(),
			game_state_get_score(),
		)
		gd.set_string(self.info, "text", text)
	}
}

// on_health_changed — the signal target (a @(gd_method) so the engine can dispatch to it).
@(gd_method)
hud_on_health_changed :: proc(self: ^Hud, value: int) {
	self.hp = value
}
