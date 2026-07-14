package speedball

// Census hooks + spawns. Note what is NOT here: no lane calls at all — the
// generated kinds rows carry kicker_sim_set and ball_sim_set (the ball's
// marked contested), and boot_lane's factory does the tracking.

import "core:fmt"
import gd "godot:godot"
import knet "godot:kit/net"
import ksess "godot:kit/session"

kicker_spawned :: proc(game: ^Speedball, self: ^Kicker, id: knet.Net_Id, owner: knet.Player_Id) {
	game.kickers[id] = self
	game.owner_pid[id] = owner
	if owner != knet.PLAYER_ID_INVALID {
		game.avatar_of[owner] = id
		if owner == game.ses.me {
			self.mine = true
			game.me_kick = self
		}
	}
	gd.print_str(fmt.tprintf("SPB_SPAWN id=%d mine=%v", u32(id), owner == game.ses.me))
}

kicker_freed :: proc(game: ^Speedball, self: ^Kicker, id: knet.Net_Id) {
	if self == game.me_kick {
		game.me_kick = nil
	}
	if pid, ok := game.owner_pid[id]; ok {
		if game.avatar_of[pid] == id {
			delete_key(&game.avatar_of, pid)
		}
	}
	delete_key(&game.owner_pid, id)
	delete_key(&game.kickers, id)
}

ball_spawned :: proc(game: ^Speedball, self: ^Ball, id: knet.Net_Id, owner: knet.Player_Id) {
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
	b.x = PITCH_W / 2
	b.y = PITCH_H / 2
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
	if _, has := self.avatar_of[pid]; has {return}
	kp, kid := ksess.session_spawn_make(&self.ses, KICKER_TYPE, owner = pid)
	k := cast(^Kicker)kp
	k.pid = u8(pid)
	spot := SPAWNS[int(pid) % len(SPAWNS)]
	k.x = spot[0]
	k.y = spot[1]
	ksess.session_spawn_send(&self.ses, kid)
}
