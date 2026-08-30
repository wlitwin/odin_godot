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
import "core:math"

// THE ENGINE TRAP this block exists to hide: a RigidBody2D IGNORES node
// transform writes — live ones are stomped by the server's next sync, and
// writes made while frozen vanish when the freeze lifts (the server restores
// its own state; slopball's ball snapped back to wherever THIS peer last
// simulated it, one possession stale, every time it took the seat). Every
// pose the puppet imposes goes through PhysicsServer2D.body_set_state; the
// node is written too, but only because the node is what gets drawn.
@(private = "file")
body_impose :: proc(body: gd.Rigid_Body2d, x, y, rot: f32) {
	gd.node2d_set_position(cast(gd.Node2d)body, {x, y})
	gd.node2d_set_rotation(cast(gd.Node2d)body, gd.Float(rot))
	c := math.cos(rot)
	sn := math.sin(rot)
	t := gd.Transform2d{x = {c, sn}, y = {-sn, c}, origin = {x, y}}
	v := gd.variant_from_transform2d(&t)
	gd.physics_server2d_body_set_state(
		gd.singleton_physics_server2d(),
		gd.collision_object2d_get_rid(cast(gd.Collision_Object2d)body),
		.Body_State_Transform, v,
	)
}

// A CUT must not smear: with the engine's physics interpolation on, a
// teleported body streaks between its last two physics states for a tick
// unless the interpolation history is reset at the jump.
@(private = "file")
body_cut :: proc(body: gd.Rigid_Body2d, x, y, rot: f32) {
	body_impose(body, x, y, rot)
	gd.node_reset_physics_interpolation(cast(gd.Node)body)
}

@(private = "file")
body_impel :: proc(body: gd.Rigid_Body2d, vx, vy: f32) {
	vel := gd.Vector2{vx, vy}
	v := gd.variant_from_vector2(&vel)
	gd.physics_server2d_body_set_state(
		gd.singleton_physics_server2d(),
		gd.collision_object2d_get_rid(cast(gd.Collision_Object2d)body),
		.Body_State_Linear_Velocity, v,
	)
}

Puppet :: struct {
	x, y:   f32 `gd:"owner,wire=f16"`, // continuous owner fields interpolate by default
	rot:    f32 `gd:"owner,snap,wire=f16"`, // SNAP, never lerp: an angle
	// interpolated componentwise sweeps the long way around the ±π wrap —
	// a spinning kicked ball whipped its markings a full turn in one sample.
	vx, vy: f32 `gd:"owner,wire=f16"`, // momentum: carried across ownership handoffs
	body:   gd.Rigid_Body2d, // the wrapped node — attach-time, never on the wire
	skin:   gd.Node2d, // optional visual child — render-error smoothing rides on it
	ox, oy: f32, // the render error: TRUTH minus what was drawn, decaying to zero
	mine:   bool, // is THIS peer the simulator right now? (puppet_seat's latch)
	claimed: bool, // PREDICTED possession: simulating on spec, awaiting the referee
	claim_left: f32, // seconds until an unconfirmed claim reverts
}

// RENDER-ERROR SMOOTHING: authority snaps (a seat seed, a handoff re-anchor)
// move the BODY instantly — physics must live at the truth — but the drawn
// skin holds its ground and glides in over ~100ms: the error offset decays
// while the skin counter-translates by it. Small hops vanish; deliberate CUTS
// (kickoff teleports) still snap outright past PUPPET_CUT.
PUPPET_SMOOTH_MIN :: f32(6) // one-frame jumps under this are ordinary motion
PUPPET_CUT :: f32(90) // past this it is a teleport — smoothing a cut looks worse
PUPPET_DECAY :: f32(11) // error half-life ~63ms

@(private = "file")
puppet_absorb :: proc(p: ^Puppet, from_x, from_y, to_x, to_y: f32) {
	if cast(rawptr)p.skin == nil {return}
	jx := to_x - from_x
	jy := to_y - from_y
	d := math.abs(jx) + math.abs(jy)
	if d < PUPPET_SMOOTH_MIN || d > PUPPET_CUT {
		p.ox = 0
		p.oy = 0
		return
	}
	p.ox -= jx // the skin stays where the eye last saw the ball...
	p.oy -= jy
}

@(private = "file")
puppet_skin_frame :: proc(p: ^Puppet, dt: f32) {
	if cast(rawptr)p.skin == nil {return}
	decay := math.exp(-dt * PUPPET_DECAY)
	p.ox *= decay
	p.oy *= decay
	if math.abs(p.ox) + math.abs(p.oy) < 0.5 {
		p.ox = 0
		p.oy = 0
	}
	// ...expressed in the BODY's local space (the body may spin under it).
	c := math.cos(-p.rot)
	sn := math.sin(-p.rot)
	gd.node2d_set_position(p.skin, {c*p.ox - sn*p.oy, sn*p.ox + c*p.oy})
}

// puppet_attach — every peer, at spawn: wrap the body. Everyone starts as a
// watcher (frozen kinematic — solid to the local scene, moved by the stream);
// the first puppet_seat(true) wakes the simulator's solver.
puppet_attach :: proc(p: ^Puppet, body: gd.Rigid_Body2d, x, y: f32, skin: gd.Node2d = nil) {
	p.body = body
	p.skin = skin
	p.mine = false
	p.x = x
	p.y = y
	gd.rigid_body2d_set_freeze_mode(body, .Freeze_Mode_Kinematic)
	gd.rigid_body2d_set_freeze_enabled(body, true)
	body_impose(body, x, y, 0)
}

// puppet_claim — PREDICTED possession: seize the simulation on spec, the
// frame YOUR screen sees the touch, without waiting for the referee. The
// solver wakes immediately (your touch responds with zero latency); the
// entity's registered owner is unchanged, so this peer does NOT stream —
// the flight is private until the grant confirms it. Three endings:
//   confirmed — Ev_Owner_Changed names you; the provisional flight becomes
//               canon seamlessly (puppet_seat skips the re-seed);
//   denied    — someone else is named; you freeze and snap back to their
//               stream (render-error smoothing glides the correction);
//   timed out — no ruling within `hold`: revert quietly the same way.
puppet_claim :: proc(p: ^Puppet, hold: f32 = 0.6) {
	if p.mine || p.claimed || cast(rawptr)p.body == nil {return}
	p.claimed = true
	p.claim_left = hold
	gd.rigid_body2d_set_freeze_enabled(p.body, false)
	body_cut(p.body, p.x, p.y, p.rot)
	body_impel(p.body, p.vx, p.vy)
}

@(private = "file")
puppet_claim_revert :: proc(p: ^Puppet) {
	p.claimed = false
	gd.rigid_body2d_set_freeze_enabled(p.body, true)
	// The next glide snaps the body to the real owner's stream; the jump is
	// absorbed by the skin offset — the wrong guess melts away.
}

// puppet_seat — the handoff: call with `owner == ses.me` on Ev_Owner_Changed
// (and once after spawn/resync). The new simulator unfreezes and seeds the
// solver from the streamed pose and velocity — momentum crosses the seam; a
// demoted simulator freezes and goes back to gliding.
puppet_seat :: proc(p: ^Puppet, mine: bool) {
	if p.mine == mine {
		if !mine && p.claimed {puppet_claim_revert(p)} // denied mid-claim
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
		was := gd.node2d_get_position(cast(gd.Node2d)p.body)
		gd.rigid_body2d_set_freeze_enabled(p.body, false)
		body_cut(p.body, p.x, p.y, p.rot)
		body_impel(p.body, p.vx, p.vy)
		puppet_absorb(p, was.x, was.y, p.x, p.y) // the seed hop glides in
	} else {
		p.claimed = false
		gd.rigid_body2d_set_freeze_enabled(p.body, true)
	}
}

// puppet_frame — every peer, every frame, after the solver ran. The simulator
// publishes the body onto the stream; watchers glide the frozen body along
// the interpolated fields.
puppet_frame :: proc(p: ^Puppet, dt: f32 = 1.0 / 60) {
	if cast(rawptr)p.body == nil {return}
	if p.claimed {
		// Simulating ON SPEC: the body is ours, the FIELDS are not — they
		// keep tracking the registered owner's stream, held ready for the
		// deny-snap. Publish nothing, impose nothing, watch the clock.
		p.claim_left -= dt
		if p.claim_left <= 0 {
			puppet_claim_revert(p)
		}
		puppet_skin_frame(p, dt)
		return
	}
	if p.mine {
		pos := gd.node2d_get_position(cast(gd.Node2d)p.body)
		vel := gd.rigid_body2d_get_linear_velocity(p.body)
		p.x = pos.x
		p.y = pos.y
		p.rot = f32(gd.node2d_get_rotation(cast(gd.Node2d)p.body))
		p.vx = vel.x
		p.vy = vel.y
	} else {
		// The server write matters here too: a node-only glide leaves the
		// PHYSICS body at its stale spot — your avatar collides with an
		// invisible ghost ball while the drawn one slides elsewhere.
		was := gd.node2d_get_position(cast(gd.Node2d)p.body)
		body_impose(p.body, p.x, p.y, p.rot)
		puppet_absorb(p, was.x, was.y, p.x, p.y) // handoff re-anchors glide in
	}
	puppet_skin_frame(p, dt)
}

// puppet_born — the body was just instanced (the scene's default pose) and
// the fields just landed (Ev_Spawned): put the body ON the fields, no glide.
// Call from `<game>_entity_spawned`, before puppet_seat. Without it a
// watcher's body sits at the origin until its first puppet_frame — which is
// the NEXT frame for a body born mid-frame (a host-step spawn, an arrival
// under an injected delay; Godot runs no _process on a node added during
// the _process pass) — one rendered frame in the corner, then a cut.
puppet_born :: proc(p: ^Puppet) {
	if cast(rawptr)p.body == nil {return}
	body_cut(p.body, p.x, p.y, p.rot)
	p.ox = 0 // born IS a cut — nothing to glide from
	p.oy = 0
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
	body_cut(p.body, x, y, 0)
	if p.mine {
		body_impel(p.body, vx, vy)
	}
	p.ox = 0 // a place IS a cut — never glide across a kickoff
	p.oy = 0
}

// puppet_shove — the simulator's impulse verb (a kick, a blast). Claimed
// counts: a predicted possession must kick like a real one, or the touch
// the prediction bought still waits on the referee. A no-op on watchers.
puppet_shove :: proc(p: ^Puppet, ix, iy: f32) {
	if (!p.mine && !p.claimed) || cast(rawptr)p.body == nil {return}
	gd.rigid_body2d_apply_central_impulse(p.body, {ix, iy})
}
