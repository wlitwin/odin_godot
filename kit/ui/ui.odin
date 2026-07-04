package kit_ui

// kit/ui — the toolkit's stock widgets, built programmatically (no scene
// assets to install; any script can summon them). Phase 1 ships the LOBBY:
// a title, a status line, a live player list fed straight from a
// ksess.Session (names, host marker, you-marker, connection state, and the
// stat registry's auto-fed ping), and the three buttons a lobby needs. The
// GAME wires the buttons — kit/ui builds controls, it never owns flow:
//
//     self.ui = kui.lobby_make(self.owner, "CAVECRAWL")
//     gd.connect_to(cast(gd.Object)self.ui.host_btn, "pressed", self.owner, "on_host")
//     ...
//     kui.lobby_refresh(&self.ui, &self.ses)   // on any session event
//
// Styling is deliberately stock Godot theme — friendslop lobbies are for
// friends, and games that care can theme the returned nodes.

import gd "godot:godot"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import "core:fmt"

Lobby :: struct {
	root:      gd.Control, // full-rect CenterContainer under the owner node
	panel:     gd.Control, // the VBox column (title/status/rows/buttons)
	title:     gd.Label,
	status:    gd.Label,
	rows_box:  gd.Control, // player rows live here
	host_btn:  gd.Button,
	join_btn:  gd.Button,
	start_btn: gd.Button, // hidden until the game shows it (host, enough players)
	rows:      [dynamic]gd.Label, // reused across refreshes
}

// Build the lobby under `parent` (any node in the tree). Call from ready().
lobby_make :: proc(parent: gd.Node, title: cstring) -> Lobby {
	l: Lobby

	l.root = cast(gd.Control)gd.new_center_container()
	gd.node_set_name(cast(gd.Node)l.root, gd.new_string_name_cstring("Lobby", true))
	gd.add_child(parent, cast(gd.Node)l.root)
	gd.control_set_anchors_preset(l.root, .Preset_Full_Rect, false)

	l.panel = cast(gd.Control)gd.new_v_box_container()
	gd.add_child(cast(gd.Node)l.root, cast(gd.Node)l.panel)

	l.title = gd.new_label()
	gd.set_string(cast(gd.Object)l.title, "text", title)
	gd.add_child(cast(gd.Node)l.panel, cast(gd.Node)l.title)

	l.status = gd.new_label()
	gd.set_string(cast(gd.Object)l.status, "text", "")
	gd.add_child(cast(gd.Node)l.panel, cast(gd.Node)l.status)

	l.rows_box = cast(gd.Control)gd.new_v_box_container()
	gd.node_set_name(cast(gd.Node)l.rows_box, gd.new_string_name_cstring("Players", true))
	gd.add_child(cast(gd.Node)l.panel, cast(gd.Node)l.rows_box)

	l.host_btn = gd.new_button()
	gd.set_string(cast(gd.Object)l.host_btn, "text", "Host")
	gd.add_child(cast(gd.Node)l.panel, cast(gd.Node)l.host_btn)

	l.join_btn = gd.new_button()
	gd.set_string(cast(gd.Object)l.join_btn, "text", "Join")
	gd.add_child(cast(gd.Node)l.panel, cast(gd.Node)l.join_btn)

	l.start_btn = gd.new_button()
	gd.set_string(cast(gd.Object)l.start_btn, "text", "Start")
	gd.add_child(cast(gd.Node)l.panel, cast(gd.Node)l.start_btn)
	gd.set_bool(cast(gd.Object)l.start_btn, "visible", false)

	return l
}

lobby_destroy :: proc(l: ^Lobby) {
	delete(l.rows)
	l^ = {}
	// The node tree itself belongs to the scene (freed with the owner).
}

lobby_set_status :: proc(l: ^Lobby, text: cstring) {
	gd.set_string(cast(gd.Object)l.status, "text", text)
}

// Once connected/hosting, the menu buttons make no sense; the host may show
// Start when it likes the roster.
lobby_show_menu :: proc(l: ^Lobby, menu: bool, start: bool) {
	gd.set_bool(cast(gd.Object)l.host_btn, "visible", menu)
	gd.set_bool(cast(gd.Object)l.join_btn, "visible", menu)
	gd.set_bool(cast(gd.Object)l.start_btn, "visible", start)
}

// Repaint the player list from the session: sorted by Player_Id (join order —
// stable), with the host crowned, yourself marked, departed players dimmed
// to "(away)", and the stat registry's ping when it has been measured.
// Rows (Labels) are reused; extras hide. Call on any session event.
lobby_refresh :: proc(l: ^Lobby, s: ^ksess.Session) {
	ids: [dynamic]knet.Player_Id
	defer delete(ids)
	for id in s.players {
		append(&ids, id)
	}
	// insertion sort: friendslop rosters are tiny
	for i in 1 ..< len(ids) {
		for j := i; j > 0 && ids[j] < ids[j - 1]; j -= 1 {
			ids[j], ids[j - 1] = ids[j - 1], ids[j]
		}
	}

	for id, i in ids {
		p, _ := ksess.session_player(s, id)
		row: gd.Label
		if i < len(l.rows) {
			row = l.rows[i]
		} else {
			row = gd.new_label()
			gd.add_child(cast(gd.Node)l.rows_box, cast(gd.Node)row)
			append(&l.rows, row)
		}
		gd.set_bool(cast(gd.Object)row, "visible", true)

		crown := id == 1 ? "\xF0\x9F\x91\x91 " : "" // the host wears it
		you := id == s.me ? "  (you)" : ""
		suffix := ""
		if !p.connected {
			suffix = "  (away)"
		} else if ping := ksess.session_stat(s, id, ksess.STAT_PING); ping > 0 {
			suffix = fmt.tprintf("  %dms", ping)
		} else if id == 1 {
			suffix = "  host"
		}
		gd.set_string(cast(gd.Object)row, "text", fmt.ctprintf("%s%s%s%s", crown, p.name, you, suffix))
	}
	for i in len(ids) ..< len(l.rows) {
		gd.set_bool(cast(gd.Object)l.rows[i], "visible", false)
	}
}
