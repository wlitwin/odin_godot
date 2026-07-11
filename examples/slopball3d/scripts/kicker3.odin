//gd:extends CharacterBody3D
//gd:class Kicker3
package slopball3d

// A KICKER — one player's avatar, a real CharacterBody3D capsule. Each peer
// move_and_slides only its OWN kicker (input.odin drives it, XZ plane) and
// owner-streams the resulting pose as ONE [3]f32 field; every other screen
// glides the body to the streamed spot. The body stays a body everywhere: the
// ball simulator's solver collides with remote kickers as solid kinematic
// obstacles, which is what makes dribbling into a crowd feel like a crowd.

import gd "godot:godot"
import knet "godot:kit/net"

Kicker3 :: struct {
	owner:   gd.Character_Body3d,
	skin:    gd.Mesh_Instance3d `gd:"onready=Skin"`,
	tag:     gd.Label3d `gd:"onready=Tag"`,
	net_id:  knet.Net_Id,
	pos:     [3]f32 `gd:"replicate,interp,owner,wire=f16"`,
	pid:     u8 `gd:"replicate"`, // the seat this avatar belongs to (color + team)
	mine:    bool, // set by the factory: this peer drives (and streams) this body
	placed:  bool, // one-shot: the NODE adopts the spawned pos (scenes instance at 0,0,0)
	hx, hz:  f32, // HOST grant-loop scratch: last sampled pose (intent = displacement)
	painted: bool, // one-shot: skin color + name tag applied
}

// Team by seat: odd player ids defend the LEFT goal, even the RIGHT — a stable
// split that needs no picker (host is 1 = left; first joiner 2 = right; ...).
kicker3_team :: proc "contextless" (pid: u8) -> u8 {
	return pid % 2 == 1 ? u8(1) : u8(2)
}

kicker3_process :: proc(self: ^Kicker3, delta: f64) {
	if !self.painted && self.pid != 0 {
		self.painted = true
		// 3D has no per-node modulate: give this capsule its own material.
		mat := gd.new_standard_material3d()
		gd.base_material3d_set_albedo(cast(gd.Base_Material3d)mat, peer_color(int(self.pid)))
		gd.geometry_instance3d_set_material_override(cast(gd.Geometry_Instance3d)self.skin, cast(gd.Material)mat)
	}
	// My own body is driven by input.odin (move_and_slide, then publish).
	// Everyone else's glides to their stream.
	if !self.mine {
		gd.node3d_set_position(cast(gd.Node3d)self.owner, self.pos)
	}
}
