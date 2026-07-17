package slopball3d

// The host's tick: seat arbitration (last toucher owns the ball), goals off
// the replicated pose, and the match. All of it reads STREAMED state — the
// host needs no private physics knowledge, which is what lets any peer
// simulate the ball at any moment. The arbitration is the 2D pitch's tuned
// ruleset verbatim; distances are GROUND-PLANE (XZ) so a lofted pass sailing
// over a kicker's head still reads as "near" only when it actually is.

import gd "godot:godot"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import play "godot:play"
import "core:fmt"
import "core:math"

// The attribute is the whole wiring: generated `slopball3_step(self, ticks)`
// runs this on the AUTHORITY alone off boot_pump's accumulator, then fires
// the host's fresh edges same-frame — no is_host in the shell.
@(gd_step = "authority")
slop3_host_tick :: proc(self: ^Slopball3) {
	b := self.ball
	if b == nil || b.score.won != 0 {return}

	// Kickoff hold: the ball rests at center under the HOST's seat until the
	// whistle. session_teleport made every screen snap it there.
	if self.kickoff_at != 0 {
		if now_s() < self.kickoff_at {return}
		self.kickoff_at = 0
	}

	// THE SEAT: the nearest kicker inside TOUCH_R takes the simulation —
	// granted a step BEFORE contact, so the touch itself resolves on the
	// toucher's own solver (that pre-grant is what makes kicks feel local).
	if now_s() >= self.grant_at {
		cur := ksess.session_owner_of(&self.ses, self.ball_id)
		best: knet.Player_Id = knet.PLAYER_ID_INVALID
		best_d := TOUCH_R * TOUCH_R
		cur_d := f32(1e9) // the sitting owner's own distance (possession is sticky)
		for _, k in self.kickers {
			pid := knet.Player_Id(k.pid)
			moved := abs(k.pos.x - k.hx) + abs(k.pos.z - k.hz) // intent: this tick's stride
			k.hx = k.pos.x
			k.hz = k.pos.z
			if p, ok := ksess.session_player(&self.ses, pid); !ok || !p.connected {continue}
			dx := k.pos.x - b.puppet.pos.x
			dz := k.pos.z - b.puppet.pos.z
			d := dx * dx + dz * dz
			if pid == cur {cur_d = d}
			if moved < INTENT_SPEED && pid != cur {continue} // statues never claim
			if d < best_d {
				best_d = d
				best = pid
			}
		}
		// STICKY possession + HELD challenges: the full 2D ruleset (see
		// slopball's host.odin for the derivation of every clause).
		challenge_at := math.sqrt(cur_d) - GRANT_EDGE
		challenging := best != knet.PLAYER_ID_INVALID && best != cur &&
			(cur_d > TOUCH_R * TOUCH_R || math.sqrt(best_d) < challenge_at)
		if !challenging {
			self.challenger = knet.PLAYER_ID_INVALID
		} else {
			if best != self.challenger {
				self.challenger = best
				self.challenge_since = now_s()
			}
			speed_sq := b.puppet.vel.x * b.puppet.vel.x + b.puppet.vel.z * b.puppet.vel.z
			hold := best_d <= CONTACT_R * CONTACT_R ? CHALLENGE_HOLD / 3 : CHALLENGE_HOLD
			held := now_s() - self.challenge_since >= hold
			if speed_sq <= BALL_SLOW * BALL_SLOW || held {
				ksess.session_set_owner(&self.ses, self.ball_id, best)
				self.grant_at = now_s() + GRANT_COOL
				self.challenger = knet.PLAYER_ID_INVALID
			}
		}
	}

	// GOALS, off the streamed pose: behind the left line in the mouth = the
	// RIGHT team scored (and vice versa). The mouth is a z-range on the goal
	// line; height doesn't gate it (the backstop walls are the crossbar).
	if b.puppet.pos.z >= GOAL_MOUTH_NEAR && b.puppet.pos.z <= GOAL_MOUTH_FAR {
		scored := u8(0)
		if b.puppet.pos.x < 0.15 {scored = 2}
		if b.puppet.pos.x > PITCH_W - 0.15 {scored = 1}
		if scored != 0 {
			if scored == 1 {b.score.l += 1} else {b.score.r += 1}
			gd.print_str(fmt.tprintf("SB3_GOAL by=%d l=%d r=%d", scored, b.score.l, b.score.r))
			if int(b.score.l) >= self.goals_to || int(b.score.r) >= self.goals_to {
				b.score.won = scored
				return
			}
			reset_kickoff(self)
		}
	}
}

// The whistle: host takes the seat back, teleports the ball to center (every
// screen snaps — session_teleport suppresses the cross-pitch slide), and
// holds it there for a beat.
reset_kickoff :: proc(self: ^Slopball3) {
	ksess.session_set_owner(&self.ses, self.ball_id, self.ses.me)
	seat_ball(self, self.ses.me)
	play.puppet3_place(&self.ball.puppet, {PITCH_W / 2, BALL_REST_Y, PITCH_D / 2})
	ksess.session_teleport(&self.ses, self.ball_id)
	self.kickoff_at = now_s() + KICKOFF_HOLD
}
