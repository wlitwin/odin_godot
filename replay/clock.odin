package replay

import "core:math"

// Time outside simulation. A failed advance need not consume a prepared tick.
// Call clock_add once per render frame, then clock_consume after each committed
// simulation tick. Excess stall time is accounted for explicitly, never replayed
// as an unbounded burst. Pausing does not build a backlog.
Clock :: struct {
	hz: u32,
	max_steps: u32,
	accumulator: f64,
	dropped_seconds: f64,
	paused: bool,
}

clock_init :: proc(c: ^Clock, hz: u32 = 60, max_steps: u32 = 8) -> bool {
	if hz == 0 || hz > 1000 || max_steps == 0 || max_steps > 1000 {return false}
	c^ = {hz = hz, max_steps = max_steps}
	return true
}

clock_add :: proc(c: ^Clock, dt: f64) -> (steps: u32, ok: bool) {
	if c.hz == 0 || dt < 0 || math.is_nan(dt) || math.is_inf(dt) {return 0, false}
	if c.paused {return 0, true}
	limit := f64(c.max_steps) / f64(c.hz)
	// Clamp dt before addition so even an enormous finite stall can't overflow.
	if dt > limit {c.dropped_seconds += dt - limit}
	c.accumulator += min(dt, limit)
	if c.accumulator > limit {
		c.dropped_seconds += c.accumulator - limit
		c.accumulator = limit
	}
	return min(u32(math.floor(c.accumulator * f64(c.hz) + 1e-9)), c.max_steps), true
}

clock_consume :: proc(c: ^Clock) -> bool {
	if c.hz == 0 || c.paused {return false}
	step := 1.0 / f64(c.hz)
	if c.accumulator + 1e-12 < step {return false}
	c.accumulator = max(c.accumulator - step, 0)
	return true
}

clock_alpha :: proc(c: ^Clock) -> f32 {
	return f32(clamp(c.accumulator * f64(c.hz), 0, 1))
}

// Transition buffering outside the frame; consume edges only after a committed
// tick. A down+up between ticks retains both edges, while held follows the most
// recent device state. Multiple presses of the SAME button coalesce per tick;
// ordered multi-click actions should use a separate bounded action queue.
Buttons :: struct {held, pressed, released: u64}

buttons_set :: proc(b: ^Buttons, held: u64) {
	b.pressed |= held & ~b.held
	b.released |= b.held & ~held
	b.held = held
}

buttons_consume :: proc(b: ^Buttons) {
	b.pressed, b.released = 0, 0
}
