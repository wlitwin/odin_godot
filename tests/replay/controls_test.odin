package replay_test
import "core:testing"
import r "godot:replay"

@(test)
control_capture_buffers_tick_edges_and_suppresses_held_buttons_across_gates :: proc(t: ^testing.T) {
    c: r.Control_Capture
    r.controls_capture(&c, 0, 1, 1)
    testing.expect(t, c.buttons.held == 0 && c.buttons.pressed == 1 && c.buttons.released == 1)
    r.controls_capture(&c, 0, 0, 0)
    testing.expect_value(t, c.buttons.pressed, u64(1))
    r.controls_consume(&c)
    testing.expect_value(t, c.buttons, r.Buttons{})
    r.controls_capture(&c, 1, 1, 0)
    r.controls_capture(&c, 1, 0, 0, {.Paused})
    testing.expect_value(t, c.buttons, r.Buttons{})
    r.controls_capture(&c, 1, 0, 0)
    testing.expect_value(t, c.buttons, r.Buttons{})
    r.controls_capture(&c, 0, 0, 1)
    testing.expect_value(t, c.buttons, r.Buttons{})
    r.controls_consume(&c)
    r.controls_capture(&c, 1, 1, 0)
    testing.expect(t, c.buttons.held == 1 && c.buttons.pressed == 1)
    r.controls_capture(&c, 1, 0, 0, {.Unfocused, .Menu})
    testing.expect(t, c.blocked)
    r.controls_capture(&c, 0, 0, 1, {.Menu})
    r.controls_capture(&c, 0, 0, 0)
    r.controls_capture(&c, 2, 2, 0)
    testing.expect(t, !c.blocked && c.buttons.held == 2 && c.buttons.pressed == 2)
}
