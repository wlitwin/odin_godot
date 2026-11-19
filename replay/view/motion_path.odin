package replay_view

import "core:math"

// A presentation-space point. Give a spawned object a new lifetime even when
// its pool slot is reused. Terminal contacts can still be visible on their tick.
Motion_Key :: struct($D: int) {
    tick:     u64,
    position: [D]f32,
    life:     u64,
    visible:  bool,
}
Motion_Path :: struct($D: int) {
    lower, upper: Motion_Key(D),
    tick:         u64,
    fraction:     f32,
}

// Start with the authoritative snapshot endpoints. Insert any known in-between
// turns, impacts, births or removals before sampling. No allocations or retained
// pointers; the same generic path works in two or three dimensions.
motion_path :: proc(lower, upper: Motion_Key($D), tick: u64, fraction: f32) -> Motion_Path(D) {
    if upper.tick < lower.tick {return {lower, lower, lower.tick, 0}}
    if tick < lower.tick {return {lower, upper, lower.tick, 0}}
    if tick >= upper.tick {return {lower, upper, upper.tick, 0}}
    f := math.is_nan(fraction) ? f32(0) : clamp(fraction, 0, 1)
    return {lower, upper, tick, f}
}
motion_key :: proc(path: ^Motion_Path($D), key: Motion_Key(D)) {
    if key.tick >= path.lower.tick && key.tick <= path.tick {path.lower = key}
    if key.tick <= path.upper.tick &&
       (key.tick > path.tick || (key.tick == path.tick && path.fraction == 0)) {path.upper = key}
}
motion_sample :: proc(path: Motion_Path($D)) -> Motion_Key(D) {
    a, b := path.lower, path.upper
    if path.tick >= b.tick {return b}
    if path.tick < a.tick || a.life != b.life || !a.visible || !b.visible {return a}
    alpha := (f32(path.tick - a.tick) + path.fraction) / f32(b.tick - a.tick)
    a.position += (b.position - a.position) * clamp(alpha, 0, 1)
    return a
}
