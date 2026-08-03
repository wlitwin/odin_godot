//gd:extends Node2D
//gd:class Dweller
package cavecrawl_scripts

// A hostile cave dweller — THE toolkit NPC pattern. There is no NPC
// machinery anywhere: this is an ordinary entity OWNED BY THE HOST PLAYER,
// so the host's brain tick (host.odin) writes x/y like any owner writes
// streamed fields and every client interpolates the motion for free. Its
// mood is one replicated byte — every peer renders the same 🦇/😈/💨 —
// and its hp is hit by the same rocks that hit spelunkers.
// The body is entities/dweller.tscn.

import gd "godot:godot"
import kai "godot:kit/ai"
import kcombat "godot:kit/combat"
import knet "godot:kit/net"
import play "godot:play"

DWELLER_IDLE :: u8(0)
DWELLER_CHASE :: u8(1)
DWELLER_FLEE :: u8(2)

Dweller :: struct {
	owner:  gd.Node2d,
	glyph:  gd.Label `gd:"onready=Glyph"`,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"owner,interp"`, // the HOST owns it: brain writes, clients interp
	hp:     i32 `gd:"replicate"`,
	state:  u8 `gd:"replicate"`, // its mood, on every screen
	php:    kcombat.Predicted_Hp, // scratch: impacts SEEN here, pre-truth
	rx, ry: f32, // scratch: where THIS screen draws it (see dweller_process)
	seen:   bool, // scratch: first frame snaps instead of gliding in from 0,0
}

dweller_process :: proc(self: ^Dweller, delta: f64) {
	// Interp smooths REMOTE screens; the AUTHORITY's own screen is only as
	// smooth as the writer — and the brain writes x/y in 20 Hz tick steps.
	// So every screen GLIDES the node toward the sim at the dweller's own
	// pace (+slack so it never falls behind): on clients this shadows the
	// already-smooth stream, on the host it melts the steps. Same cure as
	// the rocks: sim on ticks, render on the frame clock. No role branch.
	if play.latch(&self.seen, true) {
		self.rx, self.ry = self.x, self.y
	}
	glide := DWELLER_SPEED * f32(knet.DEFAULT_TICK_HZ) * 1.5 * f32(delta)
	p, _ := kai.step_toward({self.rx, self.ry, 0}, {self.x, self.y, 0}, glide)
	self.rx, self.ry = p.x, p.y
	gd.node2d_set_position(self.owner, {self.rx, self.ry})
	glyph: cstring = "\xF0\x9F\xA6\x87" // 🦇
	switch self.state {
	case DWELLER_CHASE:
		glyph = "\xF0\x9F\x98\x88" // 😈
	case DWELLER_FLEE:
		glyph = "\xF0\x9F\x92\xA8" // 💨
	}
	gd.set_text(cast(gd.Object)self.glyph, glyph)
}
