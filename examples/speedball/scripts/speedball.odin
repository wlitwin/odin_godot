//gd:extends Node2D
//gd:class Speedball
package speedball

// ----------------------------------------------------------------------------
// SPEEDBALL — slopball's contested twin, and the predict-the-contested-object
// showcase. Same game, the OTHER netcode: where slopball hands the ball's
// SIMULATION SEAT to the last toucher (peer-authoritative, play.Puppet),
// speedball keeps one authority and lets EVERY peer predict the ball
// (`@(gd_tick="contested")`, ball.odin). Your touches and kicks resolve on
// your own screen the frame you make them at any latency; the server's word
// reconciles the fights; the glide hides the losses. Read the two games side
// by side to pick a model — that comparison is the point of this example.
//
// The world pass here is PURE SIM (contact + kicks, every peer, resim
// included) — no role gates: it only touches predicted state, driven by
// inputs. Consequences stay name-paired: ball_tick_then lands the score on
// the delta lane; the goal reset itself is predicted (ball.odin).
// ----------------------------------------------------------------------------

import "core:fmt"
import gd "godot:godot"
import kboot "godot:kit/boot"
import kcomms "godot:kit/comms"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import ksim "godot:kit/sim"
import kui "godot:kit/ui"
import psim "godot:play/sim"

MSG_SESSION :: u8(0)
DEFAULT_PORT :: 4190

Speedball :: struct {
	owner:   gd.Node2d,
	ses:     ksess.Session,
	comms:   kcomms.Comms,
	boot:    kboot.Boot,
	lane:    ksim.Lane,
	running: bool,
	started: bool,

	kicker_scene: ^gd.Resource `gd:"export,resource=PackedScene,entity=Kicker:1"`,
	ball_scene:   ^gd.Resource `gd:"export,resource=PackedScene,entity=Ball:2"`,

	// The census is GENERATED (kicker_of / kicker_ids / kicker_owned_by) —
	// what's left is the hot pointers the sample, bots, and probes poke.
	me_kick: ^Kicker,
	ball:      ^Ball,

	goals_to: u8,

	// Presentation edges + the acid's probes.
	auto_peers: int,
	bot:        string, // SPB_BOT: "" | "striker" | "spiker" | "idle"
	done:       bool,
	spiked:     bool, // the spiker's one burst fired (two verbs, one RTT — the chain)
	spike_seen: bool, // the acid's local-effect edge landed
	spike_from: [2]f32, // where the ball stood at issue — displacement proves the local apply
}

now_s :: knet.now_s

speedball_ready :: proc(self: ^Speedball) {
	// (The wire-contract version gate is on by default — the generated guard
	// file registers NET_FINGERPRINT as the session default at load.)
	kboot.boot_attach(&self.boot, cast(gd.Node)self.owner, &self.ses, &self.comms, kboot.Options{
		title = "S P E E D B A L L",
		status = "Host a pitch, or join one at localhost — the contested twin",
		legend = "WASD move · Space kick · Tab scores · Enter chat",
		msg_kind = MSG_SESSION,
		env = "SPB", // SPB_PORT/_NAME/_TOKEN identity + the SPB_LATENCY shim
		min_players = 1,
		methods = {"on_host", "on_join", "on_start", "on_chat", "on_packet", "on_peer_left", "on_net_up", "on_net_down"},
	})
	kboot.boot_entities(&self.boot, self, speedball_entity_kinds[:])

	// PREDICT-WORLD: batches echo every player's held input, every peer ticks
	// every kicker AND the ball — one timeline for the whole pitch (the
	// Rocket League model). No claim dance; constant small glided corrections
	// on remote avatars instead of delayed-but-accurate ones.
	// tolerance: sub-half-pixel held-input drift rides uncorrected — the
	// reconcile fires on real divergence, not float noise.
	speedball_lane_init(self, &self.lane, &self.ses, cfg = ksim.Lane_Config{smooth_cut = 60, echo_inputs = true, tolerance = 0.5})
	kboot.boot_lane(&self.boot, &self.lane)

	install_controls()
	self.bot = gd.env_string("SPB_BOT", "")
	self.goals_to = u8(gd.env_int("SPB_GOALS", 3))

	role := gd.env_string("SPB_ROLE", "")
	switch role {
	case "host":
		self.auto_peers = gd.env_int("SPB_PEERS", 2)
		speedball_on_host(self)
	case "join":
		speedball_on_join(self)
	case "single":
		self.auto_peers = 1
		speedball_on_host(self)
	case "serve":
		self.auto_peers = gd.env_int("SPB_PEERS", 2)
		speedball_on_serve(self)
	}
	// Scripted matches auto-start when the pitch fills — checked wherever the
	// count can change: here (single mode seats only me) and on each join's
	// authority consequence (speedball_player_joined_then).
	speedball_try_start(self)
	gd.print_str("SPB_UI_READY")
}

speedball_try_start :: proc(self: ^Speedball) {
	if self.started || self.auto_peers <= 0 {return}
	if ksess.session_count(&self.ses, connected_only = true, players_only = true) >= self.auto_peers {
		speedball_on_start(self) // self-gating: non-hosts and re-calls no-op
	}
}

speedball_process :: proc(self: ^Speedball, delta: f64) {
	if !self.running {return}
	events, _, _ := kboot.boot_pump(&self.boot, delta, now_s())

	// THE SPIKE DOOR — a verb on the contested ball, issued like any command
	// (a key edge, or the spiker bot's one two-verb burst — two schedules
	// inside one RTT, riding the pending chain). The displacement watch is
	// the acid's proof that MY screen's ball answered within a tick or two,
	// a full round trip before the authority's word could return.
	if self.me_kick != nil && self.ball != nil {
		b := self.ball
		me := self.me_kick
		want := gd.is_action_just_pressed("spb_spike")
		if self.bot == "spiker" && !self.spiked && b.hold == 0 && b.score.won == 0 {
			dx := b.roll.x - me.run.x
			dy := b.roll.y - me.run.y
			want = want || dx * dx + dy * dy < SPIKE_REACH * SPIKE_REACH
		}
		if want && knet.command_ok(ball_spike_cmd(&self.boot, b, me.run.x, me.run.y)) {
			if !self.spiked {
				self.spiked = true
				self.spike_from = {b.roll.x, b.roll.y}
				_ = ball_spike_cmd(&self.boot, b, me.run.x, me.run.y) // the burst's second verb
				gd.print_str(fmt.tprintf("SPB_SPIKE_SENT tick=%d", ksim.lane_now(&self.lane)))
			}
		}
		if self.spiked && !self.spike_seen {
			dx := b.roll.x - self.spike_from[0]
			dy := b.roll.y - self.spike_from[1]
			if dx * dx + dy * dy > 12 * 12 {
				self.spike_seen = true
				gd.print_str(fmt.tprintf("SPB_SPIKE_LOCAL tick=%d", ksim.lane_now(&self.lane)))
			}
		}
	}

	// The event reactions are the name-paired halves below; the generated
	// speedball_events holds the switch and every role gate.
	speedball_events(self, events)
}

// ---- session event halves ---------------------------------------------------

speedball_welcomed :: proc(self: ^Speedball, me: knet.Player_Id) {
	gd.print_str(fmt.tprintf("SPB_SEATED me=%d", u64(me)))
}

// The join's authority consequence: word the arrival, field a late joiner,
// start the scripted match when the pitch fills — is_host-free (the
// generated dispatch holds the gate).
speedball_player_joined_then :: proc(self: ^Speedball, id: knet.Player_Id, rejoin: bool) {
	if p, ok := ksess.session_player(&self.ses, id); ok {
		kcomms.comms_welcome(&self.comms, id, rejoin, fmt.tprintf("%s takes the pitch", p.name))
	}
	if self.started && !rejoin {
		spawn_kicker(self, id)
	}
	speedball_try_start(self)
}

speedball_host_left :: proc(self: ^Speedball) {
	kui.lobby_set_status(&self.boot.ui, "The host left — this match is over")
	gd.print_str("SPB_HOST_LEFT")
}

// The scoreboard's INITIAL dress — a late joiner's 3—2 — rides this half, on
// the event (fields are set), never in the ball_spawned census hook (it
// fires before the spawn tuple applies); the edge half stays silent on
// first sight by design (a baseline, not an edge).
speedball_entity_spawned :: proc(self: ^Speedball, id: knet.Net_Id, type: ksess.Entity_Type, owner: knet.Player_Id) {
	_ = id
	_ = owner
	if !self.started {
		self.started = true
		gd.set_bool(cast(gd.Object)self.boot.ui.root, "visible", false)
		gd.set_bool(cast(gd.Object)self.boot.legend, "visible", true)
		gd.print_str("SPB_STARTED")
	}
	if type == BALL_TYPE && self.ball != nil && (self.ball.score.l != 0 || self.ball.score.r != 0) {
		kui.lobby_set_status(&self.boot.ui, fmt.tprintf("%d — %d", self.ball.score.l, self.ball.score.r))
	}
}

speedball_join_failed :: proc(self: ^Speedball) {
	gd.print_str("SPB_JOIN_FAILED")
}

// THE SCOREBOARD EDGE — every peer narrates goals and the match from
// REPLICATED state, but the seen_* mirrors and the per-frame compare are
// gone: Score is ONE field (ball.odin's co-location), so this half receives
// the whole old/new atomically and fires ONCE per net change even when a
// goal moves l and won together — where per-field halves would have printed
// the log twice and dinged a horn twice. Wire-fresh on purpose: a scoreboard
// is timelines row 4 (no spatial cause) — never delay it. The INITIAL dress
// (a late joiner's 3—2) rides Ev_Spawned above — the event fires with the
// tuple's fields SET, unlike the census hook: spawn values are a baseline,
// not an edge.
ball_score_edge :: proc(g: ^Speedball, self: ^Ball, old, new: Score) {
	if new.l != old.l || new.r != old.r {
		kui.lobby_set_status(&g.boot.ui, fmt.tprintf("%d — %d", new.l, new.r))
		gd.print_str(fmt.tprintf("SPB_SCORE l=%d r=%d", new.l, new.r))
	}
	if new.won != old.won && new.won != 0 {
		side := new.won == 1 ? "LEFT" : "RIGHT"
		kui.lobby_set_status(&g.boot.ui, fmt.tprintf("%s takes the match %d—%d", side, new.l, new.r))
		gd.print_str(fmt.tprintf("SPB_MATCH winner=%d", new.won))
		if !g.done {
			g.done = true
			gd.print_str("SPEEDBALL_DONE")
		}
	}
}

// ---- input ---------------------------------------------------------------------

install_controls :: proc "contextless" () {
	if gd.has_action("spb_left") {return}
	bind :: proc "contextless" (action: cstring, keys: ..i64) {
		gd.add_action(action)
		for k in keys {
			gd.action_add_key(action, k)
		}
	}
	bind("spb_left", i64('A'), i64(gd.Key.Left))
	bind("spb_right", i64('D'), i64(gd.Key.Right))
	bind("spb_up", i64('W'), i64(gd.Key.Up))
	bind("spb_down", i64('S'), i64(gd.Key.Down))
	bind("spb_kick", i64(gd.Key.Space))
	bind("spb_spike", i64('E'))
}

@(gd_sample)
sp_sample :: proc(self: ^Speedball, tick: u64, input: ^Kicker_Input) {
	input^ = {}
	if self.bot != "" {
		bot_sample(self, tick, input)
		return
	}
	typing := bool(gd.control_has_focus(cast(gd.Control)self.boot.chat.input, false))
	if typing {return}
	if gd.is_action_pressed("spb_left") {input.move[0] -= 1}
	if gd.is_action_pressed("spb_right") {input.move[0] += 1}
	if gd.is_action_pressed("spb_up") {input.move[1] -= 1}
	if gd.is_action_pressed("spb_down") {input.move[1] += 1}
	if gd.is_action_pressed("spb_kick") {input.buttons |= BTN_KICK}
}

// The striker chases the ball it PREDICTS (its own screen's ball — that is
// the pattern working): when the ball sits goalward of it, it CHARGES
// through holding the kick (hold-to-kick, so sample-time and step-time can
// never anti-phase around the reach edge); otherwise it loops to the far
// side first. Production sample path, no side doors.
bot_sample :: proc(g: ^Speedball, tick: u64, input: ^Kicker_Input) {
	// The spiker: walk at the ball it predicts, never kick — its one move is
	// the verb burst (speedball_process), fired the moment the ball's in reach.
	if g.bot == "spiker" && g.me_kick != nil && g.ball != nil && !g.spiked {
		steer := normalized({g.ball.roll.x - g.me_kick.run.x, g.ball.roll.y - g.me_kick.run.y})
		if steer.x > 0.3 {input.move[0] = 1} else if steer.x < -0.3 {input.move[0] = -1}
		if steer.y > 0.3 {input.move[1] = 1} else if steer.y < -0.3 {input.move[1] = -1}
		return
	}
	if g.bot != "striker" || g.me_kick == nil || g.ball == nil {return}
	me := g.me_kick
	b := g.ball
	gx: f32 = team_of(me.pid) == 1 ? PITCH_W : 0 // team 1 scores RIGHT
	to_goal := normalized({gx - b.roll.x, PITCH_H / 2 - b.roll.y})
	rel := gd.Vector2{b.roll.x - me.run.x, b.roll.y - me.run.y}
	aligned := rel.x * to_goal.x + rel.y * to_goal.y // >0: the ball is between me and the goal

	steer: gd.Vector2
	if aligned > 4 {
		steer = normalized(rel) // charge the ball, goalward
		if rel.x * rel.x + rel.y * rel.y < (KICK_REACH + 8) * (KICK_REACH + 8) {
			input.buttons |= BTN_KICK // held: the crossing through reach fires it
		}
	} else {
		// Loop AROUND to the far side — never through the ball: motion-drag
		// dribble means plowing across it herds it the wrong way (the first
		// echo-mode acid wedged itself and the ball into a corner this way).
		tx := b.roll.x - to_goal.x * (KICKER_R + BALL_R + 14)
		ty := b.roll.y - to_goal.y * (KICKER_R + BALL_R + 14)
		steer = normalized({tx - me.run.x, ty - me.run.y})
		d2b := rel.x * rel.x + rel.y * rel.y
		orbit := (KICKER_R + BALL_R + 12)
		if d2b < orbit * orbit * 4 {
			// Near the ball while mispositioned: orbit tangentially with an
			// outward bias instead of walking into it.
			nrel := normalized(rel)
			tangent := gd.Vector2{-nrel.y, nrel.x}
			if tangent.x * steer.x + tangent.y * steer.y < 0 {
				tangent = {-tangent.x, -tangent.y}
			}
			steer = normalized({tangent.x - nrel.x * 0.6, tangent.y - nrel.y * 0.6})
		}
	}
	if steer.x > 0.3 {input.move[0] = 1} else if steer.x < -0.3 {input.move[0] = -1}
	if steer.y > 0.3 {input.move[1] = 1} else if steer.y < -0.3 {input.move[1] = -1}
}

// ---- the world pass: contact, on every peer, one timeline ----------------------
//
// PURE SIM, no role gates: it reads inputs and writes predicted state, so it
// runs identically live and in replays, on the server and on every
// predicting client. In PREDICT-WORLD mode every pair has an input here —
// mine fresh from my ring, remote kickers' HELD from the batch echo — so
// every peer simulates every touch on its own timeline: a remote tackle
// plays out beside the remote avatar making it, immediately, and the next
// batch's truth corrects whatever the held inputs got wrong (the glide
// hides it). That constant small correction is the model's whole price.

@(gd_step)
sp_step :: proc(g: ^Speedball, tick: u64) {
	b := g.ball
	if b == nil {return}
	// The acid's convergence probe reports through holds and match end.
	if g.ses.is_host && tick % 60 == 0 {
		gd.print_str(fmt.tprintf("SPB_POS tick=%d x=%.1f y=%.1f l=%d r=%d", tick, b.roll.x, b.roll.y, b.score.l, b.score.r))
	}
	if !g.ses.is_host && ksim.lane_live(&g.lane) && tick % 60 == 0 {
		mx, my := f32(-1), f32(-1)
		if g.me_kick != nil {
			mx = g.me_kick.run.x
			my = g.me_kick.run.y
		}
		gd.print_str(fmt.tprintf("SPB_CVIEW tick=%d bx=%.1f by=%.1f mex=%.1f mey=%.1f resims=%d", tick, b.roll.x, b.roll.y, mx, my, g.lane.stat_resims))
	}

	if b.score.won != 0 || b.hold > 0 {return}

	for id in kicker_ids(&g.boot) {
		k, _ := kicker_of(&g.boot, id)
		input, drives := ksim.lane_input_of(&g.lane, kboot.boot_entity_owner(&g.boot, id), Kicker_Input)
		if !drives {continue} // a pair this peer doesn't simulate

		dx := b.roll.x - k.run.x
		dy := b.roll.y - k.run.y
		d2 := dx * dx + dy * dy

		// Dribble: SOFT contact. Resolve half the overlap per tick along a
		// STABLE direction, and nudge velocity along the KICKER'S MOTION —
		// not center-to-center, which flips sign frame-to-frame in a deep
		// overlap and teleported the ball to alternating sides of your feet
		// (the "erratic bump" of the first playtest). Capped, so contact
		// never compounds past dribble pace. Cross-entity by nature, so it
		// stays HERE — the roller owns the flight, not the feet.
		reach := KICKER_R + BALL_R
		if d2 < reach * reach {
			dist := sqrt_f32(d2)
			sep: gd.Vector2
			if dist > 0.5 {
				sep = {dx / dist, dy / dist}
			} else {
				sep = normalized({k.run.vx, k.run.vy}) // coincident: shove along my motion
				if sep.x == 0 && sep.y == 0 {sep = {1, 0}}
			}
			overlap := reach - dist
			b.roll.x += sep.x * overlap * 0.5
			b.roll.y += sep.y * overlap * 0.5
			mv := normalized({k.run.vx, k.run.vy})
			if (mv.x != 0 || mv.y != 0) && b.roll.vx * b.roll.vx + b.roll.vy * b.roll.vy < DRIBBLE_MAX * DRIBBLE_MAX {
				b.roll.vx += mv.x * DRIBBLE_PUSH
				b.roll.vy += mv.y * DRIBBLE_PUSH
			}
		}

		// The kick: your foot answers on YOUR screen, this tick. (ready()
		// sits LAST in the guard — it re-arms the cooldown only when the
		// press and the reach already held.)
		if input.buttons & BTN_KICK != 0 && d2 < KICK_REACH * KICK_REACH && psim.ready(&k.kick, KICK_CD) {
			aim := normalized({f32(input.move[0]), f32(input.move[1])})
			if aim.x == 0 && aim.y == 0 {
				aim = normalized({dx, dy})
			}
			b.roll.vx += aim.x * KICK_POWER
			b.roll.vy += aim.y * KICK_POWER
			// (mine && live) is the _fx gate written inline — the kick moves
			// ANOTHER entity (the ball) from this tick, so it can't ride the
			// tick's own fact channel; lane_live keeps the lane's internals out.
			if k.mine && ksim.lane_live(&g.lane) {
				gd.print_str(fmt.tprintf("SPB_KICK tick=%d bvx=%.1f bvy=%.1f", tick, b.roll.vx, b.roll.vy))
			}
		}
	}

}

// ---- the goal's consequence: authority only, name-paired ------------------------

// The spike's receipt — AUTHORITY only, at the verb's execution tick (the
// acid counts these on the marshal: the burst must land exactly twice).
ball_spike_then :: proc(g: ^Speedball, self: ^Ball, by: knet.Player_Id, px, py: f32) {
	gd.print_str(fmt.tprintf("SPB_SPIKE by=%d tick=%d", u64(by), ksim.lane_now(&g.lane)))
}

ball_tick_then :: proc(g: ^Speedball, self: ^Ball, by: knet.Player_Id, scored: u8) {
	if scored == 0 {return}
	if scored == 1 {
		self.score.l += 1
	} else {
		self.score.r += 1
	}
	gd.print_str(fmt.tprintf("SPB_GOAL team=%d l=%d r=%d", scored, self.score.l, self.score.r))
	if self.score.l >= g.goals_to || self.score.r >= g.goals_to {
		self.score.won = scored
	}
}
