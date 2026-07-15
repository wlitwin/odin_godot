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
	bullet_scene: ^gd.Resource `gd:"export,resource=PackedScene,entity=Bullet:2"`,

	// The census is GENERATED (gunner_of / my_gunner / gunner_owned_by /
	// gunner_ids read the kit's own ledgers) — the only bookkeeping left is
	// the hot my-avatar pointer the sample and bots poke every tick.
	me_gun: ^Gunner,

	// Host scratch.
	kills_col:  ksess.Stat_Col,
	deaths_col: ksess.Stat_Col,
	respawns:   [dynamic]Respawn,

	// Env roles + the acid's probes.
	auto_peers: int,
	bot:        string, // QD_BOT: "" | "orbit" | "strafer" | "deadeye"
	shot_count: int,
	gear_seen:  u8, // my avatar's last shown gear — the local-flip edge the acid times
}

now_s :: knet.now_s

quickdraw_ready :: proc(self: ^Quickdraw) {
	kboot.boot_attach(&self.boot, cast(gd.Node)self.owner, &self.ses, &self.comms, kboot.Options{
		title = "Q U I C K D R A W",
		status = "Host a duel, or join one at localhost",
		legend = "WASD move · Mouse aim · Click fire · Space dash · Tab scores · Enter chat",
		msg_kind = MSG_SESSION,
		env = "QD", // QD_PORT/_NAME/_TOKEN identity + the QD_LATENCY shim
		min_players = 1,
		methods = {"on_host", "on_join", "on_start", "on_chat", "on_packet", "on_peer_left", "on_net_up", "on_net_down"},
	})
	kboot.boot_entities(&self.boot, self, quickdraw_entity_kinds[:])

	// The sim lane beside the session — the wiring is GENERATED from the
	// @(gd_sample)/@(gd_step) attributes (typed procs, input size, and the
	// step's authority gate all come from the declarations). Config: 60 Hz
	// ticks, snapshots every 3 (20 Hz), respawn teleports big enough to CUT
	// instead of glide, and a GENEROUS half-second rewind ceiling — a
	// shooter's view is transit + lead + watch-delay old (~400ms at the
	// acid's 240ms RTT), and a quickdraw favors the shooter by premise.
	// Competitive games tighten this knob. judge_live is the acid's control
	// arm — feel free to feel the difference.
	quickdraw_lane_init(self, &self.lane, &self.ses, cfg = ksim.Lane_Config{
		smooth_cut = 48,
		rewind_max = 30,
		judge_live = gd.env_int("QD_NOREWIND", 0) != 0,
	})
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

	// THE SHOP DOOR — a tick-scheduled verb, issued like any coop command
	// (a key edge, or the bots' own hands): your gear flips at your NEXT
	// TICK, the server's verdict lands a round trip later. The gear edge
	// below is the acid's watch: QD_GEAR_LOCAL fires the moment MY screen
	// wears the boots — ~15 ticks before truth can possibly return at the
	// acid's 240ms RTT.
	if self.me_gun != nil {
		buy := gd.is_action_just_pressed("qd_buy") ||
			(self.bot != "" && self.me_gun.gear == 0 && self.me_gun.gold >= BOOTS_PRICE)
		if buy && gunner_buy_cmd(&self.lane, self.me_gun, GEAR_BOOTS) {
			gd.print_str(fmt.tprintf("QD_BUY_SENT tick=%d", ksim.lane_now(&self.lane)))
		}
		if self.me_gun.gear != self.gear_seen {
			self.gear_seen = self.me_gun.gear
			gd.print_str(fmt.tprintf("QD_GEAR_LOCAL gear=%d tick=%d", self.me_gun.gear, ksim.lane_now(&self.lane)))
		}
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
	bind("qd_buy", i64('B'))
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
		for id in gunner_ids(&g.boot) {
			gun, _ := gunner_of(&g.boot, id)
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

// AUTHORITY: the shot's consequences. The hitscan shot judges where the
// shooter's screen aimed (delta-lane damage); the LOB spawns the AUTHORITATIVE
// bullet — a real net id, announced to every peer — at the same tick the client
// already predicted its own.
gunner_tick_then :: proc(g: ^Quickdraw, self: ^Gunner, by: knet.Player_Id, fired: bool, lobbed: bool) {
	if fired {
		adjudicate_shot(g, self.net_id, self, by, self.aim, ksim.lane_now(&g.lane))
	}
	if lobbed {
		lob_bullet(g, self, by)
		gd.print_str(fmt.tprintf("QD_LOB_HOST by=%d tick=%d", u64(by), ksim.lane_now(&g.lane)))
	}
}

// THIS PLAYER, live pass only: the muzzle answers the click NOW, and the lob's
// bullet leaves the barrel THIS instant — a predicted spawn, before the
// authority's real one is even in flight on the wire.
gunner_tick_fx :: proc(g: ^Quickdraw, self: ^Gunner, fired: bool, lobbed: bool) {
	if fired {
		gunner_beam(self, self.aim)
		gd.print_str("QD_FIRE")
	}
	if lobbed {
		lob_bullet(g, self, g.ses.me)
		gd.print_str(fmt.tprintf("QD_LOB_LOCAL tick=%d", ksim.lane_now(&g.lane)))
	}
}

// Spawn the lob's bullet at the muzzle, aimed. One call, no role branch:
// boot_fire_spawn routes it — the authority (the _then half) gets a real net id
// it announces; this client (the _fx half) gets a local predicted node, flying
// now, that the authority's spawn will rekey. Set the flight, then send.
lob_bullet :: proc(g: ^Quickdraw, gun: ^Gunner, owner: knet.Player_Id) {
	bp, bid := kboot.boot_fire_spawn(&g.boot, BULLET_TYPE, owner)
	if bp == nil {return}
	b := cast(^Bullet)bp
	dx, dy := math.cos(gun.aim), math.sin(gun.aim)
	b.x = gun.x + dx * (GUN_R + 4)
	b.y = gun.y + dy * (GUN_R + 4)
	b.vx = dx * LOB_SPEED
	b.vy = dy * LOB_SPEED
	b.life = LOB_LIFE
	b.pid = u8(owner)
	kboot.boot_fire_spawn_send(&g.boot, bid)
}

// The buy's consequence — AUTHORITY only, at the verb's execution tick: the
// receipt every screen can trust (the acid greps it on the marshal).
gunner_buy_then :: proc(g: ^Quickdraw, self: ^Gunner, by: knet.Player_Id, item: u8) {
	gd.print_str(fmt.tprintf("QD_BUY by=%d item=%d tick=%d", u64(by), item, ksim.lane_now(&g.lane)))
}

// The world pass keeps only genuinely WORLD-shaped authority work: respawns
// and the acid's convergence probe. `authority` holds the role gate the
// game used to open with — the lane runs this on the host alone.
@(gd_step = "authority")
qd_step :: proc(self: ^Quickdraw, tick: u64) {
	run_respawns(self, tick)
	if tick % 60 == 0 {
		for id in gunner_ids(&self.boot) {
			gun, _ := gunner_of(&self.boot, id)
			gd.print_str(fmt.tprintf("QD_POS tick=%d id=%d x=%.1f y=%.1f hp=%d gear=%d gold=%d", tick, u32(id), gun.x, gun.y, gun.hp, gun.gear, gun.gold))
		}
	}
}

adjudicate_shot :: proc(g: ^Quickdraw, shooter_id: knet.Net_Id, gun: ^Gunner, pid: knet.Player_Id, a: f32, tick: u64) {
	sx, sy := gun.x, gun.y // the shooter's own pose stays live either way
	dx, dy := math.cos(a), math.sin(a)
	best := shot_wall_limit(sx, sy, a)
	victim := knet.Net_Id(0)

	// Between begin and end every OTHER gunner stands where the SHOOTER's
	// screen showed them — the hit test is written right here, no context
	// struct across a rawptr. judge_live (the QD_NOREWIND acid knob) lives
	// in Lane_Config — one call, no fork, on or off.
	judged := ksim.lane_rewound_begin(&g.lane, pid)
	for id in gunner_ids(&g.boot) {
		target, _ := gunner_of(&g.boot, id)
		if id == shooter_id || target.hp <= 0 {continue}
		t := ray_body(sx, sy, dx, dy, target.x, target.y, best)
		if t < best {
			best = t
			victim = id
		}
	}
	ksim.lane_rewound_end(&g.lane)

	// The tracer + the verdict reach every screen as STATE (the delta lane).
	gun.shot_seq += 1
	gun.shot_aim = a
	g.shot_count += 1
	gd.print_str(fmt.tprintf("QD_SHOT by=%d tick=%d judged=%d", u64(pid), tick, judged))

	if victim == 0 {return}
	hit, _ := gunner_of(&g.boot, victim)
	vpid := kboot.boot_entity_owner(&g.boot, victim)
	hit.hp -= 1
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
		gd.print_str(fmt.tprintf("QD_RESPAWN pid=%d", gun.pid))
	}
}
