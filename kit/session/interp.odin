package kit_session

// Adaptive interp delay — an OPT-IN slew controller for how far in the past
// remote entities render (session.interp_delay). See Session_Config.interp_adapt.
//
// The problem it solves: interp_delay is ONE number, and one number can't serve
// a LAN and a 120ms link. The two-timelines discipline (docs/kit/net.md) is
// exact only while a stream's transit+jitter stays under interp_delay; tuned for
// a LAN, it undershoots on a real link and remote motion samples past the last
// packet (an overshoot the render clock can't hide). Tuned for the worst link,
// it renders a LAN needlessly ~100ms stale. Adapting closes both.
//
// The controller is a PURE function of (current delay, the link's raw need, dt).
// It carries no clock, no Session, no allocation — the session feeds it the
// worst active peer's need each tick and stores the result back into
// interp_delay, and this file's tests drive it with synthetic sequences. The
// asymmetry is the whole design:
//
//   - GROW promptly (GROW_RATE, straight at the target): headroom is
//     correctness. The cost of over-delaying is remote bodies briefly ~75%
//     speed as the buffer fills — a smoothness tax, not a break.
//   - SHRINK slowly (SHRINK_RATE, ~12x slower) and HYSTERETICALLY (only after
//     the target has read better by SHRINK_DEADBAND for SHRINK_HOLD continuous
//     seconds, re-armed by ANY grow): shrinking INTO a spike causes the exact
//     stall the delay exists to prevent. The ratchet is the anti-oscillation
//     argument — the same lesson as the sim-lane deep-nudge scar.
//
// This tracks the SAME ClockSync rtt/jitter the ping stat and the sim-lane
// cold-start lead already read — no second estimator.

// Grow at this many seconds of delay per real second, straight toward target.
GROW_RATE :: 0.25
// Shrink this slowly (per real second) — deliberately ~12x under GROW_RATE.
SHRINK_RATE :: 0.02
// The target must beat the current delay by this margin to count as "better"
// at all — noise inside the band is not a reason to shrink.
SHRINK_DEADBAND :: 0.010 // 10 ms
// ...and it must STAY better for this many continuous seconds before a shrink
// begins. Any grow re-arms this to zero.
SHRINK_HOLD :: 5.0 // s
// Fixed headroom added to the raw need (rtt/2 + 2*jitter) — the target is
// always a hair above what the link strictly requires.
INTERP_MARGIN :: 0.010 // 10 ms

// The controller state. min/max are the clamp band (resolved from the config at
// *_start: min = the configured/DEFAULT interp_delay, the floor a set
// interp_delay still guarantees; max = the ceiling). delay is the live value the
// session reads. target and shrink_s are the controller's own memory.
Interp_Adapt :: struct {
	min:      f64,
	max:      f64,
	delay:    f64, // the current interp_delay (what the session renders against)
	target:   f64, // last-computed target (need + margin, clamped) — for the netgraph/tests
	shrink_s: f64, // continuous seconds the target has read below delay-deadband
}

// interp_adapt_reset — arm the controller at *_start. floor is the delay a set
// interp_delay still guarantees (and the value adapting starts from); ceiling is
// the cap. Adapting begins at the floor and only ever grows from real link need.
interp_adapt_reset :: proc(a: ^Interp_Adapt, floor, ceiling: f64) {
	a^ = Interp_Adapt {
		min    = floor,
		max    = max(ceiling, floor), // a nonsense ceiling below the floor collapses to the floor
		delay  = floor,
		target = floor,
	}
}

// interp_adapt_update — advance the controller by dt real seconds toward the
// link's raw need (want = max over active peers of rtt/2 + 2*jitter, BEFORE the
// margin). Returns the new delay (also stored in a.delay). Pure: same inputs,
// same output — the property the tests lean on.
interp_adapt_update :: proc(a: ^Interp_Adapt, want, dt: f64) -> f64 {
	if dt <= 0 {
		return a.delay
	}
	target := want + INTERP_MARGIN
	target = clamp(target, a.min, a.max)
	a.target = target

	cur := a.delay
	switch {
	case target > cur:
		// GROW: straight at the target, and re-arm the shrink gate. A link that
		// pokes back up mid-hold resets the whole 5-second countdown, by design.
		cur = min(cur + GROW_RATE * dt, target)
		a.shrink_s = 0
	case target < cur - SHRINK_DEADBAND:
		// The target reads better by more than the deadband — start (or continue)
		// the hysteresis countdown; only actually shrink once it has held.
		a.shrink_s += dt
		if a.shrink_s >= SHRINK_HOLD {
			cur = max(cur - SHRINK_RATE * dt, target)
		}
	case:
		// Inside the deadband: neither grow nor commit to a shrink. Hold, and drop
		// any partial countdown — the link is effectively where we render it.
		a.shrink_s = 0
	}

	a.delay = clamp(cur, a.min, a.max)
	return a.delay
}
