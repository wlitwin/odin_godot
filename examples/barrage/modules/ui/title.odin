//gd:extends Control
//gd:class Title
package barrage_ui

// ----------------------------------------------------------------------------
// Title — the menu scene root (ui MODULE). Its Play button's `pressed` is wired to
// `start_game` in title.tscn ([connection]); starting = real SCENE LOADING
// (change_scene_to_file into game.tscn). The heading pulses via flowgd.tween — an
// engine Tween wrapped as a flow.Action and ticked from _process (docs: flow).
// ----------------------------------------------------------------------------

import gd "godot:godot"
import flow "godot:flow"
import flowgd "godot:flowgd"

Title :: struct {
	owner: gd.Control,

	heading: gd.Node, // resolved by relative path in _ready

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
	// GameState survives scene switches (autoload) — a fresh title = a fresh run.
	gs := gd.node_get_node(cast(gd.Node)self.owner, gd.new_node_path_cstring("/root/GameState"))
	if gs != nil {
		m := gd.sname("reset")
		_ = gd.object_call(cast(gd.Object)gs, m)
	}
	self.heading = gd.node_get_node(cast(gd.Node)self.owner, gd.new_node_path_cstring("Heading"))
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
	tree := gd.node_get_tree(cast(gd.Node)self.owner)
	if tree == nil {return}
	path := gd.new_string_cstring("res://game.tscn")
	_ = gd.scene_tree_change_scene_to_file(tree, path)
}
