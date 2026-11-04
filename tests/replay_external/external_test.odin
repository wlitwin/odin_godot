package replay_external_test

import "core:testing"
import "core:mem"
import r "godot:replay"
import net "godot:replay/net"
import diag "godot:replay/diagnostic"
import f "fixture"

ok :: proc(t: ^testing.T, error: r.Error) {
    testing.expect_value(t, error, r.Error.None)
}

state :: proc(t: ^testing.T, timeline: ^r.Timeline(f.Game, f.Input, i64)) -> (f.Game, i64) {
    checkpoint, error := r.capture_complete(timeline, timeline.head)
    ok(t, error)
    defer r.complete_checkpoint_destroy(&checkpoint)
    return checkpoint.frame.state, f.value(&checkpoint)
}

init :: proc(
    t: ^testing.T,
    timeline: ^r.Timeline(f.Game, f.Input, i64),
    checkpoint: ^r.Complete_Checkpoint(f.Game, i64),
    history := 8,
) {
    ok(t, r.init_complete(timeline, checkpoint, f.step, {history, 4}))
}

@(test)
publication_aborts_rejection_and_stale_capabilities :: proc(t: ^testing.T) {
    stats: f.Stats
    initial, owner := f.checkpoint(i64, &stats)
    defer f.owner_destroy(&owner)
    defer r.complete_checkpoint_destroy(&initial)
    timeline: r.Timeline(f.Game, f.Input, i64)
    init(t, &timeline, &initial)
    defer r.destroy(&timeline)
    ok(t, r.advance(&timeline, f.Input{delta = 3, event = true}).error)
    _, value := state(t, &timeline)
    testing.expect_value(t, value, i64(3))
    _, cap_error := r.execution_pointer(stats.last_capability, f.IDENTITY)
    testing.expect_value(t, cap_error, r.Error.Stale_Execution)
    testing.expect_value(t, r.advance(&timeline, f.Input{delta = 100, abort = true}).error, r.Error.Aborted)
    gate := r.Commit_Gate {
        allow = proc(_: rawptr, _: u64) -> bool {
            return false
        },
    }
    testing.expect_value(t, r.advance(&timeline, f.Input{delta = 200}, gate).error, r.Error.Commit_Rejected)
    game, after := state(t, &timeline)
    testing.expect_value(t, after, i64(3))
    testing.expect_value(t, game.sum, i64(3))
    testing.expect_value(t, timeline.head, u64(1))
    _, exported := r.current(&timeline)
    testing.expect(t, !exported)
    values, found := r.current_values(&timeline)
    testing.expect(t, found && values.state.sum == 3)
    testing.expect_value(t, stats.executions, 1)
}

@(test)
all_failed_preparation_boundaries_preserve_publication :: proc(t: ^testing.T) {
    for operation in f.Operation {
        if operation == .Equal {
            continue
        }

        stats: f.Stats
        initial, owner := f.checkpoint(i64, &stats)
        timeline: r.Timeline(f.Game, f.Input, i64)
        init(t, &timeline, &initial)
        ok(t, r.advance(&timeline, f.Input{delta = 1}).error)
        f.fail(&owner, operation)

        if operation == .Clone {
            checkpoint, error := r.capture_complete(&timeline, timeline.head)
            testing.expect_value(t, error, r.Error.External_State)
            r.complete_checkpoint_destroy(&checkpoint)
        } else {
            testing.expect(t, r.advance(&timeline, f.Input{delta = 100}).error != .None)
        }

        game, after := state(t, &timeline)
        testing.expect(t, game.sum == 1 && after == 1 && timeline.head == 1)
        testing.expect_value(t, stats.executions, 1)
        r.destroy(&timeline)
        r.complete_checkpoint_destroy(&initial)
        f.owner_destroy(&owner)
        testing.expect(t, stats.images == 0 && stats.executions == 0 && stats.domains == 0)
    }
}

@(test)
revisions_correction_audit_reset_and_failure_cleanup :: proc(t: ^testing.T) {
    stats: f.Stats
    initial, owner := f.checkpoint(i64, &stats)
    defer f.owner_destroy(&owner)
    defer r.complete_checkpoint_destroy(&initial)
    timeline: r.Timeline(f.Game, f.Input, i64)
    init(t, &timeline, &initial)
    defer r.destroy(&timeline)

    for _ in 0 ..< 4 {
        ok(t, r.advance(&timeline, f.Input{delta = 1}).error)
    }

    f.fail(&owner, .Capture, 2)
    testing.expect_value(t, r.revise_input(&timeline, 2, f.Input{delta = 10}).error, r.Error.External_State)
    _, unchanged := state(t, &timeline)
    testing.expect_value(t, unchanged, i64(4))
    ok(t, r.revise_input(&timeline, 2, f.Input{delta = 10}).error)
    game, revised := state(t, &timeline)
    testing.expect(t, game.sum == 13 && revised == 13)
    rewrite := r.Input_Rewrite(f.Input) {
        apply = proc(_: rawptr, _: u64, _: f.Input) -> f.Input {
            return {delta = 2}
        },
    }
    ok(t, r.revise_inputs(&timeline, 3, rewrite).error)
    _, multiple := state(t, &timeline)
    testing.expect_value(t, multiple, i64(15))
    ok(t, r.audit(&timeline, 2).error)
    _, audited := state(t, &timeline)
    testing.expect_value(t, audited, i64(15))
    f.bias(&owner, 1)
    capture: r.Audit_Capture(f.Game, f.Input, i64)
    result := r.audit_capture(&timeline, 2, &capture)
    testing.expect_value(t, result.error, r.Error.Diverged_External)
    testing.expect(t, capture.ready && f.value(capture.expected_complete) != f.value(capture.actual_complete))
    f.bias(&owner, 0)
    r.audit_capture_destroy(&capture)
    truth, truth_owner := f.checkpoint(i64, &stats, value = 100, frame = {2, {sum = 11, ticks = 2}})
    defer f.owner_destroy(&truth_owner)
    defer r.complete_checkpoint_destroy(&truth)
    testing.expect_value(t, r.correct(&timeline, truth.frame, nil).error, r.Error.Incomplete_State)
    reuse, _ := r.correct_reusing(&timeline, truth.frame, nil)
    testing.expect_value(t, reuse.error, r.Error.Reuse_Disabled)
    ok(t, r.correct_complete(&timeline, &truth).error)
    corrected_game, corrected := state(t, &timeline)
    testing.expect(t, corrected_game.sum == 15 && corrected == 104 && timeline.confirmed == 2)
    ok(t, r.rewind(&timeline, 3))
    testing.expect_value(t, timeline.head, u64(3))
    _, rewound := state(t, &timeline)
    testing.expect_value(t, rewound, i64(102))
    testing.expect_value(t, r.reset_checkpoint(&timeline, truth.frame, 1), r.Error.Incomplete_State)
    ok(t, r.reset_complete(&timeline, &truth, 2))
    _, reset := state(t, &timeline)
    testing.expect(t, reset == 100 && timeline.head == 2 && timeline.epoch == 2)
}

@(test)
detached_checkpoint_survives_ring_wrap_and_source_owner_destruction :: proc(t: ^testing.T) {
    stats: f.Stats
    initial, owner := f.checkpoint(i64, &stats, history = 4)
    timeline: r.Timeline(f.Game, f.Input, i64)
    init(t, &timeline, &initial, 4)

    for _ in 0 ..< 2 {
        ok(t, r.advance(&timeline, f.Input{delta = 1}).error)
    }

    saved, error := r.capture_complete(&timeline, 2)
    ok(t, error)
    clone, clone_error := r.complete_checkpoint_clone(&saved)
    ok(t, clone_error)

    for _ in 0 ..< 12 {
        ok(t, r.advance(&timeline, f.Input{delta = 1}).error)
    }

    _, missing := r.capture_complete(&timeline, 2)
    testing.expect_value(t, missing, r.Error.History_Missing)
    r.destroy(&timeline)
    r.complete_checkpoint_destroy(&initial)
    r.complete_checkpoint_destroy(&saved)
    f.owner_destroy(&owner)
    testing.expect(t, f.value(&clone) == 2 && stats.images == 1 && stats.executions == 0)
    branch: r.Timeline(f.Game, f.Input, i64)
    init(t, &branch, &clone, 4)
    ok(t, r.advance(&branch, f.Input{delta = 8}).error)
    _, value := state(t, &branch)
    testing.expect_value(t, value, i64(10))
    r.destroy(&branch)
    r.complete_checkpoint_destroy(&clone)
    testing.expect(t, stats.images == 0 && stats.executions == 0 && stats.domains == 0)
}

@(test)
deterministic_limits_and_incomplete_recording :: proc(t: ^testing.T) {
    stats: f.Stats
    initial, owner := f.checkpoint(i64, &stats, prediction = 2, repair = 1)
    defer f.owner_destroy(&owner)
    defer r.complete_checkpoint_destroy(&initial)
    timeline: r.Timeline(f.Game, f.Input, i64)
    init(t, &timeline, &initial)
    defer r.destroy(&timeline)

    for _ in 0 ..< 2 {
        ok(t, r.advance(&timeline, f.Input{delta = 1}).error)
    }

    testing.expect_value(t, r.advance(&timeline, f.Input{delta = 1}).error, r.Error.Prediction_Limit)
    testing.expect_value(t, r.revise_input(&timeline, 1, f.Input{delta = 4}).error, r.Error.Repair_Limit)
    ok(t, r.audit(&timeline, 1).error) // offline audit has its own history bound
    _, after := state(t, &timeline)
    testing.expect_value(t, after, i64(2))
    recording: diag.Recording(f.Game, f.Input, i64)
    result := diag.recording_capture(&recording, &timeline, {content = 1, build = 1, tick_hz = 60})
    testing.expect_value(t, result.error, diag.Recording_Error.Context)
    tiny, tiny_owner := f.checkpoint(i64, &stats)
    tiny._external.limits.max_bytes = 1
    defer f.owner_destroy(&tiny_owner)
    defer r.complete_checkpoint_destroy(&tiny)
    rejected: r.Timeline(f.Game, f.Input, i64)
    testing.expect_value(t, r.init_complete(&rejected, &tiny, f.step, {8, 4}), r.Error.Resource_Limit)
    r.destroy(&rejected)
}

Action :: struct {
    delta:           i64,
    accepted, abort: bool,
}

network_step :: proc(game: ^f.Game, controls: [1]i64, joins, leaves: u64, ctx: ^r.Step(i64)) {
    f.add(ctx.execution, controls[0])
    game.sum += controls[0]
    game.ticks += 1
    r.emit(ctx, 1, ctx.tick, game.sum)
}

network_action :: proc(game: ^f.Game, seat: u16, action: Action, ctx: ^r.Step(i64)) -> bool {
    f.add(ctx.execution, action.delta)
    game.sum += action.delta
    r.emit(ctx, 2, 1, game.sum)

    if action.abort {
        r.abort(ctx)
    }

    return action.accepted
}

@(test)
actual_network_model_action_rejection_and_nested_errors :: proc(t: ^testing.T) {
    stats: f.Stats
    initial, owner := f.checkpoint(net.Net_Event(i64), &stats)
    defer f.owner_destroy(&owner)
    defer r.complete_checkpoint_destroy(&initial)
    model := net.Model(f.Game, i64, Action, i64, 1) {
        complete_state = true,
        step = network_step,
        action = network_action,
        control_valid = proc(_: i64) -> bool {
            return true
        },
    }
    timeline: r.Timeline(f.Game, net.Batch(i64, Action, 1), net.Net_Event(i64))
    ok(t, r.init_complete(&timeline, &initial, net.model_callback(f.Game, i64, Action, i64, 1), {8, 8}, user = &model))
    defer r.destroy(&timeline)
    input := net.Batch(i64, Action, 1) {
        controls   = {1},
        has_action = {true},
        actions    = {{delta = 100}},
        sequences  = {1},
    }
    ok(t, r.advance(&timeline, input).error)
    checkpoint, error := r.capture_complete(&timeline, 1)
    ok(t, error)
    testing.expect(t, checkpoint.frame.state.sum == 1 && f.value(&checkpoint) == 1)
    testing.expect_value(t, len(checkpoint.events), 2) // control occurrence plus rejected action verdict
    r.complete_checkpoint_destroy(&checkpoint)
    input.actions[0] = {
        delta    = 5,
        accepted = true,
    }
    input.sequences[0] = 2
    ok(t, r.advance(&timeline, input).error)
    accepted, accepted_error := r.capture_complete(&timeline, 2)
    ok(t, accepted_error)
    testing.expect(t, accepted.frame.state.sum == 7 && f.value(&accepted) == 7)
    r.complete_checkpoint_destroy(&accepted)
    input.actions[0] = {
        delta    = 99,
        accepted = true,
        abort    = true,
    }
    testing.expect_value(t, r.advance(&timeline, input).error, r.Error.Aborted)
    f.fail(&owner, .Capture)
    input.actions[0] = {
        delta    = 99,
        accepted = true,
    }
    testing.expect_value(t, r.advance(&timeline, input).error, r.Error.External_State)
    input.actions[0] = {
        delta = 99,
    } // rejecting restore fails after outer open succeeds
    f.fail(&owner, .Open, 2)
    testing.expect_value(t, r.advance(&timeline, input).error, r.Error.External_State)
    unchanged, unchanged_error := r.capture_complete(&timeline, 2)
    ok(t, unchanged_error)
    testing.expect(t, unchanged.frame.state.sum == 7 && f.value(&unchanged) == 7 && timeline.head == 2)
    r.complete_checkpoint_destroy(&unchanged)
    testing.expect_value(t, stats.executions, 1)
}

@(test)
storage_preflight_precedes_ring_and_event_allocations :: proc(t: ^testing.T) {
    Large_State :: struct {
        bytes: [4096]u8,
    }

    Large_Event :: struct {
        bytes: [16384]u8,
    }

    stats: f.Stats
    source, owner := f.checkpoint(i64, &stats)
    defer f.owner_destroy(&owner)
    defer r.complete_checkpoint_destroy(&source)
    policy := source._external
    policy.limits.history_frames = 128
    policy.limits.max_bytes = 64 * 1024
    image, clone_error := policy.clone(source._image)
    ok(t, clone_error)
    large, error := r.complete_checkpoint_adopt(r.Frame(Large_State){}, i64, policy, image, source._image_bytes)
    ok(t, error)
    defer r.complete_checkpoint_destroy(&large)
    tracker: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracker, context.allocator)
    defer mem.tracking_allocator_destroy(&tracker)
    timeline: r.Timeline(Large_State, u8, i64)
    result := r.init_complete(
        &timeline,
        &large,
        proc(_: ^Large_State, _: u8, _: ^r.Step(i64)) {},
        {128, 4},
        allocator = mem.tracking_allocator(&tracker),
    )
    testing.expect_value(t, result, r.Error.Resource_Limit)
    testing.expect_value(t, tracker.total_allocation_count, i64(0))
    testing.expect(t, len(timeline.records) == 0 && stats.executions == 0)
    second_image, second_clone := policy.clone(source._image)
    ok(t, second_clone)
    large_events, event_error := r.complete_checkpoint_adopt(
        r.Frame(u8){},
        Large_Event,
        policy,
        second_image,
        source._image_bytes,
    )
    ok(t, event_error)
    defer r.complete_checkpoint_destroy(&large_events)
    event_timeline: r.Timeline(u8, u8, Large_Event)
    event_result := r.init_complete(
        &event_timeline,
        &large_events,
        proc(_: ^u8, _: u8, _: ^r.Step(Large_Event)) {},
        {128, 4096},
        allocator = mem.tracking_allocator(&tracker),
    )
    testing.expect_value(t, event_result, r.Error.Resource_Limit)
    testing.expect_value(t, tracker.total_allocation_count, i64(0))
}

@(test)
offline_audit_streams_full_retained_window_without_a_second_image_ring :: proc(t: ^testing.T) {
    stats: f.Stats
    initial, owner := f.checkpoint(i64, &stats, history = 128, prediction = 8, repair = 8)
    defer f.owner_destroy(&owner)
    defer r.complete_checkpoint_destroy(&initial)
    timeline: r.Timeline(f.Game, f.Input, i64)
    init(t, &timeline, &initial, 128)
    defer r.destroy(&timeline)

    for _ in 0 ..< 160 {
        ok(t, r.advance(&timeline, f.Input{delta = 1}).error)
        ok(t, r.confirm_through(&timeline, timeline.head))
    }

    live := stats.images
    result := r.audit(&timeline, 34)
    ok(t, result.error)
    testing.expect_value(t, result.steps, 127)
    testing.expect(t, stats.images == live && stats.peak_images <= live + 1 && stats.executions == 1)
    testing.expect_value(t, timeline.head, u64(160))
    _, after := state(t, &timeline)
    testing.expect_value(t, after, i64(160))
}

@(test)
malformed_successful_clone_cannot_publish_a_missing_image :: proc(t: ^testing.T) {
    stats: f.Stats
    initial, owner := f.checkpoint(i64, &stats)
    defer f.owner_destroy(&owner)
    defer r.complete_checkpoint_destroy(&initial)
    initial._external.clone = proc(_: rawptr) -> (rawptr, r.Error) {
        return nil, .None
    }
    timeline: r.Timeline(f.Game, f.Input, i64)
    testing.expect_value(t, r.init_complete(&timeline, &initial, f.step, {8, 4}), r.Error.External_State)
    testing.expect(t, len(timeline.records) == 0 && stats.executions == 0 && stats.images == 1)
    clone, error := r.complete_checkpoint_clone(&initial)
    testing.expect_value(t, error, r.Error.External_State)
    r.complete_checkpoint_destroy(&clone)
}

@(test)
wire_init_advancement_and_authority_archive_refuse_missing_complete_codec :: proc(t: ^testing.T) {
    model := net.Model(f.Game, i64, Action, i64, 1) {
        complete_state = true,
        step = network_step,
        action = network_action,
        control_valid = proc(_: i64) -> bool {
            return true
        },
    }
    server: net.Server(f.Game, i64, Action, i64, 1)
    client: net.Client(f.Game, i64, Action, i64, 1)
    testing.expect_value(t, net.server_init(&server, r.Frame(f.Game){}, model, {}), net.Error.Incomplete_State)
    testing.expect_value(t, net.client_init(&client, model, {}, {}), net.Error.Incomplete_State)
    stats: f.Stats
    initial, owner := f.checkpoint(net.Net_Event(i64), &stats)
    defer f.owner_destroy(&owner)
    defer r.complete_checkpoint_destroy(&initial)
    server.model = model
    ok(
        t,
        r.init_complete(
            &server.timeline,
            &initial,
            net.model_callback(f.Game, i64, Action, i64, 1),
            {8, 8},
            user = &server.model,
        ),
    )
    defer r.destroy(&server.timeline)
    server.initialized = true
    archive: net.Checkpoint(f.Game, i64, Action, 1)
    testing.expect_value(t, net.checkpoint_capture(&server, &archive), net.Error.Incomplete_State)
    testing.expect_value(t, net.server_step(&server), net.Error.Incomplete_State)
    testing.expect_value(t, server.timeline.head, u64(0))
}

Check_Context :: struct {
    calls:         int,
    reject:        bool,
    expected_tick: u64,
    observed:      f.Game,
    solver:        i64,
    retained:      r.Complete_Checkpoint(f.Game, i64),
}

check_staged :: proc(pointer: rawptr, borrow: ^r.Complete_Checkpoint(f.Game, i64)) -> r.Error {
    c := cast(^Check_Context)pointer
    c.calls += 1
    c.observed = borrow.frame.state
    c.solver = f.value(borrow)

    if borrow.frame.tick != c.expected_tick {
        return .Invalid_Config
    }

    if c.reject {
        return .External_State
    }

    clone, error := r.complete_checkpoint_clone(borrow)

    if error != .None {
        return error
    }

    c.retained = clone
    return .None
}

@(test)
checked_revision_is_once_before_commit_and_retained_clone_is_independent :: proc(t: ^testing.T) {
    stats: f.Stats
    initial, owner := f.checkpoint(i64, &stats)
    timeline: r.Timeline(f.Game, f.Input, i64)
    init(t, &timeline, &initial)

    for _ in 0 ..< 4 {
        ok(t, r.advance(&timeline, f.Input{delta = 1, event = true}).error)
    }

    c := Check_Context {
        expected_tick = 2,
    }
    rewrite := r.Input_Rewrite(f.Input) {
        apply = proc(_: rawptr, _: u64, _: f.Input) -> f.Input {
            return {delta = 2, event = true}
        },
    }
    check := r.Revision_Check(f.Game, i64) {
        tick  = 2,
        user  = &c,
        check = check_staged,
    }
    ok(t, r.revise_inputs_checked(&timeline, 2, rewrite, check).error)
    testing.expect(t, c.calls == 1 && c.observed.sum == 3 && c.solver == 3)
    game, solver := state(t, &timeline)
    testing.expect(t, game.sum == 7 && solver == 7)
    r.destroy(&timeline)
    r.complete_checkpoint_destroy(&initial)
    f.owner_destroy(&owner)
    testing.expect(t, c.retained.frame.tick == 2 && f.value(&c.retained) == 3)
    r.complete_checkpoint_destroy(&c.retained)
    testing.expect(t, stats.images == 0 && stats.executions == 0 && stats.domains == 0)
}

@(test)
checked_revision_rejects_invalid_checks_and_all_failure_boundaries_atomically :: proc(t: ^testing.T) {
    stats: f.Stats
    initial, owner := f.checkpoint(i64, &stats)
    defer f.owner_destroy(&owner)
    defer r.complete_checkpoint_destroy(&initial)
    timeline: r.Timeline(f.Game, f.Input, i64)
    init(t, &timeline, &initial)
    defer r.destroy(&timeline)

    for _ in 0 ..< 4 {
        ok(t, r.advance(&timeline, f.Input{delta = 1, event = true}).error)
    }

    original_images := stats.images
    original_captures := stats.captures
    c := Check_Context {
        expected_tick = 2,
        reject        = true,
    }
    rewrite := r.Input_Rewrite(f.Input) {
        apply = proc(_: rawptr, _: u64, _: f.Input) -> f.Input {
            return {delta = 2, event = true}
        },
    }
    check := r.Revision_Check(f.Game, i64) {
        tick  = 2,
        user  = &c,
        check = check_staged,
    }

    for tick in ([3]u64{0, 1, 5}) {
        bad := check
        bad.tick = tick
        testing.expect_value(t, r.revise_inputs_checked(&timeline, 2, rewrite, bad).error, r.Error.Invalid_Config)
    }

    nil_check := check
    nil_check.check = nil
    testing.expect_value(t, r.revise_inputs_checked(&timeline, 2, rewrite, nil_check).error, r.Error.Invalid_Config)
    testing.expect(t, c.calls == 0 && stats.captures == original_captures)
    testing.expect_value(t, r.revise_inputs_checked(&timeline, 2, rewrite, check).error, r.Error.External_State)
    testing.expect_value(t, c.calls, 1)
    c.calls = 0
    c.reject = false
    f.fail(&owner, .Clone)
    testing.expect_value(t, r.revise_inputs_checked(&timeline, 2, rewrite, check).error, r.Error.External_State)
    testing.expect_value(t, c.calls, 0)
    late_failure := r.Input_Rewrite(f.Input) {
        apply = proc(_: rawptr, tick: u64, input: f.Input) -> f.Input {
            return {delta = 2, event = true, abort = tick == 4}
        },
    }
    testing.expect_value(t, r.revise_inputs_checked(&timeline, 2, late_failure, check).error, r.Error.Aborted)
    testing.expect_value(t, c.calls, 1)
    r.complete_checkpoint_destroy(&c.retained)
    game, solver := state(t, &timeline)
    testing.expect(t, game.sum == 4 && solver == 4 && timeline.head == 4 && timeline.confirmed == 0)

    for tick in 1 ..= 4 {
        input, found := r.read_input(&timeline, u64(tick))
        testing.expect(t, found && input.delta == 1)
        events: [4]r.Occurrence(i64)
        count, error := r.copy_events(&timeline, u64(tick), events[:])
        ok(t, error)
        testing.expect(t, count == 1 && events[0].value == i64(tick))
    }

    testing.expect(t, stats.images == original_images && stats.executions == 1)
}
