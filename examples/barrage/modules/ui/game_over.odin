//gd:extends Control
//gd:class GameOver
package barrage_ui

// ----------------------------------------------------------------------------
// GameOver — end screen (ui MODULE): CLEARED (boss down) vs GAME OVER (hp zero), the
// final score from GameState, and two [connection]-wired buttons: retry -> game.tscn,
// menu -> title.tscn (scene loading again).
// ----------------------------------------------------------------------------

import "core:fmt"
import gd "godot:godot"

GameOver :: struct {
	owner: gd.Control,

	result_label: gd.Node,
	score_label:  gd.Node,
}

game_over_ready :: proc(self: ^GameOver) {
	n := cast(gd.Node)self.owner
	self.result_label = gd.node_get_node(n, gd.new_node_path_cstring("Result"))
	self.score_label = gd.node_get_node(n, gd.new_node_path_cstring("Score"))
	gs := cast(gd.Object)gd.node_get_node(cast(gd.Node)self.owner, gd.new_node_path_cstring("/root/GameState"))
	if gs == nil {return}
	sm := gd.sname("get_score")
	sv := gd.object_call(gs, sm)
	cm := gd.sname("is_cleared")
	cv := gd.object_call(gs, cm)
	cleared := bool(gd.variant_to_bool(&cv))
	if self.result_label != nil {
		t := gd.new_string_cstring(cleared ? "CLEARED!" : "GAME OVER")
		gd.label_set_text(cast(gd.Label)self.result_label, t)
	}
	if self.score_label != nil {
		t := gd.new_string_odin(fmt.tprintf("final score %d", gd.variant_to_int(&sv)))
		gd.label_set_text(cast(gd.Label)self.score_label, t)
	}
	// The suite's game-over sentinel (only under BARRAGE_TEST — see game_state.odin).
	tm := gd.sname("is_test")
	tv := gd.object_call(gs, tm)
	if bool(gd.variant_to_bool(&tv)) {
		gd.print_str(fmt.tprintf("BARRAGE_GAMEOVER cleared=%v score=%d", cleared, gd.variant_to_int(&sv)))
	}
}

@(gd_method)
game_over_retry :: proc(self: ^GameOver) {
	gs := cast(gd.Object)gd.node_get_node(cast(gd.Node)self.owner, gd.new_node_path_cstring("/root/GameState"))
	if gs != nil {
		m := gd.sname("reset")
		_ = gd.object_call(gs, m)
	}
	if tree := gd.node_get_tree(cast(gd.Node)self.owner); tree != nil {
		path := gd.new_string_cstring("res://game.tscn")
		_ = gd.scene_tree_change_scene_to_file(tree, path)
	}
}

@(gd_method)
game_over_to_menu :: proc(self: ^GameOver) {
	if tree := gd.node_get_tree(cast(gd.Node)self.owner); tree != nil {
		path := gd.new_string_cstring("res://title.tscn")
		_ = gd.scene_tree_change_scene_to_file(tree, path)
	}
}
