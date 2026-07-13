package slopball

// Spawns + the census hooks. The FACTORY is generated: each scene field's
// `entity=Name:id` tag (slopball.odin) declares what the scene bodies and
// its wire id; kboot.boot_entities instantiates/frees under boot.world and
// keeps the id→node ledger. What's left here is the game-shaped half — the
// typed *_spawned/*_freed hooks that keep the by-type maps.

import gd "godot:godot"
import knet "godot:kit/net"
import ksess "godot:kit/session"

kicker_spawned :: proc(game: ^Slopball, self: ^Kicker, id: knet.Net_Id, owner: knet.Player_Id) {
	game.kickers[id] = self
	if owner != knet.PLAYER_ID_INVALID {
		game.avatar_of[owner] = id
		if owner == game.ses.me {
			self.mine = true
			game.me_kick = self
		}
	}
}

kicker_freed :: proc(game: ^Slopball, self: ^Kicker, id: knet.Net_Id) {
	if self == game.me_kick {
		game.me_kick = nil
	}
	delete_key(&game.kickers, id)
}

ball_spawned :: proc(game: ^Slopball, self: ^Ball, id: knet.Net_Id, owner: knet.Player_Id) {
	game.ball = self
	game.ball_id = id
}

ball_freed :: proc(game: ^Slopball, self: ^Ball, id: knet.Net_Id) {
	if game.ball_id == id {
		game.ball = nil
		game.ball_id = 0
	}
}

// Host: the pitch fills — one ball (host simulates it first), one kicker per
// seated player, spread along their team's half.
spawn_world :: proc(self: ^Slopball) {
	if self.ball != nil {return} // the started flag flips on the EVENT; this guard is synchronous
	bp, bid := ksess.session_spawn_make(&self.ses, BALL_TYPE, owner = self.ses.me)
	ball := cast(^Ball)bp
	ball.puppet.x = PITCH_W / 2
	ball.puppet.y = PITCH_H / 2
	ksess.session_spawn_send(&self.ses, bid)
	seat_ball(self, self.ses.me)
	self.kickoff_at = now_s() + KICKOFF_HOLD

	for _, p in self.ses.players {
		if !p.connected {continue}
		if p.dedicated {continue} // the server referees; it fields no kicker
		spawn_kicker(self, p.id)
	}
	// Go live: ship the full world to every seated client and start the
	// per-tick delta walk (later joiners get it right behind their WELCOME).
	ksess.session_start_replicating(&self.ses)
	gd.print_str("SB_WORLD_UP")
}

// Host: one avatar for `pid`, placed on its team's side of the center line.
spawn_kicker :: proc(self: ^Slopball, pid: knet.Player_Id) {
	if _, has := self.avatar_of[pid]; has {return}
	kp, kid := ksess.session_spawn_make(&self.ses, KICKER_TYPE, owner = pid)
	k := cast(^Kicker)kp
	k.pid = u8(pid)
	team := kicker_team(k.pid)
	rank := (int(pid) - int(team)) / 2 // 0,1,2.. within the team
	off := [4]f32{-70, 70, -120, 120}
	k.x = team == 1 ? PITCH_W/2 - 120 : PITCH_W/2 + 120
	// Fan the team OFF the center lane: a kickoff shot at the goal mouth must
	// not thread a parked teammate (the acid learned this as an own-goal).
	k.y = PITCH_H/2 + off[rank % 4]
	ksess.session_spawn_send(&self.ses, kid)
}
