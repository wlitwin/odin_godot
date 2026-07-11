//gd:extends RigidBody2D
//gd:class Ball
package slopball

// THE BALL — a real RigidBody2D, replicated by play.Puppet: whoever owns it
// simulates it (bounce material, damping, the works); everyone else's copy is
// frozen kinematic and glides on the owner stream. Ownership is granted by the
// HOST's proximity arbitration (last toucher owns — see slopball.odin), so the
// ball needs no commands at all.
//
// The score lives here too, as plain `gd:"replicate"` fields — HOST-authoritative
// deltas on the very entity whose pose a CLIENT may be owner-streaming. Mixed
// authority on one entity is not a trick; it is the tag semantics: `owner`
// fields belong to the owner stream, everything else to the host.

import gd "godot:godot"
import knet "godot:kit/net"
import play "godot:play"

Ball :: struct {
	owner:   gd.Rigid_Body2d,
	look:    gd.Node2d `gd:"onready=Look"`, // the drawn ball — render-error smoothing rides here
	net_id:  knet.Net_Id,
	puppet:  play.Puppet, // pose + velocity replicate through the embed
	score_l: u8 `gd:"replicate"`, // host: goals by the LEFT team (defends left, scores right)
	score_r: u8 `gd:"replicate"`,
	won:     u8 `gd:"replicate"`, // 0 = playing, 1/2 = that side took the match
}

ball_ready :: proc(self: ^Ball) {
	play.puppet_attach(&self.puppet, self.owner, PITCH_W / 2, PITCH_H / 2, skin = self.look)
}

ball_process :: proc(self: ^Ball, delta: f64) {
	play.puppet_frame(&self.puppet, f32(delta))
}
