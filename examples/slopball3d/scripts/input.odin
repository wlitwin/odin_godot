package slopball3d

// My kicker: WASD -> move_and_slide (XZ plane) -> publish the pose onto my
// owner stream. The autopilot (SLOP3_BOT) drives the same path the hands do —
// the acid tests steer with the production movement code, not a side door.

import gd "godot:godot"
import ksess "godot:kit/session"
import play "godot:play"
import "core:math"

install_controls :: proc "contextless" () {
	if gd.has_action("slop3_left") {return} // scene reloads re-run ready
	bind :: proc "contextless" (action: cstring, keys: ..i64) {
		gd.add_action(action)
		for k in keys {
			gd.action_add_key(action, k)
		}
	}
	bind("slop3_left", i64('A'), i64(gd.Key.Left))
	bind("slop3_right", i64('D'), i64(gd.Key.Right))
	bind("slop3_up", i64('W'), i64(gd.Key.Up))
	bind("slop3_down", i64('S'), i64(gd.Key.Down))
	bind("slop3_kick", i64(gd.Key.Space))
}

drive_my_kicker :: proc(self: ^Slopball3, delta: f64) {
	me := self.me_kick // set at BORN (slopball3_entity_spawned): a placed body, or nothing to drive
	if me == nil {return}

	typing := bool(gd.control_has_focus(cast(gd.Control)self.boot.chat.input, false))
	dir: [3]f32 // screen-up is -z: W walks toward the far sideline
	if self.bot != "" {
		dir = bot_steer(self)
	} else if !typing {
		if gd.is_action_pressed("slop3_left") {dir.x -= 1}
		if gd.is_action_pressed("slop3_right") {dir.x += 1}
		if gd.is_action_pressed("slop3_up") {dir.z -= 1}
		if gd.is_action_pressed("slop3_down") {dir.z += 1}
	}
	dir = normalized_xz(dir)

	// The engine does the collision: walls stop me, the frozen ball is solid.
	// Kickers live ON the floor plane — no gravity, no vertical velocity.
	gd.character_body3d_set_velocity(me.owner, {dir.x * KICKER_SPEED, 0, dir.z * KICKER_SPEED})
	gd.character_body3d_move_and_slide(me.owner)
	me.pos = gd.node3d_get_position(cast(gd.Node3d)me.owner)

	// DRIBBLE: move_and_slide does NOT push rigid bodies — a walking contact
	// imparts nothing on its own (the classic Godot gotcha, same in 3D). While
	// MY solver runs the ball — seated OR claimed — nudge it along my motion
	// each contact frame, capped so a dribbled ball never outruns a kicked one.
	if self.ball != nil && (dir.x != 0 || dir.z != 0) {
		bp := gd.node3d_get_position(cast(gd.Node3d)self.ball.owner)
		bdx := bp.x - me.pos.x
		bdz := bp.z - me.pos.z
		if bdx * bdx + bdz * bdz <= DRIBBLE_R * DRIBBLE_R && bp.y < 0.6 {
			has := ksess.session_owner_of(&self.ses, self.ball_id) == self.ses.me ||
				self.ball.puppet.claimed
			if !has && self.ball.score.won == 0 {
				// PREDICTED POSSESSION: my screen sees the touch NOW; seize
				// the sim on spec. The host's grant confirms in ~a round
				// trip — or the claim melts away, smoothed.
				play.puppet3_claim(&self.ball.puppet)
				has = true
			}
			bv := self.ball.puppet.vel
			if has && bv.x * bv.x + bv.z * bv.z < KICKER_SPEED * KICKER_SPEED * 2 {
				play.puppet3_shove(&self.ball.puppet, {dir.x * DRIBBLE_NUDGE, 0, dir.z * DRIBBLE_NUDGE})
			}
		}
	}

	// The boot: while MY solver runs the ball and it's in reach, punt it away
	// from me — all local, all instant (that is the whole point of the seat).
	// A 3D kick lofts: the arc is what exercises y and the tumble.
	want_kick := (self.bot == "striker" && self.ball != nil && self.ball.score.won == 0) ||
		(self.bot == "" && !typing && gd.is_action_just_pressed("slop3_kick"))
	if want_kick && self.ball != nil && now_s() >= self.kick_cool &&
	   (ksess.session_owner_of(&self.ses, self.ball_id) == self.ses.me || self.ball.puppet.claimed) {
		bpk := gd.node3d_get_position(cast(gd.Node3d)self.ball.owner)
		dx, dz := bpk.x - me.pos.x, bpk.z - me.pos.z
		if dx * dx + dz * dz <= KICK_REACH * KICK_REACH && bpk.y < 0.6 {
			aim := kick_aim(self, {dx, 0, dz})
			play.puppet3_shove(&self.ball.puppet, {aim.x * KICK_POWER, KICK_LOFT, aim.z * KICK_POWER})
			self.kick_cool = now_s() + 0.25
			gd.print_str("SB3_KICK")
		}
	}
}

// A human kick goes where you push; the striker bot aims at the OPPONENT goal.
kick_aim :: proc(self: ^Slopball3, away: [3]f32) -> [3]f32 {
	if self.bot == "striker" && self.me_kick != nil {
		gx: f32 = kicker3_team(self.me_kick.pid) == 1 ? PITCH_W : 0 // team 1 scores RIGHT
		b := self.ball.puppet.pos
		return normalized_xz({gx - b.x, 0, PITCH_D / 2 - b.z})
	}
	return normalized_xz(away)
}

// The striker walks at the ball (slightly behind it, so contact pushes goalward);
// idle bots stand there being defenders.
bot_steer :: proc(self: ^Slopball3) -> [3]f32 {
	if self.ball == nil || self.me_kick == nil {return {}}
	if self.bot == "chaser" {
		// The repro dog: runs at the ball forever, never kicks — possession
		// trades by contact, the way humans dribble into each other.
		b := self.ball.puppet.pos
		return normalized_xz({b.x - self.me_kick.pos.x, 0, b.z - self.me_kick.pos.z})
	}
	if self.bot != "striker" {return {}}
	if self.ball.score.won != 0 {return {}}
	me := self.me_kick
	b := self.ball.puppet.pos
	gx: f32 = kicker3_team(me.pid) == 1 ? PITCH_W : 0
	behind := normalized_xz({b.x - gx, 0, b.z - PITCH_D / 2}) // from goal, through the ball
	tx := b.x + behind.x * 0.1
	tz := b.z + behind.z * 0.1
	d := [3]f32{tx - me.pos.x, 0, tz - me.pos.z}
	if math.abs(d.x) < 0.05 && math.abs(d.z) < 0.05 {return {}}
	return normalized_xz(d)
}
