package play_sim

// play/sim/roller — the contested rolling body: timelines laws #5 and #6,
// packaged. A ball (a crate, a puck) that integrates its OWN flight, so
// every peer's between-batch prediction is good — friction, a hard speed
// ceiling, and walls that eat energy, all inside the sim where every screen
// clamps identically.
//
//   Ball :: struct {
//       ...
//       roll: psim.Roller, // x/y/vx/vy join the predict set through the embed
//   }
//
// The entity's own tick runs BEFORE the block's, which makes the division of
// labor natural: the entity reads LAST tick's settled pose (a Roller
// crossing lands exactly ON the clamped wall for one tick — compare against
// the bound and you've detected it), decides consequences (goals, resets,
// freezes), and writes velocity when it must (a freeze writes 0; the block
// then integrates a no-op). Impulses — kicks, spikes, contact nudges — stay
// the game's: world passes and verbs write vx/vy directly, the same fields
// they always wrote.
//
// Config is LAW, not state: plain untagged fields, set at spawn on every
// peer (the census hook runs before the first tick), never on the wire.

import "core:math"

Roller :: struct {
	x, y:   f32 `gd:"replicate,predict,interp"`,
	vx, vy: f32 `gd:"replicate,predict"`,

	// Config — law, not state: same numbers on every peer, set at spawn.
	friction:                   f32, // velocity retained per tick (law #5: self-simulating flight)
	max_speed:                  f32, // hard per-tick ceiling (law #6: clamp in the tick, every peer alike)
	bounce:                     f32, // wall restitution — walls eat energy, so a
	                                 // kicked ball doesn't ping-pong back at full
	                                 // speed into the foot that sent it
	min_x, min_y, max_x, max_y: f32, // the walls
}

// The block tick: friction, cap, integrate, bounce. Inputless and
// self-simulating by contract — nobody drives a rolling body, they impulse
// it and physics does the rest.
@(gd_tick)
roller_tick :: proc(r: ^Roller) {
	r.vx *= r.friction
	r.vy *= r.friction
	sp2 := r.vx * r.vx + r.vy * r.vy
	if sp2 > r.max_speed * r.max_speed {
		s := r.max_speed / math.sqrt(sp2)
		r.vx *= s
		r.vy *= s
	}
	r.x += r.vx
	r.y += r.vy
	if r.x <= r.min_x {
		r.x = r.min_x
		r.vx = -r.vx * r.bounce
	}
	if r.x >= r.max_x {
		r.x = r.max_x
		r.vx = -r.vx * r.bounce
	}
	if r.y <= r.min_y {
		r.y = r.min_y
		r.vy = -r.vy * r.bounce
	}
	if r.y >= r.max_y {
		r.y = r.max_y
		r.vy = -r.vy * r.bounce
	}
}
