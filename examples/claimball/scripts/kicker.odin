//gd:extends Node2D
//gd:class Kicker
package claimball

// A KICKER — one player's avatar, PREDICT-SELF: a plain `@(gd_tick)` (NOT
// `contested`), so each peer predicts only ITS OWN kicker and WATCHES the others
// (rendered an interp-delay behind, but always accurate — no held-input echo).
// This is the claimball/speedball split: speedball marks the kicker contested
// and echoes inputs so the whole pitch is one predicted timeline; claimball
// predicts only the avatar and the ball, and lets the CLAIM decide how the
// shared ball presents (claimball.odin's world pass). The body is the shelf's
// now: psim.Mover carries x/y/vx/vy (predicted through the embed) and integrates
// the RUN_ACCEL approach; psim.Cool carries the kick cooldown. The tick that's
// left is pure intent — read the stick, say what you want. The kick itself lives
// in the world pass, because it mutates the BALL and cross-entity writes are the
// world pass's whole job.

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
	painted: bool,
}

Kicker_Input :: struct {
	move:    [2]i8,
	buttons: u8,
}

BTN_KICK :: u8(1)

@(gd_tick)
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
