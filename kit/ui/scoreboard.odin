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
	root:   gd.Control, // centered PanelContainer (background + auto-size)
	box:    gd.Control, // the VBox column inside it
	header: gd.Label,
	rows:   [dynamic]gd.Label, // reused across refreshes
}

score_make :: proc(parent: gd.Node) -> Score {
	sb: Score
	// A PanelContainer gives the overlay a themed background and sizes
	// itself to its content. Centering is done BY HAND in score_refresh:
	// anchor presets only mean something under a Control parent, and kit
	// widgets attach to whatever plain Node the game hands them — under one
	// of those, ".Preset_Center" quietly measures a zero rect and the board
	// sits in the top-left corner (puttputt found it live). High z-index: an
	// on-demand overlay reads on TOP of the HUD it happens to cover.
	sb.root = cast(gd.Control)gd.new_panel_container()
	gd.node_set_name(cast(gd.Node)sb.root, gd.new_string_name_cstring("Scoreboard", true))
	gd.add_child(parent, cast(gd.Node)sb.root)
	gd.canvas_item_set_z_index(cast(gd.Canvas_Item)sb.root, 10)
	sb.box = cast(gd.Control)gd.new_v_box_container()
	gd.add_child(cast(gd.Node)sb.root, cast(gd.Node)sb.box)
	sb.header = gd.new_label()
	gd.add_child(cast(gd.Node)sb.box, cast(gd.Node)sb.header)
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

	roster := ksess.session_roster(s)
	for p, i in roster {
		row: gd.Label
		if i < len(sb.rows) {
			row = sb.rows[i]
		} else {
			row = gd.new_label()
			gd.add_child(cast(gd.Node)sb.box, cast(gd.Node)row)
			append(&sb.rows, row)
		}
		gd.set_bool(cast(gd.Object)row, "visible", true)

		rb := strings.builder_make(context.temp_allocator)
		strings.write_string(&rb, p.name)
		for _, col in ksess.session_stat_names(s) {
			fmt.sbprintf(&rb, " | %d", ksess.session_stat(s, p.id, ksess.Stat_Col(col)))
		}
		gd.set_string(cast(gd.Object)row, "text", fmt.ctprintf("%s", strings.to_string(rb)))
	}
	for i in len(roster) ..< len(sb.rows) {
		gd.set_bool(cast(gd.Object)sb.rows[i], "visible", false)
	}

	// Center in the viewport by hand (see score_make): position from the
	// panel's own minimum size, which reflects THIS refresh's content even
	// before a layout pass has resized the control.
	need := gd.control_get_combined_minimum_size(sb.root)
	vp := gd.viewport_get_visible_rect(gd.node_get_viewport(cast(gd.Node)sb.root))
	gd.control_set_position(sb.root, {(vp.size.x - need.x) * 0.5, (vp.size.y - need.y) * 0.5}, false)
}
