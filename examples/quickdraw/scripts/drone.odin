//gd:extends Node2D
//gd:class Drone
package quickdraw

// A DRONE — the companion each duelist steers ALONGSIDE their gunner, and
// kit/sim's MULTI-INPUT showcase. The same player, on the same tick, drives two
// entities from two DIFFERENT input structs: the gunner reads Gunner_Input, the
// drone reads Drone_Input, and each ships its own window on the one upstream
// packet. The drone predicts locally exactly like the avatar — its steer
// answers your hand THIS instant at any latency — and its timeline never
// crosses the gunner's: a resim of one leaves the other untouched.
//
// It carries no weapon; it exists to prove that a second input class flows the
// whole distance — sampled, shipped, de-jittered, routed, predicted, resimmed —
// in a real game beside a first.

import "core:fmt"
import gd "godot:godot"
import knet "godot:kit/net"

Drone :: struct {
	owner:  gd.Node2d,
	skin:   gd.Polygon2d `gd:"onready=Skin"`,
	net_id: knet.Net_Id,

	// The predicted position — server-simulated from the drone's own input,
	// client-predicted, reconciled. The same predict/interp story as a gunner.
	x, y: f32 `gd:"predict,interp"`,

	// Delta lane: whose drone (its color; the acid's ownership).
	pid: u8 `gd:"replicate"`,

	// Local scratch — never on the wire.
	mine:    bool, // set by the census hook: my drone
	painted: bool,
	home_x:  f32, // first-shown x, for the acid's moved-under-its-own-input edge
	moved:   bool,
}

// The SECOND input class — distinct from Gunner_Input (a different struct, a
// different width). Just a steer direction; the drone hovers where you point
// it, on its own window on the wire.
Drone_Input :: struct {
	steer: [2]i8, // -1/0/1 per axis
}

// Pure predicted state driven by the drone's OWN input — never the gunner's.
// Self-integrating, so every peer's between-batch prediction is exact and a
// reconcile of the avatar can't perturb it.
@(gd_tick)
drone_tick :: proc(self: ^Drone, input: Drone_Input) {
	self.x += f32(input.steer[0]) * DRONE_SPEED
	self.y += f32(input.steer[1]) * DRONE_SPEED
	self.x = clamp(self.x, ARENA_WALL, ARENA_W - ARENA_WALL)
	self.y = clamp(self.y, ARENA_WALL, ARENA_H - ARENA_WALL)
}

drone_process :: proc(self: ^Drone, delta: f64) {
	if !self.painted && self.pid != 0 {
		self.painted = true
		self.home_x = self.x
		gd.polygon2d_set_color(self.skin, peer_color(int(self.pid)))
	}
	gd.node2d_set_position(cast(gd.Node2d)self.owner, {self.x, self.y})

	// The acid's edge: MY drone has visibly moved on MY OWN screen — predicted
	// from the second input class, no round trip. Fires once.
	if self.mine && !self.moved && self.painted && abs(self.x - self.home_x) > 30 {
		self.moved = true
		gd.print_str(fmt.tprintf("QD_DRONE_LOCAL x=%.1f dx=%.1f", self.x, self.x - self.home_x))
	}
}
