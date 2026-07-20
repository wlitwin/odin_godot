//gd:extends Node3D
//gd:class Slopball3
package slopball3d

// ----------------------------------------------------------------------------
// SLOPBALL3D — co-op physics soccer in THREE dimensions: the kit's 3D exercise.
//
// The 2D slopball proved engine-physics replication (play.Puppet); this example
// proves the same contract with the third axis turned on: a RigidBody3D ball
// under REAL GRAVITY, kicked with loft, tumbling — its orientation a replicated
// quaternion the stream layer nlerps hemisphere-safely — and CharacterBody3D
// kickers streaming their pose as one [3]f32 field. Same ownership rule:
//
//   - each peer move_and_slides only its OWN kicker (XZ plane) and owner-streams it;
//   - exactly one peer simulates the ball (play.Puppet3 freezes it everywhere
//     else), and the HOST hands that seat to the LAST TOUCHER by the same
//     proximity arbitration the 2D pitch tuned (anticipatory radius, sticky
//     possession, intent gating, held challenges);
//   - goals, score, and the match are host-authoritative fields on the ball.
//
// The file map mirrors slopball exactly. Acid: run.sh (solo), native_run.sh
// (3 peers, centimeter convergence).
// ----------------------------------------------------------------------------

import "core:fmt"
import gd "godot:godot"
import kboot "godot:kit/boot"
import kcomms "godot:kit/comms"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import kui "godot:kit/ui"
import netgd "godot:kit/netgd"
import play "godot:play"

MSG_SESSION :: u8(0) // all kit/session traffic under one game byte

// (KICKER3_TYPE/BALL3_TYPE are GENERATED from the scene fields' entity= tags —
// each tag declares what its scene bodies and the entity's stable wire id.)

DEFAULT_PORT :: 4189

// Meters and meters/second — the 2D pitch's pixel numbers divided by 40.
KICKER_SPEED :: f32(3.75)
KICK_REACH :: f32(0.65) // boot-kick range
KICK_POWER :: f32(6.5) // horizontal impulse (ball mass 1: ~its Δv)
KICK_LOFT :: f32(2.2) // upward component — a 3D kick ARCS (and tests y + tumble)
DRIBBLE_R :: f32(0.55) // contact-nudge range (capsule 0.25 + ball 0.2 + a hair)
DRIBBLE_NUDGE :: f32(0.35) // per-contact-frame impulse — a push, not a shot
TOUCH_R :: f32(1.1) // ANTICIPATORY seat radius (see slopball: the grant round trip)
GRANT_COOL :: 0.45 // seconds between seat grants — no thrash in a scrum
GRANT_EDGE :: f32(0.3) // a challenger must be this much CLOSER than the sitting owner
CHALLENGE_HOLD :: 0.3 // a MOVING ball changes hands only after a held advantage
BALL_SLOW :: f32(1.5) // m/s: under this the ball is "at rest" — first touch grants instantly
INTENT_SPEED :: f32(0.015) // m/tick of challenger motion: statues never claim
CONTACT_R :: f32(0.55) // true contact: at this range a held claim resolves fast
KICKOFF_HOLD :: 1.2 // ball frozen at center after a goal/kickoff
GOAL_MOUTH_NEAR :: f32(3.25) // the mouth spans this z range on both goal lines
GOAL_MOUTH_FAR :: f32(5.75)

Slopball3 :: struct {
	owner:   gd.Node3d,
	ses:     ksess.Session,
	comms:   kcomms.Comms,
	boot:    kboot.Boot,
	running: bool, // transport up (hosting or joining)
	started: bool, // the world reached this peer

	// The authored bodies. Each tag's `entity=Name:id` IS the factory
	// declaration — scriptgen generates the TYPE consts + the kind table,
	// and kboot.boot_entities (ready(), below) instantiates/frees them.
	kicker_scene: ^gd.Resource `gd:"entity=Kicker3:1"`,
	ball_scene:   ^gd.Resource `gd:"entity=Ball3:2"`,

	kickers:   map[knet.Net_Id]^Kicker3,
	avatar_of: map[knet.Player_Id]knet.Net_Id,
	me_kick:   ^Kicker3, // my avatar (nil until spawned)
	ball:      ^Ball3,
	ball_id:   knet.Net_Id,

	// Host scratch (empty elsewhere).
	grant_at:   f64, // last seat grant (GRANT_COOL)
	challenger: knet.Player_Id, // who is contesting the moving ball...
	challenge_since: f64, // ...and since when (CHALLENGE_HOLD)
	kickoff_at: f64, // until when the ball rests at center
	goals_to:   int, // first to N takes the match (SLOP3_GOALS)

	// Presentation + acid. (The old seen_l/seen_r/seen_won mirrors are GONE —
	// the ball3_score_edge half below receives the net change directly.)
	netgraph:       kui.Netgraph, // the "is it healthy?" overlay — coop form + the traffic row
	auto_peers:     int, // env role: auto-start when this many are seated (0 = lobby UI)
	bot:            string, // SLOP3_BOT: "", "striker", "chaser", "idle"
	kick_cool:      f64,
	report_tick:    u64, // last SB3_BALL print (convergence probe)
	done:           bool, // acid: SLOPBALL3D_DONE printed
}

now_s :: knet.now_s

slopball3_ready :: proc(self: ^Slopball3) {
	// Same pipeline the 2D pitch needed: 60Hz streams, ~3-keyframe interp
	// window, and the SOLVER stepped at the net rate (a 120Hz session over
	// 60Hz physics just streams duplicate poses).
	hz := gd.env_int("SLOP3_HZ", 60)
	ksess.session_configure(&self.ses, {
		tick_hz = hz,
		interp_delay = f64(gd.env_int("SLOP3_INTERP_MS", max(3000 / hz, 16))) / 1000.0,
	})
	gd.engine_set_physics_ticks_per_second(gd.singleton_engine(), gd.Int(hz))

	kboot.boot_attach(&self.boot, cast(gd.Node)self.owner, &self.ses, &self.comms, kboot.Options{
		title = "S L O P B A L L  3 D",
		status = "Host a pitch, or join one at localhost",
		legend = "WASD move · Space kick · Tab scores · Enter chat",
		msg_kind = MSG_SESSION,
		env = "SLOP3", // SLOP3_PORT/_NAME/_TOKEN identity + the SLOP3_LATENCY shim
		min_players = 1, // a lone host may start and kick the ball around
		spatial = true, // 3D game: Node3D stage/world containers
		methods = {"on_host", "on_join", "on_start", "on_chat", "on_packet", "on_peer_left", "on_net_up", "on_net_down"},
	})
	// The factory, written by nobody: the generated table (from the entity=
	// tags above) makes/frees under boot.world; world.odin's *_spawned/
	// *_freed hooks keep the kicker/ball census.
	kboot.boot_entities(&self.boot, self, slopball3_entity_kinds[:])

	self.goals_to = gd.env_int("SLOP3_GOALS", 3)
	self.bot = gd.env_string("SLOP3_BOT", "")
	self.netgraph = kui.netgraph_make(cast(gd.Node)self.owner)
	kui.netgraph_show(&self.netgraph, true)
	install_controls()

	// Headless drivers pick a role from the env (the acid path); humans get
	// the lobby. `single` is host-with-no-peers: the same code, nobody joins.
	role := gd.env_string("SLOP3_ROLE", "")
	switch role {
	case "host":
		self.auto_peers = gd.env_int("SLOP3_PEERS", 1)
		slopball3_on_host(self)
	case "join":
		slopball3_on_join(self)
	case "single":
		self.auto_peers = 1
		slopball3_on_host(self)
	}
	// Scripted matches auto-start when the pitch fills — checked wherever the
	// count can change: here (single mode seats only me) and on each join's
	// authority consequence (slopball3_player_joined_then).
	slopball3_try_start(self)
	gd.print_str("SB3_UI_READY")
}

slopball3_try_start :: proc(self: ^Slopball3) {
	if self.started || self.auto_peers <= 0 {return}
	if ksess.session_count(&self.ses, connected_only = true) >= self.auto_peers {
		slopball3_on_start(self) // self-gating: non-hosts and re-calls no-op
	}
}

slopball3_process :: proc(self: ^Slopball3, delta: f64) {
	if !self.running {return}

	events, _, ticks := kboot.boot_pump(&self.boot, delta, now_s())

	if self.started {
		drive_my_kicker(self, delta)
		// The authority's fixed steps, role-free at the call site: the
		// generated slopball3_step holds the host gate (clients no-op) and
		// runs the same-frame edge pass after the loop.
		slopball3_step(self, ticks)
		ball_report(self)
	}

	// The "is it healthy?" overlay: rtt off the replicated ping stat, the
	// LINK's own truth (ENet loss + rtt variance — clients only), and the
	// wire's bytes-by-kind row. Coop form: `sim` stays false.
	ng := kui.Net_Stats{
		rtt_ms  = kui.net_ping_ms(&self.ses),
		traffic = netgd.wire_traffic(&self.boot.wire),
	}
	if _, jit, loss, has := netgd.wire_link_quality(&self.boot.wire, ksess.HOST_PEER); has {
		ng.jitter_ms = jit
		ng.loss_pct = loss
	}
	kui.netgraph_refresh(&self.netgraph, ng)

	// The game's event reactions are the name-paired halves below; the
	// generated slopball3_events holds the switch and every role gate.
	slopball3_events(self, events)
}

// ---- session event halves ---------------------------------------------------

slopball3_welcomed :: proc(self: ^Slopball3, me: knet.Player_Id) {
	gd.print_str(fmt.tprintf("SB3_SEATED me=%d", u64(me)))
}

// The join's authority consequence: word the arrival, field a drop-in kicker,
// start the scripted match when the pitch fills — is_host-free (the generated
// dispatch holds the gate).
slopball3_player_joined_then :: proc(self: ^Slopball3, id: knet.Player_Id, rejoin: bool) {
	if p, ok := ksess.session_player(&self.ses, id); ok {
		kcomms.comms_welcome(&self.comms, id, rejoin, fmt.tprintf("%s takes the pitch", p.name))
	}
	if self.started && !rejoin {
		spawn_kicker(self, id)
	}
	slopball3_try_start(self)
}

// The seat outlives the socket, but the SIM must not: a ball owned by the
// leaver would freeze mid-air on every screen. Authority consequence — the
// host reclaims the seat.
slopball3_player_left_then :: proc(self: ^Slopball3, id: knet.Player_Id) {
	if self.ball != nil && ksess.session_owner_of(&self.ses, self.ball_id) == id {
		ksess.session_set_owner(&self.ses, self.ball_id, self.ses.me)
		gd.print_str("SB3_BALL_RECLAIMED")
	}
}

slopball3_host_left :: proc(self: ^Slopball3) {
	kui.lobby_set_status(&self.boot.ui, "The host left — this match is over")
	gd.print_str("SB3_HOST_LEFT")
}

// The world reached this peer — and the ball's INITIAL dress: adopt the
// current seat (a late joiner may arrive while a client already simulates)
// and paint a mid-match score (spawn values seed the edge silently — a
// baseline, not an edge).
slopball3_entity_spawned :: proc(self: ^Slopball3, id: knet.Net_Id, type: ksess.Entity_Type, owner: knet.Player_Id) {
	_ = type
	if !self.started {
		self.started = true
		gd.set_bool(cast(gd.Object)self.boot.ui.root, "visible", false)
		gd.set_bool(cast(gd.Object)self.boot.legend, "visible", true)
		gd.print_str("SB3_STARTED")
	}
	if id == self.ball_id && self.ball != nil {
		seat_ball(self, ksess.session_owner_of(&self.ses, id))
		if self.ball.score.l != 0 || self.ball.score.r != 0 {
			kui.lobby_set_status(&self.boot.ui, fmt.tprintf("%d — %d", self.ball.score.l, self.ball.score.r))
		}
	}
	gd.print_str(fmt.tprintf("SB3_SPAWN id=%d mine=%v", u32(id), owner == self.ses.me))
}

slopball3_owner_changed :: proc(self: ^Slopball3, id: knet.Net_Id, owner: knet.Player_Id, prev: knet.Player_Id) {
	_ = prev
	if id == self.ball_id {
		seat_ball(self, owner)
		gd.print_str(fmt.tprintf("SB3_BALL_OWNER player=%d", u64(owner)))
	}
}

slopball3_join_denied :: proc(self: ^Slopball3, reason: ksess.Deny_Reason) {
	gd.print_str(fmt.tprintf("SB3_DENIED reason=%v", reason))
}

slopball3_join_failed :: proc(self: ^Slopball3) {
	gd.print_str("SB3_JOIN_FAILED")
}

// seat_ball — the Puppet3 handoff: whoever the session names, that peer's
// solver wakes; everyone else's freezes.
seat_ball :: proc(self: ^Slopball3, owner: knet.Player_Id) {
	if self.ball == nil {return}
	p := self.ball.puppet.pos
	gd.print_str(fmt.tprintf(
		"SB3_SEAT owner=%d mine=%v x=%.2f y=%.2f z=%.2f",
		u64(owner), owner == self.ses.me, p.x, p.y, p.z,
	))
	play.puppet3_seat(&self.ball.puppet, owner == self.ses.me)
}

// THE SCOREBOARD EDGE — every peer narrates goals and the match end from
// REPLICATED score bytes (the host never sends a "goal!" message; the state
// IS the news). Score is ONE co-located field, so a goal that moves l and won
// together fires ONCE with the whole old/new — the seen_* mirrors are gone,
// and first sight (a late joiner's 3—2) seeds silently by design (dressed on
// slopball3_entity_spawned above).
ball3_score_edge :: proc(g: ^Slopball3, self: ^Ball3, old, new: Score) {
	if new.l != old.l || new.r != old.r {
		kui.lobby_set_status(&g.boot.ui, fmt.tprintf("%d — %d", new.l, new.r))
		gd.print_str(fmt.tprintf("SB3_SCORE l=%d r=%d", new.l, new.r))
	}
	if new.won != 0 && old.won == 0 {
		side := new.won == 1 ? "LEFT" : "RIGHT"
		kui.lobby_set_status(&g.boot.ui, fmt.tprintf("%s takes the match %d—%d", side, new.l, new.r))
		gd.print_str(fmt.tprintf("SB3_MATCH winner=%d", new.won))
		if !g.done {
			g.done = true
			gd.print_str("SLOPBALL3D_DONE")
		}
	}
}

// ball_report — the acid's convergence probe: every peer prints the ball's
// spot in CENTIMETERS (integers keep the harness in plain shell math) at the
// same session ticks, so the harness can diff screens.
ball_report :: proc(self: ^Slopball3) {
	if self.ball == nil {return}
	t := ksess.session_tick_no(&self.ses)
	if t == 0 || t == self.report_tick || t % 30 != 0 {return}
	self.report_tick = t
	own, warp, ring := -1, -1, -1
	if e, eok := knet.registry_get(&self.ses.reg, self.ball_id); eok {
		own = int(e.owner)
		warp = int(e.warp)
		ring = int(e.stream.count)
	}
	p := self.ball.puppet.pos
	q := transmute([4]f32)self.ball.puppet.rot // the quat receipt: a settled ball's
	// orientation must agree across screens — garbage in the wire round trip or the
	// nlerp would show here even though the POSITION diff can't see it.
	bp := gd.node3d_get_position(cast(gd.Node3d)self.ball.owner)
	gd.print_str(fmt.tprintf(
		"SB3_BALL tick=%d x=%.0f y=%.0f z=%.0f qx=%.0f qw=%.0f own=%d warp=%d ring=%d mine=%v body=%.0f,%.0f,%.0f",
		t, p.x * 100, p.y * 100, p.z * 100, q[0] * 100, q[3] * 100, own, warp, ring, self.ball.puppet.mine,
		bp.x * 100, bp.y * 100, bp.z * 100,
	))
}
