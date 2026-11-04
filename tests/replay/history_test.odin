package replay_test

import "core:testing"
import r "godot:replay"

@(test)
inspection_window_includes_initial_checkpoint_and_tracks_wrapping :: proc(t: ^testing.T) {
    tl: Counter_Timeline
    defer r.destroy(&tl)
    _, _, err := r.history_window(&tl)
    testing.expect_value(t, err, r.Error.Not_Initialized)
    r.init(&tl, r.Frame(Counter){tick = 100}, counter_step, {history_frames = 4, events_per_tick = 1})
    first, last, e := r.history_window(&tl)
    testing.expect_value(t, e, r.Error.None)
    testing.expect_value(t, first, u64(100))
    testing.expect_value(t, last, u64(100))

    for _ in 0 ..< 7 {
        testing.expect_value(t, r.advance(&tl, Counter_Input{}).error, r.Error.None)
    }

    first, last, e = r.history_window(&tl)
    testing.expect_value(t, e, r.Error.None)
    testing.expect_value(t, first, u64(104))
    testing.expect_value(t, last, u64(107))
    // Confirmed frames remain inspectable even though rewind cannot discard them.
    r.confirm_through(&tl, 107)
    first, last, e = r.history_window(&tl)
    testing.expect_value(t, first, u64(104))
    testing.expect_value(t, last, u64(107))
    _, _, e = r.audit_window(&tl)
    testing.expect_value(t, e, r.Error.None)
    testing.expect_value(t, r.reset_checkpoint(&tl, r.Frame(Counter){tick = 900}, 2), r.Error.None)
    first, last, e = r.history_window(&tl)
    testing.expect_value(t, first, u64(900))
    testing.expect_value(t, last, u64(900))
}

@(test)
inspection_window_handles_tick_zero_overflow_boundary_and_busy_source :: proc(t: ^testing.T) {
    tl: Counter_Timeline
    defer r.destroy(&tl)
    r.init(&tl, r.Frame(Counter){}, counter_step, {history_frames = 4, events_per_tick = 1})
    first, last, err := r.history_window(&tl)
    testing.expect_value(t, first, u64(0))
    testing.expect_value(t, last, u64(0))
    testing.expect_value(t, err, r.Error.None)
    tl.busy = true
    _, _, err = r.history_window(&tl)
    testing.expect_value(t, err, r.Error.Reentrant)
    tl.busy = false
    r.reset_checkpoint(&tl, r.Frame(Counter){tick = max(u64) - 1}, 2)
    testing.expect_value(t, r.advance(&tl, Counter_Input{}).error, r.Error.None)
    first, last, err = r.history_window(&tl)
    testing.expect_value(t, first, max(u64) - 1)
    testing.expect_value(t, last, max(u64))
}
