package replay_view_test

import "core:testing"
import r "godot:replay"
import v "godot:replay/view"

@(test)
one_shot_consumption_survives_cancel_and_reappearance :: proc(t: ^testing.T) {
    log: v.One_Shots
    testing.expect(t, v.one_shots_init(&log, 1))
    defer v.one_shots_destroy(&log)
    j: v.Journal(Event)
    v.journal_init(&j)
    v.journal_set_policy(&j, policy)
    defer v.journal_destroy(&j)
    batch := [1]r.Occurrence(Event){occ(1, 10)}
    changes: [8]v.Change(Event)
    played := 0

    for phase in 0 ..< 4 {
        switch phase {
        case 0:
            v.sync_tick(&j, 1, batch[:])
        case 1:
            v.sync_tick(&j, 1, nil)
        case 2:
            v.sync_tick(&j, 1, batch[:])
        case 3:
            v.advance_time(&j, 1, 1)
        }

        count := v.drain(&j, changes[:])

        for change in changes[:count] {
            if change.kind == .Begin && v.one_shot_note(&log, change.occurrence.id) == .New {
                played += 1
            }
        }
    }

    testing.expect_value(t, played, 1)
    testing.expect_value(t, v.one_shot_note(&log, batch[0].id, 1), v.Once_Result.New)
}

@(test)
one_shot_bounds_retirement_and_epoch_fencing_are_explicit :: proc(t: ^testing.T) {
    log: v.One_Shots
    v.one_shots_init(&log, 1, history = 2, per_tick = 2)
    defer v.one_shots_destroy(&log)
    id := r.Event_Id{1, 1, 5, 1}
    testing.expect_value(t, v.one_shot_note(&log, id), v.Once_Result.New)
    id.key = 2
    testing.expect_value(t, v.one_shot_note(&log, id), v.Once_Result.New)
    id.key = 3
    testing.expect_value(t, v.one_shot_note(&log, id), v.Once_Result.Capacity)
    id.tick = 3
    testing.expect_value(t, v.one_shot_note(&log, id), v.Once_Result.Capacity)
    testing.expect(t, v.one_shots_retire(&log, 1))
    testing.expect_value(t, v.one_shot_note(&log, id), v.Once_Result.New)
    id.tick = 1
    testing.expect_value(t, v.one_shot_note(&log, id), v.Once_Result.Expired)
    testing.expect(t, !v.one_shots_retire(&log, 0) && !v.one_shots_reset(&log, 1, 0))
    testing.expect(t, v.one_shots_reset(&log, 2, 10))
    testing.expect_value(t, v.one_shot_note(&log, id), v.Once_Result.Wrong_Epoch)
    id.epoch, id.tick = 2, 11
    testing.expect_value(t, v.one_shot_note(&log, id), v.Once_Result.New)
}
