//gd:extends Node2D
//gd:class Mob
package repl_spike_scripts

// Mob — a spawnable scene whose ROOT carries an Odin script. The MultiplayerSpawner instantiates
// it on the client when the host adds it to the spawn path; a MultiplayerSynchronizer child
// replicates the node's native `position` AND this script's @export `hp` (the untested
// Odin-property-through-the-synchronizer path).

import gd "godot:godot"
import "core:fmt"

Mob :: struct {
	owner: gd.Node2d,
	hp:    int `gd:"export"`,
}

mob_ready :: proc(self: ^Mob) {
	gd.print_str(fmt.tprintf("MOB_READY on=%d hp=%d", gd.my_peer_id(self.owner), self.hp))
}

// host-only mover, called by the orchestrator each frame to prove position sync.
mob_advance :: proc(self: ^Mob, dx: f32) {
	pos := gd.node2d_get_position(self.owner)
	pos.x += dx
	gd.node2d_set_position(self.owner, pos)
}

mob_x :: proc(self: ^Mob) -> f32 {
	return gd.node2d_get_position(self.owner).x
}
