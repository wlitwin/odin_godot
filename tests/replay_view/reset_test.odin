package replay_view_test

import "core:testing"
import r "godot:replay"
import v "godot:replay/view"

@(test)
epoch_reset_cancels_retained_effects_and_starts_a_new_baseline :: proc(t: ^testing.T) {
    j: v.Journal(u32)
    v.journal_init(&j)
    defer v.journal_destroy(&j)
    events := [1]r.Occurrence(u32){{id = {epoch = 1, tick = 1, source = 5, key = 7}, value = 99}}
    v.sync_tick(&j, 1, events[:])
    testing.expect_value(t, v.journal_reset(&j, 2, 0), v.Error.Output_Full)
    changes: [8]v.Change(u32)
    v.drain(&j, changes[:])
    testing.expect_value(t, v.journal_reset(&j, 2, 0), v.Error.None)
    testing.expect_value(t, v.drain(&j, changes[:]), 1)
    testing.expect_value(t, changes[0].kind, v.Change_Kind.Cancel)
    testing.expect_value(t, changes[0].occurrence.id.epoch, u64(1))
    events[0].id.epoch = 2
    testing.expect_value(t, v.sync_tick(&j, 1, events[:]), v.Error.None)
    testing.expect_value(t, v.drain(&j, changes[:]), 1)
    testing.expect_value(t, changes[0].kind, v.Change_Kind.Begin)
    testing.expect_value(t, changes[0].occurrence.id.epoch, u64(2))
}
