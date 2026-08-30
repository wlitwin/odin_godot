package slopball

// The host's tick: seat arbitration (last toucher owns the ball), goals off
// the replicated pose, and the match. All of it reads STREAMED state — the
// host needs no private physics knowledge, which is what lets any peer
// simulate the ball at any moment.

import gd "godot:godot"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import play "godot:play"
import "core:fmt"
import "core:math"

// The attribute is the whole wiring: generated `slopball_step(self, ticks)`
// runs this on the AUTHORITY alone off boot_pump's accumulator, then fires
// the host's fresh edges same-frame — no is_host in the shell.
@(gd_step = "authority")
slop_host_tick :: proc(self: ^Slopball) {
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
		for tracked in kicker_all(&self.boot) {
			k := tracked.entity
			pid := knet.Player_Id(k.pid)
			moved := abs(k.x - k.hx) + abs(k.y - k.hy) // intent: this tick's stride
			k.hx = k.x
			k.hy = k.y
			if p, ok := ksess.session_player(&self.ses, pid); !ok || !p.connected {continue}
			dx := k.x - b.puppet.x
			dy := k.y - b.puppet.y
			d := dx*dx + dy*dy
			if pid == cur {cur_d = d}
			if moved < INTENT_SPEED && pid != cur {continue} // statues never claim
			if d < best_d {
				best_d = d
				best = pid
			}
		}
		// STICKY possession: in a scrum both stand inside TOUCH_R and a plain
		// nearest-wins flips the seat every cooldown — the ball teleports
		// between two delayed views. A challenger must beat the sitting owner
		// by a real margin; the owner drifting away on its own loses nothing.
		challenge_at := math.sqrt(cur_d) - GRANT_EDGE
		challenging := best != knet.PLAYER_ID_INVALID && best != cur &&
			(cur_d > TOUCH_R * TOUCH_R || math.sqrt(best_d) < challenge_at)
		if !challenging {
			self.challenger = knet.PLAYER_ID_INVALID
		} else {
			// A MOVING ball demands a HELD claim: a pass rolling by a
			// bystander clips their radius for a beat — stealing the seat
			// mid-flight stutters every screen. A resting ball grants on
			// the first tick (the first touch stays snappy).
			if best != self.challenger {
				self.challenger = best
				self.challenge_since = now_s()
			}
			speed_sq := b.puppet.vx*b.puppet.vx + b.puppet.vy*b.puppet.vy
			// True contact resolves a held claim fast (a receiver trapping the
			// pass at their feet); a claim from the anticipation ring waits out
			// the full hold (a chaser converging on a through-ball).
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
	// RIGHT team scored (and vice versa). The detection lags a client
	// simulator by ~an interp delay — friendslop shrugs, the net bulges.
	if b.puppet.y >= GOAL_MOUTH_TOP && b.puppet.y <= GOAL_MOUTH_BOT {
		scored := u8(0)
		if b.puppet.x < 6 {scored = 2}
		if b.puppet.x > PITCH_W - 6 {scored = 1}
		if scored != 0 {
			if scored == 1 {b.score.l += 1} else {b.score.r += 1}
			gd.print_str(fmt.tprintf("SB_GOAL by=%d l=%d r=%d", scored, b.score.l, b.score.r))
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
reset_kickoff :: proc(self: ^Slopball) {
	ksess.session_set_owner(&self.ses, self.ball_id, self.ses.me)
	seat_ball(self, self.ses.me)
	play.puppet_place(&self.ball.puppet, PITCH_W/2, PITCH_H/2)
	_ = ball_teleport(&self.boot, self.ball_id)
	self.kickoff_at = now_s() + KICKOFF_HOLD
}
