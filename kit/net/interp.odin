package kit_net

// interp — delayed interpolated sampling for remote entities.
//
// Owner-authoritative streams arrive as timestamped snapshots on the unreliable
// channel. Remote peers don't render the newest sample — they render the state as
// of (now - delay), with delay ≈ 2 send intervals (~100ms at 20Hz): there is
// almost always a bracketing PAIR of samples to lerp between, so motion stays
// smooth through jitter and through any single dropped packet (last-value
// semantics: the gap just widens one interval and the lerp spans it).
//
// Beyond the buffer: sampling before the oldest sample clamps to it; sampling
// past the newest (a real gap — several drops or a hitching sender) clamps and
// HOLDS rather than extrapolating into a guess. Friendslop-grade: a briefly
// frozen enemy beats one that rockets off on a stale velocity.

INTERP_CAP :: 16 // samples kept per buffer; at 20Hz that's 800ms of history

Interp_Sample :: struct($T: typeid) {
	t: f64,
	v: T,
}

Interp_Buffer :: struct($T: typeid) {
	samples: [INTERP_CAP]Interp_Sample(T), // ring, oldest at `head`
	head:    int,
	count:   int,
}

// Push a timestamped sample. Out-of-order arrivals older than the newest sample
// are DROPPED (unreliable-sequenced transports already discard reordered packets;
// this is the belt to that suspenders).
interp_push :: proc(b: ^Interp_Buffer($T), t: f64, v: T) {
	if b.count > 0 {
		newest := b.samples[(b.head + b.count - 1) % INTERP_CAP]
		if t <= newest.t {
			return
		}
	}
	if b.count < INTERP_CAP {
		b.samples[(b.head + b.count) % INTERP_CAP] = {t, v}
		b.count += 1
	} else {
		b.samples[b.head] = {t, v}
		b.head = (b.head + 1) % INTERP_CAP
	}
}

// Sample the buffered timeline at time `t` using `lerp`. ok=false only when the
// buffer is empty (caller keeps the entity at its spawn/last state).
interp_sample :: proc(b: ^Interp_Buffer($T), t: f64, lerp: proc(a, b: T, alpha: f32) -> T) -> (v: T, ok: bool) {
	if b.count == 0 {
		return {}, false
	}
	oldest := b.samples[b.head]
	newest := b.samples[(b.head + b.count - 1) % INTERP_CAP]
	if t <= oldest.t {
		return oldest.v, true
	}
	if t >= newest.t {
		return newest.v, true // clamp-and-hold: never extrapolate
	}
	// Find the bracketing pair (count is small; linear scan beats cleverness).
	for i in 1 ..< b.count {
		hi := b.samples[(b.head + i) % INTERP_CAP]
		if t <= hi.t {
			lo := b.samples[(b.head + i - 1) % INTERP_CAP]
			span := hi.t - lo.t
			alpha := span > 0 ? f32((t - lo.t) / span) : 1
			return lerp(lo.v, hi.v, alpha), true
		}
	}
	return newest.v, true // unreachable given the clamps; safe fallback
}

// The standard render-time for remote entities: the sender's estimated clock,
// pulled back by `delay` seconds (≈ 2 send intervals).
interp_render_time :: proc(c: ^Clock_Sync, local_now: f64, delay: f64) -> f64 {
	return clock_remote_now(c, local_now) - delay
}
