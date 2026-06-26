//gd:extends Node2D
//gd:class ArenaBullet
package coop_arena

// ----------------------------------------------------------------------------
// ArenaBullet — an OWNER-SIMULATED projectile. Bullets are NOT replicated by a synchronizer;
// instead they are DETERMINISTIC-LOCAL: the firing peer spawns its own bullet locally (the
// `owned` one) the instant it fires, and broadcasts `fired(origin, dir)`, so every other peer
// spawns a matching GHOST bullet that flies the same path. The owner sees its shot with no
// network delay; peers see it a tick later when the broadcast arrives.
//
// AUTHORITY: only the OWNER's bullet resolves hits. When the owned bullet overlaps an enemy it
// authoritatively applies + BROADCASTS the damage/kill (arena_damage, peer-authoritative,
// trusted — no anti-cheat), then despawns. Ghost bullets are visual only: they fly and expire
// but never decide a hit (that would double-apply the damage).
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

BULLET_SPEED :: f32(460)
BULLET_LIFETIME :: f32(1.2)
BULLET_HIT_RADIUS :: f32(16)

ArenaBullet :: struct {
	owner:     gd.Node2d,
	dir:       gd.Vector2,
	damage:    int,
	owner_peer: int,  // the peer that fired this bullet (the killer credited on a kill)
	owned:     bool,  // true only on the firing peer's local bullet — it alone resolves hits
	life:      f32,
}

arena_bullet_physics_process :: proc(self: ^ArenaBullet, delta: f64) {
	pos := gd.node2d_get_global_position(self.owner)
	pos.x += self.dir.x * BULLET_SPEED * f32(delta)
	pos.y += self.dir.y * BULLET_SPEED * f32(delta)
	gd.node2d_set_global_position(self.owner, pos)

	self.life += f32(delta)
	if self.life >= BULLET_LIFETIME {
		gd.node_queue_free(self.owner)
		return
	}

	// Only the firing peer's own bullet resolves hits (owner-authoritative damage).
	if !self.owned {return}
	target, ok := nearest_enemy(self.owner, pos)
	if !ok {return}
	tpos := gd.node2d_get_global_position(target)
	dx := tpos.x - pos.x
	dy := tpos.y - pos.y
	if dx * dx + dy * dy > BULLET_HIT_RADIUS * BULLET_HIT_RADIUS {return}
	e := rt.script_of(cast(gd.Object)target, ArenaEnemy)
	if e == nil {return}
	game := find_game(self.owner)
	if game != nil {
		// Broadcast the damage to ALL peers (call_local -> also applies here). The firing peer
		// is credited as the killer. Peers trust it — no host round-trip, no anti-cheat.
		arena_broadcast_damage(game, e.id, self.damage, self.owner_peer)
	}
	gd.node_queue_free(self.owner)
}
