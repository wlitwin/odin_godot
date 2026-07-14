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
	owner:   gd.Node2d,
	ses:     ksess.Session,
	comms:   kcomms.Comms,
	boot:    kboot.Boot,
	lane:    ksim.Lane,
	running: bool,
	started: bool,

	gunner_scene: ^gd.Resource `gd:"export,resource=PackedScene,entity=Gunner:1"`,

	gunners:   map[knet.Net_Id]^Gunner,
	avatar_of: map[knet.Player_Id]knet.Net_Id,
	owner_pid: map[knet.Net_Id]knet.Player_Id,
	me_gun:    ^Gunner,

	// Host scratch.
	kills_col:  ksess.Stat_Col,
	deaths_col: ksess.Stat_Col,
	respawns:   [dynamic]Respawn,

	// Env roles + the acid's probes.
	auto_peers: int,
	bot:        string, // QD_BOT: "" | "orbit" | "strafer" | "deadeye"
	shot_count: int,
}

now_s :: knet.now_s

quickdraw_ready :: proc(self: ^Quickdraw) {
	kboot.boot_attach(&self.boot, cast(gd.Node)self.owner, &self.ses, &self.comms, kboot.Options{
		title = "Q U I C K D R A W",
		status = "Host a duel, or join one at localhost",
		legend = "WASD move · Mouse aim · Click fire · Space dash · Tab scores · Enter chat",
		msg_kind = MSG_SESSION,
		latency_env = "QD_LATENCY",
		min_players = 1,
		methods = {"on_host", "on_join", "on_start", "on_chat", "on_packet", "on_peer_left", "on_net_up", "on_net_down"},
	})
	kboot.boot_entities(&self.boot, self, quickdraw_entity_kinds[:])

	// The sim lane beside the session: 60 Hz ticks, snapshots every 3 (20 Hz),
	// respawn teleports big enough to CUT instead of glide, and a GENEROUS
	// half-second rewind ceiling — a shooter's view is transit + lead +
	// watch-delay old (~400ms at the acid's 240ms RTT), and a quickdraw
	// favors the shooter by premise. Competitive games tighten this knob.
	// judge_live is the acid's control arm — feel free to feel the difference.
	ksim.lane_init(&self.lane, &self.ses, size_of(Gunner_Input), cfg = ksim.Lane_Config{
		smooth_cut = 48,
		rewind_max = 30,
		judge_live = gd.env_int("QD_NOREWIND", 0) != 0,
	})
	ksim.lane_set_sim(&self.lane, self, qd_sample, qd_step)
	kboot.boot_lane(&self.boot, &self.lane) // the boot drives the lane from here on

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
	gd.print_str("QD_UI_READY")
}

quickdraw_process :: proc(self: ^Quickdraw, delta: f64) {
	if !self.running {return}

	// boot_pump drives EVERYTHING now — wire, session, and the sim lane
	// (predict/simulate, then present) — before this returns.
	events, _, _ := kboot.boot_pump(&self.boot, delta, now_s())

	if !self.started && self.ses.is_host && self.auto_peers > 0 &&
	   ksess.session_count(&self.ses, connected_only = true, players_only = true) >= self.auto_peers {
		quickdraw_on_start(self)
	}

	for ev in events {
		#partial switch e in ev {
		case ksess.Ev_Welcomed:
			gd.print_str(fmt.tprintf("QD_SEATED me=%d", u64(e.me)))
		case ksess.Ev_Player_Joined:
			if self.ses.is_host {
				if p, ok := ksess.session_player(&self.ses, e.id); ok {
					kcomms.comms_welcome(&self.comms, e.id, e.rejoin, fmt.tprintf("%s steps into the dust", p.name))
				}
				if self.started && !e.rejoin {
					spawn_gunner(self, e.id)
				}
			}
		case ksess.Ev_Host_Left:
			kui.lobby_set_status(&self.boot.ui, "The marshal left — duel's off")
			gd.print_str("QD_HOST_LEFT")
		case ksess.Ev_Spawned:
			if !self.started {
				self.started = true
				gd.set_bool(cast(gd.Object)self.boot.ui.root, "visible", false)
				gd.set_bool(cast(gd.Object)self.boot.legend, "visible", true)
				gd.print_str("QD_STARTED")
			}
		case ksess.Ev_Join_Denied:
			gd.print_str(fmt.tprintf("QD_DENIED reason=%v", e.reason))
		case ksess.Ev_Join_Failed:
			gd.print_str("QD_JOIN_FAILED")
		}
	}
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
	gd.add_action("qd_fire")
	gd.action_add_mouse_button("qd_fire", i64(gd.Mouse_Button.Left))
}

qd_sample :: proc(user: rawptr, tick: u64, dst: rawptr) {
	g := cast(^Quickdraw)user
	input := cast(^Gunner_Input)dst
	input^ = {}
	if g.bot != "" {
		bot_sample(g, tick, input)
		return
	}
	typing := bool(gd.control_has_focus(cast(gd.Control)g.boot.chat.input, false))
	if !typing {
		if gd.is_action_pressed("qd_left") {input.move[0] -= 1}
		if gd.is_action_pressed("qd_right") {input.move[0] += 1}
		if gd.is_action_pressed("qd_up") {input.move[1] -= 1}
		if gd.is_action_pressed("qd_down") {input.move[1] += 1}
		if gd.is_action_pressed("qd_dash") {input.buttons |= BTN_DASH}
		if gd.is_action_pressed("qd_fire") {input.buttons |= BTN_FIRE}
	}
	if g.me_gun != nil {
		m := gd.canvas_item_get_global_mouse_position(cast(gd.Canvas_Item)g.owner)
		input.aim = angle_to_wire(math.atan2(f32(m.y) - g.me_gun.y, f32(m.x) - g.me_gun.x))
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
		for _, gun in g.gunners {
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
// the authority, the fx on this player's live pass, never a resim, never a
// double fire. What's left is single-player-looking on both sides.

// AUTHORITY: the shot's consequence — judge it where the shooter's screen
// aimed, land the damage as delta-lane state.
gunner_tick_then :: proc(g: ^Quickdraw, self: ^Gunner, by: knet.Player_Id, fired: bool) {
	if !fired {return}
	adjudicate_shot(g, self.net_id, self, by, self.aim, ksim.lane_now(&g.lane))
}

// THIS PLAYER, live pass only: the muzzle answers the click NOW.
gunner_tick_fx :: proc(g: ^Quickdraw, self: ^Gunner, fired: bool) {
	if fired {
		gunner_beam(self, self.aim)
		gd.print_str("QD_FIRE")
	}
}

// The world pass keeps only genuinely WORLD-shaped authority work: respawns
// and the acid's convergence probe.
qd_step :: proc(user: rawptr, tick: u64) {
	g := cast(^Quickdraw)user
	if !g.ses.is_host {return}

	run_respawns(g, tick)
	if tick % 60 == 0 {
		for pid, gun in g.gunners {
			gd.print_str(fmt.tprintf("QD_POS tick=%d id=%d x=%.1f y=%.1f hp=%d", tick, u32(pid), gun.x, gun.y, gun.hp))
		}
	}
}

// The lag-comp probe's world view (package-scope: no closures on the wire path).
Shot_Ctx :: struct {
	g:       ^Quickdraw,
	shooter: knet.Net_Id,
	sx, sy:  f32,
	dx, dy:  f32,
	best:    f32,
	victim:  knet.Net_Id,
}

shot_probe :: proc(user: rawptr) {
	c := cast(^Shot_Ctx)user
	// Inside lane_rewound every OTHER gunner stands where the SHOOTER saw it.
	for id, gun in c.g.gunners {
		if id == c.shooter || gun.hp <= 0 {continue}
		t := ray_body(c.sx, c.sy, c.dx, c.dy, gun.x, gun.y, c.best)
		if t < c.best {
			c.best = t
			c.victim = id
		}
	}
}

adjudicate_shot :: proc(g: ^Quickdraw, shooter_id: knet.Net_Id, gun: ^Gunner, pid: knet.Player_Id, a: f32, tick: u64) {
	ctx := Shot_Ctx{
		g       = g,
		shooter = shooter_id,
		sx      = gun.x,
		sy      = gun.y,
		dx      = math.cos(a),
		dy      = math.sin(a),
		best    = shot_wall_limit(gun.x, gun.y, a),
	}
	// judge_live (the QD_NOREWIND acid knob) lives in Lane_Config now — one
	// call, no fork, on or off.
	judged := ksim.lane_rewound(&g.lane, pid, &ctx, shot_probe)

	// The tracer + the verdict reach every screen as STATE (the delta lane).
	gun.shot_seq += 1
	gun.shot_aim = a
	g.shot_count += 1
	gd.print_str(fmt.tprintf("QD_SHOT by=%d tick=%d judged=%d", u64(pid), tick, judged))

	if ctx.victim == 0 {return}
	victim := g.gunners[ctx.victim]
	victim.hp -= 1
	gd.print_str(fmt.tprintf("QD_HIT by=%d on=%d hp=%d", u64(pid), u64(g.owner_pid[ctx.victim]), victim.hp))
	if victim.hp <= 0 {
		ksess.session_stat_add(&g.ses, pid, g.kills_col, 1)
		ksess.session_stat_add(&g.ses, g.owner_pid[ctx.victim], g.deaths_col, 1)
		append(&g.respawns, Respawn{id = ctx.victim, at = tick + RESPAWN_TICKS})
		gd.print_str(fmt.tprintf("QD_KILL by=%d on=%d", u64(pid), u64(g.owner_pid[ctx.victim])))
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
		gun, ok := g.gunners[id]
		if !ok {continue}
		spot := SPAWNS[int(gun.pid) % len(SPAWNS)]
		gun.x = spot[0]
		gun.y = spot[1]
		gun.vx = 0
		gun.vy = 0
		gun.hp = MAX_HP
		gd.print_str(fmt.tprintf("QD_RESPAWN pid=%d", gun.pid))
	}
}
