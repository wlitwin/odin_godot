package replay_net

import r "godot:replay"

// Optional monotonic microsecond clock. Runtime diagnostics only: never part of
// gameplay, recorded inputs, checkpoints or the wire contract.
Profile_Clock :: r.Profile_Clock
Profile_Metric :: enum {Advance, Pump, Snapshot, Replay, Snapshot_Encode, Snapshot_Delta, Snapshot_Hash, Snapshot_Cache, Snapshot_Validate, Snapshot_Send, Physics_Inspect, Physics_Decode, Physics_Repair, Physics_Compare}

// Adjacent subphases use one clock read per boundary. They are included in the
// outer Snapshot/Pump measurements, not additional independent frame costs.
@(private)
profile_lap :: proc(metrics:^[Profile_Metric]r.Timing,metric:Profile_Metric,clock:Profile_Clock,cursor:^u64,valid:^bool,
                   user:rawptr,sample:proc(user:rawptr,metric:Profile_Metric,elapsed_us:u64)) {
	if clock.read==nil {return}
	ended,ok:=clock.read(clock.user)
	if valid^ && ok && ended>=cursor^ {
		elapsed:=ended-cursor^;r.timing_add(&metrics[metric],elapsed)
		if sample!=nil {sample(user,metric,elapsed)}
	} else {metrics[metric].errors+=1}
	cursor^,valid^=ended,ok
}

@(private)
profile_finish :: proc(metrics: ^[Profile_Metric]r.Timing, metric: Profile_Metric, clock: Profile_Clock, started: u64, valid: bool,
                       user: rawptr, sample: proc(user: rawptr, metric: Profile_Metric, elapsed_us: u64)) {
	ended, ok := r.timing_finish(&metrics[metric], clock, started, valid)
	if ok && sample != nil {sample(user, metric, ended - started)}
}

// Conservative histogram bound, not an exact sample percentile. Zero samples
// returns zero. The overflow bucket uses the actual maximum as its bound.
profile_percentile_upper :: proc(stats: Stats, percentile: u32) -> u64 {
	if stats.replay_samples == 0 {return 0}
	p := u64(clamp(percentile, 1, 100))
	rank := stats.replay_samples / 100 * p + (stats.replay_samples % 100 * p + 99) / 100
	cumulative, ceiling := u64(0), u64(1)
	for count, bucket in stats.replay_histogram {
		cumulative += count
		if cumulative >= rank {return bucket == len(stats.replay_histogram) - 1 ? stats.replay_max_us : min(ceiling, stats.replay_max_us)}
		ceiling *= 2
	}
	return stats.replay_max_us
}

@(private)
profile_start :: proc(clock: Profile_Clock) -> (u64, bool) {
	return r.profile_read(clock)
}

@(private)
profile_replay :: proc(stats: ^Stats, clock: Profile_Clock, start: u64, valid: bool, depth: int,
                       metrics: ^[Profile_Metric]r.Timing, user: rawptr, sample: proc(user: rawptr, metric: Profile_Metric, elapsed_us: u64)) {
	if clock.read == nil {return}
	end, ok := clock.read(clock.user)
	if !valid || !ok || end < start {stats.profile_errors += 1; return}
	elapsed := end - start
	r.timing_add(&metrics[.Replay], elapsed)
	if sample != nil {sample(user, .Replay, elapsed)}
	stats.replay_samples += 1
	stats.replay_wall_us += elapsed
	stats.replay_max_us = max(stats.replay_max_us, elapsed)
	stats.replay_max_depth = max(stats.replay_max_depth, u64(max(depth, 0)))
	// Log2 upper bounds in microseconds; the last bucket also holds overflow.
	bucket, ceiling := 0, u64(1)
	for bucket < len(stats.replay_histogram) - 1 && elapsed > ceiling {bucket += 1; ceiling *= 2}
	stats.replay_histogram[bucket] += 1
}
