package framework_tests

import "core:testing"
import r "godot:replay"
import f "godot:tests/replay_external/fixture"

Borrow_Probe :: struct {
    old:      r.Execution,
    observed: r.Error,
}

probe_step :: proc(game: ^f.Game, input: f.Input, ctx: ^r.Step(i64)) {
    // Deliberately misuse an earlier borrowed capability to test that the public
    // scope guard rejects it even when a Timeline's storage is reused.
    probe := cast(^Borrow_Probe)ctx.user
    _, probe.observed = r.execution_pointer(probe.old, f.IDENTITY)
    f.step(game, input, ctx)
}

@(test)
replay_borrowed_execution_does_not_revive_after_destroy_and_reinit :: proc(t: ^testing.T) {
    stats: f.Stats
    initial, owner := f.checkpoint(i64, &stats)
    defer r.complete_checkpoint_destroy(&initial)
    defer f.owner_destroy(&owner)
    timeline: r.Timeline(f.Game, f.Input, i64)
    testing.expect_value(t, r.init_complete(&timeline, &initial, f.step, {8, 4}), r.Error.None)
    testing.expect_value(t, r.advance(&timeline, f.Input{delta = 1}).error, r.Error.None)
    old := stats.last_capability
    _, ended := r.execution_pointer(old, f.IDENTITY)
    testing.expect_value(t, ended, r.Error.Stale_Execution)
    r.destroy(&timeline)

    probe := Borrow_Probe {
        old = old,
    }
    testing.expect_value(t, r.init_complete(&timeline, &initial, probe_step, {8, 4}, user = &probe), r.Error.None)
    testing.expect_value(t, r.advance(&timeline, f.Input{delta = 2}).error, r.Error.None)
    testing.expect_value(t, probe.observed, r.Error.Stale_Execution)
    r.destroy(&timeline)
}

@(test)
replay_managed_presentation_values_do_not_become_complete_truth :: proc(t: ^testing.T) {
    stats: f.Stats
    initial, owner := f.checkpoint(i64, &stats)
    defer r.complete_checkpoint_destroy(&initial)
    defer f.owner_destroy(&owner)
    timeline: r.Timeline(f.Game, f.Input, i64)
    testing.expect_value(t, r.init_complete(&timeline, &initial, f.step, {8, 4}), r.Error.None)
    defer r.destroy(&timeline)

    for tick in 1 ..= 4 {
        testing.expect_value(t, r.advance(&timeline, f.Input{delta = i64(tick), event = true}).error, r.Error.None)
    }

    _, misleading := r.current(&timeline)
    testing.expect(t, !misleading)
    values, ok := r.current_values(&timeline)
    testing.expect(t, ok && values.tick == 4 && values.state.sum == 10)
    testing.expect_value(t, r.correct(&timeline, values, nil).error, r.Error.Incomplete_State)
    testing.expect_value(t, r.reset_checkpoint(&timeline, values, timeline.epoch), r.Error.Incomplete_State)
    checkpoint, error := r.capture_complete(&timeline, 4)
    testing.expect_value(t, error, r.Error.None)
    defer r.complete_checkpoint_destroy(&checkpoint)
    testing.expect_value(t, f.value(&checkpoint), i64(10))
}
