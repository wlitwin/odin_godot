//gd:extends Node2D
//gd:class Kicker
package speedball

// A KICKER — one player's avatar on the sim lane, marked CONTESTED like the
// ball: in predict-world (echo) mode EVERY peer ticks every kicker — yours
// from your ring, the others from the batch-echoed held inputs — so the
// whole pitch lives on one predicted timeline. The body is the shelf's now:
// psim.Mover carries x/y/vx/vy (predicted through the embed) and integrates
// the RUN_ACCEL momentum approach; psim.Cool carries the kick cooldown. The
// tick that's left is pure intent — read the stick, say what you want.
// The kick itself lives in the world pass (speedball.odin), because it
// mutates the BALL and cross-entity writes are the world pass's whole job.

import gd "godot:godot"
import knet "godot:kit/net"
import psim "godot:play/sim"

Kicker :: struct {
	owner:  gd.Node2d,
	skin:   gd.Polygon2d `gd:"onready=Skin"`,
	net_id: knet.Net_Id,

	run:  psim.Mover, // x/y/vx/vy join the predict set through the embed
	kick: psim.Cool, // the kick cooldown, predicted

	pid: u8 `gd:"replicate"`,

	mine:    bool,
	painted: bool
}

@(gd_input)

Kicker_Input :: struct {
	move:    [2]i8 `gd:"range=-1:1"`,
	buttons: u8 `gd:"mask=0x01"`
}

BTN_KICK :: u8(1)

@(gd_tick = "contested")
kicker_tick :: proc(self: ^Kicker, input: Kicker_Input) {
	// Momentum, deliberately: velocity APPROACHES the stick instead of
	// snapping to it. Feel-wise it is a touch of weight; netcode-wise it is
	// the held-input extrapolation smoother — an input change (the one
	// moment extrapolation guesses wrong) now diverges gradually, so remote
	// stops and turns correct by a glide, not a pull-back. The approach
	// itself is psim.Mover's (accel = RUN_ACCEL, set at spawn); this tick
	// only writes the velocity it WANTS — intent through fields.
	dir := normalized({f32(input.move[0]), f32(input.move[1])})
	self.run.tx = dir.x * RUN_SPEED
	self.run.ty = dir.y * RUN_SPEED
}

kicker_process :: proc(self: ^Kicker, delta: f64) {
	if !self.painted && self.pid != 0 {
		self.painted = true
		gd.polygon2d_set_color(self.skin, peer_color(int(self.pid)))
	}
	gd.node2d_set_position(cast(gd.Node2d)self.owner, {self.run.x, self.run.y})
}
