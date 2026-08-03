//gd:extends Node2D
//gd:class ArenaEnemy
//gd:group arena_enemies
package coop_arena

// ----------------------------------------------------------------------------
// ArenaEnemy — the root of arena_enemy.tscn, the SHARED HORDE unit. Spawning + movement are
// HOST-authoritative (one source of truth for a horde nobody "inputs", so host authority is not
// felt as lag): the host spawns it through a MultiplayerSpawner (auto-instantiated on every
// client) and moves it toward the nearest pawn; a sibling MultiplayerSynchronizer streams the
// host's `position` (native) + this script's spawn-once `id` to every client.
//
// DAMAGE/death is PEER-authoritative, NOT host: `hp` is tracked locally on every peer and
// decremented by the broadcast arena_damage RPC (whoever's bullet hit). `hp` is therefore NOT
// in the synchronizer config — the call_local broadcast keeps it identical on all peers, and
// both peers agree on the death. The host owns the node, so the HOST frees it on death and the
// MultiplayerSpawner replicates the despawn (no explicit despawn RPC — that would double-free).
// `id` is the stable cross-peer handle the damage RPC uses to resolve the same enemy everywhere.
//
// The `//gd:group` marker above makes every instance join GROUP_ENEMIES at READY — the
// declarative form of the gd.add_to_group ready line (query side: gd.nearest_in_group & co.).
// ----------------------------------------------------------------------------

import gd "godot:godot"

ArenaEnemy :: struct {
	owner: gd.Node2d,
	id:    int `gd:"export"`, // stable cross-peer handle (spawn-replicated, mode 0)
	hp:    int,               // peer-authoritative, NOT synced (kept identical by arena_damage)
	dead:  bool,
}

arena_enemy_ready :: proc(self: ^ArenaEnemy) {
	// hp default stays a ready-time guard (NOT `export,default=`): hp is deliberately not a
	// script property — exporting it would grow the wire-adjacent surface for no gain. On the
	// host the spawner pokes hp BEFORE parenting, so this only fires on client-side spawner
	// instances — where 12 must equal the host's COOP_ENEMY_HP for the peers to agree.
	if self.hp == 0 {self.hp = 12}
}
