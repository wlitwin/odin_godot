package replay_test

import "core:reflect"
import "core:testing"
import r "godot:replay"

@(test)
checkpoint_occurrences_install_atomically_and_cannot_rewrite_committed_events :: proc(t: ^testing.T) {
    tl: Counter_Timeline
    r.init(
        &tl,
        r.Frame(Counter){tick = 20, state = {value = 3}},
        counter_step,
        cfg = {history_frames = 8, events_per_tick = 2},
    )
    defer r.destroy(&tl)
    events := [2]r.Occurrence(i32) {
        {id = {epoch = 1, tick = 20, source = 1, key = 1}, value = 3},
        {id = {epoch = 1, tick = 20, source = 1, key = 1}, value = 4},
    }
    testing.expect_value(t, r.seed_checkpoint_events(&tl, events[:]), r.Error.Duplicate_Event)
    out: [2]r.Occurrence(i32)
    n, _ := r.copy_events(&tl, 20, out[:])
    testing.expect_value(t, n, 0)
    events[1].id.key = 2
    events[1].id.epoch = 2
    testing.expect_value(t, r.seed_checkpoint_events(&tl, events[:]), r.Error.Invalid_Event)
    n, _ = r.copy_events(&tl, 20, out[:])
    testing.expect_value(t, n, 0)
    events[1].id.epoch = 1
    testing.expect_value(t, r.seed_checkpoint_events(&tl, events[:]), r.Error.None)
    testing.expect_value(t, r.seed_checkpoint_events(&tl, events[:1]), r.Error.Committed)
    n, _ = r.copy_events(&tl, 20, out[:])
    testing.expect_value(t, n, 2)
    testing.expect(t, reflect.equal(events, out))
    r.advance(&tl, Counter_Input{add = 1})
    r.confirm_through(&tl, 21)
    testing.expect_value(t, r.seed_checkpoint_events(&tl, nil), r.Error.Committed)
    testing.expect_value(t, r.audit(&tl, 21).error, r.Error.None)
}

@(test)
replacing_predicted_input_suffix_never_confirms_guessed_history :: proc(t: ^testing.T) {
    timeline: Counter_Timeline
    r.init(&timeline, r.Frame(Counter){}, counter_step)
    defer r.destroy(&timeline)

    for _ in 0 ..< 4 {
        r.advance(&timeline, Counter_Input{add = 1})
    }

    r.confirm_through(&timeline, 1)
    rewrite := r.Input_Rewrite(Counter_Input) {
        apply = proc(user: rawptr, tick: u64, input: Counter_Input) -> Counter_Input {
            return {add = 2}
        },
    }
    testing.expect_value(t, r.revise_inputs(&timeline, 3, rewrite).error, r.Error.None)
    testing.expect_value(t, timeline.confirmed, u64(1))
    frame, _ := r.current(&timeline)
    testing.expect_value(t, frame.state.value, i32(6))
    testing.expect_value(t, r.revise_input(&timeline, 2, Counter_Input{add = 0}).error, r.Error.None)
    testing.expect_value(t, r.audit(&timeline, 2).error, r.Error.None)
}

@(test)
rewritten_predictions_commit_with_the_checkpoint_or_roll_back_together :: proc(t: ^testing.T) {
    client: Counter_Timeline
    r.init(&client, r.Frame(Counter){}, counter_step)
    defer r.destroy(&client)

    for _ in 0 ..< 4 {
        r.advance(&client, Counter_Input{add = 1})
    }

    before, _ := r.current(&client)
    truth := r.Frame(Counter) {
        tick = 2,
        state = {value = 4},
    }
    fail := true
    rewrite := r.Input_Rewrite(Counter_Input) {
        user = &fail,
        apply = proc(user: rawptr, tick: u64, original: Counter_Input) -> Counter_Input {
            return {add = 2, stop = (cast(^bool)user)^ && tick == 4}
        },
    }
    testing.expect_value(t, r.correct(&client, truth, nil, rewrite).error, r.Error.Aborted)
    after, _ := r.current(&client)
    testing.expect(t, reflect.equal(before, after))
    input, _ := r.read_input(&client, 3)
    testing.expect_value(t, input.add, i32(1))
    testing.expect_value(t, client.confirmed, u64(0))
    fail = false
    testing.expect_value(t, r.correct(&client, truth, nil, rewrite).error, r.Error.None)
    after, _ = r.current(&client)
    testing.expect_value(t, after.state.value, i32(8))
    input, _ = r.read_input(&client, 3)
    testing.expect_value(t, input.add, i32(2))
    testing.expect_value(t, r.audit(&client, 3).error, r.Error.None)
}

@(test)
authority_state_correction_replays_the_whole_suffix :: proc(t: ^testing.T) {
    client: Counter_Timeline
    r.init(&client, r.Frame(Counter){}, counter_step)
    defer r.destroy(&client)

    for _ in 0 ..< 4 {
        r.advance(&client, Counter_Input{add = 1})
    }

    truth := r.Frame(Counter) {
        tick = 2,
        state = {value = 6},
    }
    events := [1]r.Occurrence(i32){{id = {epoch = 1, tick = 2, source = 1, key = 1}, value = 6}}
    result := r.correct(&client, truth, events[:])
    testing.expect_value(t, result.error, r.Error.None)
    testing.expect_value(t, result.steps, 2)
    frame, _ := r.current(&client)
    testing.expect_value(t, frame.state.value, i32(8))
    testing.expect_value(t, client.confirmed, u64(2))
    corrected, _ := r.read(&client, 2)
    testing.expect(t, reflect.equal(corrected, truth))
    _, known := r.read_input(&client, 2)
    testing.expect(t, !known)
    input, input_known := r.read_input(&client, 3)
    testing.expect(t, input_known)
    testing.expect_value(t, input.add, i32(1))
    testing.expect_value(t, r.audit(&client, 3).error, r.Error.None)
    testing.expect_value(t, r.audit(&client, 1).error, r.Error.Initial_Frame)
    out: [1]r.Occurrence(i32)
    r.copy_events(&client, 4, out[:])
    testing.expect_value(t, out[0].value, i32(8))
    testing.expect_value(t, r.correct(&client, truth, events[:]).error, r.Error.None)
    truth.state.value = 7
    testing.expect_value(t, r.correct(&client, truth, events[:]).error, r.Error.Committed)
}

@(test)
failed_authority_replay_does_not_commit_its_checkpoint :: proc(t: ^testing.T) {
    client: Counter_Timeline
    r.init(&client, r.Frame(Counter){}, counter_step)
    defer r.destroy(&client)

    for _ in 0 ..< 4 {
        r.advance(&client, Counter_Input{add = 2})
    }

    before, _ := r.current(&client)
    truth := r.Frame(Counter) {
        tick = 2,
        state = {value = 8},
    }
    result := r.correct(&client, truth, nil)
    testing.expect_value(t, result.error, r.Error.Aborted)
    testing.expect_value(t, result.steps, 1)
    testing.expect_value(t, client.confirmed, u64(0))
    after, _ := r.current(&client)
    testing.expect(t, reflect.equal(before, after))
    testing.expect_value(t, r.audit(&client, 1).error, r.Error.None)
    bad := [1]r.Occurrence(i32){{id = {epoch = 2, tick = 2}}}
    testing.expect_value(t, r.correct(&client, truth, bad[:]).error, r.Error.Invalid_Event)
}

@(test)
resync_requires_an_explicit_checkpoint_and_valid_epoch :: proc(t: ^testing.T) {
    client: Counter_Timeline
    r.init(&client, r.Frame(Counter){}, counter_step, cfg = {history_frames = 3, events_per_tick = 1})
    defer r.destroy(&client)

    for _ in 0 ..< 6 {
        r.advance(&client, Counter_Input{add = 1})
    }

    testing.expect_value(t, r.correct(&client, r.Frame(Counter){tick = 1}, nil).error, r.Error.History_Missing)
    checkpoint := r.Frame(Counter) {
        tick = 100,
        state = {value = 4},
    }
    testing.expect_value(t, r.reset_checkpoint(&client, checkpoint, 1), r.Error.None)
    _, old := r.read(&client, 6)
    testing.expect(t, !old)
    testing.expect_value(t, r.advance(&client, Counter_Input{add = 1}).error, r.Error.None)
    testing.expect_value(t, r.reset_checkpoint(&client, r.Frame(Counter){tick = 99}, 1), r.Error.Committed)
    testing.expect_value(t, r.reset_checkpoint(&client, r.Frame(Counter){tick = 99}, 0), r.Error.Invalid_Epoch)
    testing.expect_value(t, r.reset_checkpoint(&client, r.Frame(Counter){tick = 99}, 2), r.Error.None)
    testing.expect_value(t, client.epoch, u64(2))
}
