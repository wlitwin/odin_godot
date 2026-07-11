//gd:extends RigidBody3D
//gd:class Ball3
package slopball3d

// THE BALL — a real RigidBody3D under real gravity, replicated by
// play.Puppet3: whoever owns it simulates it (bounce material, damping,
// gravity, the tumble); everyone else's copy is frozen kinematic and glides
// on the owner stream — position AND quaternion, hemisphere-safe nlerp'd, so
// a spinning lofted ball turns smoothly on every screen. Ownership is granted
// by the HOST's proximity arbitration (last toucher owns — see slopball3d.odin).
//
// The score lives here too, as plain `gd:"replicate"` fields — HOST-authoritative
// deltas on the very entity whose pose a CLIENT may be owner-streaming; mixed
// authority on one entity is exactly what the field tags mean.

import gd "godot:godot"
import knet "godot:kit/net"
import play "godot:play"

Ball3 :: struct {
	owner:   gd.Rigid_Body3d,
	look:    gd.Node3d `gd:"onready=Look"`, // the drawn ball — render-error smoothing rides here
	net_id:  knet.Net_Id,
	puppet:  play.Puppet3, // pose + both velocities replicate through the embed
	score_l: u8 `gd:"replicate"`, // host: goals by the LEFT team (defends left, scores right)
	score_r: u8 `gd:"replicate"`,
	won:     u8 `gd:"replicate"`, // 0 = playing, 1/2 = that side took the match
}

ball3_ready :: proc(self: ^Ball3) {
	play.puppet3_attach(&self.puppet, self.owner, {PITCH_W / 2, BALL_REST_Y, PITCH_D / 2}, skin = self.look)
}

ball3_process :: proc(self: ^Ball3, delta: f64) {
	play.puppet3_frame(&self.puppet, f32(delta))
}
