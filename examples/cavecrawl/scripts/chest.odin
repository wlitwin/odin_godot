//gd:extends Node2D
//gd:class Chest
package cavecrawl_scripts

// The cave's chest. Its inventory is a plain replicated field — kit/net's
// delta walk ships it, reject-truth restores it — and `chest_take` is the
// whole loot rule: range-gated (the SAME gate the prompt uses), predicted on
// the taker's screen, host-serialized when two spelunkers grab at once. What
// it took rides the verb's PAYLOAD return into `chest_take_then` right below
// — the typed, authority-only consequence that credits the taker's bag.
// The body is entities/chest.tscn.

import gd "godot:godot"
import kinter "godot:kit/interact"
import kitems "godot:kit/items"
import knet "godot:kit/net"

Chest :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"replicate"`,
	slots:  [8]kitems.Slot `gd:"replicate"`,
}

@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
chest_take :: proc(self: ^Chest, slot: i32, px: f32, py: f32) -> (ok: bool, taken: kitems.Slot) {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false, {}}
	taken = kitems.take(self.slots[:], int(slot), 99) // the whole stack
	return taken.count > 0, taken
}

// The cross-entity half, next to its verb: runs on the HOST only, right after
// the take applies — never on the taker's optimistic run (the credit reaches
// their screen as an ordinary delta). See host.odin's cave_credit.
@(gd_half)
chest_take_then :: proc(game: ^CaveLobby, self: ^Chest, by: knet.Player_Id, slot: i32, px: f32, py: f32, taken: kitems.Slot) {
	cave_credit(game, by, self, taken)
}

chest_process :: proc(self: ^Chest, delta: f64) {
	gd.node2d_set_position(self.owner, {self.x, self.y})
}
