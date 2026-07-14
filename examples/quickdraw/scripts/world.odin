package quickdraw

// Spawns + the census hooks. The factory is generated from the entity= tag
// (quickdraw.odin); what's left is the game-shaped half — and for a sim-lane
// game the census hook has ONE extra line: lane_track_set puts the entity on
// the lane with its generated Sim_Set, and from then on it drives itself.

import "core:fmt"
import gd "godot:godot"
import knet "godot:kit/net"
import ksess "godot:kit/session"

gunner_spawned :: proc(game: ^Quickdraw, self: ^Gunner, id: knet.Net_Id, owner: knet.Player_Id) {
	game.gunners[id] = self
	game.owner_pid[id] = owner
	if owner != knet.PLAYER_ID_INVALID {
		game.avatar_of[owner] = id
		if owner == game.ses.me {
			self.mine = true
			game.me_gun = self
		}
	}
	// (The sim lane tracks this spawn ITSELF: the generated kinds row carries
	// gunner_sim_set, and boot_lane's factory does the rest.)
	gd.print_str(fmt.tprintf("QD_SPAWN id=%d mine=%v", u32(id), owner == game.ses.me))
}

gunner_freed :: proc(game: ^Quickdraw, self: ^Gunner, id: knet.Net_Id) {
	if self == game.me_gun {
		game.me_gun = nil
	}
	if pid, ok := game.owner_pid[id]; ok {
		if game.avatar_of[pid] == id {
			delete_key(&game.avatar_of, pid)
		}
	}
	delete_key(&game.owner_pid, id)
	delete_key(&game.gunners, id)
}

// Host: the duel fills — one gunner per seated player, corners first.
spawn_world :: proc(self: ^Quickdraw) {
	if len(self.gunners) > 0 {return}
	self.kills_col = ksess.session_stat_column(&self.ses, "kills")
	self.deaths_col = ksess.session_stat_column(&self.ses, "deaths")
	for _, p in self.ses.players {
		if !p.connected {continue}
		if p.dedicated {continue} // the marshal referees; it draws no iron
		spawn_gunner(self, p.id)
	}
	ksess.session_start_replicating(&self.ses)
	gd.print_str("QD_WORLD_UP")
}

spawn_gunner :: proc(self: ^Quickdraw, pid: knet.Player_Id) {
	if _, has := self.avatar_of[pid]; has {return}
	gp, gid := ksess.session_spawn_make(&self.ses, GUNNER_TYPE, owner = pid)
	g := cast(^Gunner)gp
	g.pid = u8(pid)
	g.hp = MAX_HP
	spot := SPAWNS[int(pid) % len(SPAWNS)]
	g.x = spot[0]
	g.y = spot[1]
	ksess.session_spawn_send(&self.ses, gid)
}
