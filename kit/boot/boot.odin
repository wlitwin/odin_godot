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
//     // ready(): the conventional Boot + Session + Comms fields generate this
//     my_game_net_attach(self, kboot.Options{
//         title    = "P U T T P U T T",
//         status   = "Host a course, or join one at localhost",
//         legend   = "click: putt · Tab scores · Enter chat",
//         msg_kind = MSG_SESSION,
//         latency_env = "GOLF_LATENCY",
//     })
//
//     // process(): network pump + event dispatch in one generated call
//     frame := my_game_net_pump(self, delta, now_s())
//     my_game_step(self, frame.ticks) // @(gd_step="authority"): host gate + edge pass
//
// The eight @(gd_method) names stay the game's to declare — Godot signals
// must land on the game's script class; their bodies are one-liners (see
// either example game's net.odin).
//
// LIFECYCLE — the generated `<game>_net_detach` tears down lane, comms, Boot,
// and Session in dependency order for a back-to-menu → reattach in one live
// process. The lower boot_detach owns only boot_attach's slice. See both procs.

import gd "godot:godot"
import "godot:gdext"
import kcomms "godot:kit/comms"
import kcfg "godot:kit/netcfg"
import kxfer "godot:kit/xfer"
import knet "godot:kit/net"
import netgd "godot:kit/netgd"
import ksave "godot:kit/save"
import ksess "godot:kit/session"
import ksim "godot:kit/sim"
import kui "godot:kit/ui"
import "core:fmt"
import "core:strings"

// The generated facade exposes the complete-stack profiles through kboot so a
// game needs no extra import. The implementation stays engine-free in
// kit/netcfg, where its value and validation contract are unit tested.
Network_Profile :: kcfg.Network_Profile
Network_Config :: kcfg.Network_Config
Network_Capabilities :: kcfg.Network_Capabilities
Network_Config_Error :: kcfg.Network_Config_Error
network_profile :: kcfg.network_profile
network_config_resolve :: kcfg.network_config_resolve
network_config_check :: kcfg.network_config_check
network_config_error :: kcfg.network_config_error
network_configure :: kcfg.network_configure

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
//   .Menu       — no seat and none coming; the Host/Join doors are showing
//   .Connecting — a join is in flight, no seat yet (a join code at the
//                 phonebook counts, and so does a survivor's chase: the dial
//                 restarts the session as a client, which IS connecting)
//   .Lobby      — seated (hosting counts), the world not yet on this screen
//   .Playing    — the world reached this peer (first spawn/state/resync)
// A failed or denied join and a kick fall back to .Menu; a BARE host loss
// stays put — the seat survives the socket, and succession may re-seat it.
Boot_Phase :: enum u8 {
	Menu,
	Connecting,
	Lobby,
	Playing,
}

// The game-facing residue of one generated `<game>_net_pump`: declared
// session events have already reached their typed halves, while chat markers
// and the co-op fixed-step count remain game-shaped work. Both slices are
// frame-temporary, exactly like boot_pump's results; consume them this frame.
Net_Frame :: struct {
	marks: []kcomms.Ev_Marker,
	ticks: int,
}

// WHERE THE BOOT STANDS — derived, not tracked.
//
// This was a stored `phase` field once, advanced only by boot's own doors and
// boot_pump's drain. Which meant the documented RAW path — netgd/ksess started
// by hand, boot_pump for everything after — left it frozen at .Menu forever: a
// SECOND lifecycle record, disagreeing with the session's own, sitting there
// with zero consumers and waiting for the first kit feature to branch on it and
// misbehave for every game that had not come through a door. (Three records was
// the real count: the games' `running`/`started` bools, boot's phase, and the
// session's ran/joined/is_host/replicating.)
//
// So every coarse answer is READ OFF the session, which knows regardless of who
// started it, and the ONE fact nothing below boot knows — the world REACHED
// this screen — is the single latch left (see Boot.world_seen). A raw-path game
// gets a truthful phase for free; the doors write no lifecycle state at all.
boot_phase :: proc(b: ^Boot) -> Boot_Phase {
	s := b.ses
	if s == nil || !s.ran {
		// Pre-attach, post-detach, or nothing started yet. The one exception is
		// boot's OWN errand: a join code at the phonebook has no session to
		// report — the relay answers first, and boot_join proper runs after.
		return dialing_code(b) ? .Connecting : .Menu
	}
	if s.joined {
		// Seated. Hosting seats you outright (session_host_start), so this arm
		// is role-free — and the host's own first spawn raises the latch too.
		return b.world_seen ? .Playing : .Lobby
	}
	// Unseated, with the session's join clock ARMED, is a join in flight. A
	// refusal, a denial, and a kick all DISARM it (join_waited = -1), which is
	// exactly the fall-back-to-menu the doors used to hand-write — and a
	// never-started run reads -1 too, so the clock alone is the whole test.
	if !s.is_host && s.join_waited >= 0 {
		return .Connecting
	}
	return dialing_code(b) ? .Connecting : .Menu
}

@(private = "file")
dialing_code :: proc(b: ^Boot) -> bool {
	return b.rdv.active && !b.rdv.is_host
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
	max_fps:     int, // the unthrottle's cap (0 = 120): a laptop game that wants 60 says so
	                  // here instead of re-capping by hand right after boot_attach
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
unthrottle_desktop :: proc(max_fps: int) {
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
	gd.engine_set_max_fps(gd.singleton_engine(), gd.Int(max_fps > 0 ? max_fps : 120))
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
	fx_layer: gd.Node, // CanvasLayer BETWEEN the field and the widgets — screen fades,
	                   // vignettes, full-rect flashes (kui.overlay_attach); games used to
	                   // node_move_child their overlays under the chat at index 0/1
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
	album:     ^kxfer.Album, // boot_album: pumped per net tick, welcomed per join — nil = no album
	talk_sent: bool, // chat_submit's anti-re-grab latch: pass &b.talk_sent to boot_chat/chat_submit,
	                 // boot_keys_frame consumes it (the submitting ENTER must not reopen the chat)
	// The WEBRTC door's surfaced state (boot_web_pulse): the assigned room
	// code (a boot-owned clone; "" until the relay replies) and the last
	// handshake state worded, so edges word once.
	web_room:       string,
	web_state_seen: gd.Webrtc_State,
	ent_game:  rawptr,
	ent_nodes: map[knet.Net_Id]gd.Node,
	// The game's generated event dispatcher (`<game>_events` behind a rawptr
	// thunk), when the game handed it over (the generated `<game>_entities`
	// does). It is what lets boot deliver the AUTHORITY's own Ev_Spawned at
	// the send — boot_born — instead of from the next pump's batch.
	ent_events: Events_Proc,
	// It LOOKS like a copy of the session's `types` map, and it is not — twice
	// over, both load-bearing. (1) LIFETIME: both despawn paths delete the
	// session's row BEFORE calling the factory free (session_despawn and the
	// SES_DESPAWN handler, in that order), so at the moment boot_free_entity
	// must resolve the kind to fire the game's `_freed` half, the session has
	// already forgotten it. (2) SCOPE: a PREDICTED spawn (kit/sim, a fired
	// projectile flying under a provisional id) has no session registry entry
	// at all until the authority's spawn rekeys it — this ledger is the only
	// place that id is a known kind. Deriving it would mean reordering
	// kit/session's despawn contract and finding a second home for provisional
	// ids; keeping it costs one map entry per live entity.
	ent_types: map[knet.Net_Id]ksess.Entity_Type,
	// Per-kind linked indexes over ent_types. The old census scanned EVERY
	// entity to answer `<kind>_ids` / owner queries, then hot loops looked each
	// id up again. Heads + links make a kind walk proportional to that kind and
	// preserve one canonical ledger for authoritative and provisional ids.
	// Links are sorted by Net_Id, which also makes cross-entity sim passes
	// deterministic across peers instead of inheriting map iteration order.
	ent_heads: map[ksess.Entity_Type]knet.Net_Id,
	ent_next:  map[knet.Net_Id]knet.Net_Id,
	ent_prev:  map[knet.Net_Id]knet.Net_Id,
	// A predicted entity changes from its local provisional id to the
	// authority's real id without changing identity. Keep that one local alias
	// so a typed ref retained at fire time continues resolving after the match.
	ent_alias: map[knet.Net_Id]knet.Net_Id,

	// boot_migration's state (succession.odin): the rendezvous ceremony, the
	// generated hook table, and the latches every migrating game hand-kept
	// (host_gone/rejoin_tries/kicked_out — absorbed).
	succ:             netgd.Succession,
	succ_hooks:       Succ_Hooks,
	succ_game:        rawptr,
	succ_armed:       bool,
	succ_kicked:      bool, // a kicked player never chases the torch
	succ_phase:       Succ_Phase, // THE window record — one owner (was: latches here + chase state in netgd)
	succ_tries:       int, // THE chase counter, both flavors (was: a native counter here and a web twin in netgd)
	succ_next:        f64, // web: when the next knock may go (heir headstart, then the retry gap)
	succ_room:        string, // web: the room being knocked on (owned; "" = no live web chase)
	succ_pending:     knet.Player_Id, // a noted succession, mechanics deferred
	succ_has_pending: bool,
	succ_now:         f64, // boot_pump's clock, for the deferred chase
	succ_name:        string, // boot-owned clones (door callers pass temps)
	succ_url:         string,

	// THE ONE fact below boot cannot answer: the world REACHED this screen.
	// Everything else boot_phase reports is read off the session (see there);
	// this is the residue, and it has exactly ONE owner — boot_pump, which
	// raises it in the drain when the first spawn/state/resync lands and drops
	// it at the top of any frame that finds no seat. boot_open_host drops it
	// too, for the one re-seat that never has an unseated frame (menu → host
	// again inside a live process). Read boot_phase(b), never this.
	world_seen: bool,
	// A host spawn born BETWEEN pumps (boot_born) owes the latch above its
	// rise — at the next pump, not at the send. The phase is a level games
	// edge-detect ACROSS the pump ("boot_pump is the only place the phase
	// RISES"); a mid-frame rise would slip past that edge on the host.
	world_pending: bool,

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
		unthrottle_desktop(opts.max_fps)
	}

	// Every widget lives on a CanvasLayer: layers draw above world-space
	// CanvasItems no matter what z_index entities carry, so a full-screen
	// playfield can never bury the chat (homestead found it live — its
	// grass covered the viewport and z>0 entities beat every Control).
	// The FX layer first (screen fades/vignettes ride above the field but
	// under every widget — layers stack in add order at the same layer index).
	fxl := gd.new_canvas_layer()
	gd.node_set_name(cast(gd.Node)fxl, gd.new_string_name_cstring("BootFx", true))
	gd.add_child(node, cast(gd.Node)fxl)
	b.fx_layer = cast(gd.Node)fxl
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
		// <ENV>_JITTER (extra uniform ms, order-preserving), <ENV>_LOSS
		// (percent: streams drop, reliable pays a retransmit delay),
		// <ENV>_BURST (mean lost-run length in packets — losses CLUSTER like
		// real WiFi instead of coin-flipping), and <ENV>_BANDWIDTH (downlink
		// bytes/s — overflow queues and delay grows, bufferbloat-shaped).
		// Prove your game FEELS right on a bad link, not just a slow one —
		// and on a CRUEL one, not just a statistically tidy one. Up/down
		// asymmetry is per-process: each end shims its own receive, so give
		// the two windows different values.
		jit, loss, burst, bw := 0, 0, 1, 0
		if opts.env != "" {
			jit = gd.env_int(fmt.ctprintf("%s_JITTER", opts.env), 0)
			loss = gd.env_int(fmt.ctprintf("%s_LOSS", opts.env), 0)
			burst = gd.env_int(fmt.ctprintf("%s_BURST", opts.env), 1)
			bw = gd.env_int(fmt.ctprintf("%s_BANDWIDTH", opts.env), 0)
		}
		netgd.wire_set_latency(&b.wire, gd.env_int(latency_env, 0), jit, loss, burst, bw)
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

// Boot's teardown verb — boot_attach's symmetric twin, for the ONE flow that
// keeps the process alive across it: back to menu, then re-host/re-join in the
// same run. boot_attach's slice is boot-owned, and without this it LEAKED on
// every return (the widget tracking arrays, the wire's gauge + shim containers,
// the entity ledgers, the succession clones) and DOUBLED on every
// re-host (a second ui_layer/stage/world forest piled onto the first, Godot
// auto-renaming the collisions). boot_detach frees exactly what boot_attach and
// the doors allocated, queue-frees the container nodes boot itself created (see
// THE OWNERSHIP RULE below), and zeroes the Boot back to pre-attach — a fresh
// boot_attach then rebuilds everything. Idempotent: safe on an already-detached
// (zeroed) Boot, every free below no-ops on a nil container.
//
// NOT wired to any scene-exit hook, on purpose. The normal game calls its
// generated `<game>_net_detach`, which wraps this and destroys the sibling
// lane/comms/session too. A custom shell calls this only when it is separately
// honoring those values' destroy contracts.
//
// THE OWNERSHIP RULE: boot lives as long as its node; below boot, X destroys
// what X inits; node trees belong to the scene. boot CREATED the container
// nodes (ui_layer / stage / world), so boot_detach queue-frees THOSE — and the
// widgets, the legend, and the world's entities parented under them ride the
// subtree down with one free each. The kui *_destroy calls free only their
// Odin-side tracking arrays (the nodes are the container's, i.e. boot's);
// wire_detach frees the wire's own containers. Nothing is freed twice: no layer
// frees a node another layer created (queue-freeing world AND an entity node
// under it is the one overlap, and Godot's deletion queue validates each id, so
// the parent-then-child pair is safe by construction).
boot_detach :: proc(b: ^Boot) {
	// Widgets: drop the Odin tracking arrays. The NODES ride ui_layer, freed
	// with its subtree below — these calls never touch the tree (their own
	// contract, stated on each *_destroy).
	kui.lobby_destroy(&b.ui)
	kui.chat_destroy(&b.chat)
	kui.score_destroy(&b.score)
	// The transport binding's owned containers (gauge windows, shim queues) and
	// a live web relay session, if one is up.
	netgd.wire_detach(&b.wire)
	// The join-code rendezvous socket, if one is open (no-op when idle).
	netgd.code_close(&b.rdv)
	// The succession ceremony's one owned clone (the minted web reservation).
	netgd.succession_destroy(&b.succ)
	// The entity ledgers: the documented back-to-lobby wipe queue-frees the
	// nodes + clears the maps, then release the maps' backing before the zero
	// (clear keeps the allocation; a bare b^ = {} would orphan it).
	boot_entities_clear(b)
	delete(b.ent_nodes)
	delete(b.ent_types)
	delete(b.ent_heads)
	delete(b.ent_next)
	delete(b.ent_prev)
	delete(b.ent_alias)
	// The boot-owned string clones the doors minted (callers passed temps;
	// boot_succ_end may have pre-freed succ_room — delete("") is a no-op).
	delete(b.web_room)
	delete(b.succ_name)
	delete(b.succ_url)
	delete(b.succ_room)
	delete(b.rdv_name)
	// The container nodes boot created — one free each carries the whole subtree
	// (ui_layer: lobby/chat/score/legend; world: every live entity).
	if cast(rawptr)b.ui_layer != nil {
		gd.node_queue_free(b.ui_layer)
	}
	if cast(rawptr)b.fx_layer != nil {
		gd.node_queue_free(b.fx_layer)
	}
	if cast(rawptr)b.stage != nil {
		gd.node_queue_free(b.stage)
	}
	if cast(rawptr)b.world != nil {
		gd.node_queue_free(b.world)
	}
	b^ = {} // back to pre-attach — the ses/comms/lane pointers included (a fresh
	// boot_attach re-supplies them); env / ent_kinds were the game's, never ours.
}

// The whole network stack's symmetric teardown, used by the generated
// `<game>_net_detach`. Boot owns the lifecycle even though the values remain
// public sibling fields on the game struct: destroy riders before the Session
// they are registered on, let boot release its wire/UI/entity slice while its
// pointers are still live, then reset the Session run/registry. Its pre-start
// configuration and generated wiring survive for a fresh attach + start.
//
// The pointers are captured before boot_detach zeroes Boot. Every destroy is
// nil/zero-safe, so this is idempotent and a detached game can attach afresh.
boot_net_detach :: proc(b: ^Boot) {
	lane := b.lane
	comms := b.comms
	ses := b.ses
	if lane != nil {
		ksim.lane_destroy(lane)
	}
	if comms != nil {
		kcomms.comms_destroy(comms)
	}
	boot_detach(b)
	if ses != nil {
		ksess.session_reset(ses)
	}
}

// The frame preamble + the boilerplate half of the event drain. Pumps the
// wire, ticks the session, walks every drained event through the KIT's own
// forwarding table (forward.odin — one exhaustive switch, so no consequence
// the kit owes can go missing) — and RE-YIELDS every session event plus the
// comms markers, both temp-allocated, so the game's own switch sees everything.
boot_pump :: proc(b: ^Boot, delta: f64, now: f64) -> (events: []ksess.Event, marks: []kcomms.Ev_Marker, ticks: int) {
	boot_code_pulse(b) // the join-code phonebook (no-op unless a coded door opened)
	boot_web_pulse(b) // the WebRTC room's twin (no-op unless the wire is WEBRTC)
	// The transport's own control plane, before anything asks whether a session
	// exists — on WebRTC this IS the handshake that brings one up. One nil
	// check on every other transport. (Web games used to hand-call web_poll
	// from process() and nothing said so; a boot-door browser game that missed
	// the line simply never connected.)
	netgd.transport_service(&b.wire)
	if !b.ses.ran {
		// No session yet — a joiner-by-code waiting on the relay. The pulse
		// above is the whole frame; its boot_join starts everything else.
		return
	}
	// The world cannot be on a screen that holds no seat, so the phase's one
	// latch resets itself as the run turns over — dropped HERE, ahead of the
	// pump that may deliver the welcome re-seating us this very frame.
	if !b.ses.joined {
		b.world_seen = false
		b.world_pending = false
	}
	netgd.wire_pump(&b.wire, now)
	b.succ_now = now
	boot_succ_pulse(b, now) // the web chase's knock pump (no-op native / idle)
	ticks, _ = ksess.session_tick(b.ses, delta, now)
	if b.album != nil {
		for _ in 0 ..< ticks {
			kxfer.album_pump(b.album) // chunks ship on the net cadence, like everything else
		}
	}

	evs := make([dynamic]ksess.Event, context.temp_allocator)
	for {
		ev, ok := ksess.session_poll(b.ses)
		if !ok {
			break
		}
		boot_forward(b, ev) // THE kit-side table — one full switch, forward.odin
		append(&evs, ev)
	}
	if b.world_pending {
		// The authority's own spawns since the last pump were born at their
		// send (boot_born) — the world reached this screen then; the PHASE
		// reports it here, where it always has (see world_pending).
		b.world_seen = true
		b.world_pending = false
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
		// The authority's SIM ticks just mutated delta-lane state, and
		// session_tick's own edge pass is already behind us — so without this
		// line a sim game's `<field>_edge` halves see this frame's mutations
		// only NEXT frame. Coop games never had the bug: their tick loop lives
		// in the generated <snake>_step, which fires the pass right after it,
		// for exactly this reason. Lane-routed ticks had no equivalent, so the
		// two lanes disagreed about when an edge means "now".
		//
		// Before lane_present on purpose: present blends WATCHED fields toward
		// their delayed view, and an edge is a statement about the authority's
		// truth, not about smoothing. The pass is idempotent (diff, fire,
		// commit), so a client — or a host whose ticks changed nothing — pays
		// one memcmp.
		ksess.session_run_edges(b.ses)
		ksim.lane_present(b.lane, delta)
	}
	return evs[:], mks[:], ticks
}

@(private) // forward.odin's table paints through this on both roster edges
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

// ---- the two doors, once per direction -------------------------------------
//
// THE HOST DOOR and THE JOIN DOOR, parameterized by transport. Every named
// door below (boot_host, boot_join, the web pair, the code pair, the Steam
// pair a game writes for itself) is these two plus a status line: the ritual
// — reconnect identity, succession config, phase, menu, chat, roster — is
// written ONCE here and a new transport inherits all of it by filling a
// netgd.Transport record. That is the whole point of the record: before it,
// each transport grew its own door-set and each door-set forgot a different
// part of the ritual (Steam had no door at all, so it forgot every part).

// The generic HOST door. false = the transport refused; the session was NOT
// started and the caller words the failure (each transport fails for its own
// reason — a taken port, an unreachable relay, a lobby that never came up).
// `token` is the host's own reconnect identity (session_host_start); the 0
// default resolves to boot_token — the machine's persisted identity — so a
// dead host reclaims its seat from a resumed run WITHOUT the game remembering
// to pass one (token 0 shipped in every reference game and silently forfeited
// exactly that).
boot_open_host :: proc(
	b: ^Boot,
	t: ^netgd.Transport,
	at: netgd.Endpoint,
	name: string,
	token: u64 = 0,
	dedicated := false,
) -> bool {
	token := token
	if token == 0 {
		token = boot_token(b)
	}
	// Fold whatever the LAST door left open (a stale web signaling socket, a
	// failed attempt's holdings) so this one binds clean — the leak every
	// by-hand rejoin path had to remember (idempotent; ENet holds nothing).
	netgd.transport_close(&b.wire)
	boot_web_reset(b)
	if !netgd.transport_host(&b.wire, t, at, name, token, dedicated) {
		return false
	}
	// The torch flavor comes from the TRANSPORT (it is the one that knows how
	// it addresses a peer) — a door never has to be told twice, and a
	// transport that cannot migrate says .None once, in its own record.
	// Dedicated servers arm nothing: a dead server restarts, it does not
	// migrate.
	if !dedicated {
		boot_succ_config(b, t.rendezvous, at.port, at.addr, token, name)
	}
	// The ONE lifecycle write left in either door, and the only one boot_pump
	// cannot make for itself: hosting seats you the instant session_host_start
	// returns, so a re-host inside a live process (menu → Host again, no
	// boot_detach between) never spends a frame unseated — and without this the
	// dead run's world would still read as "on this screen".
	b.world_seen = false
	b.world_pending = false
	kui.lobby_show_menu(&b.ui, false, false)
	kui.lobby_refresh(&b.ui, b.ses)
	kui.chat_show(&b.chat, true)
	return true
}

// The generic JOIN door. false = the transport refused outright; an
// unreachable host resolves later as Ev_Join_Failed. `spectate` takes a
// receive-only seat (see boot_spectate for what that means).
// (Argument order matches boot_open_host and the Transport record: NAME then
// TOKEN, everywhere in this door pair. The older named doors kept the
// begin_join order they always had — `token, name` — so their call sites did
// not move; the new pair is the one that gets to be consistent.)
boot_open_join :: proc(
	b: ^Boot,
	t: ^netgd.Transport,
	at: netgd.Endpoint,
	name: string,
	token: u64,
	spectate := false,
	status := "Joining...",
) -> bool {
	// Same fold as boot_open_host: the last door's holdings die before this
	// one binds (a retry after a failed web join reuses the socket slot).
	netgd.transport_close(&b.wire)
	boot_web_reset(b)
	if !netgd.transport_join(&b.wire, t, at, name, token, spectate) {
		return false
	}
	boot_succ_config(b, t.rendezvous, at.port, at.addr, token, name)
	// No phase to write: session_client_start armed the join clock, which IS
	// .Connecting — and disarms itself into .Menu on a refusal, a denial, or a
	// kick. See boot_phase.
	kui.lobby_show_menu(&b.ui, false, false)
	kui.lobby_set_status(&b.ui, status)
	kui.chat_show(&b.chat, true)
	return true
}

// The Host button, ceremony included: transport up, session started, menu
// hidden, status set, chat shown. false = port taken (status already says so).
boot_host :: proc(b: ^Boot, port: int, name: string, max_peers := 32, token: u64 = 0) -> bool {
	if !boot_open_host(b, &netgd.ENET, {port = port, max_peers = max_peers}, name, token) {
		kui.lobby_set_status(&b.ui, "Could not host (port taken?)")
		return false
	}
	kui.lobby_set_status(&b.ui, fmt.tprintf("Hosting on :%d — waiting for friends", port))
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
	// token 0 → boot_token inside the door: a stable server identity, so a
	// restart is a resume.
	if !boot_open_host(b, &netgd.ENET, {port = port, max_peers = max_peers}, name, token, dedicated = true) {
		kui.lobby_set_status(&b.ui, "Could not host (port taken?)")
		return false
	}
	kui.lobby_set_status(&b.ui, fmt.tprintf("Serving on :%d", port))
	return true
}

// Register the game's ALBUM (kit/xfer: latest-payload-per-(player, kind) —
// sprays, skins) so its two chores become the kit's: boot_pump pumps it once
// per net tick (chunks ship on the session's cadence) and every Ev_Player_Joined
// welcomes the newcomer with the kept payloads (the host-side catch-up games
// forgot until "the late joiner sees no sprays" was filed as a bug). ready(),
// after kxfer.album_init.
boot_album :: proc(b: ^Boot, a: ^kxfer.Album) {
	b.album = a
}

// The SOLO door: the same game, alone — a full authority session over
// netgd.OFFLINE (an OfflineMultiplayerPeer seats you as host id 1; broadcasts
// cleanly reach nobody), through the SAME ritual as every door (world_seen
// reset, lobby folded, phase readable), so the solo path stops being the one
// hand-rolled special case that bypassed it. The whole authoritative sim runs
// exactly as it does with friends; succession never arms (.None — nobody to
// migrate to). token 0 → boot_token, like the other doors.
boot_single :: proc(b: ^Boot, name: string, token: u64 = 0) -> bool {
	if !boot_open_host(b, &netgd.OFFLINE, {}, name, token) {
		kui.lobby_set_status(&b.ui, "Could not start solo (no multiplayer node?)")
		return false
	}
	kui.lobby_set_status(&b.ui, "Solo — the same game, alone")
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
	if !boot_open_join(b, &netgd.ENET, {addr = addr, port = port}, name, token, status = status) {
		kui.lobby_set_status(&b.ui, "Could not start joining")
		return false
	}
	return true
}

// The WATCHING door: join a run to see it, not to play it. The seat is
// receive-only past the join (the host refuses its commands, streams, and
// inputs), bypasses max_players (a full room can be watched), never holds
// the torch, and games field it no avatar (its rows read spectator on every
// roster — the spawn loops' `!p.spectator` guard is the game's half). It
// still chases the torch on a migration — as a spectator of the resumed run.
boot_spectate :: proc(b: ^Boot, addr: cstring, port: int, token: u64, name: string, status := "Watching...") -> bool {
	if !boot_open_join(b, &netgd.ENET, {addr = addr, port = port}, name, token, spectate = true, status = status) {
		kui.lobby_set_status(&b.ui, "Could not start joining")
		return false
	}
	return true
}

// The Host button, WebRTC flavor: room opened on the relay, session started,
// menu hidden, status set (the CODE arrives async — boot_pump services the
// handshake, then read gd.webrtc_room_code), chat shown. A non-empty `room` RESERVES that
// code (host migration pre-arranges tomorrow's room; the relay honors a free
// valid code, else assigns). false = the relay socket refused.
boot_host_web :: proc(b: ^Boot, url: cstring, name: string, token: u64 = 0, room: cstring = "") -> bool {
	if !boot_open_host(b, &netgd.WEBRTC, {addr = url, room = room}, name, token) {
		kui.lobby_set_status(&b.ui, "Could not reach the relay")
		return false
	}
	kui.lobby_set_status(&b.ui, "Opening a room…")
	return true
}

// The Join button, WebRTC flavor. A dead room resolves later through
// gd.webrtc_session_state/.Failed (the relay answers no_room / full).
boot_join_web :: proc(b: ^Boot, url: cstring, room: cstring, token: u64, name: string) -> bool {
	status := fmt.tprintf("Joining room %s…", room)
	if !boot_open_join(b, &netgd.WEBRTC, {addr = url, room = room}, name, token, status = status) {
		kui.lobby_set_status(&b.ui, "Could not reach the relay")
		return false
	}
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
	// A live joiner-side rendezvous IS .Connecting (boot_phase reads it): the
	// phonebook first, then the join proper, and code_close ends both.
	kui.lobby_show_menu(&b.ui, false, false)
	kui.lobby_set_status(&b.ui, fmt.tprintf("Looking up %s…", code))
	kui.chat_show(&b.chat, true)
	return true
}

// The minted join code — "" until the relay answers (the lobby status shows
// it too; this is for games that paint it somewhere of their own). Answers
// for BOTH coded doors: the native join-code relay and a WebRTC room
// (boot_web_pulse keeps the latter current — web games used to poll
// gd.webrtc_room_code behind a hand latch).
boot_room_code :: proc(b: ^Boot) -> string {
	if netgd.transport_of(&b.wire) == &netgd.WEBRTC {
		return b.web_room
	}
	return b.rdv.is_host ? netgd.code_room(&b.rdv) : ""
}

// The WEBRTC door's rendezvous pump — boot_code_pulse's twin (that one is
// the native join-code phonebook; this one the browser room). Surfaces what
// every web game hand-latched in its own process():
//   * the assigned ROOM CODE the moment the relay replies: logged as
//     `BOOT_ROOM_CODE <code>` (drivers scrape it), worded in the lobby
//     status pre-world ("share it with the crew") or into chat mid-run (a
//     room born mid-run is a takeover's — the lobby is long gone), and
//     readable via boot_room_code.
//   * the handshake's state EDGES pre-world: "handshaking…", and .Failed
//     with the relay's worded reason + the doors restored — the same
//     treatment the join-code door's failures get.
// A fresh door voids the last room's surfaced state (the code was that
// run's; a takeover's new room re-surfaces through the pulse).
@(private = "file")
boot_web_reset :: proc(b: ^Boot) {
	delete(b.web_room)
	b.web_room = ""
	b.web_state_seen = .Idle
}

@(private = "file")
boot_web_pulse :: proc(b: ^Boot) {
	if netgd.transport_of(&b.wire) != &netgd.WEBRTC {
		return
	}
	node := b.wire.node
	if cast(rawptr)node == nil {
		return
	}
	if b.web_room == "" {
		if code := gd.webrtc_room_code(node); len(code) > 0 {
			b.web_room = strings.clone(code)
			gd.print_str(fmt.tprintf("BOOT_ROOM_CODE %s", code))
			if b.world_seen {
				if b.comms != nil && b.ses != nil && b.ses.is_host {
					kcomms.comms_system(b.comms, fmt.tprintf("new room %s — share it to call the crew back", code))
				}
			} else {
				kui.lobby_set_status(&b.ui, fmt.tprintf("ROOM CODE  %s  — share it with the crew", code))
			}
		}
	}
	st := gd.webrtc_session_state(node)
	if st == b.web_state_seen || b.world_seen {
		b.web_state_seen = st
		return
	}
	b.web_state_seen = st
	#partial switch st {
	case .Handshaking:
		kui.lobby_set_status(&b.ui, "handshaking…")
	case .Failed:
		r := gd.webrtc_error_reason(node)
		why := "the signaling socket dropped"
		switch r {
		case "no_room":
			why = "no room wears that code"
		case "full":
			why = "that room is full"
		case "":
			why = "connection failed"
		case:
			why = r
		}
		boot_doors_again(b, fmt.tprintf("Web room failed — %s", why))
	}
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
			// (no phase write: code_close below ends the rendezvous, and with
			// no session started that IS .Menu — see boot_phase.)
		}
		netgd.code_close(&b.rdv)
	}
}

// The complete netgraph fill. Co-op games get link, traffic, malformed, policy,
// and rate telemetry; boot_lane adds the simulation lane's lead/gap/ack/rewind,
// replay cost, command pressure, snapshot mix, and AOI pressure automatically.
//
// The traffic string is temp-allocated (netgd.wire_traffic's default), so it
// only lives to the end of the frame — refresh the graph the same frame you
// call this (every caller does).
boot_net_stats :: proc(b: ^Boot) -> kui.Net_Stats {
	rates := netgd.wire_rates(&b.wire)
	ingress := ksess.session_authority_ingress_stats(b.ses)
	ng := kui.Net_Stats {
		rtt_ms     = kui.net_ping_ms(b.ses),
		drops      = ksess.session_malformed(b.ses) + ingress.by_reason[int(knet.Action_Reject_Reason.Malformed)],
		packets_in = rates.packets_in,
		packets_out = rates.packets_out,
		bytes_in   = rates.bytes_in,
		bytes_out  = rates.bytes_out,
		policy_drops = ingress.by_reason[int(knet.Action_Reject_Reason.Access)] + ingress.by_reason[int(knet.Action_Reject_Reason.Predicate)],
		guard_hits = ksess.session_guard_hits(b.ses), // a client wrote a host-lane field (either model) — surface it beside drops
		traffic_dropped = ksess.session_traffic_dropped(b.ses),
		traffic    = netgd.wire_traffic(&b.wire),
	}
	if _, jit, loss, has := netgd.wire_link_quality(&b.wire, ksess.HOST_PEER); has {
		ng.jitter_ms = jit
		ng.loss_pct = loss
	}
	if b.lane != nil {
		lane := ksim.lane_net_stats(b.lane)
		ng.sim = true
		ng.lead = lane.lead
		ng.input_gaps = lane.input_gaps
		ng.ack_age = lane.ack_age
		ng.rewind_depth = lane.rewind_depth
		ng.resims = lane.resim_ticks
		ng.resim_seconds = lane.resim_seconds
		ng.recons = b.lane.stat_reconciles
		ng.command_queue = lane.command_queue
		ng.fact_drops = b.lane.stat_facts_dropped
		ng.snapshot_rows = lane.snapshot_rows
		ng.snapshot_full = lane.snapshot_full
		ng.snapshot_delta = lane.snapshot_delta
		ng.snapshot_suppressed = lane.snapshot_suppressed
		ng.snapshot_deferred = lane.snapshot_deferred
		ng.snapshot_aoi_culled = lane.aoi_culled
		ng.snapshot_bytes = lane.snapshot_bytes
		ng.input_drops = b.lane.stat_input_drops
		ng.input_rejected = b.lane.stat_input_rejected
		ng.ack_rejected = b.lane.stat_ack_rejected
		ng.cmd_capped = b.lane.stat_cmd_capped
		ng.cmd_rate = b.lane.stat_cmd_rate_dropped
		ng.cmd_rejected = b.lane.stat_cmd_rejected
		ng.rewind_clamped = b.lane.stat_rewind_clamped
		ng.echo_dropped = b.lane.stat_echo_dropped
	}
	return ng
}

// Chat's text_submitted, one call (see kui.chat_submit for the trap it fixes).
boot_chat :: proc(b: ^Boot, text: gd.String, sent: ^bool = nil) {
	kui.chat_submit(&b.chat, b.comms, text, sent != nil ? sent : &b.talk_sent)
}

// THE FLOW KEYS, once per frame — the trio every game re-rolled in its
// proven order (and each re-earned a trap of it): the HELD scoreboard
// (refresh-then-show; the kit built the board all along and no game code
// ever showed it), ENTER-to-talk with the anti-re-grab latch (the submitting
// ENTER is still "just pressed" when this check runs — un-latched, every
// send reopened the chat and you could never leave; games shipped 150 ms
// timers for it), and ESC handing the keyboard back from a chat you thought
// better of. Returns whether the keyboard was IN CHAT at frame start — gate
// your own hotkeys (movement, abilities, the menu's other ESC meaning) on
// it: `typing := kboot.boot_keys_frame(&b, "sy_talk", "sy_board", "sy_menu")`.
// "" skips a binding (a game with no scoreboard passes no board action).
boot_keys_frame :: proc(b: ^Boot, talk_action: cstring = "", board_action: cstring = "", esc_action: cstring = "") -> (typing: bool) {
	typing = kui.chat_typing(&b.chat)
	if board_action != "" {
		if gd.is_action_just_pressed(board_action) && !typing {
			kui.score_refresh(&b.score, b.ses)
			kui.score_show(&b.score, true)
		}
		if gd.is_action_just_released(board_action) {
			kui.score_show(&b.score, false)
		}
	}
	if esc_action != "" && typing && gd.is_action_just_pressed(esc_action) {
		gd.control_release_focus(cast(gd.Control)b.chat.input)
	}
	if talk_action != "" {
		if gd.is_action_just_pressed(talk_action) && !typing && !b.talk_sent {
			gd.control_grab_focus(cast(gd.Control)b.chat.input, false)
		}
		b.talk_sent = false // the submit frame's hold expires with the frame
	}
	return
}
