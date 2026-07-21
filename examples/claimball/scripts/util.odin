package claimball

// util — the pitch's shared math (no //gd:class, scriptgen skips this file).
// All pure, all per-tick: the ball and the kickers are resimmable arithmetic.

import gd "godot:godot"
import "core:math"

PITCH_W :: f32(640)
PITCH_H :: f32(360)
PITCH_WALL :: f32(12)
KICKER_R :: f32(9)
BALL_R :: f32(8)

RUN_SPEED :: f32(2.2) // px/tick at 60 Hz
RUN_ACCEL :: f32(0.35) // velocity approach per tick — MOMENTUM is the
	// extrapolation smoother (the Rocket League trick): a kicker that can't
	// stop instantly diverges SLOWLY from its held-input extrapolation, so a
	// remote stop reads as "slowed a beat late", not a 20px pull-back
KICK_REACH :: f32(30)
KICK_POWER :: f32(6.5) // px/tick impulse
KICK_CD :: u16(20)

// The CLAIM (claimball's whole point). CLAIM_REACH is the influence radius — a
// touch inside it presents the ball from MY predicted timeline (lane_claim);
// wider than KICK_REACH so a dribble claims it, not just a kick. RELEASE_SPEED
// is where the flight my kick started counts as SPENT: below it the predicted
// and watched timelines have nearly converged, so the handback to the watched
// view is invisible. Releasing on DISTANCE instead would yank the kick backward
// mid-flight (the fade target sits speed×skew behind a fast ball) — the one
// footgun this example exists to get right.
CLAIM_REACH :: f32(38)
RELEASE_SPEED :: f32(0.6) // px/tick (~36 px/s at 60 Hz) — a ball this slow is spent
SPIKE_REACH :: f32(44) // the verb reaches a little past the dribble scrum
SPIKE_POWER :: f32(5.5) // per spike; the burst doubles it (BALL_MAX ceilings)
DRIBBLE_PUSH :: f32(1.1) // contact nudge — a push, not a shot
DRIBBLE_MAX :: f32(3.2) // dribbling never accelerates a ball already at dribble pace
BALL_MAX :: f32(9.0) // px/tick ceiling — slopball's lesson, ported: an uncapped
	// contact-per-tick push compounds into a wall-ricocheting blur that reads
	// as jitter on every screen (the truth itself thrashes)
FRICTION :: f32(0.985) // ball velocity retained per tick
WALL_BOUNCE :: f32(0.55) // restitution — walls eat energy, so a kicked ball
	// doesn't ping-pong back at full speed into the foot that sent it
KICKOFF_HOLD :: u16(72) // ~1.2s frozen at center after a goal

GOAL_TOP :: f32(130)
GOAL_BOT :: f32(230)
GOAL_LINE_L :: f32(PITCH_WALL + BALL_R)
GOAL_LINE_R :: f32(PITCH_W - PITCH_WALL - BALL_R)

sqrt_f32 :: proc "contextless" (v: f32) -> f32 {
	return math.sqrt(v)
}

normalized :: proc "contextless" (v: gd.Vector2) -> gd.Vector2 {
	length := math.sqrt(v.x * v.x + v.y * v.y)
	if length <= 0.00001 {return gd.Vector2{0, 0}}
	return gd.Vector2{v.x / length, v.y / length}
}

peer_color :: proc "contextless" (player_id: int) -> gd.Color {
	switch player_id % 4 {
	case 1:  return gd.Color{0.35, 0.65, 1.0, 1}
	case 2:  return gd.Color{1.0, 0.62, 0.2, 1}
	case 3:  return gd.Color{0.5, 0.9, 0.4, 1}
	case:    return gd.Color{0.9, 0.45, 0.9, 1}
	}
}

// Team by seat, slopball's rule: odd ids defend the LEFT goal.
team_of :: proc "contextless" (pid: u8) -> u8 {
	return pid % 2 == 1 ? u8(1) : u8(2)
}

SPAWNS := [4][2]f32{{200, 100}, {440, 260}, {200, 260}, {440, 100}}
