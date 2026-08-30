//gd:extends Node2D
//gd:class Quickdraw
package quickdraw

// ----------------------------------------------------------------------------
// QUICKDRAW — a top-down western duel, and kit/sim's showcase: the game whose
// PREMISE is lag compensation. A quickdraw is unplayable unless your shots
// land where YOUR screen aimed — so the revolver is hitscan judged by
// lane_rewound (the server winds every target back to what the shooter
// rendered), movement is server-simulated from inputs and client-predicted
// (strafe and dash answer the stick at any latency), and hp/score stay on
// the coop kit's delta lane beside it. One game, both netcodes, zero role
// branches in the entity code.
//
// The file map mirrors slopball: net.odin (transport pads + doors),
// world.odin (census hooks + spawns), gunner.odin (the entity + its
// @(gd_tick)), this file (lane wiring, the input sample, the world pass —
// where shots adjudicate). Acid markers print as QD_*.
// ----------------------------------------------------------------------------

import "core:fmt"
import "core:math"
import gd "godot:godot"
import kboot "godot:kit/boot"
import kcomms "godot:kit/comms"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import ksim "godot:kit/sim"
import kui "godot:kit/ui"

MSG_SESSION :: u8(0)
DEFAULT_PORT :: 4189

Respawn :: struct {
	id: knet.Net_Id,
	at: u64, // lane tick
}

Quickdraw :: struct {
	owner:        gd.Node2d,
	ses:          ksess.Session,
	comms:        kcomms.Comms,
	boot:         kboot.Boot,
	lane:         ksim.Lane,
	netgraph:     kui.Netgraph, // the drop-in net-health overlay (rtt + resim spikes)
	running:      bool,
	started:      bool,
	gunner_scene: ^gd.Resource `gd:"entity=Gunner:1"`,
	bullet_scene: ^gd.Resource `gd:"entity=Bullet:2"`,
	drone_scene:  ^gd.Resource `gd:"entity=Drone:3"`,

	// The census is GENERATED (gunner_of / gunner_mine / gunner_owned_by /
	// gunner_ids read the kit's own ledgers) — the only bookkeeping left is
	// the hot my-avatar pointer the sample and bots poke every tick.
	me_gun:       ^Gunner,

	// Host scratch.
	kills_col:    ksess.Stat_Col,
	deaths_col:   ksess.Stat_Col,
	respawns:     [dynamic]Respawn,

	// Env roles + the acid's probes.
	auto_peers:   int,
	bot:          string, // QD_BOT: "" | "orbit" | "strafer" | "deadeye"
	shot_count:   int,
	gear_seen:    u8, // my avatar's last shown gear — the local-flip edge the acid times

	// THE EDGE-ORDERING PROBE (the acid's QD_EDGE receipt). `frame` counts
	// _process calls; the authority stamps it onto a gunner whenever it writes
	// hp from inside a tick, and gunner_hp_edge reads it back to say whether
	// the edge pass saw that write on the frame it happened or a frame later.
	// See gunner_hp_edge for the bug this exists to catch.
	frame:        u64,
	edge_same:    int, // hp edges the authority saw on the writing frame
	edge_late:    int, // hp edges it saw a frame (or more) behind — the bug
	lead_ticks:   int, // client-side frame counter for the once-a-second QD_LEAD trace
}

now_s :: knet.now_s

quickdraw_ready :: proc(self: ^Quickdraw) {
	net_cfg := kboot.network_profile(.Listen_Server_Action)
	// A generous half-second ABSOLUTE ceiling is quickdraw's favor-the-shooter
	// rule; each seat's actual credit is tighter, derived from authority-observed
	// RTT/jitter and lane timing. Large respawn jumps cut instead of gliding.
	// These are validated overrides on top of the named complete-stack profile.
	net_cfg.lane.smooth_cut = 48
	net_cfg.lane.rewind_max = 30
	net_cfg.lane.judge_live = gd.env_int("QD_NOREWIND", 0) != 0

	// The build's wire contract (generated): a version-skewed join is refused
	// at the door (Deny_Reason.Version) instead of misparsing deltas.
	quickdraw_net_attach(
		self,
		kboot.Options {
			title       = "Q U I C K D R A W",
			status      = "Host a duel, or join one at localhost",
			legend      = "WASD move · Mouse aim · Click fire · Space dash · Tab scores · Enter chat",
			msg_kind    = MSG_SESSION,
			env         = "QD", // QD_PORT/_NAME/_TOKEN identity + the QD_LATENCY shim
			min_players = 1,
			methods     = {
				"on_host",
				"on_join",
				"on_start",
				"on_chat",
				"on_packet",
				"on_peer_left",
				"on_net_up",
				"on_net_down",
			},
		},
		net_cfg,
	)

	// The sim lane beside the session is wired by that generated attach from the
	// @(gd_sample)/@(gd_step) attributes (typed procs, input size, and the
	// step's authority gate all come from the declarations). The listen-action
	// profile supplies 60 Hz ticks and 20 Hz snapshots. Its half-second rewind
	// override covers a
	// shooter's view is transit + lead + watch-delay old (~400ms at the
	// acid's 240ms RTT), and a quickdraw favors the shooter by premise.
	// Competitive games tighten this knob. judge_live is the acid's control
	// arm — feel free to feel the difference.

	// The net-health overlay — a kit/ui drop-in, left on. Its resim sparkline
	// is the visible proof of the promise: flat when the wire is calm, spiking
	// exactly when a lost input or a mispredict makes the client rewind.
	self.netgraph = kui.netgraph_make(cast(gd.Node)self.owner)
	kui.netgraph_show(&self.netgraph, true)

	install_controls()
	self.bot = gd.env_string("QD_BOT", "")

	role := gd.env_string("QD_ROLE", "")
	switch role {
	case "host":
		self.auto_peers = gd.env_int("QD_PEERS", 2)
		quickdraw_on_host(self)
	case "join":
		quickdraw_on_join(self)
	case "single":
		self.auto_peers = 1
		quickdraw_on_host(self)
	case "serve":
		self.auto_peers = gd.env_int("QD_PEERS", 2)
		quickdraw_on_serve(self)
	}
	// Scripted matches auto-start when the table fills — checked wherever the
	// count can change: here (single mode seats only me) and on each join's
	// authority consequence (quickdraw_player_joined_then).
	quickdraw_try_start(self)
	gd.print_str("QD_UI_READY")
}

quickdraw_try_start :: proc(self: ^Quickdraw) {
	if self.started || self.auto_peers <= 0 {return}
	if ksess.session_count(&self.ses, connected_only = true, players_only = true) >=
	   self.auto_peers {
		quickdraw_on_start(self) // self-gating: non-hosts and re-calls no-op
	}
}

quickdraw_process :: proc(self: ^Quickdraw, delta: f64) {
	if !self.running {return}
	self.frame += 1 // the edge-ordering probe's clock (gunner_hp_edge)

	// boot_pump drives EVERYTHING now — wire, session, and the sim lane
	// (predict/simulate, then present) — before this returns.
	events, _, _ := kboot.boot_pump(&self.boot, delta, now_s())

	// Boot sees boot_lane and projects the complete link + simulation pipeline:
	// rates, drops, lead/gaps, ack/rewind, replay cost, commands, snapshots, AOI.
	ng := kboot.boot_net_stats(&self.boot)
	kui.netgraph_refresh(&self.netgraph, ng)

	// THE LEAD TRACE (a diagnostic, not a game rule — it prints and asserts
	// nothing). The deep-lead-surplus bug was a CLIENT pacing pathology whose
	// only symptom on the authority is a rewind clamp, so the two halves of the
	// evidence live on opposite ends of the wire: the host tallies clamps on
	// QD_SHOT below, and a client says what its own lead actually settled at.
	// This overlay datum was already computed every frame and shown only to a
	// human watching an on-screen graph — which is exactly why sixty seconds of
	// mispaced lead could ride through an acid without leaving a mark in a log.
	// Once a second: enough to see a cold start bleed, cheap enough to leave in.
	if !ksim.lane_is_authority(&self.lane) {
		self.lead_ticks += 1
		if self.lead_ticks % 60 == 0 {
			gd.print_str(
				fmt.tprintf(
					"QD_LEAD tick=%d lead=%d resims=%d rendersat=%d",
					ksim.lane_now(&self.lane),
					ng.lead,
					self.lane.stat_resims,
					self.lane.stat_render_sat,
				),
			)
		}
	}

	// THE SHOP DOOR — a tick-scheduled verb, issued like any coop command
	// (a key edge, or the bots' own hands): your gear flips at your NEXT
	// TICK, the server's verdict lands a round trip later. The gear edge
	// below is the acid's watch: QD_GEAR_LOCAL fires the moment MY screen
	// wears the boots — ~15 ticks before truth can possibly return at the
	// acid's 240ms RTT.
	if self.me_gun != nil {
		buy :=
			gd.is_action_just_pressed("qd_buy") ||
			(self.bot != "" && self.me_gun.gear == 0 && self.me_gun.gold >= BOOTS_PRICE)
		if buy && knet.command_ok(gunner_buy_cmd(&self.boot, self.me_gun, GEAR_BOOTS)) {
			gd.print_str(fmt.tprintf("QD_BUY_SENT tick=%d", ksim.lane_now(&self.lane)))
		}
		if self.me_gun.gear != self.gear_seen {
			self.gear_seen = self.me_gun.gear
			gd.print_str(
				fmt.tprintf(
					"QD_GEAR_LOCAL gear=%d tick=%d",
					self.me_gun.gear,
					ksim.lane_now(&self.lane),
				),
			)
		}
	}

	// The event reactions are the name-paired halves below; the generated
	// quickdraw_events holds the switch and every role gate.
	quickdraw_events(self, events)
}

// ---- session event halves ---------------------------------------------------

@(gd_half)
quickdraw_welcomed :: proc(self: ^Quickdraw, me: knet.Player_Id) {
	gd.print_str(fmt.tprintf("QD_SEATED me=%d", u64(me)))
}

// The join's authority consequence: word the arrival, field a late joiner,
// and start the scripted match when the table fills — the whole block the
// shell used to wrap in is_host, now gate-free (the dispatch holds it).
@(gd_half)
quickdraw_player_joined_then :: proc(self: ^Quickdraw, id: knet.Player_Id, rejoin: bool) {
	if p, ok := ksess.session_player(&self.ses, id); ok {
		kcomms.comms_welcome(
			&self.comms,
			id,
			rejoin,
			fmt.tprintf("%s steps into the dust", p.name),
		)
	}
	if self.started && !rejoin {
		spawn_gunner(self, id)
	}
	quickdraw_try_start(self)
}

@(gd_half)
quickdraw_host_left :: proc(self: ^Quickdraw) {
	kui.lobby_set_status(&self.boot.ui, "The marshal left — duel's off")
	gd.print_str("QD_HOST_LEFT")
}

@(gd_half)
quickdraw_entity_spawned :: proc(
	self: ^Quickdraw,
	id: knet.Net_Id,
	type: ksess.Entity_Type,
	owner: knet.Player_Id,
) {
	_ = owner
	// BORN = the fields are set: the node's FIRST placement, here — not in the
	// entity's _process (Godot runs no _process on a node added mid-_process:
	// every host-step spawn, every arrival under delay — the spawn frame
	// would render at the origin). The per-frame _process carries it on.
	// A rekeyed PREDICTED bullet reads its presented pose here: lane_present
	// ran inside boot_pump, before this dispatch. (docs/kit/boot.md.)
	if node, has := kboot.boot_node(&self.boot, id); has {
		switch type {
		case GUNNER_TYPE:
			if e, ok := gunner_of(&self.boot, id);
			   ok {gd.node2d_set_position(cast(gd.Node2d)node, {e.x, e.y})}
		case DRONE_TYPE:
			if e, ok := drone_of(&self.boot, id);
			   ok {gd.node2d_set_position(cast(gd.Node2d)node, {e.x, e.y})}
		case BULLET_TYPE:
			if e, ok := bullet_of(&self.boot, id);
			   ok {gd.node2d_set_position(cast(gd.Node2d)node, {e.x, e.y})}
		}
	}
	if !self.started {
		self.started = true
		gd.set_bool(cast(gd.Object)self.boot.ui.root, "visible", false)
		gd.set_bool(cast(gd.Object)self.boot.legend, "visible", true)
		gd.print_str("QD_STARTED")
	}
}

@(gd_half)
quickdraw_join_denied :: proc(self: ^Quickdraw, reason: ksess.Deny_Reason) {
	gd.print_str(fmt.tprintf("QD_DENIED reason=%v", reason))
}

@(gd_half)
quickdraw_join_failed :: proc(self: ^Quickdraw) {
	gd.print_str("QD_JOIN_FAILED")
}

// ---- the input sample: the ONE place that touches hardware -------------------

install_controls :: proc "contextless" () {
	if gd.has_action("qd_left") {return}
	bind :: proc "contextless" (action: cstring, keys: ..i64) {
		gd.add_action(action)
		for k in keys {
			gd.action_add_key(action, k)
		}
	}
	bind("qd_left", i64('A'), i64(gd.Key.Left))
	bind("qd_right", i64('D'), i64(gd.Key.Right))
	bind("qd_up", i64('W'), i64(gd.Key.Up))
	bind("qd_down", i64('S'), i64(gd.Key.Down))
	bind("qd_dash", i64(gd.Key.Space))
	bind("qd_buy", i64('B'))
	// The DRONE's own steer keys — a SECOND input class, distinct from WASD, so
	// a player flies the companion while their gunner strafes on the same tick.
	bind("qd_drone_left", i64('J'))
	bind("qd_drone_right", i64('L'))
	bind("qd_drone_up", i64('I'))
	bind("qd_drone_down", i64('K'))
	gd.add_action("qd_fire")
	gd.action_add_mouse_button("qd_fire", i64(gd.Mouse_Button.Left))
	gd.add_action("qd_lob")
	gd.action_add_mouse_button("qd_lob", i64(gd.Mouse_Button.Right))
}

@(gd_sample)
qd_sample :: proc(self: ^Quickdraw, tick: u64, input: ^Gunner_Input) {
	input^ = {}
	if self.bot != "" {
		bot_sample(self, tick, input)
		return
	}
	typing := bool(gd.control_has_focus(cast(gd.Control)self.boot.chat.input, false))
	if !typing {
		if gd.is_action_pressed("qd_left") {input.move[0] -= 1}
		if gd.is_action_pressed("qd_right") {input.move[0] += 1}
		if gd.is_action_pressed("qd_up") {input.move[1] -= 1}
		if gd.is_action_pressed("qd_down") {input.move[1] += 1}
		if gd.is_action_pressed("qd_dash") {input.buttons |= BTN_DASH}
		if gd.is_action_pressed("qd_fire") {input.buttons |= BTN_FIRE}
		if gd.is_action_pressed("qd_lob") {input.buttons |= BTN_LOB}
	}
	if self.me_gun != nil {
		m := gd.canvas_item_get_global_mouse_position(cast(gd.Canvas_Item)self.owner)
		input.aim = angle_to_wire(math.atan2(f32(m.y) - self.me_gun.y, f32(m.x) - self.me_gun.x))
	}
}

// The SECOND @(gd_sample) — one per input CLASS. It fills the drone's steer,
// the class scriptgen routes to Drone_Input; the gunner's mouse-and-WASD sample
// above fills Gunner_Input. Two device reads, two windows, one packet.
@(gd_sample)
drone_sample :: proc(self: ^Quickdraw, tick: u64, input: ^Drone_Input) {
	input^ = {}
	if self.bot != "" {
		// A deterministic HORIZONTAL sweep. It is ORTHOGONAL to the strafer's
		// VERTICAL gunner patrol on purpose: the drone's motion is then a
		// fingerprint of its OWN input class — a pure left-right drift with a
		// steady y — that the avatar's stick could not have produced. If the
		// two classes crossed, the drone would track the gunner instead.
		input.steer[0] = (tick / 96) % 2 == 0 ? 1 : -1
		return
	}
	typing := bool(gd.control_has_focus(cast(gd.Control)self.boot.chat.input, false))
	if !typing {
		if gd.is_action_pressed("qd_drone_left") {input.steer[0] -= 1}
		if gd.is_action_pressed("qd_drone_right") {input.steer[0] += 1}
		if gd.is_action_pressed("qd_drone_up") {input.steer[1] -= 1}
		if gd.is_action_pressed("qd_drone_down") {input.steer[1] += 1}
	}
}

// The acid's hands — deterministic intent through the production sample path:
//
//   orbit    circles and takes potshots (the solo gate's all-rounder)
//   strafer  patrols left-right at full speed, never fires — the moving target
//   deadeye  stands still and fires at the nearest gunner AS RENDERED — under
//            latency its aim is honest-but-old, which is exactly the shot lag
//            compensation exists to honor
bot_sample :: proc(g: ^Quickdraw, tick: u64, input: ^Gunner_Input) {
	switch g.bot {
	case "strafer":
		// VERTICAL patrol: perpendicular to the duel's line of fire, which is
		// the whole point — lag error on a crossing target is LATERAL, and
		// lateral error is what makes a hitscan miss. (A target strafing
		// along its own ray can't miss no matter how stale the aim — the
		// first version of the acid learned that the hard way.)
		input.move[1] = (tick / 72) % 2 == 0 ? 1 : -1
		return
	case "deadeye":
		if tick % 90 == 0 {
			input.buttons |= BTN_FIRE
		}
		// ...and lobs the slow projectile on its own cadence — the predicted
		// spawn leaves its muzzle this instant, the authority's rekeys it later.
		if tick % 54 == 0 {
			input.buttons |= BTN_LOB
		}
	case "lobber":
		// Stands its ground and lobs the slow projectile at the nearest gunner
		// on its own cadence — the predicted-spawn acid's shooter.
		if tick % 54 == 0 {
			input.buttons |= BTN_LOB
		}
	case:
		a := f32(tick) * 0.021
		input.move[0] = math.cos(a) > 0.3 ? 1 : (math.cos(a) < -0.3 ? -1 : 0)
		input.move[1] = math.sin(a) > 0.3 ? 1 : (math.sin(a) < -0.3 ? -1 : 0)
		if tick % 75 == 0 {
			input.buttons |= BTN_FIRE
		}
	}
	aim := f32(0)
	if g.me_gun != nil {
		best := f32(1e9)
		for tracked in gunner_all(&g.boot) {
			gun := tracked.entity
			if gun == g.me_gun || gun.hp <= 0 {continue}
			dx := gun.x - g.me_gun.x // presentation truth: where MY SCREEN shows them
			dy := gun.y - g.me_gun.y
			d := dx * dx + dy * dy
			if d < best {
				best = d
				aim = math.atan2(dy, dx)
			}
		}
	}
	input.aim = angle_to_wire(aim)
}

// ---- the shot, as two name-paired halves ---------------------------------------
//
// gunner_tick returns `fired` — a fact — and the generated thunk routes it,
// holding every role gate the old world pass hand-wrote: the consequence on
// the authority, the fx on EVERY screen at its own presentation time (the
// mine-form — never a resim, never a double fire, watchers on the watch
// clock). What's left is single-player-looking on both sides.

// AUTHORITY: the shot's consequences. The hitscan shot judges where the
// shooter's screen aimed (delta-lane damage); the LOB spawns the AUTHORITATIVE
// bullet — a real net id, announced to every peer — at the same tick the client
// already predicted its own.
@(gd_half)
gunner_tick_then :: proc(
	g: ^Quickdraw,
	self: ^Gunner,
	by: knet.Player_Id,
	fired: bool,
	lobbed: bool,
) {
	if fired {
		adjudicate_shot(g, self.net_id, self, by, self.aim, ksim.lane_now(&g.lane))
	}
	if lobbed {
		lob_bullet(g, self, by)
		gd.print_str(fmt.tprintf("QD_LOB_HOST by=%d tick=%d", u64(by), ksim.lane_now(&g.lane)))
	}
}

// EVERY SCREEN (the mine-form): the tracer draws where each screen presents
// the shot — the shooter's at the muzzle instant (mine, the live pass), the
// authority's live, and watchers when their watch clock reaches the shot's
// tick, ON the delayed barrel that fired it (the fact tuple rides a reliable
// SIM_FACT; the lane holds the timing). This deletes the shot_seq/shot_aim
// replicated scratch and the hand-rolled seen_shot edge the tracer used to
// need. The LOB's predicted spawn stays mine-gated: speculation is a CLIENT
// move (the authority's real bullet comes from the _then above — a hosting
// player's fire is already authoritative, and speculating it too would
// double the bullet).
@(gd_half)
gunner_tick_fx :: proc(g: ^Quickdraw, self: ^Gunner, mine: bool, fired: bool, lobbed: bool) {
	if fired {
		gunner_beam(self, self.aim)
		if mine {
			gd.print_str("QD_FIRE")
		} else {
			gd.print_str(fmt.tprintf("QD_TRACER pid=%d", self.pid))
		}
	}
	if lobbed && mine && !ksim.lane_is_authority(&g.lane) {
		lob_bullet(g, self, g.ses.me)
		gd.print_str(fmt.tprintf("QD_LOB_LOCAL tick=%d", ksim.lane_now(&g.lane)))
	}
}

// Spawn the lob's bullet at the muzzle, aimed. One call, no role branch, no
// cast: the generated bullet_spawn routes it — the authority (the _then half)
// gets a real net id it announces; this client (the _fx half) gets a local
// predicted node, flying now, that the authority's spawn will rekey. Set the
// flight, then send.
lob_bullet :: proc(g: ^Quickdraw, gun: ^Gunner, owner: knet.Player_Id) {
	b, bid := bullet_spawn(&g.boot, owner)
	if b == nil {return}
	dx, dy := math.cos(gun.aim), math.sin(gun.aim)
	b.x = gun.x + dx * (GUN_R + 4)
	b.y = gun.y + dy * (GUN_R + 4)
	b.vx = dx * LOB_SPEED
	b.vy = dy * LOB_SPEED
	b.life = LOB_LIFE
	b.pid = u8(owner)
	kboot.boot_spawn_send(&g.boot, bid)
	// The node's FIRST placement, at the fire site: a client's PREDICTED
	// bullet has no Ev_Spawned until the authority's spawn rekeys it, and its
	// own _process runs only NEXT frame (added mid-_process) — without this
	// line it renders one frame at the origin. On the host it is the pose
	// the born dress just set (quickdraw_entity_spawned, inside the send).
	gd.node2d_set_position(cast(gd.Node2d)b.owner, {b.x, b.y})
}

// The buy's consequence — AUTHORITY only, at the verb's execution tick: the
// receipt every screen can trust (the acid greps it on the marshal).
@(gd_half)
gunner_buy_then :: proc(g: ^Quickdraw, self: ^Gunner, by: knet.Player_Id, item: u8) {
	gd.print_str(
		fmt.tprintf("QD_BUY by=%d item=%d tick=%d", u64(by), item, ksim.lane_now(&g.lane)),
	)
}

// The world pass keeps only genuinely WORLD-shaped authority work: respawns
// and the acid's convergence probe. `authority` holds the role gate the
// game used to open with — the lane runs this on the host alone.
@(gd_step = "authority")
qd_step :: proc(self: ^Quickdraw, tick: u64) {
	run_respawns(self, tick)
	if tick % 60 == 0 {
		for tracked in gunner_all(&self.boot) {
			gun := tracked.entity
			gd.print_str(
				fmt.tprintf(
					"QD_POS tick=%d id=%d x=%.1f y=%.1f hp=%d gear=%d gold=%d",
					tick,
					u32(tracked.id),
					gun.x,
					gun.y,
					gun.hp,
					gun.gear,
					gun.gold,
				),
			)
		}
		// The drones' authoritative track — the SECOND input class landing
		// server-side. Each swept its own steer (horizontal, steady y), never
		// its owner's gunner input.
		for tracked in drone_all(&self.boot) {
			d := tracked.entity
			gd.print_str(
				fmt.tprintf(
					"QD_DRONE tick=%d id=%d pid=%d x=%.1f y=%.1f",
					tick,
					u32(tracked.id),
					d.pid,
					d.x,
					d.y,
				),
			)
		}
	}
}

adjudicate_shot :: proc(
	g: ^Quickdraw,
	shooter_id: knet.Net_Id,
	gun: ^Gunner,
	pid: knet.Player_Id,
	a: f32,
	tick: u64,
) {
	sx, sy := gun.x, gun.y // the shooter's own pose stays live either way
	dx, dy := math.cos(a), math.sin(a)
	best := shot_wall_limit(sx, sy, a)
	victim := knet.Net_Id(0)

	// Between begin and end every OTHER gunner stands where the SHOOTER's
	// screen showed them — the hit test is written right here, no context
	// struct across a rawptr. judge_live (the QD_NOREWIND acid knob) lives
	// in Lane_Config — one call, no fork, on or off.
	judged := ksim.lane_rewound_begin(&g.lane, pid)
	for tracked in gunner_all(&g.boot) {
		target := tracked.entity
		if tracked.id == shooter_id || target.hp <= 0 {continue}
		t := ray_body(sx, sy, dx, dy, target.x, target.y, best)
		if t < best {
			best = t
			victim = tracked.id
		}
	}
	ksim.lane_rewound_end(&g.lane)

	// The VERDICT reaches every screen as state (hp, the delta lane); the
	// tracer already rode the tick's `fired` fact (the mine-form fx above).
	g.shot_count += 1
	// `depth` is how far back this shot was actually judged; `clamped` is the
	// lane's running count of queries pinned by its authority-observed link,
	// render-hint, or absolute rewind ceiling. A shot at the envelope floor whose
	// count just moved is lag comp losing claimed history — the exact signature
	// the old deep-lead bug produced (rewound=0 on every shot, nothing logged).
	gd.print_str(
		fmt.tprintf(
			"QD_SHOT by=%d tick=%d judged=%d depth=%d clamped=%d",
			u64(pid),
			tick,
			judged,
			tick - judged,
			g.lane.stat_rewind_clamped,
		),
	)

	if victim == 0 {return}
	hit, _ := gunner_of(&g.boot, victim)
	vpid := kboot.boot_entity_owner(&g.boot, victim)
	hit.hp -= 1
	hit.hp_frame = g.frame // the edge-ordering probe: WHEN the authority wrote it
	gd.print_str(fmt.tprintf("QD_HIT by=%d on=%d hp=%d", u64(pid), u64(vpid), hit.hp))
	if hit.hp <= 0 {
		ksess.session_stat_add(&g.ses, pid, g.kills_col, 1)
		ksess.session_stat_add(&g.ses, vpid, g.deaths_col, 1)
		gun.gold += 1 // the bounty — the shop's purse fills authority-side
		append(&g.respawns, Respawn{id = victim, at = tick + RESPAWN_TICKS})
		gd.print_str(fmt.tprintf("QD_KILL by=%d on=%d", u64(pid), u64(vpid)))
	}
}

// Host: put the fallen back on their feet — an authority write straight onto
// predicted fields (outside any tick proc: the server IS the truth). Clients
// learn it from the next batch; the jump clears smooth_cut, so it SNAPS.
run_respawns :: proc(g: ^Quickdraw, tick: u64) {
	for i := 0; i < len(g.respawns); {
		if g.respawns[i].at > tick {
			i += 1
			continue
		}
		id := g.respawns[i].id
		ordered_remove(&g.respawns, i)
		gun, ok := gunner_of(&g.boot, id)
		if !ok {continue}
		spot := SPAWNS[int(gun.pid) % len(SPAWNS)]
		gun.x = spot[0]
		gun.y = spot[1]
		gun.vx = 0
		gun.vy = 0
		gun.hp = MAX_HP
		gun.hp_frame = g.frame // same stamp, from the AUTHORITY world pass
		gd.print_str(fmt.tprintf("QD_RESPAWN pid=%d", gun.pid))
	}
}
