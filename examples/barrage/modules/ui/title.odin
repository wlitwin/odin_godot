//gd:extends Control
//gd:class Title
package barrage_ui

// ----------------------------------------------------------------------------
// Title — the menu scene root (ui MODULE). Its Play button's `pressed` is wired to
// `start_game` in title.tscn ([connection]); starting = real SCENE LOADING
// (gd.change_scene into game.tscn). The heading pulses via flowgd.tween — an
// engine Tween wrapped as a flow.Action and ticked from _process (docs: flow).
// ----------------------------------------------------------------------------

import gd "godot:godot"
import flow "godot:flow"
import flowgd "godot:flowgd"

Title :: struct {
	owner: gd.Control,

	heading: gd.Node `gd:"onready=Heading"`, // auto-wired child ref (@onready)
	// The GameState autoload (absolute onready path), resolved before _ready runs.
	gs: gd.Object `gd:"onready=/root/GameState"`,

	anim:  flow.Action,
	built: bool,
}

@(private = "file")
configure_pulse :: proc(t: gd.Tween, ctx: rawptr) {
	self := cast(^Title)ctx
	if self.heading == nil {return}
	obj := cast(gd.Object)self.heading
	prop := gd.new_node_path_cstring("scale")
	up := gd.Vector2{1.06, 1.06}
	upv := gd.variant_from(&up)
	down := gd.Vector2{1, 1}
	downv := gd.variant_from(&down)
	// Successive property tweeners run as sequential steps; set_loops(0) = forever.
	_ = gd.tween_set_loops(t, 0)
	_ = gd.tween_tween_property(t, obj, prop, upv, 0.6)
	_ = gd.tween_tween_property(t, obj, prop, downv, 0.6)
}

title_ready :: proc(self: ^Title) {
	// Scene-entry sentinel: proves the ui module booted (the web smoke test greps the
	// browser console for it; on web, print_str lands in console.log).
	gd.print_str("BARRAGE_TITLE_READY")
	// GameState survives scene switches (autoload) — a fresh title = a fresh run.
	// Cross-module by-name call on the onready-wired handle (nil-quiet if absent).
	gd.vcall_void(self.gs, "reset")
	self.anim = flowgd.tween(cast(gd.Node)self.owner, configure_pulse)
	self.built = true
}

title_process :: proc(self: ^Title, delta: f64) {
	if self.built {
		flow.tick(&self.anim, self, delta)
	}
}

// start_game — title.tscn [connection] target for the Play button's `pressed`.
@(gd_method)
title_start_game :: proc(self: ^Title) {
	gd.change_scene(self.owner, "res://game.tscn")
}
