package slopball3d

// Spawns + the census hooks. The FACTORY is generated: each scene field's
// `entity=Name:id` tag (slopball3d.odin) declares what the scene bodies and
// its wire id; kboot.boot_entities instantiates/frees under boot.world and
// keeps the id→node ledger. What's left here is the game-shaped half — the
// typed *_spawned/*_freed hooks that keep the by-type maps.

import gd "godot:godot"
import kboot "godot:kit/boot"
import knet "godot:kit/net"
import ksess "godot:kit/session"

@(gd_half)
kicker3_spawned :: proc(game: ^Slopball3, self: ^Kicker3, id: knet.Net_Id, owner: knet.Player_Id) {
	game.kickers[id] = self
	if owner != knet.PLAYER_ID_INVALID {
		game.avatar_of[owner] = id
		if owner == game.ses.me {
			self.mine = true
			game.me_kick = self
		}
	}
}

@(gd_half)
kicker3_freed :: proc(game: ^Slopball3, self: ^Kicker3, id: knet.Net_Id) {
	if self == game.me_kick {
		game.me_kick = nil
	}
	delete_key(&game.kickers, id)
}

@(gd_half)
ball3_spawned :: proc(game: ^Slopball3, self: ^Ball3, id: knet.Net_Id, owner: knet.Player_Id) {
	game.ball = self
	game.ball_id = id
}

@(gd_half)
ball3_freed :: proc(game: ^Slopball3, self: ^Ball3, id: knet.Net_Id) {
	if game.ball_id == id {
		game.ball = nil
		game.ball_id = 0
	}
}

// Host: the pitch fills — one ball (host simulates it first), one kicker per
// seated player, spread along their team's half.
spawn_world :: proc(self: ^Slopball3) {
	if self.ball != nil {return} // the started flag flips on the EVENT; this guard is synchronous
	ball, bid := ball3_spawn(&self.boot, owner = self.ses.me) // typed, from the entity tag — no const, no cast
	ball.puppet.pos = {PITCH_W / 2, BALL_REST_Y, PITCH_D / 2}
	kboot.boot_spawn_send(&self.boot, bid)
	seat_ball(self, self.ses.me)
	self.kickoff_at = now_s() + KICKOFF_HOLD

	for _, p in self.ses.players {
		if !p.connected {continue}
		spawn_kicker(self, p.id)
	}
	// Go live: ship the full world to every seated client and start the
	// per-tick delta walk (later joiners get it right behind their WELCOME).
	ksess.session_start_replicating(&self.ses)
	gd.print_str("SB3_WORLD_UP")
}

// Host: one avatar for `pid`, placed on its team's side of the center line.
spawn_kicker :: proc(self: ^Slopball3, pid: knet.Player_Id) {
	if _, has := self.avatar_of[pid]; has {return}
	k, kid := kicker3_spawn(&self.boot, owner = pid)
	k.pid = u8(pid)
	team := kicker3_team(k.pid)
	rank := (int(pid) - int(team)) / 2 // 0,1,2.. within the team
	off := [4]f32{-1.75, 1.75, -3, 3}
	// Fan the team OFF the center lane: a kickoff shot at the goal mouth must
	// not thread a parked teammate (the 2D acid learned this as an own-goal).
	k.pos = {
		team == 1 ? PITCH_W / 2 - 3 : PITCH_W / 2 + 3,
		0,
		PITCH_D / 2 + off[rank % 4],
	}
	kboot.boot_spawn_send(&self.boot, kid)
}
