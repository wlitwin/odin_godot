package replay_quickdraw_test

import "core:testing"
import r "godot:replay"
import v "godot:replay/view"
import game "../../examples/replay_quickdraw/shared/duel"
import f "../../examples/replay_quickdraw/shared/feedback"

@(test)
hurt_pulse_seeds_lives_and_coalesces_sampled_damage :: proc(t: ^testing.T) {
    state: f.Feedback
    testing.expect(t, f.init(&state))
    defer f.destroy(&state)
    testing.expect(t, f.prepare(&state, 1, 0, 0, 0))
    testing.expect(t, !f.health(&state, 0, 1, 3, true))
    testing.expect(t, f.health(&state, 0, 1, 1, true))
    testing.expect_value(t, state.hurt, u64(1))
    testing.expect_value(t, state.health[0].left, f.HURT_SECONDS)
    f.advance(&state, 0.2)
    testing.expect(t, f.health(&state, 0, 1, 1, true))
    testing.expect_value(t, state.hurt, u64(1))
    f.advance(&state, 0.05)
    testing.expect(t, !f.health(&state, 0, 1, 1, true))
    testing.expect(t, f.health(&state, 0, 1, 0, true))
    testing.expect(t, !f.health(&state, 0, 2, 3, true))
    testing.expect_value(t, state.health[0].left, f64(0))
    testing.expect(t, !f.health(&state, 0, 2, 0, false))
    testing.expect(t, !f.health(&state, 0, 2, 0, true))
    testing.expect(t, f.prepare(&state, 1, 30, 30, 1))
    testing.expect(t, !f.health(&state, 0, 2, 0, true))
    testing.expect(t, f.prepare(&state, 2, 40, 40, 0))
    testing.expect(t, !f.health(&state, 0, 2, 0, true))
}

@(test)
landing_changes_move_cancel_and_never_restart_a_consumed_effect :: proc(t: ^testing.T) {
    state: f.Feedback
    testing.expect(t, f.init(&state))
    defer f.destroy(&state)
    testing.expect(t, f.prepare(&state, 1, 0, 0, 0))
    journal: v.Journal(game.Event)
    v.journal_init(&journal)
    defer v.journal_destroy(&journal)
    events := [1]r.Occurrence(game.Event) {
        {id = {epoch = 1, tick = 1, source = 77, key = 100}, value = {kind = .Landed, position = {50, 60}}},
    }
    changes: [8]v.Change(game.Event)
    testing.expect_value(t, v.sync_tick(&journal, 1, events[:]), v.Error.None)
    n := v.drain(&journal, changes[:])
    testing.expect_value(t, n, 1)
    testing.expect(t, f.change(&state, changes[0]))
    testing.expect_value(t, state.rings[0].position, ([2]f32{50, 60}))
    f.advance(&state, 0.1)
    left := state.rings[0].left
    events[0].value.position = {80, 90}
    v.sync_tick(&journal, 1, events[:])
    n = v.drain(&journal, changes[:])
    testing.expect_value(t, n, 1)
    testing.expect_value(t, changes[0].kind, v.Change_Kind.Update)
    f.change(&state, changes[0])
    testing.expect_value(t, state.rings[0].left, left)
    testing.expect_value(t, state.rings[0].position, ([2]f32{80, 90}))
    v.sync_tick(&journal, 1, nil)
    n = v.drain(&journal, changes[:])
    testing.expect_value(t, n, 1)
    f.change(&state, changes[0])
    testing.expect_value(t, state.rings[0].left, f64(0))
    testing.expect_value(t, state.canceled, u64(1))
    v.sync_tick(&journal, 1, events[:])
    n = v.drain(&journal, changes[:])
    testing.expect_value(t, n, 1)
    testing.expect(t, !f.change(&state, changes[0]))
    testing.expect_value(t, state.landed, u64(1))
    testing.expect_value(t, state.duplicates, u64(1))
    v.advance_time(&journal, 1, 1)
    n = v.drain(&journal, changes[:])

    for c in changes[:n] {
        f.change(&state, c)
    }

    testing.expect_value(t, state.rings[0].left, f64(0))
    testing.expect_value(t, state.landed, u64(1))
    // A same-epoch presentation reset clears nodes but retains consumed IDs.
    f.prepare(&state, 1, 0, 1, 1)
    testing.expect(t, !f.change(&state, {kind = .Begin, occurrence = events[0]}))
    f.prepare(&state, 2, 1, 1, 0)
    testing.expect(t, !f.change(&state, {kind = .Begin, occurrence = events[0]}))
    events[0].id.epoch, events[0].id.tick = 2, 2
    testing.expect(t, f.change(&state, {kind = .Begin, occurrence = events[0], confirmed = true}))
    f.advance(&state, f.RING_SECONDS)
    testing.expect_value(t, state.rings[0].left, f64(0))
}

@(test)
ring_capacity_and_reuse_do_not_revive_old_effects :: proc(t: ^testing.T) {
    state: f.Feedback
    testing.expect(t, f.init(&state))
    defer f.destroy(&state)
    f.prepare(&state, 1, 0, 0, 0)

    for i in 1 ..= f.RING_LIMIT {
        testing.expect(
            t,
            f.change(&state, {kind = .Begin, occurrence = {id = {1, u64(i), 1, 100}, value = {kind = .Landed}}}),
        )
    }

    overflow := v.Change(game.Event) {
        kind = .Begin,
        occurrence = {id = {1, 65, 1, 100}, value = {kind = .Landed}},
    }
    testing.expect(t, !f.change(&state, overflow))
    testing.expect_value(t, state.dropped, u64(1))
    f.advance(&state, 1)
    testing.expect(t, !f.change(&state, overflow))
    next := v.Change(game.Event) {
        kind = .Begin,
        occurrence = {id = {1, 66, 1, 100}, value = {kind = .Landed, position = {90, 80}}},
    }
    testing.expect(t, f.change(&state, next))
    f.change(&state, {kind = .Cancel, occurrence = {id = {1, 1, 1, 100}, value = {kind = .Landed}}})
    testing.expect_value(t, state.rings[0].left, f.RING_SECONDS)
    testing.expect_value(t, state.rings[0].id, next.occurrence.id)
}
