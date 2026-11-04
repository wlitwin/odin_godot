package replay_p2p

import r "godot:replay"

Profile_Metric :: enum {
    Step,
    Replay,
    Pump,
    Hash,
    Input_Latency,
}

Profile :: struct {
    clock:    r.Profile_Clock,
    metrics:  [Profile_Metric]r.Timing,
    captures: []Capture_Time,
}

@(private)
Capture_Time :: struct {
    tick, at_us: u64,
    valid:       bool,
}

// Reset when changing clock domains. Allocate diagnostic storage only while
// enabled; neither marks nor timing samples belong in archives or the protocol.
profile_set :: proc(p: ^Runner($S, $I, $E, $N), clock: r.Profile_Clock) -> Error {
    if !p.ready {
        return .Not_Ready
    }

    delete(p.profile.captures, p.allocator)
    p.profile = {
        clock = clock,
    }

    if clock.read != nil {
        p.profile.captures = make([]Capture_Time, p.cfg.history, p.allocator)
    }

    return .None
}

@(private)
profile_capture :: proc(p: ^Runner($S, $I, $E, $N), tick: u64) {
    if len(p.profile.captures) == 0 {
        return
    }

    now, valid := r.profile_read(p.profile.clock)
    p.profile.captures[tick % u64(p.cfg.history)] = {tick, now, valid}

    if !valid {
        p.profile.metrics[.Input_Latency].errors += 1
    }
}

@(private)
profile_applied :: proc(p: ^Runner($S, $I, $E, $N), tick, now: u64, valid: bool) {
    if len(p.profile.captures) == 0 {
        return
    }

    mark := &p.profile.captures[tick % u64(p.cfg.history)]

    if !mark.valid || mark.tick != tick {
        return
    }

    if valid && now >= mark.at_us {
        r.timing_add(&p.profile.metrics[.Input_Latency], now - mark.at_us)
    } else {
        p.profile.metrics[.Input_Latency].errors += 1
    }

    mark.valid = false
}
