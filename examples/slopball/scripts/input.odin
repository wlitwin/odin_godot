package slopball

// My kicker: WASD -> move_and_slide -> publish the pose onto my owner stream.
// The autopilot (SLOP_BOT) drives the same path the hands do — the acid tests
// steer with the production movement code, not a side door.

import gd "godot:godot"
import ksess "godot:kit/session"
import play "godot:play"
import "core:math"

install_controls :: proc "contextless" () {
	if gd.has_action("slop_left") {return} // scene reloads re-run ready
	bind :: proc "contextless" (action: cstring, keys: ..i64) {
		gd.add_action(action)
		for k in keys {
			gd.action_add_key(action, k)
		}
	}
	bind("slop_left", i64('A'), i64(gd.Key.Left))
	bind("slop_right", i64('D'), i64(gd.Key.Right))
	bind("slop_up", i64('W'), i64(gd.Key.Up))
	bind("slop_down", i64('S'), i64(gd.Key.Down))
	bind("slop_kick", i64(gd.Key.Space))
}

drive_my_kicker :: proc(self: ^Slopball, delta: f64) {
	me := self.me_kick
	if me == nil {return}
	if !me.placed {
		// Ev_Spawned means BORN — the replicated x/y are set; put the BODY there
		// once (the scene instanced it at the origin, inside the corner walls).
		me.placed = true
		gd.node2d_set_position(cast(gd.Node2d)me.owner, {me.x, me.y})
	}

	typing := bool(gd.control_has_focus(cast(gd.Control)self.boot.chat.input, false))
	dir: gd.Vector2
	if self.bot != "" {
		dir = bot_steer(self)
	} else if !typing {
		if gd.is_action_pressed("slop_left") {dir.x -= 1}
		if gd.is_action_pressed("slop_right") {dir.x += 1}
		if gd.is_action_pressed("slop_up") {dir.y -= 1}
		if gd.is_action_pressed("slop_down") {dir.y += 1}
	}
	dir = normalized(dir)

	// The engine does the collision: walls stop me, the frozen ball is solid.
	gd.character_body2d_set_velocity(me.owner, {dir.x * KICKER_SPEED, dir.y * KICKER_SPEED})
	gd.character_body2d_move_and_slide(me.owner)
	pos := gd.node2d_get_position(cast(gd.Node2d)me.owner)
	me.x = pos.x
	me.y = pos.y

	// DRIBBLE: move_and_slide does NOT push rigid bodies — a walking contact
	// imparts nothing on its own (the classic Godot 4 gotcha). While MY solver
	// runs the ball — seated OR claimed — nudge it along my motion each
	// contact frame, capped so a dribbled ball never outruns a kicked one.
	if self.ball != nil && (dir.x != 0 || dir.y != 0) {
		bp := gd.node2d_get_position(cast(gd.Node2d)self.ball.owner)
		bdx := bp.x - me.x
		bdy := bp.y - me.y
		if bdx*bdx + bdy*bdy <= DRIBBLE_R * DRIBBLE_R {
			has := ksess.session_owner_of(&self.ses, self.ball_id) == self.ses.me ||
				self.ball.puppet.claimed
			if !has && self.ball.won == 0 {
				// PREDICTED POSSESSION: my screen sees the touch NOW; seize
				// the sim on spec. The host's grant (intent + contact rules,
				// the same ones we mirror by touching) confirms in ~a
				// round-trip — or the claim melts away, smoothed.
				play.puppet_claim(&self.ball.puppet)
				has = true
			}
			bv := self.ball.puppet
			if has && bv.vx*bv.vx + bv.vy*bv.vy < KICKER_SPEED * KICKER_SPEED * 2 {
				play.puppet_shove(&self.ball.puppet, dir.x * DRIBBLE_NUDGE, dir.y * DRIBBLE_NUDGE)
			}
		}
	}

	// The boot: while MY solver runs the ball and it's in reach, punt it away
	// from me — all local, all instant (that is the whole point of the seat).
	want_kick := (self.bot == "striker" && self.ball != nil && self.ball.won == 0) ||
		(self.bot == "" && !typing && gd.is_action_just_pressed("slop_kick"))
	if want_kick && self.ball != nil && now_s() >= self.kick_cool &&
	   (ksess.session_owner_of(&self.ses, self.ball_id) == self.ses.me || self.ball.puppet.claimed) {
		bpk := gd.node2d_get_position(cast(gd.Node2d)self.ball.owner)
		bx, by := bpk.x, bpk.y
		dx, dy := bx - pos.x, by - pos.y
		if dx*dx + dy*dy <= KICK_REACH * KICK_REACH {
			aim := kick_aim(self, {dx, dy})
			play.puppet_shove(&self.ball.puppet, aim.x * KICK_POWER, aim.y * KICK_POWER)
			self.kick_cool = now_s() + 0.25
			gd.print_str("SB_KICK")
		}
	}
}

// A human kick goes where you push; the striker bot aims at the OPPONENT goal.
kick_aim :: proc(self: ^Slopball, away: gd.Vector2) -> gd.Vector2 {
	if self.bot == "striker" && self.me_kick != nil {
		gx: f32 = kicker_team(self.me_kick.pid) == 1 ? PITCH_W : 0 // team 1 scores RIGHT
		return normalized({gx - self.ball.puppet.x, PITCH_H/2 - self.ball.puppet.y})
	}
	return normalized(away)
}

// The striker walks at the ball (slightly behind it, so contact pushes goalward);
// idle bots stand there being defenders.
bot_steer :: proc(self: ^Slopball) -> gd.Vector2 {
	if self.ball == nil || self.me_kick == nil {return {}}
	if self.bot == "chaser" {
		// The repro dog: runs at the ball forever, never kicks — possession
		// trades by contact, the way humans dribble into each other.
		d := gd.Vector2{self.ball.puppet.x - self.me_kick.x, self.ball.puppet.y - self.me_kick.y}
		return normalized(d)
	}
	if self.bot != "striker" {return {}}
	if self.ball.won != 0 {return {}}
	me := self.me_kick
	bx, by := self.ball.puppet.x, self.ball.puppet.y
	gx: f32 = kicker_team(me.pid) == 1 ? PITCH_W : 0
	behind := normalized({bx - gx, by - PITCH_H/2}) // from goal, through the ball
	tx := bx + behind.x*4
	ty := by + behind.y*4
	d := gd.Vector2{tx - me.x, ty - me.y}
	if math.abs(d.x) < 2 && math.abs(d.y) < 2 {return {}}
	return normalized(d)
}
