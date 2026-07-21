package claimball

// Census hooks + spawns. Note what is NOT here: no lane calls at all — the
// generated kinds rows carry kicker_sim_set and ball_sim_set (the ball's
// marked contested), and boot_lane's factory does the tracking.

import "core:fmt"
import gd "godot:godot"
import kboot "godot:kit/boot"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import psim "godot:play/sim"

// The census hooks, down to the game-shaped lines — the generated queries
// (kicker_of / kicker_ids / kicker_owned_by, kboot.boot_entity_owner) answer
// everything the old three maps did.
@(gd_half)
kicker_spawned :: proc(game: ^Claimball, self: ^Kicker, id: knet.Net_Id, owner: knet.Player_Id) {
	// The mover's LAW half — config is never on the wire, so every peer
	// stamps the same numbers here, before the first tick. One call names
	// every field: leave one out and it won't compile (vs a silently-zero
	// bound that clamps this peer's movement to the origin).
	psim.mover_arm(
		&self.run,
		accel = RUN_ACCEL,
		min_x = PITCH_WALL + KICKER_R,
		min_y = PITCH_WALL + KICKER_R,
		max_x = PITCH_W - PITCH_WALL - KICKER_R,
		max_y = PITCH_H - PITCH_WALL - KICKER_R,
	)
	if owner != knet.PLAYER_ID_INVALID && owner == game.ses.me {
		self.mine = true
		game.me_kick = self
	}
	gd.print_str(fmt.tprintf("CLB_SPAWN id=%d mine=%v", u32(id), owner == game.ses.me))
}

@(gd_half)
kicker_freed :: proc(game: ^Claimball, self: ^Kicker, id: knet.Net_Id) {
	if self == game.me_kick {
		game.me_kick = nil
	}
}

@(gd_half)
ball_spawned :: proc(game: ^Claimball, self: ^Ball, id: knet.Net_Id, owner: knet.Player_Id) {
	// The roller's LAW half — friction, ceiling, restitution, walls: the
	// same numbers on every peer, stamped before the first tick.
	psim.roller_arm(
		&self.roll,
		friction = FRICTION,
		max_speed = BALL_MAX,
		bounce = WALL_BOUNCE,
		min_x = GOAL_LINE_L,
		min_y = PITCH_WALL + BALL_R,
		max_x = GOAL_LINE_R,
		max_y = PITCH_H - PITCH_WALL - BALL_R,
	)
	game.ball = self
}

@(gd_half)
ball_freed :: proc(game: ^Claimball, self: ^Ball, id: knet.Net_Id) {
	if game.ball == self {
		game.ball = nil
	}
}

spawn_world :: proc(self: ^Claimball) {
	if self.ball != nil {return}
	b, bid := ball_spawn(&self.boot) // typed, from the entity tag — no const, no cast
	b.roll.x = PITCH_W / 2
	b.roll.y = PITCH_H / 2
	b.hold = KICKOFF_HOLD
	kboot.boot_spawn_send(&self.boot, bid)

	for _, p in self.ses.players {
		if !p.connected {continue}
		if p.dedicated {continue}
		spawn_kicker(self, p.id)
	}
	ksess.session_start_replicating(&self.ses)
	gd.print_str("CLB_WORLD_UP")
}

spawn_kicker :: proc(self: ^Claimball, pid: knet.Player_Id) {
	if _, has := kicker_owned_by(&self.boot, pid); has {return}
	k, kid := kicker_spawn(&self.boot, owner = pid)
	k.pid = u8(pid)
	spot := SPAWNS[int(pid) % len(SPAWNS)]
	k.run.x = spot[0]
	k.run.y = spot[1]
	kboot.boot_spawn_send(&self.boot, kid)
}
