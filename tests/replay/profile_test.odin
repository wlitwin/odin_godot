package replay_test

import "core:testing"
import r "godot:replay"

@(test)
timing_histogram_bounds_zero_samples_and_long_outliers :: proc(t: ^testing.T) {
	timing: r.Timing
	testing.expect_value(t, r.timing_percentile_upper(timing, 95), u64(0))
	r.timing_add(&timing, 0)
	testing.expect_value(t, r.timing_percentile_upper(timing, 95), u64(0))
	for _ in 0 ..< 98 {r.timing_add(&timing, 9)}
	r.timing_add(&timing, 2_000_000)
	testing.expect_value(t, r.timing_percentile_upper(timing, 95), u64(16))
	testing.expect_value(t, r.timing_percentile_upper(timing, 100), u64(2_000_000))
	clock := r.Profile_Clock{read = proc(user: rawptr) -> (u64, bool) {return 9, true}}
	_, valid := r.timing_finish(&timing, clock, 10, true)
	testing.expect(t, !valid)
	testing.expect_value(t, timing.errors, u64(1))
	testing.expect_value(t, timing.samples, u64(100))
}
