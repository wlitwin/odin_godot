//gd:extends Label
//gd:class Door
package cavecrawl_scripts

// A stateful interactable: one replicated bool and one predicted command.
// Toggling feels instant on the toggler's screen and swings for everyone
// else a delta later; the range gate runs identically in the prediction and
// on the host.

import gd "godot:godot"
import kinter "godot:kit/interact"
import knet "godot:kit/net"

Door :: struct {
	owner:  gd.Label,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"replicate"`,
	open:   bool `gd:"replicate"`,
}

@(gd_command = "predict")
door_toggle :: proc(self: ^Door, px: f32, py: f32) -> bool {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false}
	self.open = !self.open
	return true
}

door_process :: proc(self: ^Door, delta: f64) {
	gd.control_set_position(cast(gd.Control)self.owner, {self.x, self.y}, false)
	// 🚪 closed, 🕳 an open doorway
	gd.set_string(cast(gd.Object)self.owner, "text", self.open ? "\xF0\x9F\x95\xB3" : "\xF0\x9F\x9A\xAA")
}
