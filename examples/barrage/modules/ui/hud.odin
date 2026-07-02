//gd:extends CanvasLayer
//gd:class Hud
package barrage_ui

// ----------------------------------------------------------------------------
// Hud — score / hp / LIVE BULLET COUNT / boss phase (ui MODULE). Cross-module READS
// only: polls the GameState autoload and the field/spawner groups by name each frame
// (isolated modules can't import each other's types — the engine is the interface).
// Watches GameState.player_died / cleared to drive the game-over scene switch.
// ----------------------------------------------------------------------------

import "core:fmt"
import gd "godot:godot"

Hud :: struct {
	owner: gd.Node,

	// Labels resolved by relative path in _ready (children of this CanvasLayer).
	score_label:  gd.Node,
	hp_label:     gd.Node,
	stats_label:  gd.Node,

	field:   gd.Object,
	spawner: gd.Object,
	ended:   bool,
}

@(private = "file")
call_int :: proc(obj: gd.Object, method: cstring) -> i64 {
	m := gd.sname(method)
	v := gd.object_call(obj, m)
	return gd.variant_to_int(&v)
}

hud_ready :: proc(self: ^Hud) {
	n := cast(gd.Node)self.owner
	self.score_label = gd.node_get_node(n, gd.new_node_path_cstring("Score"))
	self.hp_label = gd.node_get_node(n, gd.new_node_path_cstring("Hp"))
	self.stats_label = gd.node_get_node(n, gd.new_node_path_cstring("Stats"))
}

@(private = "file")
set_label :: proc(node: gd.Node, text: string) {
	if node == nil {return}
	s := gd.new_string_odin(text)
	gd.label_set_text(cast(gd.Label)node, s)
}

@(private = "file")
group_obj :: proc(self: ^Hud, cache: ^gd.Object, group: cstring) -> gd.Object {
	if cache^ == nil {
		if tree := gd.node_get_tree(cast(gd.Node)self.owner); tree != nil {
			grp := gd.new_string_name_cstring(group, true)
			cache^ = cast(gd.Object)gd.scene_tree_get_first_node_in_group(tree, grp)
		}
	}
	return cache^
}

hud_process :: proc(self: ^Hud, delta: f64) {
	gs := cast(gd.Object)gd.node_get_node(cast(gd.Node)self.owner, gd.new_node_path_cstring("/root/GameState"))
	if gs == nil {return}
	score := call_int(gs, "get_score")
	hp := call_int(gs, "get_hp")
	max_hp := call_int(gs, "get_max_hp")
	set_label(self.score_label, fmt.tprintf("SCORE %d", score))
	set_label(self.hp_label, fmt.tprintf("HP %d/%d", hp, max_hp))

	bullets: i64 = 0
	if f := group_obj(self, &self.field, "bullet_field"); f != nil {
		bullets = call_int(f, "live_count")
	}
	phase: i64 = 0
	if sp := group_obj(self, &self.spawner, "spawner"); sp != nil {
		phase = call_int(sp, "get_boss_phase")
	}
	set_label(self.stats_label, fmt.tprintf("bullets %d   boss phase %d", bullets, phase))

	// Run over? (dead OR cleared) -> the game-over scene. One-shot.
	if !self.ended {
		cm := gd.sname("is_cleared")
		cv := gd.object_call(gs, cm)
		dead := hp <= 0
		if dead || bool(gd.variant_to_bool(&cv)) {
			self.ended = true
			if tree := gd.node_get_tree(cast(gd.Node)self.owner); tree != nil {
				path := gd.new_string_cstring("res://gameover.tscn")
				_ = gd.scene_tree_change_scene_to_file(tree, path)
			}
		}
	}
}
