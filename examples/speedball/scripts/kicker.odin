//gd:extends Node2D
//gd:class Kicker
package speedball

// A KICKER — one player's avatar on the sim lane, marked CONTESTED like the
// ball: in predict-world (echo) mode EVERY peer ticks every kicker — yours
// from your ring, the others from the batch-echoed held inputs — so the
// whole pitch lives on one predicted timeline. The kick COOLDOWN is
// predicted state; the kick itself lives in the world pass (speedball.odin),
// because it mutates the BALL and cross-entity writes are the world pass's
// whole job.

import gd "godot:godot"
import knet "godot:kit/net"

Kicker :: struct {
	owner:  gd.Node2d,
	skin:   gd.Polygon2d `gd:"onready=Skin"`,
	net_id: knet.Net_Id,

	x, y:    f32 `gd:"replicate,predict,interp"`,
	vx, vy:  f32 `gd:"replicate,predict"`,
	kick_cd: u16 `gd:"replicate,predict"`,

	pid: u8 `gd:"replicate"`,

	mine:    bool,
	painted: bool,
}

Kicker_Input :: struct {
	move:    [2]i8,
	buttons: u8,
}

BTN_KICK :: u8(1)

@(gd_tick = "contested")
kicker_tick :: proc(self: ^Kicker, input: Kicker_Input) {
	// Momentum, deliberately: velocity APPROACHES the stick instead of
	// snapping to it. Feel-wise it is a touch of weight; netcode-wise it is
	// the held-input extrapolation smoother — an input change (the one
	// moment extrapolation guesses wrong) now diverges gradually, so remote
	// stops and turns correct by a glide, not a pull-back.
	dir := normalized({f32(input.move[0]), f32(input.move[1])})
	self.vx += (dir.x * RUN_SPEED - self.vx) * RUN_ACCEL
	self.vy += (dir.y * RUN_SPEED - self.vy) * RUN_ACCEL
	self.x = clamp(self.x + self.vx, PITCH_WALL + KICKER_R, PITCH_W - PITCH_WALL - KICKER_R)
	self.y = clamp(self.y + self.vy, PITCH_WALL + KICKER_R, PITCH_H - PITCH_WALL - KICKER_R)
	if self.kick_cd > 0 {
		self.kick_cd -= 1
	}
}

kicker_process :: proc(self: ^Kicker, delta: f64) {
	if !self.painted && self.pid != 0 {
		self.painted = true
		gd.polygon2d_set_color(self.skin, peer_color(int(self.pid)))
	}
	gd.node2d_set_position(cast(gd.Node2d)self.owner, {self.x, self.y})
}
