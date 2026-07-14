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
// Even the GOAL RESET is predicted: detection and the kickoff freeze live in
// this tick, so every screen snaps the ball to center the instant ITS
// simulation sees the line crossed — no round trip on the reset. Only the
// SCORE is authority business: the tick returns `scored` as a fact, and
// ball_tick_then (speedball.odin) lands it on the delta lane.

import gd "godot:godot"
import knet "godot:kit/net"

Ball :: struct {
	owner:  gd.Node2d,
	skin:   gd.Polygon2d `gd:"onready=Skin"`,
	net_id: knet.Net_Id,

	// The sim lane — contested: predicted on every screen.
	x, y:   f32 `gd:"replicate,predict,interp"`,
	vx, vy: f32 `gd:"replicate,predict"`,
	hold:   u16 `gd:"replicate,predict"`, // kickoff freeze, itself predicted

	// The delta lane beside it — the authority's ledger of consequence.
	score_l: u8 `gd:"replicate"`,
	score_r: u8 `gd:"replicate"`,
	won:     u8 `gd:"replicate"`, // 0 = playing; 1/2 = that team took the match

	// Local scratch.
	placed: bool,
}

@(gd_tick = "contested")
ball_tick :: proc(self: ^Ball) -> (scored: u8) {
	if self.won != 0 || self.hold > 0 {
		self.vx = 0
		self.vy = 0
		if self.hold > 0 {
			self.hold -= 1
		}
		return
	}

	self.vx *= FRICTION
	self.vy *= FRICTION
	// The speed ceiling — deterministic, in the tick, so every peer's
	// prediction clamps identically.
	sp2 := self.vx * self.vx + self.vy * self.vy
	if sp2 > BALL_MAX * BALL_MAX {
		s := BALL_MAX / f32(sqrt_f32(sp2))
		self.vx *= s
		self.vy *= s
	}
	self.x += self.vx
	self.y += self.vy

	// Walls bounce; the goal mouths swallow.
	in_mouth := self.y > GOAL_TOP && self.y < GOAL_BOT
	if self.x <= GOAL_LINE_L {
		if in_mouth {
			scored = 2 // the RIGHT team put it in the LEFT goal
		} else {
			self.x = GOAL_LINE_L
			self.vx = -self.vx
		}
	}
	if self.x >= GOAL_LINE_R {
		if in_mouth {
			scored = 1
		} else {
			self.x = GOAL_LINE_R
			self.vx = -self.vx
		}
	}
	if self.y <= PITCH_WALL + BALL_R {
		self.y = PITCH_WALL + BALL_R
		self.vy = -self.vy
	}
	if self.y >= PITCH_H - PITCH_WALL - BALL_R {
		self.y = PITCH_H - PITCH_WALL - BALL_R
		self.vy = -self.vy
	}

	if scored != 0 {
		// The reset is SIM, so it predicts: every screen's own simulation
		// snaps the ball home and starts the freeze the moment IT sees the
		// goal — the authority's score arrives as ordinary deltas meanwhile.
		self.x = PITCH_W / 2
		self.y = PITCH_H / 2
		self.vx = 0
		self.vy = 0
		self.hold = KICKOFF_HOLD
	}
	return
}

ball_process :: proc(self: ^Ball, delta: f64) {
	if !self.placed {
		self.placed = true
		gd.polygon2d_set_color(self.skin, {0.95, 0.95, 0.9, 1})
	}
	gd.node2d_set_position(cast(gd.Node2d)self.owner, {self.x, self.y})
}
