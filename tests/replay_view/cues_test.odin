package replay_view_test

import "core:testing"
import v "godot:replay/view"
import r "godot:replay"

@(test)
visual_cues_update_confirm_cancel_without_restarting_or_reusing_identity :: proc(t: ^testing.T) {
    c: v.Cues([2]f32)
    assert(v.cues_init(&c, 1, capacity = 1, history = 8))
    defer v.cues_destroy(&c)
    event := v.Change([2]f32) {
        kind = .Begin,
        occurrence = {id = {1, 1, 10, 20}, value = {2, 3}},
    }
    testing.expect(t, v.cues_change(&c, event, .4))
    key := c.slots[0].key
    v.cues_advance(&c, .1)
    event.kind = .Update
    event.occurrence.value = {4, 5}
    testing.expect(t, !v.cues_change(&c, event, 2))
    testing.expect_value(t, c.slots[0].value, ([2]f32{4, 5}))
    testing.expect_value(t, c.slots[0].seconds, .4)
    testing.expect_value(t, c.slots[0].age, .1)
    event.kind = .Confirm
    v.cues_change(&c, event, .4)
    testing.expect(t, c.slots[0].confirmed)
    event.kind = .Cancel
    v.cues_change(&c, event, .4)
    testing.expect(t, !c.slots[0].active)
    event.kind = .Begin
    testing.expect(t, !v.cues_change(&c, event, .4))
    event.occurrence.id.tick = 2
    testing.expect(t, v.cues_change(&c, event, .4))
    testing.expect(t, c.slots[0].key > key)
    v.cues_advance(&c, 1)
    testing.expect(t, !c.slots[0].active)
    testing.expect(t, !v.cues_change(&c, event, .4))
}

@(test)
visual_cues_have_bounded_capacity_and_explicit_epoch_and_retirement :: proc(t: ^testing.T) {
    c: v.Cues(u32)
    assert(v.cues_init(&c, 2, baseline = 5, capacity = 1, history = 4))
    defer v.cues_destroy(&c)
    event := v.Change(u32) {
        kind = .Begin,
        occurrence = {id = {2, 6, 1, 1}, value = 9},
    }
    testing.expect(t, v.cues_change(&c, event, 1))
    event.occurrence.id.tick = 7
    testing.expect(t, !v.cues_change(&c, event, 1))
    testing.expect_value(t, c.stats.dropped, u64(1))
    v.cues_clear(&c)
    testing.expect(t, !v.cues_change(&c, event, 1))
    testing.expect(t, !v.cues_epoch(&c, 2, 7))
    testing.expect(t, v.cues_epoch(&c, 3, 7))
    testing.expect(t, !v.cues_change(&c, event, 1))
    event.occurrence.id = {3, 8, 1, 1}
    testing.expect(t, v.cues_change(&c, event, 1))
    testing.expect(t, v.one_shots_retire(&c.ledger, 8))
    v.cues_clear(&c)
    testing.expect(t, !v.cues_change(&c, event, 1))
    testing.expect(t, !v.cues_advance(&c, -1))
    event.occurrence.id.tick = 9
    testing.expect(t, !v.cues_change(&c, event, 0))
}

@(test)
visual_cues_consume_actual_reconciliation_and_do_not_drop_queued_rebase_effects :: proc(t: ^testing.T) {
    j: v.Journal(Event)
    assert(v.journal_init(&j, cfg = {8, 3, 24}) == .None)
    defer v.journal_destroy(&j)
    v.journal_set_policy(&j, policy)
    c: v.Cues(Event)
    assert(v.cues_init(&c, 1))
    defer v.cues_destroy(&c)
    events := [2]r.Occurrence(Event){occ(1, 1, .Speculative), occ(1, 2, .Watched)}
    assert(v.sync_tick(&j, 1, events[:]) == .None)
    out: [8]v.Change(Event)
    n := v.drain(&j, out[:])

    for change in out[:n] {
        v.cues_change(&c, change, 1)
    }

    testing.expect_value(t, c.stats.begun, u64(1))
    events[0].value.amount = 33
    assert(v.sync_tick(&j, 1, events[:]) == .None)
    n = v.drain(&j, out[:])

    for change in out[:n] {
        v.cues_change(&c, change, 1)
    }

    testing.expect_value(t, c.stats.updated, u64(1))
    assert(v.advance_time(&j, 1, 0) == .None)
    assert(v.journal_rebase(&j, 100) == .None)
    n = v.drain(&j, out[:])

    for change in out[:n] {
        v.cues_change(&c, change, 1)
    }

    testing.expect_value(t, c.stats.begun, u64(2))
    testing.expect_value(t, c.stats.confirmed, u64(1))
    assert(v.journal_reset(&j, 2, 100) == .None)
    testing.expect(t, v.cues_epoch(&c, 2, 100))
    n = v.drain(&j, out[:])

    for change in out[:n] {
        v.cues_change(&c, change, 1)
    }

    for cue in c.slots {
        testing.expect(t, !cue.active)
    }

    bad: v.Cues([]u8)
    testing.expect(t, !v.cues_init(&bad, 1))
    testing.expect(t, len(bad.slots) == 0)
}
