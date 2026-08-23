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
//
// FULL REPLACEMENT: the kit provides the implementation, never the final
// look. A game that wants its own lobby/chat/scoreboard authors a scene in
// the editor and hands it to boot (Options.lobby_scene / chat_scene /
// score_scene) — the kit ADOPTS it: resolves the nodes it drives BY NAME
// (any depth; see each widget's *_adopt contract) and pours the same
// behavior into them. Everything else in the scene is the game's own chrome;
// the kit never touches what it didn't name.

import gd "godot:godot"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import "core:fmt"
import "core:strings"

// Set a node's "text" property from an Odin string. The package's PUBLIC API
// speaks string, not cstring — callers use fmt.tprintf and never think about
// NUL termination or c-allocator lifetimes.
@(private)
set_text :: proc(obj: gd.Object, text: string) {
	if cast(rawptr)obj == nil {return} 	// a violated adopt contract already screamed; don't also crash
	s := gd.new_string_odin(text)
	defer gd.free_string(s)
	sv := gd.variant_from_string(&s)
	defer gd.variant_destroy(&sv)
	gd.set_value(obj, "text", sv)
}

// Resolve an adopted scene's contract node by NAME, searching the whole tree
// — the game nests its chrome however it likes. A missing node is reported
// LOUDLY (once, at boot, greppable) and comes back nil; the setters tolerate
// nil so a violated contract degrades to a dead widget, not a crash.
@(private)
adopt_child :: proc(root: gd.Node, name: cstring, widget: string) -> gd.Node {
	pat := gd.new_string_cstring(name)
	defer gd.free_string(pat)
	n := gd.node_find_child(root, pat, true, false)
	if cast(rawptr)n == nil {
		gd.print_str(fmt.tprintf("kit/ui: adopted %s scene has no node named \"%s\"", widget, name))
	}
	return n
}

Lobby :: struct {
	root:      gd.Control, // full-rect CenterContainer under the owner node
	panel:     gd.Control, // the VBox column (title/status/rows/buttons)
	title:     gd.Label,
	status:    gd.Label,
	rows_box:  gd.Control, // player rows live here
	host_btn:  gd.Button,
	join_btn:  gd.Button,
	start_btn: gd.Button, // hidden until the game shows it (host, enough players)
	code_edit: gd.Line_Edit, // the join-code field — hidden until lobby_show_code
	code_on:   bool, // the game turned the code field on (menu toggles honor it)
	rows:      [dynamic]gd.Label, // reused across refreshes
}

// A SCREEN OVERLAY (a fade, a vignette, a full-rect flash) attached the way
// every game hand-rolled it: mouse-invisible, transparent at birth, and
// anchored full-rect with the OFFSETS reset too — set_anchors_preset alone
// re-derives offsets to PRESERVE the birth rect, which parks a 512px texture
// in the top-left quadrant and a zero-size ColorRect at nothing (the trap
// each game found live). Parent it on kboot's fx_layer: above the field,
// under every widget, no node_move_child index-squatting on the UI layer.
overlay_attach :: proc(layer: gd.Node, node: gd.Control) {
	gd.control_set_mouse_filter(node, .Mouse_Filter_Ignore)
	gd.canvas_item_set_modulate(cast(gd.Canvas_Item)node, {1, 1, 1, 0})
	gd.add_child(layer, cast(gd.Node)node)
	gd.control_set_anchors_and_offsets_preset(node, .Preset_Full_Rect, .Preset_Mode_Minsize, 0)
}

// Build the lobby under `parent` (any node in the tree). Call from ready().
lobby_make :: proc(parent: gd.Node, title: string) -> Lobby {
	l: Lobby

	l.root = cast(gd.Control)gd.new_center_container()
	gd.node_set_name(cast(gd.Node)l.root, gd.new_string_name_cstring("Lobby", true))
	gd.add_child(parent, cast(gd.Node)l.root)
	gd.control_set_anchors_preset(l.root, .Preset_Full_Rect, false)
	// Full-rect anchors bind to a Control parent — under a plain Node (the
	// usual game root) they bind to NOTHING and the lobby quietly hugs the
	// top-left corner. Size the root to the viewport outright; the anchors
	// still handle the Control-parent case, and the CenterContainer finally
	// gets to do its one job everywhere. (Sized once: the lobby is transient.)
	if vp := gd.node_get_viewport(parent); cast(rawptr)vp != nil {
		gd.control_set_size(l.root, gd.viewport_get_visible_rect(vp).size, false)
	}

	l.panel = cast(gd.Control)gd.new_v_box_container()
	gd.add_child(cast(gd.Node)l.root, cast(gd.Node)l.panel)

	l.title = gd.new_label()
	set_text(cast(gd.Object)l.title, title)
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

	l.code_edit = gd.new_line_edit()
	gd.set_string(cast(gd.Object)l.code_edit, "placeholder_text", "join code")
	gd.add_child(cast(gd.Node)l.panel, cast(gd.Node)l.code_edit)
	gd.set_bool(cast(gd.Object)l.code_edit, "visible", false)

	l.join_btn = gd.new_button()
	gd.set_string(cast(gd.Object)l.join_btn, "text", "Join")
	gd.add_child(cast(gd.Node)l.panel, cast(gd.Node)l.join_btn)

	l.start_btn = gd.new_button()
	gd.set_string(cast(gd.Object)l.start_btn, "text", "Start")
	gd.add_child(cast(gd.Node)l.panel, cast(gd.Node)l.start_btn)
	gd.set_bool(cast(gd.Object)l.start_btn, "visible", false)

	return l
}

// Adopt a game-authored lobby scene (full replacement — see the header).
// The CONTRACT, by node name at any depth:
//
//   Title (Label) · Status (Label) · Players (any container — rows land here)
//   Host (Button) · Join (Button) · Start (Button)
//
// The kit instances the scene, wires those six, and drives them exactly as it
// drives its stock build (Start ships hidden; refresh pours rows into
// Players). Extra nodes — a Single Player key, an address field, the plate —
// are the game's to wire after boot_attach, through l.root. The scene owns
// its OWN layout (anchors under the boot layer bind to the viewport); none
// of the stock builder's sizing hacks apply.
lobby_adopt :: proc(parent: gd.Node, scene: gd.Packed_Scene, title: string) -> Lobby {
	l: Lobby
	node := gd.instantiate(scene)
	gd.add_child(parent, node)
	l.root = cast(gd.Control)node
	// (l.panel stays nil — "the column" is a stock-builder detail; an adopted
	// scene arranges itself.)
	l.title = cast(gd.Label)adopt_child(node, "Title", "lobby")
	l.status = cast(gd.Label)adopt_child(node, "Status", "lobby")
	l.rows_box = cast(gd.Control)adopt_child(node, "Players", "lobby")
	l.host_btn = cast(gd.Button)adopt_child(node, "Host", "lobby")
	l.join_btn = cast(gd.Button)adopt_child(node, "Join", "lobby")
	l.start_btn = cast(gd.Button)adopt_child(node, "Start", "lobby")
	// OPTIONAL contract node — a "Code" LineEdit for join-code games. Quiet
	// when absent: most lobbies never show one (lobby_show_code turns it on).
	{
		pat := gd.new_string_cstring("Code")
		defer gd.free_string(pat)
		l.code_edit = cast(gd.Line_Edit)gd.node_find_child(node, pat, true, false)
	}
	set_text(cast(gd.Object)l.title, title)
	if cast(rawptr)l.start_btn != nil {
		gd.set_bool(cast(gd.Object)l.start_btn, "visible", false)
	}
	return l
}

lobby_destroy :: proc(l: ^Lobby) {
	delete(l.rows)
	l^ = {}
	// The node tree itself belongs to the scene (freed with the owner).
}

lobby_set_status :: proc(l: ^Lobby, text: string) {
	set_text(cast(gd.Object)l.status, text)
}

// Once connected/hosting, the menu buttons make no sense; the host may show
// Start when it likes the roster.
lobby_show_menu :: proc(l: ^Lobby, menu: bool, start: bool) {
	gd.set_bool(cast(gd.Object)l.host_btn, "visible", menu)
	gd.set_bool(cast(gd.Object)l.join_btn, "visible", menu)
	gd.set_bool(cast(gd.Object)l.start_btn, "visible", start)
	if cast(rawptr)l.code_edit != nil {
		gd.set_bool(cast(gd.Object)l.code_edit, "visible", menu && l.code_on)
	}
}

// Reveal the join-code field (above the Join button in the stock build; the
// adopted contract's optional "Code" node). Games with a relay show it once
// in ready(); Join then reads lobby_code — empty means join by address.
lobby_show_code :: proc(l: ^Lobby, show: bool) {
	l.code_on = show
	if cast(rawptr)l.code_edit != nil {
		gd.set_bool(cast(gd.Object)l.code_edit, "visible", show)
	}
}

// What the human typed in the code field, trimmed and uppercased (the relay
// mints uppercase codes) — "" when blank or the lobby has no field.
// Temp-allocated.
lobby_code :: proc(l: ^Lobby) -> string {
	if cast(rawptr)l.code_edit == nil {
		return ""
	}
	raw := gd.get_string(cast(gd.Object)l.code_edit, "text", context.temp_allocator)
	return strings.to_upper(strings.trim_space(raw), context.temp_allocator)
}

// Repaint the player list from the session: sorted by Player_Id (join order —
// stable), with the host crowned, yourself marked, departed players dimmed
// to "(away)", and the stat registry's ping when it has been measured.
// Rows (Labels) are reused; extras hide. Call on any session event.
lobby_refresh :: proc(l: ^Lobby, s: ^ksess.Session) {
	roster := ksess.session_roster(s)
	// The crown follows the transport SEAT, not player id 1 — a resumed
	// host returns under its old id.
	host := ksess.session_host(s)

	next := 0
	for p in roster {
		if p.dedicated {continue} // infrastructure, not a player — no row
		row: gd.Label
		if next < len(l.rows) {
			row = l.rows[next]
		} else {
			row = gd.new_label()
			gd.add_child(cast(gd.Node)l.rows_box, cast(gd.Node)row)
			append(&l.rows, row)
		}
		next += 1
		gd.set_bool(cast(gd.Object)row, "visible", true)

		crown := p.id == host ? "\xF0\x9F\x91\x91 " : "" // the host wears it
		you := p.id == s.me ? "  (you)" : ""
		suffix := ""
		if p.spectator {
			suffix = "  (watching)" // a seat in the room, not in the game
		} else if !p.connected {
			suffix = "  (away)"
		} else if ping := ksess.session_stat(s, p.id, ksess.STAT_PING); ping > 0 {
			suffix = fmt.tprintf("  %dms", ping)
		} else if p.id == host {
			suffix = "  host"
		}
		gd.set_string(cast(gd.Object)row, "text", fmt.ctprintf("%s%s%s%s", crown, p.name, you, suffix))
	}
	for i in next ..< len(l.rows) {
		gd.set_bool(cast(gd.Object)l.rows[i], "visible", false)
	}
}

// The MUSTER refresh: lobby_refresh with a READY LAMP on every player — a filled
// dot when their ready bit is set, a hollow one when not (the bit is the game's,
// read through `ready`; see ksess.muster_tally). A watcher shows no lamp. Drives
// the SAME rows as lobby_refresh; call one or the other while staging. Gate the
// Start button with ksess.muster_can_start:
//
//     kui.muster_refresh(&self.lobby, &self.ses, my_ready)
//     kui.lobby_show_menu(&self.lobby, false, ksess.muster_can_start(&self.ses, 2, my_ready))
muster_refresh :: proc(l: ^Lobby, s: ^ksess.Session, ready: ksess.Ready_Proc) {
	roster := ksess.session_roster(s)
	host := ksess.session_host(s)
	next := 0
	for p in roster {
		if p.dedicated {continue}
		row: gd.Label
		if next < len(l.rows) {
			row = l.rows[next]
		} else {
			row = gd.new_label()
			gd.add_child(cast(gd.Node)l.rows_box, cast(gd.Node)row)
			append(&l.rows, row)
		}
		next += 1
		gd.set_bool(cast(gd.Object)row, "visible", true)

		crown := p.id == host ? "\xF0\x9F\x91\x91 " : ""
		you := p.id == s.me ? "  (you)" : ""
		// The lamp: filled/hollow for a present player, none for a watcher or an
		// away seat (they are in the room, not the readiness count).
		lamp := "\xE2\x97\x8B " // ○ hollow — not ready
		suffix := ""
		if p.spectator {
			lamp = ""
			suffix = "  (watching)"
		} else if !p.connected {
			lamp = ""
			suffix = "  (away)"
		} else if ready(s, p.id) {
			lamp = "\xE2\x97\x8F " // ● filled — ready
		}
		gd.set_string(cast(gd.Object)row, "text", fmt.ctprintf("%s%s%s%s%s", lamp, crown, p.name, you, suffix))
	}
	for i in next ..< len(l.rows) {
		gd.set_bool(cast(gd.Object)l.rows[i], "visible", false)
	}
}
