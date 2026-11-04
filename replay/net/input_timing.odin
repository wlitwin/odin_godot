package replay_net

// Runtime observations only: no timing estimates or local clock values enter a
// gameplay frame, checkpoint, action schedule or protocol contract.
@(private)
Input_Sent :: struct {
    tick, at_ms: u64,
    valid:       bool,
}

@(private)
Input_Timing :: struct {
    last_echo, window_at, peak_ms, previous_peak_ms, turnaround_ms: u64,
    samples:                                                        u32,
    arrival_lead:                                                   f64,
}

@(private)
client_timing_reset :: proc(c: ^Client($S, $C, $A, $E, $N)) {
    for &sent in c.input_sent {
        sent = {}
    }

    c.input_timing = {}
    c.clock_scale = 1
}

@(private)
client_note_input_sent :: proc(c: ^Client($S, $C, $A, $E, $N), tick: u64) {
    slot := &c.input_sent[tick % u64(len(c.input_sent))]

    // Keep the first successful transport submission when a window repeats a tick.
    if !slot.valid || slot.tick != tick {
        slot^ = {tick, c.now, true}
    }
}

@(private)
client_input_feedback :: proc(c: ^Client($S, $C, $A, $E, $N), newest, truth_tick: u64) {
    if c.spectator || c.model.control_timing == .Latest_Observation {
        c.clock_scale = 1
        return
    }

    if newest == 0 {
        // With no accepted input yet, stale submissions cannot supply an echo to
        // calibrate against. Gently build lead within the configured future bound;
        // existing action/input timestamps remain unchanged.
        depth := c.timeline.head >= truth_tick ? c.timeline.head - truth_tick : 0
        limit := u64(min(c.cfg.max_future - 2, c.cfg.max_prediction - 2))
        c.clock_scale = depth < limit ? 1.1 : 1
        return
    }

    timing := &c.input_timing
    margin :=
        newest >= truth_tick ? f64(min(newest - truth_tick, u64(c.cfg.max_future))) : -f64(min(truth_tick - newest, u64(c.cfg.max_future)))
    timing.arrival_lead = margin

    // Preserve gentle discipline around the three-tick arrival reserve. Large
    // over/undersupply gets bounded faster slew, without retiming queued inputs.
    if margin > 7 {
        c.clock_scale = 0.9
    } else if margin < 0 {
        c.clock_scale = 1.1
    } else {
        c.clock_scale = clamp(1 + (3 - margin) * 0.005, 0.98, 1.02)
    }

    if newest <= timing.last_echo {
        return
    }

    timing.last_echo = newest
    sent := c.input_sent[newest % u64(len(c.input_sent))]

    if !sent.valid || sent.tick != newest || sent.at_ms > c.now || c.now - sent.at_ms > c.cfg.timeout_ms {
        c.stats.timing_rejected += 1
        return
    }

    sample := c.now - sent.at_ms

    if timing.samples == 0 {
        timing.window_at = c.now
    }

    if c.now - timing.window_at >= 1000 {
        timing.previous_peak_ms = c.now - timing.window_at >= 2000 ? 0 : timing.peak_ms
        timing.peak_ms = 0
        timing.window_at = c.now
    }

    timing.peak_ms = max(timing.peak_ms, sample)
    timing.turnaround_ms = sample
    timing.samples = min(timing.samples, max(u32) - 1) + 1
    c.stats.timing_samples += 1

    if timing.samples < 3 {
        return
    }

    // The rolling peak includes transport/application queueing and snapshot
    // cadence; four ticks provide reserve beyond that recent turnaround sample.
    peak := max(timing.peak_ms, timing.previous_peak_ms)
    measured := u32((peak * u64(c.cfg.hz) + 999) / 1000) + 4
    lead := clamp(max(measured, c.cfg.lead), c.cfg.lead, min(c.cfg.max_future - 2, c.cfg.max_prediction - 2))

    if lead != c.lead_ticks {
        c.lead_ticks = lead
        c.stats.lead_updates += 1
    }
}
