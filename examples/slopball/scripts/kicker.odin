//gd:extends CharacterBody2D
//gd:class Kicker
package slopball

// A KICKER — one player's avatar, a real CharacterBody2D. Each peer
// move_and_slides only its OWN kicker (input.odin drives it) and owner-streams
// the resulting x/y; every other screen glides the body to the streamed spot.
// The body stays a body everywhere: the ball simulator's solver collides with
// remote kickers as solid kinematic obstacles, which is what makes dribbling
// into a crowd feel like a crowd.

import gd "godot:godot"
import knet "godot:kit/net"
import play "godot:play"

Kicker :: struct {
	owner:   gd.Character_Body2d,
	skin:    gd.Polygon2d `gd:"onready=Skin"`,
	tag:     gd.Label `gd:"onready=Tag"`,
	net_id:  knet.Net_Id,
	x, y:    f32 `gd:"owner,wire=f16"`,
	pid:     u8 `gd:"replicate"`, // the seat this avatar belongs to (color + team)
	mine:    bool, // set by the factory: this peer drives (and streams) this body
	hx, hy:  f32, // HOST grant-loop scratch: last sampled pose (intent = displacement)
	painted: bool, // one-shot: skin color + name tag applied
}

// Team by seat: odd player ids defend the LEFT goal, even the RIGHT — a stable
// split that needs no picker (host is 1 = left; first joiner 2 = right; ...).
kicker_team :: proc "contextless" (pid: u8) -> u8 {
	return pid % 2 == 1 ? u8(1) : u8(2)
}

kicker_process :: proc(self: ^Kicker, delta: f64) {
	if play.latch(&self.painted, self.pid != 0) {
		gd.polygon2d_set_color(self.skin, gd.peer_color(int(self.pid)))
	}
	// My own body is driven by input.odin (move_and_slide, then publish).
	// Everyone else's glides to their stream.
	if !self.mine {
		gd.node2d_set_position(cast(gd.Node2d)self.owner, {self.x, self.y})
	}
}
