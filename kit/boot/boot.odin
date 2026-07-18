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
//     // process(): the whole loop, role-free — both procs are generated
//     events, marks, ticks := kboot.boot_pump(&self.boot, delta, now_s())
//     my_game_step(self, ticks)    // @(gd_step="authority"): host gate + edge pass inside
//     my_game_events(self, events) // dispatch over the declared session event halves
//
// The eight @(gd_method) names stay the game's to declare — Godot signals
// must land on the game's script class; their bodies are one-liners (see
// either example game's net.odin).

import gd "godot:godot"
import "godot:gdext"
import kcomms "godot:kit/comms"
import knet "godot:kit/net"
import netgd "godot:kit/netgd"
import ksave "godot:kit/save"
import ksess "godot:kit/session"
import ksim "godot:kit/sim"
import kui "godot:kit/ui"
import "core:fmt"
import "core:strings"

// The eight signal landing pads, in one fixed order: host/join/start button
// presses, chat submit, then the four transport forwards. A zero Methods
// (the field simply not passed) resolves to STANDARD_METHODS — every game
// wrote these same eight strings; now only a game that DEVIATES writes any
// (scriptgen validates the defaulted names too, so a missing on_host is
// still a build error, not a dead button). "" in an explicit list skips
// that one signal on purpose.
Methods :: struct {
	host, join, start, chat:                cstring,
	packet, peer_left, net_up, net_down: cstring,
}

STANDARD_METHODS :: Methods {
	host      = "on_host",
	join      = "on_join",
	start     = "on_start",
	chat      = "on_chat",
	packet    = "on_packet",
	peer_left = "on_peer_left",
	net_up    = "on_net_up",
	net_down  = "on_net_down",
}

// Where the boot stands, coarse and honest — the two booleans every game
// declared and threaded by hand (`running`, `started`), without the hand.
//   .Menu       — no transport; the Host/Join doors are showing
//   .Connecting — a join door opened, no seat yet (includes a code resolving)
//   .Lobby      — seated (hosting counts), the world not yet on this screen
//   .Playing    — the world reached this peer (first spawn/state/resync)
// A failed or denied join and a kick fall back to .Menu; a host loss stays
// put (succession may re-seat — the welcome moves it, not the loss).
Boot_Phase :: enum u8 {
	Menu,
	Connecting,
	Lobby,
	Playing,
}

boot_phase :: proc(b: ^Boot) -> Boot_Phase {
	return b.phase
}

Options :: struct {
	title:       string, // the lobby's big title
	status:      string, // the first status line ("" = none)
	legend:      string, // bottom-right control hints ("" = no legend label)
	msg_kind:    u8, // the game's session sub-frame byte (netgd.wire_attach)
	// The game's env-var prefix ("QD"): boot_port/boot_name/boot_token read
	// <ENV>_PORT/_NAME/_TOKEN (same-machine playtests pick distinct seats),
	// and the latency shim answers <ENV>_LATENCY without latency_env.
	env:         string,
	latency_env: cstring, // env var for the injected-latency shim ("" = <ENV>_LATENCY, or off)
	min_players: int, // host's Start button appears at this count (default 2)
	spatial:     bool, // 3D game: stage/world become Node3D containers (default Node2D)
	keep_vsync:  bool, // opt OUT of the desktop playtest unthrottle (see unthrottle_desktop)
	// FULL REPLACEMENT (nil = the kit's stock build): a game that wants its
	// own look authors a scene in the editor and the kit ADOPTS it — resolves
	// the nodes it drives by NAME and pours the stock behavior in. The
	// contracts live on each widget's *_adopt in kit/ui: the lobby wants
	// Title/Status/Players/Host/Join/Start; chat wants Lines/Input; the
	// scoreboard wants Grid. Anything else in a scene is the game's own.
	lobby_scene: gd.Packed_Scene,
	chat_scene:  gd.Packed_Scene,
	score_scene: gd.Packed_Scene,
	methods:     Methods, // zero = STANDARD_METHODS (on_host/on_join/…) — pass only to deviate
}

// TWO WINDOWS, ONE LAPTOP — every friendslop game gets playtested this way,
// so boot unthrottles by default. macOS paces an occluded window's present,
// and with vsync on the whole main loop blocks on it: the background instance
// SIMULATES slow, not just draws slow (slopball's receipt: the two instances'
// session-tick counters drifted ~90 ticks — 1.5s of lost simulation — after a
// focus switch, and every timeline-synced screen stuttered for it). Pace by
// timer instead: vsync off, fps capped so the loop never waits on the
// compositor and the laptop doesn't render at 1000fps. Desktop windows only:
// headless has no vsync (and the cap would slow the acids); the web display
// server is paced by the browser, and background tabs are the browser's law.
// A shipping build that prefers tear-free rendering sets Options.keep_vsync.
@(private = "file")
unthrottle_desktop :: proc() {
	// DEV BUILDS ONLY. A shipped build must neither tear by default nor cap a
	// 240 Hz display at 120 — the playtest unthrottle keys on the BUILD, not
	// on whichever display server the player happens to run. -disable-assert
	// is the release line every kit guardrail already draws; past it the
	// engine's vsync default stands and keep_vsync is moot.
	when ODIN_DISABLE_ASSERT {
		return
	}
	ds := gd.singleton_display_server()
	name := gd.display_server_get_name(ds)
	buf: [64]u8
	n := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&name, cast(cstring)&buf[0], len(buf) - 1)
	if n <= 0 {return}
	s := string(buf[:n])
	if s == "headless" || s == "web" {return}
	gd.display_server_window_set_vsync_mode(ds, .Vsync_Disabled, 0)
	gd.engine_set_max_fps(gd.singleton_engine(), 120)
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
	lane:        ^ksim.Lane, // nil = no sim lane (boot_lane installs one)
	min_players: int,
	env:         string, // Options.env — the game's env-var prefix ("" = none)

	// boot_entities' state (entities.odin): the generated kind table, the
	// game pointer the typed hooks receive, and the per-entity node ledger
	// games used to keep by hand.
	ent_kinds: []Entity_Kind,
	ent_game:  rawptr,
	ent_nodes: map[knet.Net_Id]gd.Node,
	ent_types: map[knet.Net_Id]ksess.Entity_Type,

	// boot_migration's state (succession.odin): the rendezvous ceremony, the
	// generated hook table, and the latches every migrating game hand-kept
	// (host_gone/rejoin_tries/kicked_out — absorbed).
	succ:             netgd.Succession,
	succ_hooks:       Succ_Hooks,
	succ_game:        rawptr,
	succ_armed:       bool,
	succ_kicked:      bool, // a kicked player never chases the torch
	succ_host_gone:   bool, // the takeover/rejoin window (Ev_Host_Left opens, a seat closes)
	succ_tries:       int, // native chase cap (Ev_Succession's refire is the pulse)
	succ_pending:     knet.Player_Id, // a noted succession, mechanics deferred
	succ_has_pending: bool,
	succ_now:         f64, // boot_pump's clock, for the deferred chase
	succ_name:        string, // boot-owned clones (door callers pass temps)
	succ_url:         string,

	// The boot's lifecycle phase — the `running`/`started` latch pair every
	// game hand-kept, tracked once: doors advance it, boot_pump's event
	// drain moves it on seats and world arrival. Read boot_phase(b).
	phase: Boot_Phase,

	// boot_host_coded/boot_join_code's state (the join-code rendezvous,
	// netgd/code.odin): pumped inside boot_pump — a host's minted code lands
	// in the lobby status (and boot_room_code), a joiner's resolved endpoint
	// walks through boot_join automatically.
	rdv:       netgd.Code_Rendezvous,
	rdv_seen:  netgd.Code_State, // last state surfaced (status edges once)
	rdv_token: u64, // joiner's identity, held until the phonebook answers
	rdv_name:  string, // boot-owned clone (door callers pass temps)
}

// Install the sim lane (kit/sim), and the boot drives ALL of it: boot_pump
// runs lane_frame + lane_present each frame and forwards ownership moves;
// the generated entity table's rows carry each class's Sim_Set, so the
// factory tracks/untracks entities on the lane automatically. After this
// call a sim-lane game's remaining surface is its @(gd_tick) procs, their
// `_then`/`_fx` halves, and lane_init's config.
//
//     ksim.lane_init(&self.lane, &self.ses, size_of(Runner_Input))
//     ksim.lane_set_sim(&self.lane, self, game_sample, nil)
//     kboot.boot_lane(&self.boot, &self.lane)
boot_lane :: proc(b: ^Boot, lane: ^ksim.Lane) {
	b.lane = lane
	// A culled predicted spawn (a refused or lost fire) frees its node through here.
	ksim.lane_set_spawn_free(lane, b, boot_free_predicted)
	ksim.lane_set_present_ready(lane, b, boot_present_ready)
	// The session's write guard must not flag a tick-scheduled verb's
	// speculative delta-lane writes — exempt entities with one in flight
	// (cmd_retire blesses them as the entries settle).
	if b.ses != nil {
		ksess.session_set_guard_exempt(b.ses, lane, proc(user: rawptr, id: knet.Net_Id) -> bool {
			return ksim.lane_cmd_inflight(cast(^ksim.Lane)user, id)
		})
	}
}

// The ready() ceremony. Call once, after installing your factory/hooks is
// fine either side — this wires UI + comms + transport, nothing session-run.
boot_attach :: proc(b: ^Boot, node: gd.Node, ses: ^ksess.Session, comms: ^kcomms.Comms, opts: Options) {
	opts := opts
	if opts.methods == (Methods{}) {
		opts.methods = STANDARD_METHODS // the eight names every game wrote anyway
	}
	b.ses = ses
	b.comms = comms
	b.min_players = opts.min_players > 0 ? opts.min_players : 2

	if !opts.keep_vsync {
		unthrottle_desktop()
	}

	// Every widget lives on a CanvasLayer: layers draw above world-space
	// CanvasItems no matter what z_index entities carry, so a full-screen
	// playfield can never bury the chat (homestead found it live — its
	// grass covered the viewport and z>0 entities beat every Control).
	layer := gd.new_canvas_layer()
	gd.node_set_name(cast(gd.Node)layer, gd.new_string_name_cstring("BootUi", true))
	gd.add_child(node, cast(gd.Node)layer)
	b.ui_layer = cast(gd.Node)layer

	if cast(rawptr)opts.lobby_scene != nil {
		b.ui = kui.lobby_adopt(b.ui_layer, opts.lobby_scene, opts.title)
	} else {
		b.ui = kui.lobby_make(b.ui_layer, opts.title)
	}
	if opts.status != "" {
		kui.lobby_set_status(&b.ui, opts.status)
	}
	gd.connect_to(cast(gd.Object)b.ui.host_btn, "pressed", node, opts.methods.host)
	gd.connect_to(cast(gd.Object)b.ui.join_btn, "pressed", node, opts.methods.join)
	gd.connect_to(cast(gd.Object)b.ui.start_btn, "pressed", node, opts.methods.start)

	kcomms.comms_init(comms, ses)
	if cast(rawptr)opts.chat_scene != nil {
		b.chat = kui.chat_adopt(b.ui_layer, opts.chat_scene)
	} else {
		b.chat = kui.chat_make(b.ui_layer)
	}
	kui.chat_show(&b.chat, false)
	gd.connect_to(cast(gd.Object)b.chat.input, "text_submitted", node, opts.methods.chat)

	// Node2D containers (not plain Nodes) so games can offset them together —
	// screen shake (kfx.Shake) nudges stage+world as one. Children unaffected.
	// A SPATIAL game gets Node3D containers instead: 3D children then inherit
	// a real 3D parent (and the same nudge-together trick works in meters).
	b.stage = opts.spatial ? cast(gd.Node)gd.new_node3d() : cast(gd.Node)gd.new_node2d()
	gd.node_set_name(b.stage, gd.new_string_name_cstring("Stage", true))
	gd.add_child(node, b.stage)
	b.world = opts.spatial ? cast(gd.Node)gd.new_node3d() : cast(gd.Node)gd.new_node2d()
	gd.node_set_name(b.world, gd.new_string_name_cstring("World", true))
	gd.add_child(node, b.world)

	if cast(rawptr)opts.score_scene != nil {
		b.score = kui.score_adopt(b.ui_layer, opts.score_scene)
	} else {
		b.score = kui.score_make(b.ui_layer)
	}

	b.env = opts.env
	netgd.wire_attach(&b.wire, node, ses, opts.msg_kind)
	netgd.wire_listen(&b.wire, opts.methods.packet, opts.methods.peer_left, opts.methods.net_up, opts.methods.net_down)
	latency_env := opts.latency_env
	if latency_env == "" && opts.env != "" {
		latency_env = fmt.ctprintf("%s_LATENCY", opts.env)
	}
	if latency_env != "" {
		// The whole bad-link shim off env: <ENV>_LATENCY (one-way ms) plus
		// <ENV>_JITTER (extra uniform ms, order-preserving) and <ENV>_LOSS
		// (percent: streams drop, reliable pays a retransmit delay) — prove
		// your game FEELS right on a bad link, not just a slow one.
		jit, loss := 0, 0
		if opts.env != "" {
			jit = gd.env_int(fmt.ctprintf("%s_JITTER", opts.env), 0)
			loss = gd.env_int(fmt.ctprintf("%s_LOSS", opts.env), 0)
		}
		netgd.wire_set_latency(&b.wire, gd.env_int(latency_env, 0), jit, loss)
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
	boot_code_pulse(b) // the join-code phonebook (no-op unless a coded door opened)
	if !b.ses.ran {
		// No session yet — a joiner-by-code waiting on the relay. The pulse
		// above is the whole frame; its boot_join starts everything else.
		return
	}
	netgd.wire_pump(&b.wire, now)
	b.succ_now = now
	boot_succ_pulse(b, now) // the web chase's knock pump (no-op native / idle)
	ticks, _ = ksess.session_tick(b.ses, delta, now)

	evs := make([dynamic]ksess.Event, context.temp_allocator)
	for {
		ev, ok := ksess.session_poll(b.ses)
		if !ok {
			break
		}
		boot_succ_event(b, ev) // torch / noted succession / chase-over / kick latch
		#partial switch e in ev {
		case ksess.Ev_Owner_Changed:
			// The lane must always hear ownership moves (predicted↔watched,
			// whose inputs drive it, whom rewinds spare) — forwarded here so
			// no game ever forgets the line.
			if b.lane != nil {
				ksim.lane_set_owner(b.lane, e.id, e.owner)
			}
		case ksess.Ev_Welcomed:
			// The roster RODE the welcome — paint it now, not at the next change.
			kui.lobby_refresh(&b.ui, b.ses)
			kui.score_refresh(&b.score, b.ses)
			kui.lobby_set_status(&b.ui, "Seated — waiting for the host to start")
			b.phase = .Lobby // a fresh seat; the world (or its resync) moves it on
		case ksess.Ev_Player_Joined, ksess.Ev_Player_Left:
			roster_changed(b)
		case ksess.Ev_Stats_Updated:
			kui.score_refresh(&b.score, b.ses)
		case ksess.Ev_Spawned, ksess.Ev_Resynced, ksess.Ev_State_Applied:
			// The world is on this screen (every role: a host's own first
			// spawn lands here too) — the `started` latch, kept once.
			if b.phase == .Lobby {
				b.phase = .Playing
			}
		case ksess.Ev_Join_Failed:
			kui.lobby_set_status(&b.ui, "Could not reach the host")
			b.phase = .Menu
		case ksess.Ev_Join_Denied:
			b.phase = .Menu
		case ksess.Ev_Kicked:
			b.phase = .Menu
		case ksess.Ev_Host_Left:
			kui.lobby_set_status(&b.ui, "The host left — round over")
			// (phase stays — succession may re-seat; the welcome moves it.)
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

	// The sim lane's whole frame drive, when one is installed: predict/
	// simulate, then present (watched interp + the reconcile glide) — after
	// the event drain so ownership moves land first, before the game's
	// _process dresses nodes from the fields.
	if b.lane != nil {
		ksim.lane_frame(b.lane, delta)
		ksim.lane_present(b.lane, delta)
	}
	return evs[:], mks[:], ticks
}

@(private = "file")
roster_changed :: proc(b: ^Boot) {
	kui.lobby_refresh(&b.ui, b.ses)
	kui.score_refresh(&b.score, b.ses)
	if b.ses.is_host {
		// players_only: a dedicated server's own seat is not one of the
		// "%d players ready" (nor does it help reach min_players).
		n := ksess.session_count(b.ses, connected_only = true, players_only = true)
		kui.lobby_set_status(&b.ui, fmt.tprintf("%d players ready", n))
		kui.lobby_show_menu(&b.ui, false, n >= b.min_players)
	}
}

// The env-identity trio — the port()/my_name()/my_token() helpers every
// game kept per-prefix, absorbed behind Options.env ("QD" reads QD_PORT /
// QD_NAME / QD_TOKEN, persists user://qd_token). Same-machine playtests
// pick distinct seats via env; shipped builds ride the defaults. The token
// IS the player: same token later — after a crash, a quit, a resumed save —
// reclaims the same identity; never regenerate it.

boot_port :: proc(b: ^Boot, def: int) -> int {
	if b.env == "" {return def}
	return gd.env_int(fmt.ctprintf("%s_PORT", b.env), def)
}

boot_name :: proc(b: ^Boot, def: string) -> string {
	if b.env == "" {return def}
	n := gd.env_string(fmt.ctprintf("%s_NAME", b.env))
	return n == "" ? def : n
}

boot_token :: proc(b: ^Boot) -> u64 {
	lower := strings.to_lower(b.env, context.temp_allocator)
	return ksave.token({
		env  = fmt.ctprintf("%s_TOKEN", b.env),
		path = fmt.ctprintf("user://%s_token", lower),
	})
}

// The Host button, ceremony included: transport up, session started, menu
// hidden, status set, chat shown. false = port taken (status already says
// so). `token` is the host's own reconnect identity (session_host_start);
// the 0 default resolves to boot_token — the machine's persisted identity —
// so a dead host reclaims its seat from a resumed run WITHOUT the game
// remembering to pass one (token 0 shipped in every reference game and
// silently forfeited exactly that).
boot_host :: proc(b: ^Boot, port: int, name: string, max_peers := 32, token: u64 = 0) -> bool {
	token := token
	if token == 0 {
		token = boot_token(b)
	}
	if !netgd.begin_host(&b.wire, port, name, max_peers, token) {
		kui.lobby_set_status(&b.ui, "Could not host (port taken?)")
		return false
	}
	boot_succ_config(b, false, port, "", token, name)
	b.phase = .Lobby // hosting seats you outright; the first spawn moves it on
	kui.lobby_show_menu(&b.ui, false, false)
	kui.lobby_set_status(&b.ui, fmt.tprintf("Hosting on :%d — waiting for friends", port))
	kui.lobby_refresh(&b.ui, b.ses)
	kui.chat_show(&b.chat, true)
	return true
}

// The DEDICATED-SERVER door: transport up as an always-on authority holding
// an INFRASTRUCTURE seat — no avatar to field (games skip `p.dedicated`
// seats when spawning), no roster/scoreboard row, uncounted by player gates,
// and succession never arms (a dead server restarts; it does not migrate).
// Nobody presses Start on a server, so the game auto-starts its world —
// typically once session_count(players_only = true) reaches its threshold
// (see examples/slopball's `serve` role). Native only: a browser tab makes a
// poor always-on box. false = the port was taken.
boot_serve :: proc(b: ^Boot, port: int, name: string, max_peers := 32, token: u64 = 0) -> bool {
	token := token
	if token == 0 {
		token = boot_token(b) // stable server identity — a restart is a resume
	}
	if !netgd.begin_host(&b.wire, port, name, max_peers, token, dedicated = true) {
		kui.lobby_set_status(&b.ui, "Could not host (port taken?)")
		return false
	}
	b.phase = .Lobby
	kui.lobby_show_menu(&b.ui, false, false)
	kui.lobby_set_status(&b.ui, fmt.tprintf("Serving on :%d", port))
	kui.chat_show(&b.chat, true)
	return true
}

// The WHOLE kick: seat revoked + socket closed AFTER the kicked message
// flushes — session_kick alone leaves the transport open, and every game
// hand-rolled the second half (or forgot it: the ghost stayed seated on the
// wire). ban=true also shuts the token out for the rest of the run.
boot_kick :: proc(b: ^Boot, player: knet.Player_Id, ban := false) -> bool {
	seat, ok := ksess.session_kick(b.ses, player, ban)
	if ok {
		netgd.wire_drop(&b.wire, seat)
	}
	return ok
}

// The Join button. An unreachable host resolves later as Ev_Join_Failed.
boot_join :: proc(b: ^Boot, addr: cstring, port: int, token: u64, name: string, status := "Joining...") -> bool {
	if !netgd.begin_join(&b.wire, addr, port, token, name) {
		kui.lobby_set_status(&b.ui, "Could not start joining")
		return false
	}
	boot_succ_config(b, false, port, "", token, name)
	b.phase = .Connecting // Ev_Welcomed seats it; Ev_Join_Failed sends it home
	kui.lobby_show_menu(&b.ui, false, false)
	kui.lobby_set_status(&b.ui, status)
	kui.chat_show(&b.chat, true)
	return true
}

// The Host button, WebRTC flavor: room opened on the relay, session started,
// menu hidden, status set (the CODE arrives async — netgd.web_poll it and
// read gd.webrtc_room_code), chat shown. A non-empty `room` RESERVES that
// code (host migration pre-arranges tomorrow's room; the relay honors a free
// valid code, else assigns). false = the relay socket refused.
boot_host_web :: proc(b: ^Boot, url: cstring, name: string, token: u64 = 0, room: cstring = "") -> bool {
	token := token
	if token == 0 {
		token = boot_token(b) // same reclaim default as boot_host
	}
	if !netgd.begin_host_web(&b.wire, url, name, token, room) {
		kui.lobby_set_status(&b.ui, "Could not reach the relay")
		return false
	}
	boot_succ_config(b, true, 0, url, token, name)
	b.phase = .Lobby
	kui.lobby_show_menu(&b.ui, false, false)
	kui.lobby_set_status(&b.ui, "Opening a room…")
	kui.chat_show(&b.chat, true)
	return true
}

// The Join button, WebRTC flavor. A dead room resolves later through
// gd.webrtc_session_state/.Failed (the relay answers no_room / full).
boot_join_web :: proc(b: ^Boot, url: cstring, room: cstring, token: u64, name: string) -> bool {
	if !netgd.begin_join_web(&b.wire, url, room, token, name) {
		kui.lobby_set_status(&b.ui, "Could not reach the relay")
		return false
	}
	boot_succ_config(b, true, 0, url, token, name)
	b.phase = .Connecting
	kui.lobby_show_menu(&b.ui, false, false)
	kui.lobby_set_status(&b.ui, fmt.tprintf("Joining room %s…", room))
	kui.chat_show(&b.chat, true)
	return true
}

// The Host button, JOIN-CODE flavor: a native ENet host (boot_host, ceremony
// included) that ALSO registers the port with the signaling relay for a
// copyable room code — the same relay the browser build uses (the production
// one serves /rtc; tests/webrtc/signal_server.mjs speaks it locally). The
// code arrives async (one relay round trip): boot_pump lands it in the lobby
// status, boot_room_code reads it any time. A dead relay demotes to plain
// hosting — the session stands either way; false means the PORT was taken.
// A non-empty `room` RESERVES that code when free (succession pre-arranges).
boot_host_coded :: proc(b: ^Boot, url: cstring, port: int, name: string, max_peers := 32, token: u64 = 0, room := "") -> bool {
	if !boot_host(b, port, name, max_peers, token) {
		return false
	}
	b.rdv_seen = .Idle
	if !netgd.code_host_open(&b.rdv, url, port, room) {
		kui.lobby_set_status(&b.ui, "Hosting — but the relay is unreachable (no code)")
		return true
	}
	kui.lobby_set_status(&b.ui, fmt.tprintf("Hosting on :%d — minting a join code…", port))
	return true
}

// The Join button, JOIN-CODE flavor: trade a friend's code for the host's
// endpoint, then it's a normal ENet join — boot_pump polls the relay and
// walks through boot_join the moment the phonebook answers (keep calling it;
// there is no session to pump until then, and it knows). A bad code resolves
// later in the lobby status (no such room / full / relay gone) with the menu
// restored; an unreachable host after that as Ev_Join_Failed. false = the
// relay socket refused outright.
boot_join_code :: proc(b: ^Boot, url: cstring, code: string, token: u64, name: string) -> bool {
	if !netgd.code_join_open(&b.rdv, url, code) {
		kui.lobby_set_status(&b.ui, "Could not reach the relay")
		return false
	}
	b.rdv_seen = .Idle
	b.rdv_token = token
	if b.rdv_name != "" {
		delete(b.rdv_name)
	}
	b.rdv_name = strings.clone(name)
	b.phase = .Connecting // the phonebook first, then the join proper
	kui.lobby_show_menu(&b.ui, false, false)
	kui.lobby_set_status(&b.ui, fmt.tprintf("Looking up %s…", code))
	kui.chat_show(&b.chat, true)
	return true
}

// The minted join code — "" until the relay answers (the lobby status shows
// it too; this is for games that paint it somewhere of their own).
boot_room_code :: proc(b: ^Boot) -> string {
	return b.rdv.is_host ? netgd.code_room(&b.rdv) : ""
}

// The rendezvous pump: surface state edges in the lobby, complete a joiner's
// door. A host's socket stays open past .Ready — the relay brokers every
// later join through it (and each joiner's NAT punch rides the same poll).
@(private = "file")
boot_code_pulse :: proc(b: ^Boot) {
	if !b.rdv.active {
		return
	}
	st := netgd.code_poll(&b.rdv, &b.wire)
	if st == b.rdv_seen {
		return
	}
	b.rdv_seen = st
	#partial switch st {
	case .Ready:
		if b.rdv.is_host {
			kui.lobby_set_status(&b.ui, fmt.tprintf("Join code %s — waiting for friends", netgd.code_room(&b.rdv)))
		} else {
			// The phonebook answered: a normal ENet join from here on.
			ip, port := netgd.code_endpoint(&b.rdv)
			boot_join(b, ip, port, b.rdv_token, b.rdv_name, fmt.tprintf("Code %s accepted — joining...", netgd.code_room(&b.rdv)))
			netgd.code_close(&b.rdv)
		}
	case .Failed:
		if b.rdv.is_host {
			// The host stands regardless — friends can still join by address.
			kui.lobby_set_status(&b.ui, "Hosting — but the relay dropped (no code)")
		} else {
			why := "the relay dropped before answering"
			#partial switch b.rdv.err {
			case .No_Room:
				why = "no room wears that code"
			case .Full:
				why = "that room is full"
			}
			kui.lobby_set_status(&b.ui, fmt.tprintf("Join code failed — %s", why))
			kui.lobby_show_menu(&b.ui, true, false) // back to the doors
			b.phase = .Menu
		}
		netgd.code_close(&b.rdv)
	}
}

// Chat's text_submitted, one call (see kui.chat_submit for the trap it fixes).
boot_chat :: proc(b: ^Boot, text: gd.String, sent: ^bool = nil) {
	kui.chat_submit(&b.chat, b.comms, text, sent)
}
