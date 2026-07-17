//gd:extends Node2D
//gd:class Slopball
package slopball

// ----------------------------------------------------------------------------
// SLOPBALL — co-op physics soccer, the friendslop kit's ENGINE-PHYSICS exercise.
//
// Everything the other examples replicate is hand-rolled kinematics; slopball's
// ball is a real RigidBody2D and its players are real CharacterBody2Ds, so this
// example answers the question every Godot dev asks the kit first: "can I just
// use physics bodies?" The answer is play.Puppet + one ownership rule:
//
//   - each peer move_and_slides only its OWN kicker and owner-streams the pose;
//   - exactly one peer simulates the ball (play.Puppet freezes it everywhere
//     else), and the HOST hands that seat to the LAST TOUCHER by plain
//     proximity arbitration (host.odin) — your kicks resolve on your OWN
//     solver, no round trip, and the handoff carries momentum;
//   - goals, score, and the match are host-authoritative fields on the ball
//     entity itself — host deltas and a client's owner stream sharing one
//     entity is exactly what the field tags mean.
//
// The file map mirrors cavecrawl: net.odin (transport pads), world.odin (the
// factory + spawns), input.odin (my kicker + the autopilot), host.odin (claim
// arbitration, goals, the match). Acid: run.sh (solo), native_run.sh (3 peers).
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

// (KICKER_TYPE/BALL_TYPE are GENERATED from the scene fields' entity= tags —
// each tag declares what its scene bodies and the entity's stable wire id.)

DEFAULT_PORT :: 4188

KICKER_SPEED :: f32(150)
KICK_REACH :: f32(26) // boot-kick range
KICK_POWER :: f32(260)
DRIBBLE_R :: f32(21) // contact-nudge range (kicker 9 + ball 8 + a hair)
DRIBBLE_NUDGE :: f32(14) // per-contact-frame impulse — a push, not a shot
TOUCH_R :: f32(44) // ANTICIPATORY seat radius: the grant round-trip (your streamed
	// pose to the host + SETOWNER back) costs ~2 transits + an interp delay; granting
	// before your foot arrives is what makes the touch feel local. Contact is ~17px.
GRANT_COOL :: 0.45 // seconds between seat grants — no thrash in a scrum
GRANT_EDGE :: f32(12) // a challenger must be this much CLOSER than the sitting owner
CHALLENGE_HOLD :: 0.3 // a MOVING ball changes hands only after the challenger holds
	// the advantage this long — a kicked ball rolling PAST a bystander spends ~0.3s
	// inside TOUCH_R, and a drive-by seat theft is a visible stutter on every screen.
BALL_SLOW :: f32(60) // px/s: under this the ball is "at rest" — first touch grants instantly
INTENT_SPEED :: f32(0.6) // px/tick of challenger motion: an IDLE bystander never claims —
	// the seat exists so the toucher's kicks work; a statue needs nothing (the ball
	// bounces off its body on the owner's screen regardless). Walter's last stutter
	// was a parked host claiming a slowing pass that merely rolled by.
CONTACT_R :: f32(22) // true contact: at this range a held claim resolves fast
KICKOFF_HOLD :: 1.2 // ball frozen at center after a goal/kickoff
GOAL_MOUTH_TOP :: f32(130)
GOAL_MOUTH_BOT :: f32(230)

Slopball :: struct {
	owner:   gd.Node2d,
	ses:     ksess.Session,
	comms:   kcomms.Comms,
	boot:    kboot.Boot,
	running: bool, // transport up (hosting or joining)
	started: bool, // the world reached this peer

	// The authored bodies. Each tag's `entity=Name:id` IS the factory
	// declaration — scriptgen generates the TYPE consts + the kind table,
	// and kboot.boot_entities (ready(), below) instantiates/frees them.
	kicker_scene: ^gd.Resource `gd:"export,resource=PackedScene,entity=Kicker:1"`,
	ball_scene:   ^gd.Resource `gd:"export,resource=PackedScene,entity=Ball:2"`,

	// The census is GENERATED (kicker_of / kicker_ids / kicker_owned_by) —
	// what's left is the hot pointers the input and probes poke every frame.
	me_kick: ^Kicker, // my avatar (nil until spawned)
	ball:    ^Ball,
	ball_id: knet.Net_Id,

	// Host scratch (empty elsewhere).
	grant_at:   f64, // last seat grant (GRANT_COOL)
	challenger: knet.Player_Id, // who is contesting the moving ball...
	challenge_since: f64, // ...and since when (CHALLENGE_HOLD)
	kickoff_at: f64, // until when the ball rests at center
	goals_to:   int, // first to N takes the match (SLOP_GOALS)

	// Presentation + acid. (The old seen_l/seen_r/seen_won mirrors are GONE —
	// the ball_score_edge half below receives the net change directly.)
	netgraph:       kui.Netgraph, // the "is it healthy?" overlay — coop form + the traffic row
	auto_peers:     int, // env role: auto-start when this many are seated (0 = lobby UI)
	bot:            string, // SLOP_BOT: "", "striker", "idle"
	kick_cool:      f64,
	report_tick:    u64, // last SB_BALL print (convergence probe)
	done:           bool, // acid: SLOPBALL_DONE printed
}

now_s :: knet.now_s

slopball_ready :: proc(self: ^Slopball) {
	// A physics game lives and dies on pipeline latency: 60Hz streams with a
	// ~3-keyframe interp window (the kit default is 20Hz/100ms — fine for a
	// dungeon crawl, mud for a ball you dribble). SLOP_HZ/SLOP_INTERP_MS
	// keep the acid's A/B knobs.
	hz := gd.env_int("SLOP_HZ", 60)
	ksess.session_configure(&self.ses, {
		tick_hz = hz,
		// Default the interp window to ~3 keyframes of the chosen rate (50ms
		// at 60Hz, 25ms at 120) — SLOP_INTERP_MS overrides for A/B feel tests.
		interp_delay = f64(gd.env_int("SLOP_INTERP_MS", max(3000 / hz, 16))) / 1000.0,
		// The wire-contract version gate needs no wiring: the generated guard
		// file registers NET_FINGERPRINT as the session default at load.
	})
	// The net rate is only honest if the SOLVER steps at it too: a 120Hz
	// session over 60Hz physics just streams duplicate poses.
	gd.engine_set_physics_ticks_per_second(gd.singleton_engine(), gd.Int(hz))

	kboot.boot_attach(&self.boot, cast(gd.Node)self.owner, &self.ses, &self.comms, kboot.Options{
		title = "S L O P B A L L",
		status = "Host a pitch, or join one at localhost",
		legend = "WASD move · Space kick · Tab scores · Enter chat",
		msg_kind = MSG_SESSION,
		env = "SLOP", // SLOP_PORT/_NAME/_TOKEN identity + the SLOP_LATENCY shim
		min_players = 1, // a lone host may start and kick the ball around
		methods = {"on_host", "on_join", "on_start", "on_chat", "on_packet", "on_peer_left", "on_net_up", "on_net_down"},
	})
	// The factory, written by nobody: the generated table (from the entity=
	// tags above) makes/frees under boot.world; world.odin's *_spawned/
	// *_freed hooks keep the kicker/ball census.
	kboot.boot_entities(&self.boot, self, slopball_entity_kinds[:])

	self.goals_to = gd.env_int("SLOP_GOALS", 3)
	self.bot = gd.env_string("SLOP_BOT", "")
	self.netgraph = kui.netgraph_make(cast(gd.Node)self.owner)
	kui.netgraph_show(&self.netgraph, true)
	install_controls()

	// Headless drivers pick a role from the env (the acid path); humans get
	// the lobby. `single` is host-with-no-peers: the same code, nobody joins.
	role := gd.env_string("SLOP_ROLE", "")
	switch role {
	case "host":
		self.auto_peers = gd.env_int("SLOP_PEERS", 1)
		slopball_on_host(self)
	case "join":
		slopball_on_join(self)
	case "single":
		self.auto_peers = 1
		slopball_on_host(self)
	case "serve":
		// Dedicated pitch: an avatarless referee — kicks off once SLOP_PEERS
		// actual PLAYERS are seated (the server's own seat never counts).
		self.auto_peers = gd.env_int("SLOP_PEERS", 2)
		slopball_on_serve(self)
	}
	// Scripted matches auto-start when the pitch fills — checked wherever the
	// count can change: here (single mode seats only me) and on each join's
	// authority consequence (slopball_player_joined_then).
	slopball_try_start(self)
	gd.print_str("SB_UI_READY")
}

slopball_try_start :: proc(self: ^Slopball) {
	if self.started || self.auto_peers <= 0 {return}
	if ksess.session_count(&self.ses, connected_only = true, players_only = true) >= self.auto_peers {
		slopball_on_start(self) // self-gating: non-hosts and re-calls no-op
	}
}

slopball_process :: proc(self: ^Slopball, delta: f64) {
	if !self.running {return}

	events, _, ticks := kboot.boot_pump(&self.boot, delta, now_s())

	if self.started {
		drive_my_kicker(self, delta)
		// The authority's fixed steps, role-free at the call site: the
		// generated slopball_step holds the host gate (clients no-op) and
		// runs the same-frame edge pass after the loop.
		slopball_step(self, ticks)
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
	// generated slopball_events holds the switch and every role gate.
	slopball_events(self, events)
}

// ---- session event halves ---------------------------------------------------

slopball_welcomed :: proc(self: ^Slopball, me: knet.Player_Id) {
	gd.print_str(fmt.tprintf("SB_SEATED me=%d", u64(me)))
}

// The join's authority consequence: word the arrival, field a drop-in kicker,
// start the scripted match when the pitch fills — is_host-free (the generated
// dispatch holds the gate).
slopball_player_joined_then :: proc(self: ^Slopball, id: knet.Player_Id, rejoin: bool) {
	if p, ok := ksess.session_player(&self.ses, id); ok {
		kcomms.comms_welcome(&self.comms, id, rejoin, fmt.tprintf("%s takes the pitch", p.name))
	}
	if self.started && !rejoin {
		spawn_kicker(self, id)
	}
	slopball_try_start(self)
}

// The seat outlives the socket, but the SIM must not: a ball owned by the
// leaver would freeze mid-air on every screen. Authority consequence — the
// host reclaims the seat.
slopball_player_left_then :: proc(self: ^Slopball, id: knet.Player_Id) {
	if self.ball != nil && ksess.session_owner_of(&self.ses, self.ball_id) == id {
		ksess.session_set_owner(&self.ses, self.ball_id, self.ses.me)
		gd.print_str("SB_BALL_RECLAIMED")
	}
}

slopball_host_left :: proc(self: ^Slopball) {
	kui.lobby_set_status(&self.boot.ui, "The host left — this match is over")
	gd.print_str("SB_HOST_LEFT")
}

// The world reached this peer — and the ball's INITIAL dress: adopt the
// current seat (a late joiner may arrive while a client already simulates)
// and paint a mid-match score (spawn values seed the edge silently — a
// baseline, not an edge).
slopball_entity_spawned :: proc(self: ^Slopball, id: knet.Net_Id, type: ksess.Entity_Type, owner: knet.Player_Id) {
	_ = type
	if !self.started {
		self.started = true
		gd.set_bool(cast(gd.Object)self.boot.ui.root, "visible", false)
		gd.set_bool(cast(gd.Object)self.boot.legend, "visible", true)
		gd.print_str("SB_STARTED")
	}
	if id == self.ball_id && self.ball != nil {
		seat_ball(self, ksess.session_owner_of(&self.ses, id))
		if self.ball.score.l != 0 || self.ball.score.r != 0 {
			kui.lobby_set_status(&self.boot.ui, fmt.tprintf("%d — %d", self.ball.score.l, self.ball.score.r))
		}
	}
	gd.print_str(fmt.tprintf("SB_SPAWN id=%d mine=%v", u32(id), owner == self.ses.me))
}

slopball_owner_changed :: proc(self: ^Slopball, id: knet.Net_Id, owner: knet.Player_Id, prev: knet.Player_Id) {
	_ = prev
	if id == self.ball_id {
		seat_ball(self, owner)
		gd.print_str(fmt.tprintf("SB_BALL_OWNER player=%d", u64(owner)))
	}
}

slopball_join_denied :: proc(self: ^Slopball, reason: ksess.Deny_Reason) {
	gd.print_str(fmt.tprintf("SB_DENIED reason=%v", reason))
}

slopball_join_failed :: proc(self: ^Slopball) {
	gd.print_str("SB_JOIN_FAILED")
}

// seat_ball — the Puppet handoff: whoever the session names, that peer's
// solver wakes; everyone else's freezes.
seat_ball :: proc(self: ^Slopball, owner: knet.Player_Id) {
	if self.ball == nil {return}
	// The seed pose the new simulator wakes with IS this peer's current view —
	// print it at every handoff so a stale view is visible in any log.
	gd.print_str(fmt.tprintf(
		"SB_SEAT owner=%d mine=%v x=%.0f y=%.0f",
		u64(owner), owner == self.ses.me, self.ball.puppet.x, self.ball.puppet.y,
	))
	play.puppet_seat(&self.ball.puppet, owner == self.ses.me)
}

// THE SCOREBOARD EDGE — every peer narrates goals and the match end from
// REPLICATED score bytes (the host never sends a "goal!" message; the state
// IS the news). Score is ONE co-located field, so a goal that moves l and won
// together fires ONCE with the whole old/new — the seen_* mirrors and the
// per-frame compare are deleted, and first sight (a late joiner's 3—2) seeds
// silently by design (dressed on slopball_entity_spawned above).
ball_score_edge :: proc(g: ^Slopball, self: ^Ball, old, new: Score) {
	if new.l != old.l || new.r != old.r {
		kui.lobby_set_status(&g.boot.ui, fmt.tprintf("%d — %d", new.l, new.r))
		gd.print_str(fmt.tprintf("SB_SCORE l=%d r=%d", new.l, new.r))
	}
	if new.won != 0 && old.won == 0 {
		side := new.won == 1 ? "LEFT" : "RIGHT"
		kui.lobby_set_status(&g.boot.ui, fmt.tprintf("%s takes the match %d—%d", side, new.l, new.r))
		gd.print_str(fmt.tprintf("SB_MATCH winner=%d", new.won))
		if !g.done {
			g.done = true
			gd.print_str("SLOPBALL_DONE")
		}
	}
}

// ball_report — the acid's convergence probe: every peer prints the ball's
// spot at the same session ticks, so the harness can diff screens.
ball_report :: proc(self: ^Slopball) {
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
	bp := gd.node2d_get_position(cast(gd.Node2d)self.ball.owner)
	gd.print_str(fmt.tprintf(
		"SB_BALL tick=%d x=%.0f y=%.0f kick=%d own=%d warp=%d ring=%d mine=%v body=%.0f,%.0f",
		t, self.ball.puppet.x, self.ball.puppet.y, len(kicker_ids(&self.boot)), own, warp, ring, self.ball.puppet.mine, bp.x, bp.y,
	))
}
