package play_sim

// play/sim/mover — momentum 2D movement, predicted: velocity APPROACHES the
// target instead of snapping to it, and the whole flight resims.
//
// This is timelines law #4 as a block: inertia is the extrapolation
// smoother. An avatar that can't stop instantly diverges SLOWLY from its
// held-input extrapolation, so a remote stop reads as "slowed a beat late"
// instead of a pull-back — and `accel = 1` collapses the approach to an
// exact snap (vx += (t - vx) * 1 ≡ vx = t) for games that want twitch.
//
// INTENT-THROUGH-FIELDS: the entity's own tick (which has the input) writes
// tx/ty — the velocity it WANTS — every tick, and the block tick integrates
// AFTER it. Intent is recomputed from inputs each tick, so replays
// regenerate it: tx/ty stay untagged by design.
//
//   Kicker :: struct {
//       ...
//       run: psim.Mover, // x/y/vx/vy join the predict set through the embed
//   }
//
//   @(gd_tick = "contested")
//   kicker_tick :: proc(self: ^Kicker, input: Kicker_Input) {
//       dir := normalized({f32(input.move[0]), f32(input.move[1])})
//       self.run.tx = dir.x * RUN_SPEED
//       self.run.ty = dir.y * RUN_SPEED
//   }
//
// Config (accel, bounds) is LAW, not state: plain untagged fields, set at
// spawn on every peer (the census hook runs before the first tick), never on
// the wire. Collision richer than a bounds clamp — pushouts, slides — stays
// the game's, inside its own tick or world pass.

Mover :: struct {
	x, y:   f32 `gd:"replicate,predict,interp"`,
	vx, vy: f32 `gd:"replicate,predict"`,

	// Intent — the wielder's tick writes the velocity it wants, every tick.
	tx, ty: f32,

	// Config — law, not state: same numbers on every peer, set at spawn.
	accel:                      f32, // approach per tick (1 = snap)
	min_x, min_y, max_x, max_y: f32, // position clamp
}

// mover_arm — the LAW half, stamped once per peer at spawn (the census hook
// runs before the first tick). play.gun_equip / health_arm's twin for the
// sim shelf: one call names every config field, so a game can't silently
// leave a bound at zero (the classic "same numbers on every peer" desync —
// an omitted max_y clamps movement to the origin on the peer that forgot it).
// Config never rides the wire, so the SAME args must reach this on every peer
// — feed it constants, or values derived identically everywhere (arena size).
mover_arm :: proc(m: ^Mover, accel: f32, min_x, min_y, max_x, max_y: f32) {
	m.accel = accel
	m.min_x = min_x
	m.min_y = min_y
	m.max_x = max_x
	m.max_y = max_y
}

// The block tick: approach the intent, integrate, clamp. Inputless by
// contract — the input already became tx/ty in the wielder's tick.
@(gd_tick)
mover_tick :: proc(m: ^Mover) {
	m.vx += (m.tx - m.vx) * m.accel
	m.vy += (m.ty - m.vy) * m.accel
	m.x = clamp(m.x + m.vx, m.min_x, m.max_x)
	m.y = clamp(m.y + m.vy, m.min_y, m.max_y)
}
