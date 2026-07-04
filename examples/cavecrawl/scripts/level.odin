//gd:extends Label
//gd:class CaveLevel
package cavecrawl_scripts

// The run's own tiny entity: which DEPTH the party is on. One per run,
// host-owned, spawned at Start. The replicated byte is the entire level-
// migration wire protocol — the host bumps it, every peer (and every
// drop-in joiner, and every resumed save) reads the current floor from
// the same replication that carries everything else. The node doubles as
// the depth readout in the corner.

import gd "godot:godot"
import knet "godot:kit/net"
import "core:fmt"

Level :: struct {
	owner:  gd.Label,
	net_id: knet.Net_Id,
	depth:  u8 `gd:"replicate"`,
	wave:   u8 `gd:"replicate"`, // the director's current wave — every peer reads campaign progress off this byte, ordered with the spawns it paces
}

level_ready :: proc(self: ^Level) {
	gd.control_set_position(cast(gd.Control)self.owner, {566, 4}, false)
}

level_process :: proc(self: ^Level, delta: f64) {
	gd.set_string(cast(gd.Object)self.owner, "text", fmt.ctprintf("depth %d", self.depth))
}
