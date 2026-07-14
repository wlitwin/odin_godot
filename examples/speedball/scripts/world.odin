package speedball

// Census hooks + spawns. Note what is NOT here: no lane calls at all — the
// generated kinds rows carry kicker_sim_set and ball_sim_set (the ball's
// marked contested), and boot_lane's factory does the tracking.

import "core:fmt"
import gd "godot:godot"
import knet "godot:kit/net"
import ksess "godot:kit/session"

// The census hooks, down to the game-shaped lines — the generated queries
// (kicker_of / kicker_ids / kicker_owned_by, kboot.boot_entity_owner) answer
// everything the old three maps did.
kicker_spawned :: proc(game: ^Speedball, self: ^Kicker, id: knet.Net_Id, owner: knet.Player_Id) {
	// The mover's LAW half — config is never on the wire, so every peer
	// stamps the same numbers here, before the first tick.
	self.run.accel = RUN_ACCEL
	self.run.min_x = PITCH_WALL + KICKER_R
	self.run.max_x = PITCH_W - PITCH_WALL - KICKER_R
	self.run.min_y = PITCH_WALL + KICKER_R
	self.run.max_y = PITCH_H - PITCH_WALL - KICKER_R
	if owner != knet.PLAYER_ID_INVALID && owner == game.ses.me {
		self.mine = true
		game.me_kick = self
	}
	gd.print_str(fmt.tprintf("SPB_SPAWN id=%d mine=%v", u32(id), owner == game.ses.me))
}

kicker_freed :: proc(game: ^Speedball, self: ^Kicker, id: knet.Net_Id) {
	if self == game.me_kick {
		game.me_kick = nil
	}
}

ball_spawned :: proc(game: ^Speedball, self: ^Ball, id: knet.Net_Id, owner: knet.Player_Id) {
	// The roller's LAW half — friction, ceiling, restitution, walls: the
	// same numbers on every peer, stamped before the first tick.
	self.roll.friction = FRICTION
	self.roll.max_speed = BALL_MAX
	self.roll.bounce = WALL_BOUNCE
	self.roll.min_x = GOAL_LINE_L
	self.roll.max_x = GOAL_LINE_R
	self.roll.min_y = PITCH_WALL + BALL_R
	self.roll.max_y = PITCH_H - PITCH_WALL - BALL_R
	game.ball = self
}

ball_freed :: proc(game: ^Speedball, self: ^Ball, id: knet.Net_Id) {
	if game.ball == self {
		game.ball = nil
	}
}

spawn_world :: proc(self: ^Speedball) {
	if self.ball != nil {return}
	bp, bid := ksess.session_spawn_make(&self.ses, BALL_TYPE)
	b := cast(^Ball)bp
	b.roll.x = PITCH_W / 2
	b.roll.y = PITCH_H / 2
	b.hold = KICKOFF_HOLD
	ksess.session_spawn_send(&self.ses, bid)

	for _, p in self.ses.players {
		if !p.connected {continue}
		if p.dedicated {continue}
		spawn_kicker(self, p.id)
	}
	ksess.session_start_replicating(&self.ses)
	gd.print_str("SPB_WORLD_UP")
}

spawn_kicker :: proc(self: ^Speedball, pid: knet.Player_Id) {
	if _, has := kicker_owned_by(&self.boot, pid); has {return}
	kp, kid := ksess.session_spawn_make(&self.ses, KICKER_TYPE, owner = pid)
	k := cast(^Kicker)kp
	k.pid = u8(pid)
	spot := SPAWNS[int(pid) % len(SPAWNS)]
	k.run.x = spot[0]
	k.run.y = spot[1]
	ksess.session_spawn_send(&self.ses, kid)
}
