package replay

// Runtime diagnostics only. A monotonic microsecond clock must not affect game
// state or input decisions. A missing/failed clock never fails simulation.
Profile_Clock :: struct {user: rawptr, read: proc(user: rawptr) -> (u64, bool)}
Timing :: struct {samples, total_us, max_us, errors: u64, histogram: [20]u64}

profile_read :: proc(clock: Profile_Clock) -> (u64, bool) {
	if clock.read == nil {return 0, false}
	return clock.read(clock.user)
}

timing_add :: proc(t: ^Timing, elapsed_us: u64) {
	t.samples += 1; t.total_us += elapsed_us; t.max_us = max(t.max_us, elapsed_us)
	bucket, ceiling := 0, u64(1)
	for bucket < len(t.histogram) - 1 && elapsed_us > ceiling {bucket += 1; ceiling *= 2}
	t.histogram[bucket] += 1
}

timing_finish :: proc(t: ^Timing, clock: Profile_Clock, started: u64, valid: bool) -> (u64, bool) {
	if clock.read == nil {return 0, false}
	ended, ok := clock.read(clock.user)
	if !valid || !ok || ended < started {t.errors += 1; return ended, false}
	timing_add(t, ended - started)
	return ended, true
}

// Conservative histogram bound, not an exact sample percentile. The last bucket
// includes overflow and uses the actual maximum as its bound. Empty returns zero.
timing_percentile_upper :: proc(t: Timing, percentile: u32) -> u64 {
	if t.samples == 0 {return 0}
	p := u64(clamp(percentile, 1, 100))
	rank := t.samples / 100 * p + (t.samples % 100 * p + 99) / 100
	cumulative, ceiling := u64(0), u64(1)
	for count, bucket in t.histogram {
		cumulative += count
		if cumulative >= rank {return bucket == len(t.histogram) - 1 ? t.max_us : min(ceiling, t.max_us)}
		ceiling *= 2
	}
	return t.max_us
}
