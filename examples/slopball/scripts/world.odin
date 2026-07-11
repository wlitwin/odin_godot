package slopball

// The factory + spawns: the session announces entities by type, this file
// instantiates the authored scenes and hands back struct + command set.

import gd "godot:godot"
import knet "godot:kit/net"
import rt "godot:runtime"
import ksess "godot:kit/session"

@(private = "file")
spawn_scene :: proc(self: ^Slopball, scene: ^gd.Resource) -> gd.Node {
	node := gd.instantiate(cast(gd.Packed_Scene)scene)
	gd.add_child(self.boot.world, node)
	return node
}

slop_make_entity :: proc(user: rawptr, type: ksess.Entity_Type, id: knet.Net_Id, owner: knet.Player_Id) -> (rawptr, ^knet.Command_Set) {
	self := cast(^Slopball)user
	switch type {
	case KICKER_TYPE:
		node := spawn_scene(self, self.kicker_scene)
		self.nodes[id] = node
		k := rt.script_of(node, Kicker)
		k.net_id = id
		self.kickers[id] = k
		if owner != knet.PLAYER_ID_INVALID {
			self.avatar_of[owner] = id
			if owner == self.ses.me {
				k.mine = true
				self.me_kick = k
			}
		}
		return k, &kicker_command_set
	case BALL_TYPE:
		node := spawn_scene(self, self.ball_scene)
		self.nodes[id] = node
		b := rt.script_of(node, Ball)
		b.net_id = id
		self.ball = b
		self.ball_id = id
		return b, &ball_command_set
	}
	return nil, nil
}

slop_free_entity :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) {
	self := cast(^Slopball)user
	if node, ok := self.nodes[id]; ok {
		gd.node_queue_free(node)
		delete_key(&self.nodes, id)
	}
	if k, ok := self.kickers[id]; ok {
		if k == self.me_kick {
			self.me_kick = nil
		}
		delete_key(&self.kickers, id)
	}
	if self.ball_id == id {
		self.ball = nil
		self.ball_id = 0
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
