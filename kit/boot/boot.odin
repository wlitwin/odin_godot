package kit_boot

// kit/boot — the first thirty lines of every friendslop game, written once.
//
// Two games proved the shape: ready() built the same lobby/chat/scoreboard/
// stage/world/wire stack line-for-line, and process() opened with the same
// pump-tick-drain preamble plus the same five boilerplate event reactions,
// before a single line of game code. This package absorbs exactly that —
// and NOTHING game-shaped: every widget stays a public field (restyle,
// reposition, or ignore them), every session event is RE-YIELDED so the
// game reacts to whatever it cares about, and Start/spawning/verbs remain
// entirely yours.
//
//     // ready():
//     kboot.boot_attach(&self.boot, self.owner, &self.ses, &self.comms, kboot.Options{
//         title    = "P U T T P U T T",
//         status   = "Host a course, or join one at localhost",
//         legend   = "click: putt · Tab scores · Enter chat",
//         msg_kind = MSG_SESSION,
//         latency_env = "GOLF_LATENCY",
//         methods  = {"on_host", "on_join", "on_start", "on_chat",
//                     "on_packet", "on_peer_left", "on_net_up", "on_net_down"},
//     })
//
//     // process():
//     events, marks, ticks := kboot.boot_pump(&self.boot, delta, now_s())
//     for ev in events {
//         #partial switch e in ev { /* ONLY game cases */ }
//     }
//
// The eight @(gd_method) names stay the game's to declare — Godot signals
// must land on the game's script class; their bodies are one-liners (see
// either example game's net.odin).

import gd "godot:godot"
import kcomms "godot:kit/comms"
import netgd "godot:kit/netgd"
import ksess "godot:kit/session"
import kui "godot:kit/ui"
import "core:fmt"

// The eight signal landing pads, in one fixed order: host/join/start button
// presses, chat submit, then the four transport forwards.
Methods :: struct {
	host, join, start, chat:                cstring,
	packet, peer_left, net_up, net_down: cstring,
}

Options :: struct {
	title:       string, // the lobby's big title
	status:      string, // the first status line ("" = none)
	legend:      string, // bottom-right control hints ("" = no legend label)
	msg_kind:    u8, // the game's session sub-frame byte (netgd.wire_attach)
	latency_env: cstring, // env var for the injected-latency shim ("" = off)
	min_players: int, // host's Start button appears at this count (default 2)
	methods:     Methods,
}

Boot :: struct {
	// every piece public: the game repositions/restyles/reads them freely
	ui:     kui.Lobby,
	chat:   kui.Chat,
	score:  kui.Score,
	legend: gd.Label, // nil when Options.legend was ""
	wire:   netgd.Session_Wire,
	stage:    gd.Node, // scenery container (draws behind world)
	world:    gd.Node, // entity container
	ui_layer: gd.Node, // CanvasLayer all the widgets live on — ABOVE the field

	ses:         ^ksess.Session,
	comms:       ^kcomms.Comms,
	min_players: int,
}

// The ready() ceremony. Call once, after installing your factory/hooks is
// fine either side — this wires UI + comms + transport, nothing session-run.
boot_attach :: proc(b: ^Boot, node: gd.Node, ses: ^ksess.Session, comms: ^kcomms.Comms, opts: Options) {
	b.ses = ses
	b.comms = comms
	b.min_players = opts.min_players > 0 ? opts.min_players : 2

	// Every widget lives on a CanvasLayer: layers draw above world-space
	// CanvasItems no matter what z_index entities carry, so a full-screen
	// playfield can never bury the chat (homestead found it live — its
	// grass covered the viewport and z>0 entities beat every Control).
	layer := gd.new_canvas_layer()
	gd.node_set_name(cast(gd.Node)layer, gd.new_string_name_cstring("BootUi", true))
	gd.add_child(node, cast(gd.Node)layer)
	b.ui_layer = cast(gd.Node)layer

	b.ui = kui.lobby_make(b.ui_layer, opts.title)
	if opts.status != "" {
		kui.lobby_set_status(&b.ui, opts.status)
	}
	gd.connect_to(cast(gd.Object)b.ui.host_btn, "pressed", node, opts.methods.host)
	gd.connect_to(cast(gd.Object)b.ui.join_btn, "pressed", node, opts.methods.join)
	gd.connect_to(cast(gd.Object)b.ui.start_btn, "pressed", node, opts.methods.start)

	kcomms.comms_init(comms, ses)
	b.chat = kui.chat_make(b.ui_layer)
	kui.chat_show(&b.chat, false)
	gd.connect_to(cast(gd.Object)b.chat.input, "text_submitted", node, opts.methods.chat)

	// Node2D containers (not plain Nodes) so games can offset them together —
	// screen shake (kfx.Shake) nudges stage+world as one. Children unaffected.
	b.stage = cast(gd.Node)gd.new_node2d()
	gd.node_set_name(b.stage, gd.new_string_name_cstring("Stage", true))
	gd.add_child(node, b.stage)
	b.world = cast(gd.Node)gd.new_node2d()
	gd.node_set_name(b.world, gd.new_string_name_cstring("World", true))
	gd.add_child(node, b.world)

	b.score = kui.score_make(b.ui_layer)

	netgd.wire_attach(&b.wire, node, ses, opts.msg_kind)
	netgd.wire_listen(&b.wire, opts.methods.packet, opts.methods.peer_left, opts.methods.net_up, opts.methods.net_down)
	if opts.latency_env != "" {
		netgd.wire_set_latency(&b.wire, gd.env_int(opts.latency_env, 0))
	}

	if opts.legend != "" {
		b.legend = gd.new_label()
		gd.add_child(b.ui_layer, cast(gd.Node)b.legend)
		gd.control_set_anchors_preset(cast(gd.Control)b.legend, .Preset_Bottom_Right, false)
		gd.control_set_v_grow_direction(cast(gd.Control)b.legend, .Grow_Direction_Begin)
		gd.control_set_h_grow_direction(cast(gd.Control)b.legend, .Grow_Direction_Begin)
		gd.control_set_offset(cast(gd.Control)b.legend, .Right, -8)
		gd.control_set_offset(cast(gd.Control)b.legend, .Bottom, -4)
		gd.set_string(cast(gd.Object)b.legend, "text", fmt.ctprintf("%s", opts.legend))
		gd.set_bool(cast(gd.Object)b.legend, "visible", false)
	}
}

// The frame preamble + the boilerplate half of the event drain. Pumps the
// wire, ticks the session, reacts to the five events every game reacts to
// identically (status lines, roster/score/chat repaints, the host's Start
// gating) — and RE-YIELDS every session event plus the comms markers, both
// temp-allocated, so the game's own switch sees everything.
boot_pump :: proc(b: ^Boot, delta: f64, now: f64) -> (events: []ksess.Event, marks: []kcomms.Ev_Marker, ticks: int) {
	netgd.wire_pump(&b.wire, now)
	ticks, _ = ksess.session_tick(b.ses, delta, now)

	evs := make([dynamic]ksess.Event, context.temp_allocator)
	for {
		ev, ok := ksess.session_poll(b.ses)
		if !ok {
			break
		}
		#partial switch _ in ev {
		case ksess.Ev_Welcomed:
			// The roster RODE the welcome — paint it now, not at the next change.
			kui.lobby_refresh(&b.ui, b.ses)
			kui.score_refresh(&b.score, b.ses)
			kui.lobby_set_status(&b.ui, "Seated — waiting for the host to start")
		case ksess.Ev_Player_Joined, ksess.Ev_Player_Left:
			roster_changed(b)
		case ksess.Ev_Stats_Updated:
			kui.score_refresh(&b.score, b.ses)
		case ksess.Ev_Join_Failed:
			kui.lobby_set_status(&b.ui, "Could not reach the host")
		case ksess.Ev_Host_Left:
			kui.lobby_set_status(&b.ui, "The host left — round over")
		}
		append(&evs, ev)
	}

	mks := make([dynamic]kcomms.Ev_Marker, context.temp_allocator)
	refresh_chat := false
	for {
		cev, cok := kcomms.comms_poll(b.comms)
		if !cok {
			break
		}
		switch e in cev {
		case kcomms.Ev_Line:
			refresh_chat = true
		case kcomms.Ev_Marker:
			append(&mks, e)
		}
	}
	if refresh_chat {
		kui.chat_refresh(&b.chat, b.comms)
	}
	return evs[:], mks[:], ticks
}

@(private = "file")
roster_changed :: proc(b: ^Boot) {
	kui.lobby_refresh(&b.ui, b.ses)
	kui.score_refresh(&b.score, b.ses)
	if b.ses.is_host {
		n := ksess.session_count(b.ses, connected_only = true)
		kui.lobby_set_status(&b.ui, fmt.tprintf("%d players ready", n))
		kui.lobby_show_menu(&b.ui, false, n >= b.min_players)
	}
}

// The Host button, ceremony included: transport up, session started, menu
// hidden, status set, chat shown. false = port taken (status already says
// so). `token` is the host's own reconnect identity (session_host_start) —
// pass it so a dead host can reclaim its seat from a resumed run.
boot_host :: proc(b: ^Boot, port: int, name: string, max_peers := 32, token: u64 = 0) -> bool {
	if !netgd.begin_host(&b.wire, port, name, max_peers, token) {
		kui.lobby_set_status(&b.ui, "Could not host (port taken?)")
		return false
	}
	kui.lobby_show_menu(&b.ui, false, false)
	kui.lobby_set_status(&b.ui, fmt.tprintf("Hosting on :%d — waiting for friends", port))
	kui.lobby_refresh(&b.ui, b.ses)
	kui.chat_show(&b.chat, true)
	return true
}

// The Join button. An unreachable host resolves later as Ev_Join_Failed.
boot_join :: proc(b: ^Boot, addr: cstring, port: int, token: u64, name: string, status := "Joining...") -> bool {
	if !netgd.begin_join(&b.wire, addr, port, token, name) {
		kui.lobby_set_status(&b.ui, "Could not start joining")
		return false
	}
	kui.lobby_show_menu(&b.ui, false, false)
	kui.lobby_set_status(&b.ui, status)
	kui.chat_show(&b.chat, true)
	return true
}

// Chat's text_submitted, one call (see kui.chat_submit for the trap it fixes).
boot_chat :: proc(b: ^Boot, text: gd.String, sent: ^bool = nil) {
	kui.chat_submit(&b.chat, b.comms, text, sent)
}
