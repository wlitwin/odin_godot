package large_values_test

import "core:testing"
import r "godot:replay"
import f "fixture"

@(test)
large_reads_are_detached_and_missing_reads_are_zero :: proc(t: ^testing.T) {
    timeline: f.Timeline
    defer r.destroy(&timeline)
    initial: r.Frame(f.World)
    initial.tick = 7
    initial.state.units[0].health = 20
    initial.state.units[2048].position = {1, 2, 3}
    initial.state.units[4095].tag = 0x1234567890123456
    step := proc(state: ^f.World, input: u8, ctx: ^r.Step(u8)) {
        state.units[0].health -= i32(input)
        state.units[4095].tag += 1
    }
    testing.expect_value(t, r.init(&timeline, initial, step, {2, 0}), r.Error.None)
    frame: r.Frame(f.World)
    testing.expect(t, f.large_values_read(&timeline, 7, &frame))
    testing.expect_value(t, frame, initial)
    frame.state.units[0].health = 999
    retained, ok := r.read_values(&timeline, 7)
    testing.expect(t, ok)
    testing.expect_value(t, retained, initial)
    testing.expect(t, !f.large_values_read(&timeline, 99, &frame))
    testing.expect_value(t, frame.tick, u64(0))
    for unit in frame.state.units {testing.expect_value(t, unit, f.Unit{})}
}
