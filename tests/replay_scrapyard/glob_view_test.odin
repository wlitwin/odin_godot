package replay_scrapyard_test

import "core:testing"
import "core:math"
import flow "godot:examples/replay_scrapyard/shared/flow"

@(test)
glob_phase_follows_render_time_and_resets_at_identity_and_recovery_boundaries :: proc(t: ^testing.T) {
    cue: flow.Glob_Pulse
    first := flow.glob_pulse(&cue, 1, 10, 5, 2, 8, 0.01)
    second := flow.glob_pulse(&cue, 1, 10, 5, 2, 8, 0.01)
    testing.expect(t, second > first) // rendering continues between snapshots
    generation := flow.glob_pulse(&cue, 1, 11, 5, 3, 8, 0.01)
    testing.expect_value(t, generation, first)
    _ = flow.glob_pulse(&cue, 1, 12, 5, 3, 8, 0.04)
    rewound := flow.glob_pulse(&cue, 1, 11, 5, 3, 8, 0.01)
    testing.expect_value(t, rewound, first)
    _ = flow.glob_pulse(&cue, 1, 12, 5, 3, 8, 0.04)
    restored := flow.glob_pulse(&cue, 2, 50, 5, 3, 8, 0.01)
    testing.expect_value(t, restored, first)
    _ = flow.glob_pulse(&cue, 2, 51, 5, 3, 8, 0.04)
    reused := flow.glob_pulse(&cue, 2, 52, 6, 3, 9, 0.01)
    testing.expect_value(t, reused, first)
}

@(test)
glob_pulse_stays_bounded_and_render_subdivision_preserves_phase :: proc(t: ^testing.T) {
    a, b: flow.Glob_Pulse
    large := flow.glob_pulse(&a, 1, 1, 1, 1, 1, 0.1)
    small: f32

    for _ in 0 ..< 10 {
        small = flow.glob_pulse(&b, 1, 1, 1, 1, 1, 0.01)
    }

    testing.expect(t, math.abs(large - small) < 0.00001)

    for i in 0 ..< 2000 {
        scale := flow.glob_pulse(&a, 1, u64(i + 1), 1, 1, 1, 0.017)
        testing.expect(t, scale >= 0.82 && scale <= 1.18)
    }
}
