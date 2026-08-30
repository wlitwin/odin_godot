package quickdraw

// Spawns + the census hooks. The factory is generated from the entity= tag
// (quickdraw.odin); what's left is the game-shaped half. For a sim-lane game the
// census hook adds NOTHING for the lane — the kit puts the entity on it itself,
// from the generated kinds row (each Sim_Set carries its wire class, and
// boot_lane's factory calls lane_track_set); these hooks only mark ownership.

import "core:fmt"
import gd "godot:godot"
import kboot "godot:kit/boot"
import knet "godot:kit/net"
import ksess "godot:kit/session"

// The census hooks, down to the genuinely game-shaped lines: the generated
// queries (gunner_of / gunner_mine / gunner_ids) answer everything the old
// three maps did, straight from the kit's own ledgers. (The sim lane tracks
// this spawn ITSELF: the generated kinds row carries gunner_sim_set, and
// boot_lane's factory does the rest.)
@(gd_half)
gunner_spawned :: proc(game: ^Quickdraw, self: ^Gunner, id: knet.Net_Id, owner: knet.Player_Id) {
	if owner != knet.PLAYER_ID_INVALID && owner == game.ses.me {
		self.mine = true
		game.me_gun = self
	}
	gd.print_str(fmt.tprintf("QD_SPAWN id=%d mine=%v", u32(id), owner == game.ses.me))
}

@(gd_half)
gunner_freed :: proc(game: ^Quickdraw, self: ^Gunner, id: knet.Net_Id) {
	if self == game.me_gun {
		game.me_gun = nil
	}
}

// The drone's census hook — the SECOND input-driven kind. Its one game line is
// the same lane_track_set the kit runs from the generated kinds row (drone's
// Sim_Set carries its wire class); here we only mark ownership for the sample.
@(gd_half)
drone_spawned :: proc(game: ^Quickdraw, self: ^Drone, id: knet.Net_Id, owner: knet.Player_Id) {
	self.mine = owner != knet.PLAYER_ID_INVALID && owner == game.ses.me
}

@(gd_half)
drone_freed :: proc(game: ^Quickdraw, self: ^Drone, id: knet.Net_Id) {
}

// Host: the duel fills — one gunner per seated player, corners first.
spawn_world :: proc(self: ^Quickdraw) {
	if len(gunner_all(&self.boot)) > 0 {return}
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
	if _, has := gunner_owned_by(&self.boot, pid); has {return}
	g, gid := gunner_spawn(&self.boot, owner = pid) // typed, from the entity tag — no const, no cast
	g.pid = u8(pid)
	g.hp = MAX_HP
	g.gold = u8(gd.env_int("QD_GOLD", 0)) // the solo gate's starting purse; duels earn theirs
	spot := SPAWNS[int(pid) % len(SPAWNS)]
	g.x = spot[0]
	g.y = spot[1]
	kboot.boot_spawn_send(&self.boot, gid)

	// ...and a DRONE beside them, owned by the same player: two entities, two
	// input classes, one seat. It hovers a little above the gunner's spot and
	// steers on Drone_Input every tick.
	d, did := drone_spawn(&self.boot, owner = pid)
	d.pid = u8(pid)
	d.x = spot[0]
	d.y = clamp(spot[1] - 40, ARENA_WALL, ARENA_H - ARENA_WALL)
	kboot.boot_spawn_send(&self.boot, did)
}
