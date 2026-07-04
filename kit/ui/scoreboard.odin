package kit_ui

// The SCOREBOARD (toolkit phase 4): players × whatever stat columns the game
// registered — ping (auto-fed), damage/kills/deaths (kit/combat), a game's
// own counters — straight from the phase-1 stat registry. kit/ui renders
// what the registry holds; it declares nothing. The game wires visibility
// (classically: show while Tab is held).

import gd "godot:godot"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import "core:fmt"
import "core:strings"

Score :: struct {
	root:   gd.Control, // centered VBox panel
	header: gd.Label,
	rows:   [dynamic]gd.Label, // reused across refreshes
}

score_make :: proc(parent: gd.Node) -> Score {
	sb: Score
	sb.root = cast(gd.Control)gd.new_v_box_container()
	gd.node_set_name(cast(gd.Node)sb.root, gd.new_string_name_cstring("Scoreboard", true))
	gd.add_child(parent, cast(gd.Node)sb.root)
	gd.control_set_anchors_preset(sb.root, .Preset_Center_Top, false)
	// Keep the panel centered as rows change width, and off the top edge.
	gd.control_set_h_grow_direction(sb.root, .Grow_Direction_Both)
	gd.control_set_offset(sb.root, .Top, 24)
	gd.control_set_offset(sb.root, .Bottom, 24)
	sb.header = gd.new_label()
	gd.add_child(cast(gd.Node)sb.root, cast(gd.Node)sb.header)
	gd.set_bool(cast(gd.Object)sb.root, "visible", false)
	return sb
}

score_destroy :: proc(sb: ^Score) {
	delete(sb.rows)
	sb^ = {}
	// The node tree itself belongs to the scene (freed with the owner).
}

score_show :: proc(sb: ^Score, visible: bool) {
	gd.set_bool(cast(gd.Object)sb.root, "visible", visible)
}

// Repaint players × columns. Sorted by Player_Id (join order); departed
// players stay listed — their tallies survive disconnects by design.
score_refresh :: proc(sb: ^Score, s: ^ksess.Session) {
	b := strings.builder_make(context.temp_allocator)
	strings.write_string(&b, "spelunker")
	for name in ksess.session_stat_names(s) {
		strings.write_string(&b, " | ")
		strings.write_string(&b, name)
	}
	gd.set_string(cast(gd.Object)sb.header, "text", fmt.ctprintf("%s", strings.to_string(b)))

	ids := make([dynamic]knet.Player_Id, context.temp_allocator)
	for id in s.players {
		append(&ids, id)
	}
	for i in 1 ..< len(ids) {
		for j := i; j > 0 && ids[j] < ids[j - 1]; j -= 1 {
			ids[j], ids[j - 1] = ids[j - 1], ids[j]
		}
	}

	for id, i in ids {
		row: gd.Label
		if i < len(sb.rows) {
			row = sb.rows[i]
		} else {
			row = gd.new_label()
			gd.add_child(cast(gd.Node)sb.root, cast(gd.Node)row)
			append(&sb.rows, row)
		}
		gd.set_bool(cast(gd.Object)row, "visible", true)

		p, _ := ksess.session_player(s, id)
		rb := strings.builder_make(context.temp_allocator)
		strings.write_string(&rb, p.name)
		for _, col in ksess.session_stat_names(s) {
			fmt.sbprintf(&rb, " | %d", ksess.session_stat(s, id, ksess.Stat_Col(col)))
		}
		gd.set_string(cast(gd.Object)row, "text", fmt.ctprintf("%s", strings.to_string(rb)))
	}
	for i in len(ids) ..< len(sb.rows) {
		gd.set_bool(cast(gd.Object)sb.rows[i], "visible", false)
	}
}
