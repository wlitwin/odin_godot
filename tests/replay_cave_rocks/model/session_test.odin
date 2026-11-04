package cave_rocks_test

import "core:testing"
import v "godot:replay/view"
import rgd "godot:replay/godot"
import scenegd "godot:replay/godot/scene"

@(test)
session_phase_uses_role_fencing_and_client_reset_without_mutating_runner_clock :: proc(t: ^testing.T) {
    s: rgd.Session(u8, u8, u8, u8, 1)
    phase: v.Tick_Phase
    testing.expect(t, !scenegd.session_tick_phase(&s, &phase, .01))
    s.ready, s.authority = true, true
    s.server.cfg.epoch = 1
    s.server.cfg.hz = 20
    s.server.timeline.head = 10
    s.clock.hz, s.clock.accumulator = 20, .025
    testing.expect(t, scenegd.session_tick_phase(&s, &phase, .01))
    testing.expect_value(t, phase.fraction, f32(.5))
    s.fenced = true
    testing.expect(t, scenegd.session_tick_phase(&s, &phase, 1))
    testing.expect_value(t, phase.fraction, f32(.5))
    s.fenced = false
    s.clock.paused = true
    testing.expect(t, scenegd.session_tick_phase(&s, &phase, 1))
    testing.expect_value(t, phase.fraction, f32(.5))
    testing.expect_value(t, s.clock.accumulator, .025)
    testing.expect_value(t, s.server.timeline.head, u64(10))
    s.authority = false
    s.clock.paused = false
    testing.expect(t, !scenegd.session_tick_phase(&s, &phase, .01))
    s.client.has_world = true
    s.client.phase = .Running
    s.client.clock_scale = 1
    s.client.cfg.epoch = 1
    s.client.cfg.hz = 20
    s.client.timeline.head = 8
    s.client.view_reset = 1
    testing.expect(t, scenegd.session_tick_phase(&s, &phase, .01))
    testing.expect_value(t, phase.tick, u64(8))
    s.client.spectator = true
    s.client.timeline.head = 9
    s.clock.accumulator = .049
    testing.expect(t, scenegd.session_tick_phase(&s, &phase, .01))
    testing.expect_value(t, phase.fraction, f32(0))
    testing.expect(t, scenegd.session_tick_phase(&s, &phase, .01))
    testing.expect_value(t, phase.fraction, f32(.2))
    s.client.phase = .Resyncing
    testing.expect(t, scenegd.session_tick_phase(&s, &phase, 1))
    testing.expect_value(t, phase.fraction, f32(.2))
    s.client.cfg.epoch = 2
    s.client.view_reset = 2
    s.clock.accumulator = 0
    testing.expect(t, scenegd.session_tick_phase(&s, &phase, 1))
    testing.expect_value(t, phase.fraction, f32(0))
}
