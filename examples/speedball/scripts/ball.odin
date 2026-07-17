//gd:extends Node2D
//gd:class Ball
package speedball

// THE CONTESTED OBJECT — the predict-the-contested-object pattern, showcased.
//
// `@(gd_tick="contested")` means EVERY peer predicts this ball, owner or
// not: your dribbles and kicks resolve on YOUR timeline the frame you make
// them, at any latency — the whole reason the pattern exists. The server's
// simulation stays the only truth; when two screens disagree (an opponent
// you render in the past touched it first), the reconcile snaps the sim and
// the glide hides the loss. The honest costs, documented where they live:
// resim CPU on every peer, and a mispredict whenever a REMOTE kicker beats
// you to a touch you already predicted.
//
// The FLIGHT is the shelf's now: psim.Roller carries x/y/vx/vy (predicted
// through the embed) and integrates friction, the BALL_MAX ceiling, and the
// energy-eating wall bounce — timelines laws #5 and #6, packaged. What this
// tick keeps is the GAME: the kickoff freeze and the goal. Detection reads
// the roller's last clamp (block ticks run after this proc, so a crossing
// landed exactly ON the goal line last tick); even the RESET is predicted —
// every screen snaps the ball to center the instant ITS simulation sees the
// line crossed, no round trip. Only the SCORE is authority business: the
// tick returns `scored` as a fact, and ball_tick_then (speedball.odin)
// lands it on the delta lane.

import gd "godot:godot"
import knet "godot:kit/net"
import psim "godot:play/sim"

Ball :: struct {
	owner:  gd.Node2d,
	skin:   gd.Polygon2d `gd:"onready=Skin"`,
	net_id: knet.Net_Id,

	// The sim lane — contested: predicted on every screen. The physics ride
	// the embed (config — friction/cap/bounce/walls — is set at spawn).
	roll: psim.Roller,
	hold: u16 `gd:"replicate,predict"`, // kickoff freeze, itself predicted

	// The delta lane beside it — the authority's ledger of consequence, as
	// ONE field: the scoreboard is one VALUE (l, r, and the match verdict
	// move together on a goal), so co-locating it makes it dirty as one,
	// ship as one, and EDGE as one — ball_score_edge (speedball.odin) gets
	// the whole old/new atomically and fires ONCE even when a goal moves
	// two members. The co-location idiom: fields that edge together are one
	// struct; the diff atom is the field.
	score: Score `gd:"replicate"`,

	// Local scratch.
	placed: bool,
}

// The scoreboard — one value, edged and shipped atomically through the
// single tagged field above.
Score :: struct {
	l, r: u8,
	won:  u8, // 0 = playing; 1/2 = that team took the match
}

@(gd_tick = "contested")
ball_tick :: proc(self: ^Ball) -> (scored: u8) {
	if self.score.won != 0 || self.hold > 0 {
		// Frozen: zero the intent and the roller integrates a no-op.
		self.roll.vx = 0
		self.roll.vy = 0
		if self.hold > 0 {
			self.hold -= 1
		}
		return
	}

	// The goal: the roller clamps a crossing exactly ON the line (walls
	// bounce, with restitution — full-speed returns made every rally a
	// ping-pong), so a ball AT the line with its post-move y in the mouth
	// crossed there last tick. Outside the mouth the bounce already turned
	// it around — no goal, same as ever.
	in_mouth := self.roll.y > GOAL_TOP && self.roll.y < GOAL_BOT
	if in_mouth && self.roll.x <= GOAL_LINE_L {
		scored = 2 // the RIGHT team put it in the LEFT goal
	}
	if in_mouth && self.roll.x >= GOAL_LINE_R {
		scored = 1
	}

	if scored != 0 {
		// The reset is SIM, so it predicts: every screen's own simulation
		// snaps the ball home and starts the freeze the moment IT sees the
		// goal — the authority's score arrives as ordinary deltas meanwhile.
		self.roll.x = PITCH_W / 2
		self.roll.y = PITCH_H / 2
		self.roll.vx = 0
		self.roll.vy = 0
		self.hold = KICKOFF_HOLD
	}
	return
}

// THE SPIKE — a tick-scheduled verb on a CONTESTED entity, showcased: any
// kicker in reach slams the ball away from where they stand. Everything the
// world pass's held-kick contact isn't: DISCRETE (a press), REJECTABLE (out
// of reach, dead ball — the predicate arbitrates two same-tick spikes by
// execution order), and RELATIVE — so the impulse lives in the _apply half,
// which resims re-run with the ledgered args against corrected state. The
// position args are the issuer's own screen's (the door_toggle pattern);
// bursts inside one RTT ride the pending chain.
@(gd_command)
ball_spike :: proc(self: ^Ball, px, py: f32) -> bool {
	if self.score.won != 0 || self.hold > 0 {return false}
	dx := self.roll.x - px
	dy := self.roll.y - py
	if dx * dx + dy * dy > SPIKE_REACH * SPIKE_REACH {return false}
	return true
}

ball_spike_apply :: proc(self: ^Ball, px, py: f32) {
	dir := normalized({self.roll.x - px, self.roll.y - py})
	if dir.x == 0 && dir.y == 0 {
		dir = {1, 0} // dead-center spike: pick a lane, deterministically
	}
	self.roll.vx += dir.x * SPIKE_POWER
	self.roll.vy += dir.y * SPIKE_POWER
}

ball_process :: proc(self: ^Ball, delta: f64) {
	if !self.placed {
		self.placed = true
		gd.polygon2d_set_color(self.skin, {0.95, 0.95, 0.9, 1})
	}
	gd.node2d_set_position(cast(gd.Node2d)self.owner, {self.roll.x, self.roll.y})
}
