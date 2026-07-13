package kit_sim

// tick — the fixed SIMULATION tick and the adaptive lead controller.
//
// Unlike knet.Ticker (which paces the WIRE under frame-rate gameplay), this
// ticker paces the simulation itself: every tick it produces is a call into
// the tick procs, on the server and speculatively on clients. Two additions
// earn it a separate type:
//
//   * TIMESCALE. A client must hold its simulation a lead AHEAD of the
//     server's so its input for tick T arrives just before the server
//     simulates T. Latency drifts; the lead must follow. Dropping or
//     bursting whole ticks to adjust would pop every predicted entity, so
//     the clock BENDS instead: the accumulator consumes frame time scaled by
//     ±SCALE_NUDGE_MAX (2% — beneath perception, ~1.2 ticks/s of correction
//     at 60 Hz), and the lead converges over a second or two.
//   * A CATCH-UP CAP in ticks-behind, not ticks-per-frame. A stalled client
//     (window drag, tab switch) must fast-forward back to server pace —
//     that is resimulation-shaped work the reconcile already bounds — but a
//     multi-second stall resumes from NOW instead of replaying the gap:
//     past MAX_CATCHUP_TICKS the backlog drops and the session re-anchors.
//
// The control loop closes over the wire: the server's Input_Buffer measures
// margin (input headroom over consumption), the session ships it back, and
// lead_control turns the error into a timescale. knet.Clock_Sync provides
// the cold-start estimate before the first margin arrives.

import knet "godot:kit/net"

// The clock never bends more than this — corrections stay beneath perception.
SCALE_NUDGE_MAX :: 0.02

// A frame owing more ticks than this drops its backlog (sim_ticker_advance
// returns at most this many). At 60 Hz: half a second of stall fast-forwards;
// beyond it the session re-anchors rather than replaying a dead gap.
MAX_CATCHUP_TICKS :: 32

Sim_Ticker :: struct {
	dt:    f64, // seconds per tick — THE fixed dt tick procs implicitly step
	acc:   f64,
	tick:  u64, // ticks simulated so far (the client's PREDICTED tick head)
	scale: f64, // timescale: 1.0 nominal, bent by lead_control within ±SCALE_NUDGE_MAX
}

sim_ticker_make :: proc(hz := DEFAULT_SIM_HZ) -> Sim_Ticker {
	assert(hz > 0)
	return Sim_Ticker{dt = 1.0 / f64(hz), scale = 1.0}
}

// Feed a frame's elapsed time; returns how many sim ticks to run this frame.
// Time flows through the scale, so a bent clock accumulates faster or slower
// wall time per tick — the whole timescale mechanism is this one multiply.
sim_ticker_advance :: proc(t: ^Sim_Ticker, frame_dt: f64) -> int {
	t.acc += frame_dt * t.scale
	n := 0
	for t.acc >= t.dt && n < MAX_CATCHUP_TICKS {
		t.acc -= t.dt
		t.tick += 1
		n += 1
	}
	if n == MAX_CATCHUP_TICKS {
		t.acc = 0 // stall backlog dropped — the session re-anchors the lead
	}
	return n
}

// ---------------------------------------------------------------------------
// The lead: how many ticks ahead of the server a client runs.

// Cold-start estimate from the clock sync, before any margin feedback exists:
// one way of transit for the input (rtt/2), a jitter allowance (the QUALITY
// number — a wobbling link needs more headroom than a slow steady one), and
// `slack` ticks of de-jitter buffer on the server side. Ceil'd: arriving a
// fraction early is a buffer, arriving a fraction late is a held input.
lead_target :: proc(clock: ^knet.Clock_Sync, dt: f64, jitter_mult := 2.0, slack_ticks := 1) -> int {
	seconds := clock.rtt / 2 + clock.jitter * jitter_mult
	ticks := int((seconds + dt - 1e-9) / dt) // ceil in tick units
	return max(ticks, 1) + slack_ticks
}

// Bend the clock toward closing `error_ticks`:
//
//   error > 0  — the client is BEHIND where it should be (server margin
//                shrinking, inputs arriving late): run fast.
//   error < 0  — wasted latency (inputs pooling server-side): run slow.
//
// Proportional with saturation: the full ±nudge applies from |error| ≥ 2
// ticks, tapering linearly inside that — small steady errors breathe away
// without oscillation, and the scale re-centers on 1.0 as the error dies.
// Call once per margin update (or per frame; it is idempotent on the same
// error). The session glue computes error as target_lead − measured_margin.
lead_control :: proc(t: ^Sim_Ticker, error_ticks: f64, nudge := SCALE_NUDGE_MAX) {
	p := clamp(error_ticks / 2.0, -1.0, 1.0)
	t.scale = 1.0 + p * nudge
}
