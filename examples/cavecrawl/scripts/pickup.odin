//gd:extends Label
//gd:class Pickup
package cavecrawl_scripts

// A dropped stack lying on the cave floor — an ordinary entity, minted by
// the drop hook, despawned by the grab hook (both in cavecrawl.odin). The
// grab is the contended race at its smallest: whoever the host hears first
// zeroes it; the loser's prediction dissolves with the despawn.

import gd "godot:godot"
import kinter "godot:kit/interact"
import kitems "godot:kit/items"
import knet "godot:kit/net"

Pickup :: struct {
	owner:     gd.Label,
	net_id:    knet.Net_Id,
	x, y:      f32 `gd:"replicate"`,
	item:      kitems.Item_Id `gd:"replicate"`,
	count:     u16 `gd:"replicate"`,
	last_grab: kitems.Slot, // scratch for the grab hook — never on the wire
}

@(gd_command = "predict")
pickup_grab :: proc(self: ^Pickup, px: f32, py: f32) -> bool {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false}
	if self.count == 0 {return false}
	self.last_grab = kitems.Slot{item = self.item, count = self.count}
	self.item = kitems.ITEM_NONE
	self.count = 0
	return true
}

pickup_process :: proc(self: ^Pickup, delta: f64) {
	gd.control_set_position(cast(gd.Control)self.owner, {self.x, self.y}, false)
	glyph: cstring = "\xE2\x9C\xA8" // ✨ whatever it is, it sparkles
	switch self.item {
	case GEM:
		glyph = "\xF0\x9F\x92\x8E" // 💎
	case TORCH:
		glyph = "\xF0\x9F\x94\xA6" // 🔦
	case kitems.ITEM_NONE:
		glyph = "" // grabbed; the despawn is on its way
	}
	gd.set_string(cast(gd.Object)self.owner, "text", glyph)
}
