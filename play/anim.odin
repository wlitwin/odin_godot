package play

import "core:math"

// play/anim — presentation CLOCKS: tiny float eases you advance each frame and read
// to drive a tint, a scale, a rotation. Pure float math (no engine calls), but
// presentation-by-convention — they live in an entity's `view` scratch beside the
// play.Edge shadows, off the wire. Four shapes the dogfood games kept re-spelling
// (decay to 0, ramp to 1, free-run a phase, hold-while-active) plus the pulse reads
// that turn a phase into an oscillation.
//
// These are pure, so unlike play/marker they'd be safe in a host tick — but there is
// no reason to run presentation there; keep them in the render path all the same.

// decay eases a clock toward 0 at `rate`/sec and returns the new value — the
// hit-recoil / flash shape: poke it to a peak on the event, read it as it falls.
decay :: proc(t: ^f32, dt, rate: f32) -> f32 {
	t^ = max(t^ - dt * rate, 0)
	return t^
}

// ramp eases a clock toward 1 at `rate`/sec — the death-topple / reveal shape: poke
// it to a tiny nonzero, it climbs to 1 and holds there.
ramp :: proc(t: ^f32, dt, rate: f32) -> f32 {
	t^ = min(t^ + dt * rate, 1)
	return t^
}

// advance free-runs a clock upward at `rate` (a flicker/throb phase fed to pulse); it
// never resets itself — zero it when the effect ends.
advance :: proc(t: ^f32, dt, rate: f32) -> f32 {
	t^ += dt * rate
	return t^
}

// hold advances the clock while `on`, snapping it to 0 when not — the scuttle-bob
// shape (bob only while moving, still the instant you stop).
hold :: proc(t: ^f32, dt, rate: f32, on: bool) -> f32 {
	t^ = on ? t^ + dt * rate : 0
	return t^
}

// pulse is sin(t) in [-1,1]; pulse01 is the same remapped to [0,1] for a tint or a
// scale wobble. Read-only — feed a phase advanced by `advance`/`hold`.
pulse :: proc(t: f32) -> f32 {
	return math.sin(t)
}
pulse01 :: proc(t: f32) -> f32 {
	return (math.sin(t) + 1) * 0.5
}
