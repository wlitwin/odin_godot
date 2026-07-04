//gd:extends Label
//gd:class Rock
package cavecrawl_scripts

// A rock in flight — the VISUAL half of a projectile. The authoritative sim
// (kit/combat, in cavecrawl.odin's host tick) decides what it hits; this
// entity only shows the flight: owned by the HOST player, so the host's sim
// positions stream to every peer and remote screens interpolate the arc.
// Spawned by the throw hook, despawned on impact or expiry.

import gd "godot:godot"
import knet "godot:kit/net"

Rock :: struct {
	owner:  gd.Label,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"replicate,interp,owner"`,
}

rock_ready :: proc(self: ^Rock) {
	gd.set_string(cast(gd.Object)self.owner, "text", "\xE2\x97\x8F") // ●
}

rock_process :: proc(self: ^Rock, delta: f64) {
	gd.control_set_position(cast(gd.Control)self.owner, {self.x, self.y}, false)
}
