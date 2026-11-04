package replay_history

import r "godot:replay"

Boundary :: struct($T: typeid) {
    tick:  u64,
    value: T,
    valid: bool,
}

Boundary_Policy :: enum u8 {
    Exact,
    Hold,
}

Boundary_Status :: enum u8 {
    Missing,
    Future,
    Exact,
    Held,
    Expired,
}

// Outside state carries its own time. Holding is an explicit bounded model
// assumption, not a claim that a remote body was simulated at the requested tick.
boundary_sample :: proc(b: Boundary($T), tick, max_age: u64, policy: Boundary_Policy) -> (T, Boundary_Status) {
    assert(r.value_supported(T))
    zero: T

    if !b.valid {
        return zero, .Missing
    }

    if tick < b.tick {
        return zero, .Future
    }

    if tick == b.tick {
        return b.value, .Exact
    }

    if policy == .Exact || tick - b.tick > max_age {
        return zero, .Expired
    }

    return b.value, .Held
}
