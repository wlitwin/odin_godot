package replay_physics_test

import "core:testing"
import "core:mem"
import "core:fmt"
import "core:reflect"
import b "godot:box3d"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"
import f "fixture"

ACCEPT_TIMING :: #config(REPLAY_PHYSICS_ACCEPT_TIMING, false)

ok :: proc(t: ^testing.T, error: r.Error) {
    testing.expect_value(t, error, r.Error.None)
}

save :: proc(
    t: ^testing.T,
    timeline: ^r.Timeline(f.Game, f.Input, f.Event),
    tick: u64,
) -> r.Complete_Checkpoint(f.Game, f.Event) {
    checkpoint, error := r.capture_complete(timeline, tick)
    ok(t, error)
    return checkpoint
}

bytes :: proc(t: ^testing.T, checkpoint: ^r.Complete_Checkpoint($S, $E)) -> []u8 {
    n, error := ph.dump(checkpoint, nil)
    ok(t, error)
    result := make([]u8, int(n))
    actual, fill_error := ph.dump(checkpoint, result)
    ok(t, fill_error)
    testing.expect_value(t, actual, n)
    return result
}

same :: proc(t: ^testing.T, a, z: ^r.Complete_Checkpoint(f.Game, f.Event)) {
    left, right := bytes(t, a), bytes(t, z)
    defer delete(left)
    defer delete(right)
    testing.expect(t, mem.compare(left, right) == 0 && reflect.equal(a.frame, z.frame))
}

@(test)
real_revisions_use_complete_predecessors_and_preserve_failed_publication :: proc(t: ^testing.T) {
    initial, error := f.checkpoint(f.Event)
    ok(t, error)
    defer r.complete_checkpoint_destroy(&initial)
    timeline: r.Timeline(f.Game, f.Input, f.Event)
    ok(t, r.init_complete(&timeline, &initial, f.step, {128, 70}))

    for tick in 1 ..= 8 {
        ok(t, r.advance(&timeline, f.Input{impulse = tick == 3 ? 0.2 : 0}).error)
    }

    before := save(t, &timeline, 8)
    defer r.complete_checkpoint_destroy(&before)
    base := save(t, &timeline, 4)
    defer r.complete_checkpoint_destroy(&base)
    testing.expect_value(t, r.advance(&timeline, f.Input{}).error, r.Error.Prediction_Limit)
    testing.expect_value(t, r.revise_input(&timeline, 6, f.Input{spawn = 1, abort = true}).error, r.Error.Aborted)
    after_failure := save(t, &timeline, 8)
    same(t, &before, &after_failure)
    r.complete_checkpoint_destroy(&after_failure)
    ok(t, r.revise_input(&timeline, 5, f.Input{impulse = 0.7, motor = 0.3}).error)
    revised := save(t, &timeline, 8)
    defer r.complete_checkpoint_destroy(&revised)
    ok(t, r.audit(&timeline, 1).error)
    r.destroy(&timeline)
    // Branching uses the existing Timeline from a detached complete checkpoint.
    branch: r.Timeline(f.Game, f.Input, f.Event)
    ok(t, r.init_complete(&branch, &base, f.step, {128, 70}))
    defer r.destroy(&branch)

    for tick in 5 ..= 8 {
        ok(t, r.advance(&branch, f.Input{impulse = tick == 5 ? 0.7 : 0, motor = tick == 5 ? 0.3 : 0}).error)
    }

    expected := save(t, &branch, 8)
    defer r.complete_checkpoint_destroy(&expected)
    same(t, &revised, &expected)
    gate := r.Commit_Gate {
        allow = proc(_: rawptr, _: u64) -> bool {
            return false
        },
    }
    testing.expect_value(t, r.advance(&branch, f.Input{spawn = 1}, gate).error, r.Error.Commit_Rejected)
    unchanged := save(t, &branch, 8)
    same(t, &expected, &unchanged)
    r.complete_checkpoint_destroy(&unchanged)
}

@(test)
contacts_sleep_sensor_lifecycle_and_streaming_audit_survive_history_wrap :: proc(t: ^testing.T) {
    initial, error := f.checkpoint(f.Event)
    ok(t, error)
    timeline: r.Timeline(f.Game, f.Input, f.Event)
    ok(t, r.init_complete(&timeline, &initial, f.step, {128, 70}))
    first_key := initial.frame.state.bodies[0]
    r.complete_checkpoint_destroy(&initial)
    saved: r.Complete_Checkpoint(f.Game, f.Event)

    for tick in 1 ..= 160 {
        input := f.Input {
            spawn   = tick == 20 ? 1 : 0,
            despawn = tick == 80,
            sleep   = tick == 40,
            wake    = tick == 41,
            motor   = tick == 60 ? 0.25 : 0,
        }
        ok(t, r.advance(&timeline, input).error)
        ok(t, r.confirm_through(&timeline, u64(tick)))

        if tick == 30 {
            saved = save(t, &timeline, 30)
        }
    }

    ok(t, r.audit(&timeline, 34).error)
    head, found := r.current_values(&timeline)
    testing.expect(t, found)
    testing.expect(t, head.state.births == 5 && head.state.deaths == 1 && head.state.begins > 0 && head.state.ends > 0)
    _, missing := r.capture_complete(&timeline, 30)
    testing.expect_value(t, missing, r.Error.History_Missing)
    r.destroy(&timeline)
    // Readonly pose cache outlives every runtime/source world and creates no world.
    stats_before, status := b.engine_allocation_stats()
    testing.expect_value(t, status, b.Status.Ok)

    for _ in 0 ..< 512 {
        _, read_error := ph.body_state(&saved, first_key)
        ok(t, read_error)
    }

    stats_after, after_status := b.engine_allocation_stats()
    testing.expect_value(t, after_status, b.Status.Ok)
    testing.expect_value(t, stats_before.total_calls, stats_after.total_calls)
    clone, clone_error := r.complete_checkpoint_clone(&saved)
    ok(t, clone_error)
    r.complete_checkpoint_destroy(&saved)
    resumed: r.Timeline(f.Game, f.Input, f.Event)
    ok(t, r.init_complete(&resumed, &clone, f.step, {128, 70}))
    ok(t, r.advance(&resumed, f.Input{}).error)
    r.destroy(&resumed)
    r.complete_checkpoint_destroy(&clone)
    engine, engine_status := b.engine_allocation_stats()
    testing.expect_value(t, engine_status, b.Status.Ok)
    wrapper, wrapper_status := b.snapshot_allocation_stats()
    testing.expect_value(t, wrapper_status, b.Status.Ok)
    testing.expect(t, engine.live_bytes == 0 && wrapper.live_bytes == 0 && ph.allocation_stats().live_bytes == 0)
}

@(test)
actual_limits_fixed_step_and_native_handle_state_rejection :: proc(t: ^testing.T) {
    Nested :: struct {
        bad: [2]struct {
            body: b.Body,
        },
    }

    Alias :: b.Body

    Handle_Union :: union {
        b.Shape,
        b.Pose,
    }

    for state in ([?]typeid{b.World, b.Body, b.Shape, b.Joint, Nested, Alias, Handle_Union}) {
        testing.expect(t, !ph.state_supported(state), fmt.tprintf("unexpected supported physics state: %v", state))
    }

    testing.expect(t, ph.state_supported(struct {
                body:  b.Body_Key,
                shape: b.Shape_Key,
                joint: b.Joint_Key,
                pose:  b.Pose,
            }))
    world, game, config := f.world(32)
    bad, bad_error := ph.checkpoint_make(r.Frame(Nested){}, f.Event, world, config)
    testing.expect_value(t, bad_error, r.Error.Unsupported_Value)
    r.complete_checkpoint_destroy(&bad)
    initial, error := ph.checkpoint_make(r.Frame(f.Game){state = game}, f.Event, world, config)
    ok(t, error)
    testing.expect_value(t, b.world_destroy(&world), b.Status.Ok)
    defer r.complete_checkpoint_destroy(&initial)
    timeline: r.Timeline(f.Game, f.Input, f.Event)
    ok(t, r.init_complete(&timeline, &initial, f.step, {128, 70}))
    defer r.destroy(&timeline)
    before := save(t, &timeline, 0)
    defer r.complete_checkpoint_destroy(&before)
    testing.expect_value(t, r.advance(&timeline, f.Input{spawn = 2}).error, r.Error.Resource_Limit)
    testing.expect_value(t, r.advance(&timeline, f.Input{skip_step = true}).error, r.Error.Step_Limit)
    testing.expect_value(t, r.advance(&timeline, f.Input{double_step = true}).error, r.Error.Step_Limit)
    after := save(t, &timeline, 0)
    same(t, &before, &after)
    r.complete_checkpoint_destroy(&after)
    ok(t, r.advance(&timeline, f.Input{spawn = 1}).error)
    accepted := save(t, &timeline, 1)
    defer r.complete_checkpoint_destroy(&accepted)
    testing.expect_value(t, accepted.frame.state.births, u64(33))
    profile := ph.allocation_stats()
    testing.expect(
        t,
        profile.observed_live_peak <= b.ALPHA_RESOURCE_BYTES &&
        profile.largest_operation_requests <= ph.RESERVATION_BYTES &&
        profile.reservation_failures == 0,
    )
}

Action :: struct {
    spawn, accepted, abort, destroy_sensor: bool,
}

network_step :: proc(game: ^f.Game, controls: [1]f.Input, joins, leaves: u64, ctx: ^r.Step(f.Event)) {
    f.step(game, controls[0], ctx)
}

network_action :: proc(game: ^f.Game, seat: u16, action: Action, ctx: ^r.Step(f.Event)) -> bool {
    if action.destroy_sensor {
        if error := ph.body_destroy(ctx.execution, game.sensor); error != .None {
            ctx.error = error
            return false
        }

        game.sensor = 0
    }

    if action.spawn {
        def := b.body_def_default()
        def.type = .Dynamic
        def.pose.position = {0, 5, 0}
        key, error := ph.spawn(ctx.execution, 2, def)

        if error != .None {
            ctx.error = error
            return false
        }

        game.bodies[game.initial] = key
        game.births += 1
    }

    if error := ph.body_impulse(ctx.execution, game.bodies[0], {2, 0, 0}); error != .None {
        ctx.error = error
        return false
    }

    // The provider-owned observation cache must survive a rejected action's restore.
    events: [70]ph.Sensor_Event
    _, event_error := ph.sensor_events(ctx.execution, events[:])

    if event_error != .None {
        ctx.error = event_error
    }

    if action.abort {
        r.abort(ctx)
    }

    return action.accepted
}

@(test)
accepted_sensor_destruction_keeps_pending_next_tick_ends_exactly_once :: proc(t: ^testing.T) {
    world, game, config := f.world()
    defer b.world_destroy(&world)
    initial, error := ph.checkpoint_make(r.Frame(f.Game){state = game}, net.Net_Event(f.Event), world, config)
    ok(t, error)
    defer r.complete_checkpoint_destroy(&initial)
    model := net.Model(f.Game, f.Input, Action, f.Event, 1) {
        complete_state = true,
        step = network_step,
        action = network_action,
        control_valid = proc(_: f.Input) -> bool {
            return true
        },
    }
    timeline: r.Timeline(f.Game, net.Batch(f.Input, Action, 1), net.Net_Event(f.Event))
    ok(
        t,
        r.init_complete(
            &timeline,
            &initial,
            net.model_callback(f.Game, f.Input, Action, f.Event, 1),
            {128, 78},
            user = &model,
        ),
    )
    defer r.destroy(&timeline)
    // Independent direct native execution retains its pending queue without import.
    testing.expect_value(t, b.world_step_fixed(world), b.Status.Ok)
    sensor, status := b.body_resolve(world, game.sensor)
    testing.expect_value(t, status, b.Status.Ok)
    testing.expect_value(t, b.body_destroy(&sensor), b.Status.Ok)
    testing.expect_value(t, b.world_step_fixed(world), b.Status.Ok)
    oracle: [70]b.Sensor_Event
    oracle_count, event_status := b.world_sensor_events(world, oracle[:])
    testing.expect_value(t, event_status, b.Status.Ok)
    expected_ends: u64

    for event in oracle[:oracle_count] {
        if event.began == 0 {
            expected_ends += 1
        }
    }

    testing.expect(t, expected_ends > 0)
    input := net.Batch(f.Input, Action, 1) {
        has_action = {true},
        actions    = {{accepted = true, destroy_sensor = true}},
        sequences  = {1},
    }
    ok(t, r.advance(&timeline, input).error)
    // Captured pending events must survive the next disposable execution open.
    ok(t, r.advance(&timeline, net.Batch(f.Input, Action, 1){}).error)
    after, found := r.current_values(&timeline)
    testing.expect(t, found)
    testing.expect_value(t, after.state.ends, expected_ends)
    ok(t, r.advance(&timeline, net.Batch(f.Input, Action, 1){}).error)
    once, once_found := r.current_values(&timeline)
    testing.expect(t, once_found)
    testing.expect_value(t, once.state.ends, expected_ends)
    ok(t, r.audit(&timeline, 1).error)
}

@(test)
measured_32_body_history_and_eight_tick_transaction_staging_stay_bounded :: proc(t: ^testing.T) {
    initial, error := f.checkpoint(f.Event, 32)
    ok(t, error)
    timeline: r.Timeline(f.Game, f.Input, f.Event)
    ok(t, r.init_complete(&timeline, &initial, f.step, {128, 70}))
    r.complete_checkpoint_destroy(&initial)
    max_forward_ns, max_repair_ns: u64
    steady_engine_live, steady_wrapper_live, steady_provider_live: u64

    for tick in 1 ..= 160 {
        // Settle the oldest input before admitting the next prediction, retaining
        // exactly eight speculative ticks after the successful advance.
        if tick > 8 {
            ok(t, r.confirm_through(&timeline, u64(tick - 8)))
        }

        input := f.Input {
            spawn   = tick == 20 ? 1 : 0,
            despawn = tick == 80,
            sleep   = tick == 120,
            wake    = tick == 121,
        }
        ok(t, r.advance(&timeline, input).error)
        max_forward_ns = max(max_forward_ns, timeline.external_profile.last_total_ns)

        if tick >= 128 {
            engine, status := b.engine_allocation_stats()
            testing.expect_value(t, status, b.Status.Ok)
            wrapper, wrapper_status := b.snapshot_allocation_stats()
            testing.expect_value(t, wrapper_status, b.Status.Ok)
            steady_engine_live = max(steady_engine_live, engine.live_bytes)
            steady_wrapper_live = max(steady_wrapper_live, wrapper.live_bytes)
            steady_provider_live = max(steady_provider_live, ph.allocation_stats().live_bytes)
        }

        if tick >= 128 && tick % 8 == 0 {
            first := u64(tick - 7)
            recorded, found := r.read_input(&timeline, first)
            testing.expect(t, found)
            ok(t, r.revise_input(&timeline, first, recorded).error)
            max_repair_ns = max(max_repair_ns, timeline.external_profile.last_total_ns)
        }
    }

    profile := ph.allocation_stats()
    fmt.printf(
        "REPLAY_PHYSICS_ENVELOPE bodies=32 history=128 repair=8 observed_live_peak=%d largest_operation_requests=%d reservation_failures=%d normal_max_ns=%d correction_max_ns=%d\n",
        profile.observed_live_peak,
        profile.largest_operation_requests,
        profile.reservation_failures,
        max_forward_ns,
        max_repair_ns,
    )
    fmt.printf(
        "REPLAY_PHYSICS_COMPONENTS runtime_bytes=%d steady_engine_live_max=%d steady_wrapper_live_max=%d steady_provider_charged_max=%d\n",
        timeline.runtime_bytes,
        steady_engine_live,
        steady_wrapper_live,
        steady_provider_live,
    )
    testing.expect(
        t,
        profile.observed_live_peak <= b.ALPHA_RESOURCE_BYTES &&
        profile.largest_operation_requests <= ph.RESERVATION_BYTES &&
        profile.reservation_failures == 0,
    )

    // Wall-time ceilings are measured acceptance observations, never simulation inputs.
    when ACCEPT_TIMING {
        testing.expect(
            t,
            max_forward_ns <= b.ALPHA_NORMAL_WORK_NS,
            "observed normal work exceeds alpha acceptance target",
        )
        testing.expect(
            t,
            max_repair_ns <= b.ALPHA_CORRECTION_WORK_NS,
            "observed eligible correction exceeds alpha acceptance target",
        )
    }

    r.destroy(&timeline)
    engine, es := b.engine_allocation_stats()
    wrapper, ws := b.snapshot_allocation_stats()
    testing.expect(
        t,
        es == .Ok &&
        ws == .Ok &&
        engine.live_bytes == 0 &&
        wrapper.live_bytes == 0 &&
        ph.allocation_stats().live_bytes == 0,
    )
}

@(test)
real_native_rejected_action_uses_actual_network_callback_and_solver_savepoint :: proc(t: ^testing.T) {
    initial, error := f.checkpoint(net.Net_Event(f.Event))
    ok(t, error)
    defer r.complete_checkpoint_destroy(&initial)
    model := net.Model(f.Game, f.Input, Action, f.Event, 1) {
        complete_state = true,
        step = network_step,
        action = network_action,
        control_valid = proc(_: f.Input) -> bool {
            return true
        },
    }
    baseline: r.Timeline(f.Game, net.Batch(f.Input, Action, 1), net.Net_Event(f.Event))
    callback := net.model_callback(f.Game, f.Input, Action, f.Event, 1)
    ok(t, r.init_complete(&baseline, &initial, callback, {128, 78}, user = &model))
    ok(t, r.advance(&baseline, net.Batch(f.Input, Action, 1){}).error)
    expected, expected_error := r.capture_complete(&baseline, 1)
    ok(t, expected_error)
    defer r.complete_checkpoint_destroy(&expected)
    r.destroy(&baseline)
    candidate: r.Timeline(f.Game, net.Batch(f.Input, Action, 1), net.Net_Event(f.Event))
    ok(t, r.init_complete(&candidate, &initial, callback, {128, 78}, user = &model))
    defer r.destroy(&candidate)
    input := net.Batch(f.Input, Action, 1) {
        has_action = {true},
        actions    = {{spawn = true}},
        sequences  = {1},
    }
    ok(t, r.advance(&candidate, input).error)
    actual, actual_error := r.capture_complete(&candidate, 1)
    ok(t, actual_error)
    left, right := bytes(t, &expected), bytes(t, &actual)
    defer delete(left)
    defer delete(right)
    testing.expect(t, mem.compare(left, right) == 0 && reflect.equal(expected.frame, actual.frame))
    testing.expect_value(t, len(actual.events), len(expected.events) + 1) // action verdict remains, rejected effects do not
    r.complete_checkpoint_destroy(&actual)
    input.actions[0] = {
        spawn    = true,
        accepted = true,
        abort    = true,
    }
    testing.expect_value(t, r.advance(&candidate, input).error, r.Error.Aborted)
    unchanged, unchanged_error := r.capture_complete(&candidate, 1)
    ok(t, unchanged_error)
    after := bytes(t, &unchanged)
    defer delete(after)
    testing.expect(t, mem.compare(left, after) == 0)
    r.complete_checkpoint_destroy(&unchanged)
}
