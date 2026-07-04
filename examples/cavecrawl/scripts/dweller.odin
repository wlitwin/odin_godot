//gd:extends Label
//gd:class Dweller
package cavecrawl_scripts

// A hostile cave dweller — THE toolkit NPC pattern. There is no NPC
// machinery anywhere: this is an ordinary entity OWNED BY THE HOST PLAYER,
// so the host's brain tick (cavecrawl.odin) writes x/y like any owner writes
// streamed fields and every client interpolates the motion for free. Its
// mood is one replicated byte — every peer renders the same 🦇/😈/💨 —
// and its hp is hit by the same rocks that hit spelunkers.

import gd "godot:godot"
import kcombat "godot:kit/combat"
import knet "godot:kit/net"

DWELLER_IDLE :: u8(0)
DWELLER_CHASE :: u8(1)
DWELLER_FLEE :: u8(2)

Dweller :: struct {
	owner:  gd.Label,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"replicate,interp,owner"`, // the HOST owns it: brain writes, clients interp
	hp:     i32 `gd:"replicate"`,
	state:  u8 `gd:"replicate"`, // its mood, on every screen
	php:    kcombat.Predicted_Hp, // scratch: impacts SEEN here, pre-truth
}

dweller_process :: proc(self: ^Dweller, delta: f64) {
	gd.control_set_position(cast(gd.Control)self.owner, {self.x, self.y}, false)
	glyph: cstring = "\xF0\x9F\xA6\x87" // 🦇
	switch self.state {
	case DWELLER_CHASE:
		glyph = "\xF0\x9F\x98\x88" // 😈
	case DWELLER_FLEE:
		glyph = "\xF0\x9F\x92\xA8" // 💨
	}
	gd.set_string(cast(gd.Object)self.owner, "text", glyph)
}
