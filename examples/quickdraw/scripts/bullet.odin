//gd:extends Node2D
//gd:class Bullet
package quickdraw

// A BULLET — the lob's slow projectile, and kit/sim's predicted-spawn showcase.
// You fire it and it leaves your muzzle THIS instant: a client-PREDICTED entity
// (boot_spawn_predicted, gunner_tick_fx's half), flying its own arc, born-gated
// and reconciled like your avatar — a full round trip before the authority's
// real bullet (session_spawn_make, the _then half) arrives and REKEYS the very
// one you predicted. It carries no inputs; the tick self-integrates, so every
// peer's between-batch prediction is exact. Splash lands SERVER-SIDE where the
// bullet actually is (no rewind — a slow lob is meant to be dodged).

import "core:fmt"
import gd "godot:godot"
import kboot "godot:kit/boot"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import ksim "godot:kit/sim"

Bullet :: struct {
	owner:  gd.Node2d,
	skin:   gd.Polygon2d `gd:"onready=Skin"`,
	net_id: knet.Net_Id,

	// The predicted flight — server-simulated, client-predicted, reconciled.
	x, y:   f32 `gd:"replicate,predict,interp"`,
	vx, vy: f32 `gd:"replicate,predict"`,
	life:   u16 `gd:"replicate,predict"`, // ticks of flight left; 0 = spent

	// Delta lane: who fired it (splash credit; never splashes its own shooter).
	pid:     u8 `gd:"replicate"`,
	painted: bool,
}

// The flight: pure predicted state, no input — a straight slow bolt that spends
// itself when its life runs out or it leaves the arena. `landed` is a FACT the
// tick learned; it routes to the authority's splash below.
@(gd_tick)
bullet_tick :: proc(self: ^Bullet) -> (landed: bool) {
	if self.life == 0 {return}
	self.x += self.vx
	self.y += self.vy
	self.life -= 1
	if self.life == 0 ||
	   self.x < ARENA_WALL || self.x > ARENA_W - ARENA_WALL ||
	   self.y < ARENA_WALL || self.y > ARENA_H - ARENA_WALL {
		self.life = 0
		landed = true
	}
	return
}

// AUTHORITY: the bullet spent itself — splash any gunner in reach (server truth,
// no rewind: a slow lob is dodgeable by design) and retire it. The client's own
// predicted copy just freezes at the landing point until this despawn reaches it.
bullet_tick_then :: proc(g: ^Quickdraw, self: ^Bullet, by: knet.Player_Id, landed: bool) {
	if !landed {return}
	gd.print_str(fmt.tprintf("QD_LOB_LAND by=%d tick=%d x=%.1f y=%.1f", u64(by), ksim.lane_now(&g.lane), self.x, self.y))
	for id in gunner_ids(&g.boot) {
		gun, _ := gunner_of(&g.boot, id)
		vpid := kboot.boot_entity_owner(&g.boot, id)
		if gun.hp <= 0 || u8(vpid) == self.pid {continue}
		dx := gun.x - self.x
		dy := gun.y - self.y
		if dx * dx + dy * dy > LOB_RADIUS * LOB_RADIUS {continue}
		gun.hp -= 1
		gd.print_str(fmt.tprintf("QD_LOB_HIT by=%d on=%d hp=%d", u64(by), u64(vpid), gun.hp))
		if gun.hp <= 0 {
			ksess.session_stat_add(&g.ses, by, g.kills_col, 1)
			ksess.session_stat_add(&g.ses, vpid, g.deaths_col, 1)
			append(&g.respawns, Respawn{id = id, at = ksim.lane_now(&g.lane) + RESPAWN_TICKS})
			gd.print_str(fmt.tprintf("QD_LOB_KILL by=%d on=%d", u64(by), u64(vpid)))
		}
	}
	ksess.session_despawn(&g.ses, self.net_id)
}

bullet_process :: proc(self: ^Bullet, delta: f64) {
	if !self.painted && self.pid != 0 {
		self.painted = true
		gd.polygon2d_set_color(self.skin, peer_color(int(self.pid)))
	}
	gd.node2d_set_position(cast(gd.Node2d)self.owner, {self.x, self.y})
}
