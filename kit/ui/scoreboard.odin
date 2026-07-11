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
	root:  gd.Control, // centered PanelContainer (background + auto-size)
	grid:  gd.Control, // the GridContainer inside it — real columns, so
	// names and tallies LINE UP (a VBox of pipe-joined strings drifted with
	// every proportional-font digit; homestead found it live)
	cells: [dynamic]gd.Label, // header + rows, row-major, reused across refreshes
	hidden: [dynamic]string, // column names the game declared PLUMBING (score_hide)
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
	grid := gd.new_grid_container()
	gd.control_add_theme_constant_override(cast(gd.Control)grid, gd.new_string_name_cstring("h_separation", true), 22)
	sb.grid = cast(gd.Control)grid
	gd.add_child(cast(gd.Node)sb.root, cast(gd.Node)sb.grid)
	gd.set_bool(cast(gd.Object)sb.root, "visible", false)
	return sb
}

score_destroy :: proc(sb: ^Score) {
	delete(sb.cells)
	delete(sb.hidden)
	sb^ = {}
	// The node tree itself belongs to the scene (freed with the owner).
}

score_show :: proc(sb: ^Score, visible: bool) {
	gd.set_bool(cast(gd.Object)sb.root, "visible", visible)
}

// Hide a column by NAME. Some stat columns are PLUMBING, not score — a
// loadout choice replicated through the registry (scrapyard's look/iron,
// the muster's ready bit) has no business on the board. Call once after
// the columns are declared; unknown names are a harmless no-op.
score_hide :: proc(sb: ^Score, name: string) {
	append(&sb.hidden, name)
}

@(private = "file")
score_hidden :: proc(sb: ^Score, name: string) -> bool {
	for h in sb.hidden {
		if h == name {return true}
	}
	return false
}

// Repaint players × columns. Sorted by Player_Id (join order); departed
// players stay listed — their tallies survive disconnects by design.
score_refresh :: proc(sb: ^Score, s: ^ksess.Session) {
	names := ksess.session_stat_names(s)
	shown := 0
	for name, _ in names {
		if !score_hidden(sb, name) {shown += 1}
	}
	gd.grid_container_set_columns(cast(gd.Grid_Container)sb.grid, gd.Int(1 + shown))

	next := 0
	cell :: proc(sb: ^Score, next: ^int, text: cstring, numeric: bool) {
		l: gd.Label
		if next^ < len(sb.cells) {
			l = sb.cells[next^]
		} else {
			l = gd.new_label()
			gd.add_child(cast(gd.Node)sb.grid, cast(gd.Node)l)
			append(&sb.cells, l)
		}
		next^ += 1
		gd.set_bool(cast(gd.Object)l, "visible", true)
		gd.set_string(cast(gd.Object)l, "text", text)
		gd.label_set_horizontal_alignment(l, numeric ? .Right : .Left)
	}

	cell(sb, &next, "player", false)
	for name in names {
		if score_hidden(sb, name) {continue}
		cell(sb, &next, fmt.ctprintf("%s", name), true)
	}
	roster := ksess.session_roster(s)
	for p in roster {
		cell(sb, &next, fmt.ctprintf("%s", p.name), false)
		for name, col in names {
			if score_hidden(sb, name) {continue}
			cell(sb, &next, fmt.ctprintf("%d", ksess.session_stat(s, p.id, ksess.Stat_Col(col))), true)
		}
	}
	for i in next ..< len(sb.cells) {
		gd.set_bool(cast(gd.Object)sb.cells[i], "visible", false)
	}

	// Center in the viewport by hand (see score_make): position from the
	// panel's own minimum size, which reflects THIS refresh's content even
	// before a layout pass has resized the control.
	need := gd.control_get_combined_minimum_size(sb.root)
	vp := gd.viewport_get_visible_rect(gd.node_get_viewport(cast(gd.Node)sb.root))
	gd.control_set_position(sb.root, {(vp.size.x - need.x) * 0.5, (vp.size.y - need.y) * 0.5}, false)
}
