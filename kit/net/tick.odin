package kit_net

// tick — the fixed NET tick and cross-peer clock estimation.
//
// The net tick (default 20 Hz) is when deltas are diffed+sent and commands are
// batched. It is NOT a simulation lockstep: gameplay runs at frame rate; the tick
// only paces the wire. Decoupling means a rendering hitch never distorts send
// pacing math — the accumulator just catches up (capped, so a long stall can't
// spiral into a send burst).
//
// Clock_Sync estimates a remote peer's clock offset from ping samples (EWMA over
// the classic offset = remote + rtt/2 - recv estimate). It powers interpolation
// delay (render remote entities ~100ms in their past) and the stat registry's
// ping column. Friendslop-grade: no drift modeling, just a smoothed offset.

import "core:time"

DEFAULT_TICK_HZ :: 20

// Monotonic seconds — THE clock the toolkit's time-taking APIs expect
// (session_tick, php overlays, confirm-latency math). Every game was
// writing this exact proc; it lives here now.
now_s :: proc "contextless" () -> f64 {
	return f64(time.tick_now()._nsec) / 1e9
}

Ticker :: struct {
	dt:   f64, // seconds per tick
	acc:  f64,
	tick: u64, // total ticks elapsed (the timestamp commands/deltas carry)
}

ticker_make :: proc(hz := DEFAULT_TICK_HZ) -> Ticker {
	assert(hz > 0)
	return Ticker{dt = 1.0 / f64(hz)}
}

// Feed a frame's elapsed time; returns how many net ticks fire this frame
// (usually 0 or 1). Capped at 8 so a multi-second stall resumes cleanly instead
// of bursting a backlog onto the wire.
ticker_advance :: proc(t: ^Ticker, frame_dt: f64) -> int {
	t.acc += frame_dt
	n := 0
	for t.acc >= t.dt && n < 8 {
		t.acc -= t.dt
		t.tick += 1
		n += 1
	}
	if n == 8 {
		t.acc = 0 // dropped backlog — deltas are last-value, nothing is lost
	}
	return n
}

// ---------------------------------------------------------------------------

Clock_Sync :: struct {
	offset:      f64, // remote_clock - local_clock, seconds
	rtt:         f64, // smoothed round trip, seconds
	initialized: bool,
}

// Feed one ping exchange: we sent at local_send, the peer stamped remote_time,
// we received at local_recv (all seconds, each in its own clock domain).
clock_sample :: proc(c: ^Clock_Sync, local_send, remote_time, local_recv: f64) {
	rtt := local_recv - local_send
	if rtt < 0 {return} // nonsense sample (clock adjustment mid-flight); drop
	offset := remote_time + rtt / 2 - local_recv
	if !c.initialized {
		c.rtt = rtt
		c.offset = offset
		c.initialized = true
		return
	}
	ALPHA :: 0.1 // gentle EWMA: one outlier ping barely moves the estimate
	c.rtt += (rtt - c.rtt) * ALPHA
	c.offset += (offset - c.offset) * ALPHA
}

// The remote peer's estimated clock reading "now".
clock_remote_now :: proc(c: ^Clock_Sync, local_now: f64) -> f64 {
	return local_now + c.offset
}

// ---------------------------------------------------------------------------
// The ping/pong wire messages that feed clock_sample. The session layer sends
// a ping every second or so on the reliable channel (rare + tiny; reliability
// keeps the sample loop alive through loss) and answers pings it receives.
// The echoed local_send never needs the peers' clocks to agree — each side
// only ever interprets its OWN timestamps.

// [local_send f64] — stamp with this peer's monotonic seconds.
ping_write :: proc(w: ^Writer, local_now: f64) {
	write_f64(w, local_now)
}

// Answer a received ping: echo the sender's stamp, add our own clock reading.
// Pong layout: [their_send f64][remote_time f64].
ping_answer :: proc(r: ^Reader, w: ^Writer, local_now: f64) {
	write_f64(w, read_f64(r))
	write_f64(w, local_now)
}

// Feed a received pong into the clock estimate. false = malformed/truncated
// (nothing sampled).
pong_apply :: proc(r: ^Reader, c: ^Clock_Sync, local_now: f64) -> bool {
	local_send := read_f64(r)
	remote_time := read_f64(r)
	if r.err {
		return false
	}
	clock_sample(c, local_send, remote_time, local_now)
	return true
}
