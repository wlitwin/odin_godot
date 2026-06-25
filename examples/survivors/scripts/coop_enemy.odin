//gd:extends Node2D
//gd:class CoopEnemy
package survivors_scripts

// ----------------------------------------------------------------------------
// CoopEnemy — the root of coop_enemy.tscn, a HOST-authoritative replicated enemy. The host
// spawns it through a MultiplayerSpawner (so it auto-instantiates on every client); a sibling
// MultiplayerSynchronizer streams the host's `position` (native) + this script's @export `id`
// and `hp` (Odin fields) as spawn + continuous state. The host simulates the chase + owns hp;
// clients render it. `id` is a stable handle the client passes back in a damage RPC so the
// host can find the authoritative enemy regardless of how the spawner names the node.
// ----------------------------------------------------------------------------

import gd "godot:godot"

CoopEnemy :: struct {
	owner: gd.Node2d,
	id:    int `gd:"export"`, // stable cross-peer handle (spawn-replicated)
	hp:    int `gd:"export"`, // host-owned, synced for client HUD/feedback
}

coop_enemy_ready :: proc(self: ^CoopEnemy) {
	if self.hp == 0 {self.hp = 20}
}
