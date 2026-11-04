package replay_scrapyard_test

import "core:testing"
import flow "../../examples/replay_scrapyard/shared/flow"

@(test)
screen_effects_seed_silently_and_follow_health_floor_and_motion_settings :: proc(t: ^testing.T) {
    state: flow.Screen_State
    view := flow.screen_step(&state, 1, 0, 1, 2, true, true, false, 0)
    testing.expect_value(t, view.fade, f32(0))
    testing.expect_value(t, view.zoom_add, f32(0))
    testing.expect(t, view.vignette > 0.3)
    view = flow.screen_step(&state, 1, 0, 1, 4, true, false, false, 0)
    testing.expect_value(t, view.vignette, f32(0))
    view = flow.screen_step(&state, 1, 0, 1, 4, true, true, false, 0)
    testing.expect_value(t, view.zoom_add, f32(0.1))
    view = flow.screen_step(&state, 1, 0, 1, 4, true, true, true, 0)
    testing.expect_value(t, view.zoom_add, f32(0))
    flow.screen_kick(&state, 0.5, true)
    testing.expect_value(t, state.kick, f32(0))
    view = flow.screen_step(&state, 1, 0, 2, 4, true, false, false, 0)
    testing.expect_value(t, view.fade, f32(1))
    view = flow.screen_step(&state, 1, 0, 2, 4, true, false, false, 1)
    testing.expect_value(t, view.fade, f32(0))
    view = flow.screen_step(&state, 2, 3, 8, 2, true, true, false, 0)
    testing.expect_value(t, view.fade, f32(0))
    testing.expect_value(t, view.zoom_add, f32(0))
    view = flow.screen_step(&state, 2, 3, 8, 0, true, true, false, 0)
    testing.expect_value(t, view.vignette, f32(0))
    view = flow.screen_step(&state, 2, 4, 8, 3, false, true, false, 0)
    testing.expect_value(t, view.fade, f32(1))
    testing.expect_value(t, view.vignette, f32(0))
}
