//gd:extends Node2D
//gd:class Pickup
package cavecrawl_scripts

// A dropped stack lying on the cave floor — an ordinary entity, minted by
// the drop consequence (spelunker.odin), reaped by the grab consequence
// below. The grab is the contended race at its smallest: whoever the host
// hears first zeroes it; the loser's prediction dissolves with the despawn.
// The body is entities/pickup.tscn.

import gd "godot:godot"
import kinter "godot:kit/interact"
import kitems "godot:kit/items"
import knet "godot:kit/net"

Pickup :: struct {
	owner:  gd.Node2d,
	glyph:  gd.Label `gd:"onready=Glyph"`,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"replicate"`,
	item:   kitems.Item_Id `gd:"replicate"`,
	count:  u16 `gd:"replicate"`,
}

@(gd_command = "predict,any_seat")
pickup_grab :: proc(self: ^Pickup, px: f32, py: f32) -> (ok: bool, grabbed: kitems.Slot) {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false, {}}
	if self.count == 0 {return false, {}}
	grabbed = kitems.Slot{item = self.item, count = self.count}
	self.item = kitems.ITEM_NONE
	self.count = 0
	return true, grabbed
}

// Host only: credit the grabber's bag and despawn the emptied pickup for
// everyone (clients free through the factory; the host frees its own node).
@(gd_half)
pickup_grab_then :: proc(game: ^CaveLobby, self: ^Pickup, by: knet.Player_Id, px: f32, py: f32, grabbed: kitems.Slot) {
	cave_settle_grab(game, by, self.net_id, grabbed)
}

pickup_process :: proc(self: ^Pickup, delta: f64) {
	gd.node2d_set_position(self.owner, {self.x, self.y})
	glyph: cstring = "\xE2\x9C\xA8" // ✨ whatever it is, it sparkles
	switch self.item {
	case GEM:
		glyph = "\xF0\x9F\x92\x8E" // 💎
	case TORCH:
		glyph = "\xF0\x9F\x94\xA6" // 🔦
	case kitems.ITEM_NONE:
		glyph = "" // grabbed; the despawn is on its way
	}
	gd.set_text(cast(gd.Object)self.glyph, glyph)
}
