package play

// play/puppet — ONE OWNER SIMULATES, EVERY OTHER SCREEN OBEYS: engine-physics
// replication for a RigidBody2D as a drop-in block. The Godot solver cannot be
// rewound or reconciled, so a shared dynamic body gets exactly one simulating
// peer — the entity's OWNER. The owner's solver is the truth: after each step
// the block publishes the body's pose (+ velocity) onto the owner stream; every
// other peer freezes the body (kinematic, so it stays solid to the local
// scene) and glides it along the interpolated stream.
//
//   Ball :: struct {
//       owner:  gd.Rigid_Body2d,
//       net_id: knet.Net_Id,
//       puppet: play.Puppet,   // pose + velocity replicate through the embed
//   }
//
//   ball_ready:    play.puppet_attach(&self.puppet, self.owner, x, y)
//   ball_process:  play.puppet_frame(&self.puppet)          // every peer, every frame
//   Ev_Owner_Changed(id == ball): play.puppet_seat(&b.puppet, e.owner == ses.me)
//
// WHO OWNS IT is the game's call, made with ksess.session_set_owner from host
// code or a command hook — last-toucher-owns (a ball), the carrier (a crate),
// the driver (a vehicle), or the host forever (world debris). The handoff
// carries momentum: the new simulator seeds its body from the streamed pose
// AND velocity, so a rolling ball keeps rolling through the seam. Remote
// screens snap across the handoff (the kit's Ev_Owner_Changed contract).
//
// The solver only balances what it simulates: two peers' bodies never fight,
// because only one peer's solver ever has the body unfrozen. The cost is the
// friendslop trade everywhere else in the kit: a remote body is ~an interp
// delay behind its simulator, and contacts against it resolve on the
// simulator's screen, not yours. CharacterBody2D avatars don't need this
// block — each peer already move_and_slides only its OWN body and streams
// x/y like any owner field; frozen-kinematic remote pucks stay solid to them.

import gd "godot:godot"

Puppet :: struct {
	x, y:   f32 `gd:"replicate,interp,owner,wire=f16"`, // pose: the owner stream every screen follows
	rot:    f32 `gd:"replicate,interp,owner,wire=f16"`,
	vx, vy: f32 `gd:"replicate,owner,wire=f16"`, // momentum: carried across ownership handoffs
	body:   gd.Rigid_Body2d, // the wrapped node — attach-time, never on the wire
	mine:   bool, // is THIS peer the simulator right now? (puppet_seat's latch)
}

// puppet_attach — every peer, at spawn: wrap the body. Everyone starts as a
// watcher (frozen kinematic — solid to the local scene, moved by the stream);
// the first puppet_seat(true) wakes the simulator's solver.
puppet_attach :: proc(p: ^Puppet, body: gd.Rigid_Body2d, x, y: f32) {
	p.body = body
	p.mine = false
	p.x = x
	p.y = y
	gd.rigid_body2d_set_freeze_mode(body, .Freeze_Mode_Kinematic)
	gd.rigid_body2d_set_freeze_enabled(body, true)
	gd.node2d_set_position(cast(gd.Node2d)body, {x, y})
}

// puppet_seat — the handoff: call with `owner == ses.me` on Ev_Owner_Changed
// (and once after spawn/resync). The new simulator unfreezes and seeds the
// solver from the streamed pose and velocity — momentum crosses the seam; a
// demoted simulator freezes and goes back to gliding.
puppet_seat :: proc(p: ^Puppet, mine: bool) {
	if p.mine == mine {return}
	p.mine = mine
	if cast(rawptr)p.body == nil {return}
	if mine {
		gd.node2d_set_position(cast(gd.Node2d)p.body, {p.x, p.y})
		gd.node2d_set_rotation(cast(gd.Node2d)p.body, gd.Float(p.rot))
		gd.rigid_body2d_set_freeze_enabled(p.body, false)
		gd.rigid_body2d_set_linear_velocity(p.body, {p.vx, p.vy})
	} else {
		gd.rigid_body2d_set_freeze_enabled(p.body, true)
	}
}

// puppet_frame — every peer, every frame, after the solver ran. The simulator
// publishes the body onto the stream; watchers glide the frozen body along
// the interpolated fields.
puppet_frame :: proc(p: ^Puppet) {
	if cast(rawptr)p.body == nil {return}
	if p.mine {
		pos := gd.node2d_get_position(cast(gd.Node2d)p.body)
		vel := gd.rigid_body2d_get_linear_velocity(p.body)
		p.x = pos.x
		p.y = pos.y
		p.rot = f32(gd.node2d_get_rotation(cast(gd.Node2d)p.body))
		p.vx = vel.x
		p.vy = vel.y
	} else {
		gd.node2d_set_position(cast(gd.Node2d)p.body, {p.x, p.y})
		gd.node2d_set_rotation(cast(gd.Node2d)p.body, gd.Float(p.rot))
	}
}

// puppet_place — the simulator teleports the body (kickoff, round reset).
// Pair with ksess.session_teleport(id) on the same frame so remote interp
// snaps to the new spot instead of sliding across the pitch.
puppet_place :: proc(p: ^Puppet, x, y: f32, vx: f32 = 0, vy: f32 = 0) {
	p.x = x
	p.y = y
	p.rot = 0
	p.vx = vx
	p.vy = vy
	if cast(rawptr)p.body == nil {return}
	gd.node2d_set_position(cast(gd.Node2d)p.body, {x, y})
	gd.node2d_set_rotation(cast(gd.Node2d)p.body, 0)
	if p.mine {
		gd.rigid_body2d_set_linear_velocity(p.body, {vx, vy})
	}
}

// puppet_shove — the simulator's impulse verb (a kick, a blast). A no-op on
// watchers by construction: impulses belong to the peer whose solver is live —
// anyone else asks the owner (or takes the seat) first.
puppet_shove :: proc(p: ^Puppet, ix, iy: f32) {
	if !p.mine || cast(rawptr)p.body == nil {return}
	gd.rigid_body2d_apply_central_impulse(p.body, {ix, iy})
}
