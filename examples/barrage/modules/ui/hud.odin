//gd:extends CanvasLayer
//gd:class Hud
package barrage_ui

// ----------------------------------------------------------------------------
// Hud — score / hp / LIVE BULLET COUNT / boss phase (ui MODULE). Cross-module READS
// only: isolated modules can't import each other's types, so the engine is the
// interface — and gd.vcall is that interface's spelling: poll the GameState autoload
// (onready-cached, not a get_node per frame) and the field/spawner groups by name.
// Watches GameState.player_died / cleared to drive the game-over scene switch.
// ----------------------------------------------------------------------------

import "core:fmt"
import gd "godot:godot"

Hud :: struct {
	owner: gd.Node,

	// Labels auto-wired at READY (children of this CanvasLayer) — @onready refs.
	score_label: gd.Node `gd:"onready=Score"`,
	hp_label:    gd.Node `gd:"onready=Hp"`,
	stats_label: gd.Node `gd:"onready=Stats"`,
	// The GameState autoload, resolved ONCE (absolute onready path).
	gs: gd.Object `gd:"onready=/root/GameState"`,

	// Cross-module handles, resolved lazily from their groups and cached (per-frame
	// polling — pay the group query once, not every frame).
	field:   gd.Object,
	spawner: gd.Object,
	ended:   bool,
}

@(private = "file")
set_label :: proc(node: gd.Node, text: cstring) {
	if node == nil {return}
	gd.set_text(node, text)
}

hud_process :: proc(self: ^Hud, delta: f64) {
	if self.gs == nil {return}
	score := gd.vcall_int(self.gs, "get_score")
	hp := gd.vcall_int(self.gs, "get_hp")
	max_hp := gd.vcall_int(self.gs, "get_max_hp")
	set_label(self.score_label, fmt.ctprintf("SCORE %d", score))
	set_label(self.hp_label, fmt.ctprintf("HP %d/%d", hp, max_hp))

	// vcall on a nil handle is a quiet zero, so a not-yet-found field/spawner reads 0.
	if self.field == nil {self.field = gd.first_in_group(self.owner, "bullet_field")}
	bullets := gd.vcall_int(self.field, "live_count")
	if self.spawner == nil {self.spawner = gd.first_in_group(self.owner, "spawner")}
	phase := gd.vcall_int(self.spawner, "get_boss_phase")
	set_label(self.stats_label, fmt.ctprintf("bullets %d   boss phase %d", bullets, phase))

	// Run over? (dead OR cleared) -> the game-over scene. One-shot.
	if !self.ended && (hp <= 0 || gd.vcall_bool(self.gs, "is_cleared")) {
		self.ended = true
		gd.change_scene(self.owner, "res://gameover.tscn")
	}
}
