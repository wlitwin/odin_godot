//gd:extends Node2D
//gd:class CaveLevel
package cavecrawl_scripts

// The run's own tiny entity: which DEPTH the party is on, and how far the
// wave director has marched. One per run, host-owned, spawned at Start.
// These two replicated bytes are the entire level-migration wire protocol —
// the host bumps them, every peer (and every drop-in joiner, and every
// resumed save) reads campaign progress off the same replication that
// carries everything else. The body (entities/level.tscn) doubles as the
// depth readout in the corner; its screen position is authored, not coded.

import gd "godot:godot"
import knet "godot:kit/net"
import "core:fmt"

Level :: struct {
	owner:  gd.Node2d,
	glyph:  gd.Label `gd:"onready=Glyph"`,
	net_id: knet.Net_Id,
	depth:  u8 `gd:"replicate"`,
	wave:   u8 `gd:"replicate"`, // the director's current wave — every peer reads campaign progress off this byte, ordered with the spawns it paces
	won:    u8 `gd:"replicate"`, // MATCH STATE: 1 = the last floor fell. One byte is the whole match-flow protocol — every peer keys its end screen (and its restart) off the same delta stream that built the world
}

level_process :: proc(self: ^Level, delta: f64) {
	gd.set_string(cast(gd.Object)self.glyph, "text", fmt.ctprintf("depth %d", self.depth))
}
