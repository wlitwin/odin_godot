//gd:extends Label
//gd:class Spelunker
package cavecrawl_scripts

// A player's avatar — THE toolkit author surface for a multiplayer entity:
// tag the fields, done. x/y are owner-streamed (whoever owns this spelunker
// writes them; everyone else sees interpolated motion), the bag replicates
// to everyone (co-op transparency: you can see what your friends carry).
// The node IS its own visual (a Label glyph); process just places it.

import gd "godot:godot"
import kitems "godot:kit/items"
import knet "godot:kit/net"

Spelunker :: struct {
	owner:     gd.Label,
	net_id:    knet.Net_Id, // assigned by the session at spawn
	x, y:      f32 `gd:"replicate,interp,owner"`,
	bag:       [6]kitems.Slot `gd:"replicate"`,
	last_drop: kitems.Slot, // scratch for the drop hook — never on the wire
}

// Drop a bag slot at my feet: my bag empties on my screen this frame; the
// host's drop hook mints the Pickup entity everyone sees.
@(gd_command = "predict")
spelunker_drop :: proc(self: ^Spelunker, slot: i32) -> bool {
	dropped := kitems.take(self.bag[:], int(slot), max(u16))
	if dropped.count == 0 {return false}
	self.last_drop = dropped
	return true
}

spelunker_ready :: proc(self: ^Spelunker) {
	gd.set_string(cast(gd.Object)self.owner, "text", "\xE2\x9B\x8F") // ⛏
}

spelunker_process :: proc(self: ^Spelunker, delta: f64) {
	gd.control_set_position(cast(gd.Control)self.owner, {self.x, self.y}, false)
}
