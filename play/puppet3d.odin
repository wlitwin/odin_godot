package play

// play/puppet3d — play.Puppet's 3D sibling: ONE OWNER SIMULATES, EVERY OTHER
// SCREEN OBEYS, for a RigidBody3D. Same contract, same feel ledger (seat
// seeding, render-error smoothing, cuts, predicted possession) — see
// puppet.odin for the full design story; this file only documents where the
// third dimension changes something.
//
//   Ball :: struct {
//       owner:  gd.Rigid_Body3d,
//       net_id: knet.Net_Id,
//       puppet: play.Puppet3,   // pose + velocities replicate through the embed
//   }
//
//   ball_ready:    play.puppet3_attach(&self.puppet, self.owner, {x, y, z})
//   ball_process:  play.puppet3_frame(&self.puppet)          // every peer, every frame
//   Ev_Owner_Changed(id == ball): play.puppet3_seat(&b.puppet, e.owner == ses.me)
//
// What 3D changes:
//   * ROTATION IS A QUATERNION, and unlike the 2D block it CAN interp: the
//     stream layer's .Quat lerp (hemisphere-safe nlerp) is exactly the correct
//     blend, so watchers see a tumbling body turn smoothly instead of stepping.
//   * ANGULAR VELOCITY crosses the seam too. 2D got away without it (a scalar
//     spin on a circle is cosmetic); a 3D ball's tumble IS its rolling contact —
//     a handoff that dropped it would visibly skid.
//   * Distances are METERS: the smoothing thresholds below assume human-scale
//     worlds (a ~16m pitch), 1/40th of the 2D pixel constants.

import gd "godot:godot"
import "core:math"

// THE ENGINE TRAP is identical in 3D: a RigidBody3D ignores node transform
// writes (live ones stomped at the server's next sync, frozen ones erased when
// the freeze lifts). Every imposed pose goes through PhysicsServer3D
// body_set_state; the node is written too, but only because the node is what
// gets drawn. The node write happens FIRST so its transform (position +
// quaternion, one source of truth) is what the server receives.
@(private = "file")
body3_impose :: proc(body: gd.Rigid_Body3d, pos: [3]f32, rot: gd.Quaternion) {
	n := cast(gd.Node3d)body
	gd.node3d_set_position(n, pos)
	gd.node3d_set_quaternion(n, rot)
	t := gd.node3d_get_transform(n)
	v := gd.variant_from_transform3d(&t)
	gd.physics_server3d_body_set_state(
		gd.singleton_physics_server3d(),
		gd.collision_object3d_get_rid(cast(gd.Collision_Object3d)body),
		.Body_State_Transform, v,
	)
}

@(private = "file")
body3_cut :: proc(body: gd.Rigid_Body3d, pos: [3]f32, rot: gd.Quaternion) {
	body3_impose(body, pos, rot)
	gd.node_reset_physics_interpolation(cast(gd.Node)body)
}

@(private = "file")
body3_impel :: proc(body: gd.Rigid_Body3d, vel, avel: [3]f32) {
	rid := gd.collision_object3d_get_rid(cast(gd.Collision_Object3d)body)
	srv := gd.singleton_physics_server3d()
	lv := gd.Vector3(vel)
	gd.physics_server3d_body_set_state(srv, rid, .Body_State_Linear_Velocity, gd.variant_from_vector3(&lv))
	av := gd.Vector3(avel)
	gd.physics_server3d_body_set_state(srv, rid, .Body_State_Angular_Velocity, gd.variant_from_vector3(&av))
}

@(private = "file")
QUAT3_ID :: quaternion(w = f32(1), x = 0, y = 0, z = 0)

Puppet3 :: struct {
	pos:  [3]f32 `gd:"replicate,interp,owner,wire=f16"`, // pose: the owner stream every screen follows
	rot:  gd.Quaternion `gd:"replicate,interp,owner"`, // .Quat nlerp — 3D rotation interps CORRECTLY
	vel:  [3]f32 `gd:"replicate,owner,wire=f16"`, // momentum: carried across ownership handoffs
	avel: [3]f32 `gd:"replicate,owner,wire=f16"`, // tumble: the rolling contact must cross the seam too
	body: gd.Rigid_Body3d, // the wrapped node — attach-time, never on the wire
	skin: gd.Node3d, // optional visual child — render-error smoothing rides on it
	off:  [3]f32, // the render error: TRUTH minus what was drawn, decaying to zero
	mine: bool, // is THIS peer the simulator right now? (puppet3_seat's latch)
	claimed: bool, // PREDICTED possession: simulating on spec, awaiting the referee
	claim_left: f32, // seconds until an unconfirmed claim reverts
}

// Meters (2D's pixel thresholds / 40 — a ~16m pitch against a 640px one).
PUPPET3_SMOOTH_MIN :: f32(0.15) // one-frame jumps under this are ordinary motion
PUPPET3_CUT :: f32(2.25) // past this it is a teleport — smoothing a cut looks worse
PUPPET3_DECAY :: f32(11) // error half-life ~63ms

@(private = "file")
puppet3_absorb :: proc(p: ^Puppet3, from, to: [3]f32) {
	if cast(rawptr)p.skin == nil {return}
	j := to - from
	d := math.abs(j.x) + math.abs(j.y) + math.abs(j.z)
	if d < PUPPET3_SMOOTH_MIN || d > PUPPET3_CUT {
		p.off = {}
		return
	}
	p.off -= j // the skin stays where the eye last saw the body...
}

// ...expressed in the BODY's local space (the body tumbles under it): the
// world-space error is carried through the inverse rotation before it lands
// on the skin's local position.
@(private = "file")
quat3_unspin :: proc "contextless" (q: gd.Quaternion, v: [3]f32) -> [3]f32 {
	c := transmute([4]f32)q
	x, y, z, w := -c[0], -c[1], -c[2], c[3] // conjugate: rotate by q⁻¹
	tx := 2 * (y * v.z - z * v.y)
	ty := 2 * (z * v.x - x * v.z)
	tz := 2 * (x * v.y - y * v.x)
	return {
		v.x + w * tx + (y * tz - z * ty),
		v.y + w * ty + (z * tx - x * tz),
		v.z + w * tz + (x * ty - y * tx),
	}
}

@(private = "file")
puppet3_skin_frame :: proc(p: ^Puppet3, dt: f32) {
	if cast(rawptr)p.skin == nil {return}
	decay := math.exp(-dt * PUPPET3_DECAY)
	p.off *= decay
	if math.abs(p.off.x) + math.abs(p.off.y) + math.abs(p.off.z) < 0.0125 {
		p.off = {}
	}
	gd.node3d_set_position(p.skin, quat3_unspin(p.rot, p.off))
}

// puppet3_attach — every peer, at spawn: wrap the body. Everyone starts as a
// watcher (frozen kinematic — solid to the local scene, moved by the stream);
// the first puppet3_seat(true) wakes the simulator's solver.
puppet3_attach :: proc(p: ^Puppet3, body: gd.Rigid_Body3d, pos: [3]f32, skin: gd.Node3d = nil) {
	p.body = body
	p.skin = skin
	p.mine = false
	p.pos = pos
	p.rot = QUAT3_ID
	gd.rigid_body3d_set_freeze_mode(body, .Freeze_Mode_Kinematic)
	gd.rigid_body3d_set_freeze_enabled(body, true)
	body3_impose(body, pos, QUAT3_ID)
}

// puppet3_claim — PREDICTED possession, same three endings as the 2D block:
// confirmed (seamless), denied (freeze + smoothed snap to the real stream),
// timed out (revert quietly the same way).
puppet3_claim :: proc(p: ^Puppet3, hold: f32 = 0.6) {
	if p.mine || p.claimed || cast(rawptr)p.body == nil {return}
	p.claimed = true
	p.claim_left = hold
	gd.rigid_body3d_set_freeze_enabled(p.body, false)
	body3_cut(p.body, p.pos, p.rot)
	body3_impel(p.body, p.vel, p.avel)
}

@(private = "file")
puppet3_claim_revert :: proc(p: ^Puppet3) {
	p.claimed = false
	gd.rigid_body3d_set_freeze_enabled(p.body, true)
	// The next glide snaps the body to the real owner's stream; the jump is
	// absorbed by the skin offset — the wrong guess melts away.
}

// puppet3_seat — the handoff: call with `owner == ses.me` on Ev_Owner_Changed
// (and once after spawn/resync). The new simulator unfreezes and seeds the
// solver from the streamed pose and BOTH velocities — momentum and tumble
// cross the seam; a demoted simulator freezes and goes back to gliding.
puppet3_seat :: proc(p: ^Puppet3, mine: bool) {
	if p.mine == mine {
		if !mine && p.claimed {puppet3_claim_revert(p)} // denied mid-claim
		return
	}
	p.mine = mine
	if cast(rawptr)p.body == nil {return}
	if mine {
		if p.claimed {
			// The prediction CONFIRMED: the provisional flight is already
			// the freshest truth there is — re-seeding from the (older)
			// streamed fields would yank it backward. Just take the seat.
			p.claimed = false
			return
		}
		// Unfreeze FIRST: lifting the freeze restores the server's stored
		// state, so the seed must land on the LIVE body or it is erased.
		was := gd.node3d_get_position(cast(gd.Node3d)p.body)
		gd.rigid_body3d_set_freeze_enabled(p.body, false)
		body3_cut(p.body, p.pos, p.rot)
		body3_impel(p.body, p.vel, p.avel)
		puppet3_absorb(p, was, p.pos) // the seed hop glides in
	} else {
		p.claimed = false
		gd.rigid_body3d_set_freeze_enabled(p.body, true)
	}
}

// puppet3_frame — every peer, every frame, after the solver ran. The simulator
// publishes the body onto the stream; watchers glide the frozen body along
// the interpolated fields.
puppet3_frame :: proc(p: ^Puppet3, dt: f32 = 1.0 / 60) {
	if cast(rawptr)p.body == nil {return}
	if p.claimed {
		// Simulating ON SPEC: the body is ours, the FIELDS are not — they
		// keep tracking the registered owner's stream, held ready for the
		// deny-snap. Publish nothing, impose nothing, watch the clock.
		p.claim_left -= dt
		if p.claim_left <= 0 {
			puppet3_claim_revert(p)
		}
		puppet3_skin_frame(p, dt)
		return
	}
	if p.mine {
		n := cast(gd.Node3d)p.body
		p.pos = gd.node3d_get_position(n)
		p.rot = gd.node3d_get_quaternion(n)
		p.vel = gd.rigid_body3d_get_linear_velocity(p.body)
		p.avel = gd.rigid_body3d_get_angular_velocity(p.body)
	} else {
		// The server write matters here too: a node-only glide leaves the
		// PHYSICS body at its stale spot — your avatar collides with an
		// invisible ghost while the drawn one slides elsewhere.
		was := gd.node3d_get_position(cast(gd.Node3d)p.body)
		body3_impose(p.body, p.pos, p.rot)
		puppet3_absorb(p, was, p.pos) // handoff re-anchors glide in
	}
	puppet3_skin_frame(p, dt)
}

// puppet3_place — the simulator teleports the body (kickoff, round reset).
// Pair with ksess.session_teleport(id) on the same frame so remote interp
// snaps to the new spot instead of sliding across the pitch.
puppet3_place :: proc(p: ^Puppet3, pos: [3]f32, vel: [3]f32 = {}) {
	p.pos = pos
	p.rot = QUAT3_ID
	p.vel = vel
	p.avel = {}
	if cast(rawptr)p.body == nil {return}
	body3_cut(p.body, pos, QUAT3_ID)
	if p.mine {
		body3_impel(p.body, vel, {})
	}
	p.off = {} // a place IS a cut — never glide across a kickoff
}

// puppet3_shove — the simulator's impulse verb (a kick, a blast). Claimed
// counts: a predicted possession must kick like a real one, or the touch
// the prediction bought still waits on the referee. A no-op on watchers.
puppet3_shove :: proc(p: ^Puppet3, imp: [3]f32) {
	if (!p.mine && !p.claimed) || cast(rawptr)p.body == nil {return}
	gd.rigid_body3d_apply_central_impulse(p.body, gd.Vector3(imp))
}
