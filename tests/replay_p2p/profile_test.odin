package replay_p2p_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import rb "godot:replay/p2p"
import tr "godot:replay/transport"

Profile_Time :: struct {now, increment: u64, valid: bool}
profile_clock :: proc(time: ^Profile_Time) -> r.Profile_Clock {
	return {user = time, read = proc(user: rawptr) -> (u64, bool) {t := cast(^Profile_Time)user; t.now += t.increment; return t.now, t.valid}}
}

@(test)
profiling_accounts_for_actual_work_without_changing_inputs_state_or_failure_policy :: proc(t: ^testing.T) {
	a, b: Fixture
	faults := tr.DEFAULT_FAULTS; faults.latency_ticks, faults.jitter_ticks, faults.loss_permyriad = 3, 1, 1000
	setup(&a, faults); setup(&b, faults); defer cleanup(&a); defer cleanup(&b)
	clock := Profile_Time{increment = 7, valid = true}
	testing.expect_value(t, rb.profile_set(&a.peers[0], profile_clock(&clock)), rb.Error.None)
	for _ in 0 ..< 180 {cycle(&a, 240); cycle(&b, 240)}
	p := &a.peers[0]
	metrics := [3]rb.Profile_Metric{.Step, .Replay, .Hash}
	for metric in metrics {
		samples := p.profile.metrics[metric]
		testing.expect(t, samples.samples > 0)
		testing.expect_value(t, samples.total_us, samples.samples * 7)
		testing.expect_value(t, samples.max_us, u64(7))
	}
	testing.expect(t, p.stats.max_replay_depth > 0 && p.profile.metrics[.Pump].samples > 0)
	clock.valid = false
	for _ in 0 ..< 200 {cycle(&a, 240); cycle(&b, 240)}
	left, _ := r.current(&p.timeline); right, _ := r.current(&b.peers[0].timeline)
	testing.expect(t, reflect.equal(left, right))
	testing.expect_value(t, p.chain, b.peers[0].chain)
	testing.expect_value(t, p.phase, rb.Phase.Running)
	testing.expect(t, p.profile.metrics[.Pump].errors > 0)
	testing.expect_value(t, b.peers[0].profile.metrics[.Pump].samples, u64(0))
}

@(test)
input_latency_measures_capture_to_first_simulation_and_clock_changes_drop_old_marks :: proc(t: ^testing.T) {
	f: Fixture; setup(&f); defer cleanup(&f)
	for _ in 0 ..< 80 {cycle(&f, 30)}
	clock := Profile_Time{valid = true}
	rb.profile_set(&f.peers[0], profile_clock(&clock))
	for _ in 0 ..< 90 {clock.now += 16000; cycle(&f, 60)}
	p := &f.peers[0]
	testing.expect_value(t, p.profile.metrics[.Step].samples, u64(30))
	latency := p.profile.metrics[.Input_Latency]
	testing.expect_value(t, latency.samples, u64(28))
	testing.expect_value(t, latency.total_us, u64(28 * 32000))
	testing.expect_value(t, latency.max_us, u64(32000))
	testing.expect_value(t, r.timing_percentile_upper(latency, 95), u64(32000))
	clock.now = 0
	rb.profile_set(p, profile_clock(&clock))
	for _ in 0 ..< 2 {clock.now += 16000; cycle(&f, 62)}
	testing.expect_value(t, p.profile.metrics[.Input_Latency].samples, u64(0))
	rb.profile_set(p, {})
	testing.expect_value(t, len(p.profile.captures), 0)
	cycle(&f, 63)
	testing.expect_value(t, p.profile.metrics[.Step].samples, u64(0))
}
