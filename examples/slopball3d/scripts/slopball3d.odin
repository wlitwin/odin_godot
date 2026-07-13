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
	kicker_scene: ^gd.Resource `gd:"export,resource=PackedScene,entity=Kicker3:1"`,
	ball_scene:   ^gd.Resource `gd:"export,resource=PackedScene,entity=Ball3:2"`,

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

	// Presentation edges + acid.
	seen_l, seen_r: u8, // score edges: every peer narrates goals from replication
	seen_won:       u8,
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
		latency_env = "SLOP3_LATENCY",
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
	gd.print_str("SB3_UI_READY")
}

slopball3_process :: proc(self: ^Slopball3, delta: f64) {
	if !self.running {return}

	events, _, ticks := kboot.boot_pump(&self.boot, delta, now_s())

	if self.started {
		drive_my_kicker(self, delta)
		if self.ses.is_host {
			for _ in 0 ..< ticks {
				slop3_host_tick(self)
			}
		}
		score_edges(self)
		ball_report(self)
	} else if self.ses.is_host && self.auto_peers > 0 &&
	   ksess.session_count(&self.ses, connected_only = true) >= self.auto_peers {
		slopball3_on_start(self)
	}

	for ev in events {
		#partial switch e in ev {
		case ksess.Ev_Welcomed:
			gd.print_str(fmt.tprintf("SB3_SEATED me=%d", u64(e.me)))
		case ksess.Ev_Player_Joined:
			if self.ses.is_host {
				if p, ok := ksess.session_player(&self.ses, e.id); ok {
					kcomms.comms_welcome(&self.comms, e.id, e.rejoin, fmt.tprintf("%s takes the pitch", p.name))
				}
				// Drop-in: a mid-match joiner gets a kicker on the spot.
				if self.started && !e.rejoin {
					spawn_kicker(self, e.id)
				}
			}
		case ksess.Ev_Player_Left:
			if self.ses.is_host {
				// The seat outlives the socket, but the SIM must not: a ball
				// owned by the leaver would freeze mid-air on every screen.
				if self.ball != nil && ksess.session_owner_of(&self.ses, self.ball_id) == e.id {
					ksess.session_set_owner(&self.ses, self.ball_id, self.ses.me)
					gd.print_str("SB3_BALL_RECLAIMED")
				}
			}
		case ksess.Ev_Host_Left:
			kui.lobby_set_status(&self.boot.ui, "The host left — this match is over")
			gd.print_str("SB3_HOST_LEFT")
		case ksess.Ev_Spawned:
			if !self.started {
				self.started = true
				gd.set_bool(cast(gd.Object)self.boot.ui.root, "visible", false)
				gd.set_bool(cast(gd.Object)self.boot.legend, "visible", true)
				gd.print_str("SB3_STARTED")
			}
			if e.id == self.ball_id && self.ball != nil {
				// First sight of the ball: adopt the current seat (a late
				// joiner may arrive while a client already simulates).
				seat_ball(self, ksess.session_owner_of(&self.ses, e.id))
			}
			gd.print_str(fmt.tprintf("SB3_SPAWN id=%d mine=%v", u32(e.id), e.owner == self.ses.me))
		case ksess.Ev_Owner_Changed:
			if e.id == self.ball_id {
				seat_ball(self, e.owner)
				gd.print_str(fmt.tprintf("SB3_BALL_OWNER player=%d", u64(e.owner)))
			}
		case ksess.Ev_Join_Denied:
			gd.print_str(fmt.tprintf("SB3_DENIED reason=%v", e.reason))
		case ksess.Ev_Join_Failed:
			gd.print_str("SB3_JOIN_FAILED")
		}
	}
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

// score_edges — every peer narrates goals and the match end from REPLICATED
// score bytes (the host never sends a "goal!" message; the state IS the news).
score_edges :: proc(self: ^Slopball3) {
	if self.ball == nil {return}
	b := self.ball
	if b.score_l != self.seen_l || b.score_r != self.seen_r {
		self.seen_l = b.score_l
		self.seen_r = b.score_r
		kui.lobby_set_status(&self.boot.ui, fmt.tprintf("%d — %d", b.score_l, b.score_r))
		gd.print_str(fmt.tprintf("SB3_SCORE l=%d r=%d", b.score_l, b.score_r))
	}
	if b.won != self.seen_won {
		self.seen_won = b.won
		if b.won != 0 {
			side := b.won == 1 ? "LEFT" : "RIGHT"
			kui.lobby_set_status(&self.boot.ui, fmt.tprintf("%s takes the match %d—%d", side, b.score_l, b.score_r))
			gd.print_str(fmt.tprintf("SB3_MATCH winner=%d", b.won))
			if !self.done {
				self.done = true
				gd.print_str("SLOPBALL3D_DONE")
			}
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
