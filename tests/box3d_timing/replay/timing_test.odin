package box3d_timing_replay_test

import "core:fmt"
import "core:mem"
import "core:reflect"
import "core:testing"
import b "godot:box3d"
import ba "godot:box3d/authoring"
import bd "godot:box3d/diagnostics"
import limits "godot:box3d/limits"
import r "godot:replay"
import net "godot:replay/net"
import ph "godot:replay/physics"

State :: struct {
    tick, changed: u64,
    body:          b.Body_Key,
    character:     b.Character_State,
}

scene_make :: proc(t: ^testing.T) -> ba.Baked_Scene {
    input := ba.scene_input_default("box3d.timing.replay.v1")
    input.gravity = {}
    input.enable_sleep = false
    shapes := [1]ba.Shape_Input{ba.shape_input_default("cube", "box")}
    shapes[0].half_extents = {.25, .25, .25}
    bodies := [1]ba.Body_Input{ba.body_input_default("moving")}
    bodies[0].body_type = "dynamic"
    bodies[0].pose.position = {0, 4, 0}
    bodies[0].linear_velocity = {1, 0, 0}
    bodies[0].enable_sleep = false
    bodies[0].linear_damping = 0
    bodies[0].shapes = shapes[:]
    input.bodies = bodies[:]
    scene, problem := ba.bake(input)
    testing.expect(t, problem.error == .None, fmt.tprintf("bake=%v field=%s", problem.error, problem.field))
    return scene
}

initial_state :: proc(built: ^ba.Built_Scene) -> State {
    return {body = built.bodies[0].key, character = {position = {0, 10, 4}, velocity = {.5, 0, 0}}}
}

advance_game :: proc(state: ^State, input: u8, ctx: ^r.Step($E)) {
    speed := input == 0 ? f32(1) : f32(2)

    if error := ph.body_velocity(ctx.execution, state.body, {speed, 0, 0}, {}); error != .None {
        ctx.error = error
        return
    }

    state.character.velocity = {speed * .5, 0, 0}
    character, error := ph.character_step(ctx.execution, b.character_config_default(), state.character)

    if error != .None {
        ctx.error = error
        return
    }

    state.character = character.state

    if input != 0 {
        state.changed += 1
    }

    if error := ph.step(ctx.execution); error != .None {
        ctx.error = error
        return
    }

    state.tick = ctx.tick
}

local_step :: proc(state: ^State, input: u8, ctx: ^r.Step(u8)) {
    advance_game(state, input, ctx)
}

network_step :: proc(state: ^State, controls: [2]u8, _, _: u64, ctx: ^r.Step(u8)) {
    advance_game(state, controls[0], ctx)
}

save :: proc(t: ^testing.T, timeline: ^r.Timeline(State, u8, u8), tick: u64) -> r.Complete_Checkpoint(State, u8) {
    checkpoint, error := r.capture_complete(timeline, tick)
    testing.expect_value(t, error, r.Error.None)
    return checkpoint
}

dump :: proc(t: ^testing.T, checkpoint: ^r.Complete_Checkpoint(State, $E)) -> []u8 {
    bytes, error := ph.dump(checkpoint, nil)
    testing.expect_value(t, error, r.Error.None)
    result := make([]u8, int(bytes))
    actual, copy_error := ph.dump(checkpoint, result)
    testing.expect_value(t, copy_error, r.Error.None)
    testing.expect_value(t, actual, bytes)
    return result
}

same :: proc(t: ^testing.T, left, right: ^r.Complete_Checkpoint(State, $E)) {
    a, z := dump(t, left), dump(t, right)
    defer delete(a)
    defer delete(z)
    testing.expect(
        t,
        reflect.equal(left.frame, right.frame) && mem.compare(a, z) == 0,
        "complete normalized solver and game/character state match",
    )
}

cleanup :: proc(t: ^testing.T) {
    engine, es := b.engine_allocation_stats()
    wrapper, ws := b.snapshot_allocation_stats()
    testing.expect(
        t,
        es == .Ok &&
        ws == .Ok &&
        engine.live_bytes == 0 &&
        wrapper.live_bytes == 0 &&
        ph.allocation_stats().live_bytes == 0,
        "native, wrapper and provider ownership returns to zero",
    )
}

@(test)
profile_window_revision_and_history_wrap_use_complete_physics :: proc(t: ^testing.T) {
    defer cleanup(t)
    scene := scene_make(t)
    defer ba.destroy(&scene)
    built, problem := ba.build(&scene, 0x54494d4552504c31)
    testing.expect_value(t, problem.error, ba.Error.None)

    if problem.error != .None {
        return
    }

    defer ba.built_destroy(&built)
    configuration, error := ph.authoring_config(&scene)
    testing.expect_value(t, error, r.Error.None)

    if error != .None {
        return
    }

    initial, initial_error := ph.authoring_checkpoint(
        &built,
        configuration,
        r.Frame(State){state = initial_state(&built)},
        u8,
    )
    testing.expect_value(t, initial_error, r.Error.None)

    if initial_error != .None {
        return
    }

    defer r.complete_checkpoint_destroy(&initial)

    timeline, reference: r.Timeline(State, u8, u8)
    settings := ph.timeline_config_default()
    testing.expect_value(t, settings.history_frames, limits.HISTORY_FRAMES)
    testing.expect_value(t, r.init_complete(&timeline, &initial, local_step, settings), r.Error.None)
    defer r.destroy(&timeline)
    testing.expect_value(t, r.init_complete(&reference, &initial, local_step, settings), r.Error.None)
    defer r.destroy(&reference)

    // Empty-space linear body and character travel distinguish the actual tick
    // duration. This fails when the adapter retains a literal 1/60-second step.
    testing.expect_value(t, r.advance(&timeline, 0).error, r.Error.None)
    first := save(t, &timeline, 1)
    states: [1]b.Body_State
    count, states_error := ph.body_states(&first, states[:])
    testing.expect_value(t, states_error, r.Error.None)
    testing.expect_value(t, count, u32(1))
    testing.expect(t, abs(states[0].pose.position.x - b.FIXED_SECONDS) < 0.00001)
    testing.expect(t, abs(first.frame.state.character.position.x - .5 * b.FIXED_SECONDS) < 0.00001)
    r.complete_checkpoint_destroy(&first)

    for tick in 2 ..= net.PHYSICS_WINDOW {
        testing.expect_value(t, r.advance(&timeline, 0).error, r.Error.None)
    }

    before := save(t, &timeline, u64(net.PHYSICS_WINDOW))
    defer r.complete_checkpoint_destroy(&before)
    testing.expect_value(t, r.advance(&timeline, 0).error, r.Error.Prediction_Limit)
    testing.expect_value(t, timeline.head, u64(net.PHYSICS_WINDOW))
    unchanged := save(t, &timeline, timeline.head)
    same(t, &before, &unchanged)
    r.complete_checkpoint_destroy(&unchanged)

    // Revising tick one rebuilds the full configured window, including depths
    // beyond the previous 32-tick ceiling in the high profile.
    revised := r.revise_input(&timeline, 1, 1)
    testing.expect_value(t, revised.error, r.Error.None)
    testing.expect_value(t, revised.steps, net.PHYSICS_WINDOW)

    for tick in 1 ..= net.PHYSICS_WINDOW {
        testing.expect_value(t, r.advance(&reference, tick == 1 ? u8(1) : u8(0)).error, r.Error.None)
    }

    actual := save(t, &timeline, timeline.head)
    expected := save(t, &reference, reference.head)
    same(t, &expected, &actual)
    testing.expect_value(t, actual.frame.state.changed, u64(1))
    r.complete_checkpoint_destroy(&actual)
    r.complete_checkpoint_destroy(&expected)
    testing.expect_value(t, r.audit(&timeline, 1).error, r.Error.None)
    testing.expect_value(t, r.confirm_through(&timeline, timeline.head), r.Error.None)

    last := u64(2 * limits.HISTORY_FRAMES + 5)

    for tick := timeline.head + 1; tick <= last; tick += 1 {
        result := r.advance(&timeline, 0)
        testing.expect_value(t, result.error, r.Error.None)

        if result.error != .None {
            return
        }

        testing.expect_value(t, r.confirm_through(&timeline, tick), r.Error.None)
    }

    // H retained frames hold H-1 replayable transitions. The older predecessor
    // has wrapped out; an audit may not invent it from the current world.
    oldest := last - u64(limits.HISTORY_FRAMES) + 1
    stable := save(t, &timeline, last)
    defer r.complete_checkpoint_destroy(&stable)
    audit := r.audit(&timeline, oldest + 1)
    testing.expect_value(t, audit.error, r.Error.None)
    testing.expect_value(t, audit.steps, limits.HISTORY_FRAMES - 1)
    testing.expect_value(t, r.audit(&timeline, oldest).error, r.Error.History_Missing)
    missing, missing_error := r.capture_complete(&timeline, oldest - 1)
    testing.expect_value(t, missing_error, r.Error.History_Missing)
    r.complete_checkpoint_destroy(&missing)
    after := save(t, &timeline, last)
    same(t, &stable, &after)
    r.complete_checkpoint_destroy(&after)
    fmt.printf(
        "TIMING_REPLAY_HISTORY_OK history=%d repair=%d hz=%d substeps=%d wrapped_tick=%d\n",
        limits.HISTORY_FRAMES,
        net.PHYSICS_WINDOW,
        limits.TICK_HZ,
        limits.SUBSTEPS,
        last,
    )
}

network_model :: proc(codec: ^ph.Network_Codec(State, u8, u8, u8, 2)) -> net.Model(State, u8, u8, u8, 2) {
    return {complete_state = true, complete_codec = codec.value, step = network_step, hold = proc(value: u8) -> u8 {
            return value
        }, control_valid = proc(value: u8) -> bool {
            return value <= 1
        }, action_valid = proc(value: u8) -> bool {
            return value == 0
        }, state_valid = proc(value: State) -> bool {
            return value.body != 0
        }}
}

@(test)
network_runtime_horizons_are_bounded_by_the_selected_profile :: proc(t: ^testing.T) {
    defer cleanup(t)
    scene := scene_make(t)
    defer ba.destroy(&scene)
    built, problem := ba.build(&scene, 0x54494d4552504c32)
    testing.expect_value(t, problem.error, ba.Error.None)

    if problem.error != .None {
        return
    }

    defer ba.built_destroy(&built)
    configuration, error := ph.authoring_config(&scene)
    testing.expect_value(t, error, r.Error.None)

    if error != .None {
        return
    }

    initial, initial_error := ph.authoring_checkpoint(
        &built,
        configuration,
        r.Frame(State){state = initial_state(&built)},
        net.Net_Event(u8),
    )
    testing.expect_value(t, initial_error, r.Error.None)

    if initial_error != .None {
        return
    }

    defer r.complete_checkpoint_destroy(&initial)
    codec := new(ph.Network_Codec(State, u8, u8, u8, 2))
    defer free(codec)
    defer ph.network_codec_destroy(codec)
    codec_error := ph.network_codec_init(
        codec,
        &built.catalog,
        configuration,
        bd.hash_bytes(transmute([]u8)string("box3d.timing.replay.network.v1")),
    )
    testing.expect_value(t, codec_error, net.Error.None)

    if codec_error != .None {
        return
    }

    model := network_model(codec)
    configuration_before := initial.frame
    original := dump(t, &initial)
    defer delete(original)

    cfg := net.physics_config_default()
    testing.expect_value(t, cfg.history, limits.HISTORY_FRAMES)
    testing.expect_value(t, cfg.hz, u32(limits.TICK_HZ))
    testing.expect_value(t, cfg.max_prediction, u32(limits.REPLAY_PREDICTION_TICKS))
    // An active 4-tick horizon is legal under every admitted build profile.
    cfg.max_prediction = 4
    cfg.max_future = 4

    for valid in ([?]net.Config{net.physics_config_default(), cfg}) {
        server := new(net.Server(State, u8, u8, u8, 2))
        client := new(net.Client(State, u8, u8, u8, 2))
        testing.expect_value(t, net.server_init_complete(server, &initial, model, {}, valid), net.Error.None)
        testing.expect_value(t, net.client_init(client, model, {}, net.Token{0 = 2}, cfg = valid), net.Error.None)
        testing.expect(t, server.initialized && client.initialized)
        testing.expect_value(t, net.client_destroy(client), net.Error.None)
        testing.expect_value(t, net.server_destroy(server), net.Error.None)
        free(client)
        free(server)
    }

    wrong_rate, wrong_history, excess_prediction, excess_future :=
        net.physics_config_default(),
        net.physics_config_default(),
        net.physics_config_default(),
        net.physics_config_default()
    wrong_rate.hz = wrong_rate.hz == 240 ? 239 : wrong_rate.hz + 1
    wrong_history.history /= 2
    excess_prediction.max_prediction = u32(net.PHYSICS_WINDOW + 1)
    excess_future.max_future = u32(net.PHYSICS_WINDOW + 1)

    for invalid in ([?]net.Config{wrong_rate, wrong_history, excess_prediction, excess_future}) {
        server := new(net.Server(State, u8, u8, u8, 2))
        client := new(net.Client(State, u8, u8, u8, 2))
        testing.expect_value(
            t,
            net.server_init_complete(server, &initial, model, {}, invalid),
            net.Error.Invalid_Config,
        )
        testing.expect_value(
            t,
            net.client_init(client, model, {}, net.Token{0 = 2}, cfg = invalid),
            net.Error.Invalid_Config,
        )
        testing.expect(t, !server.initialized && !client.initialized)
        testing.expect_value(t, net.client_destroy(client), net.Error.None)
        testing.expect_value(t, net.server_destroy(server), net.Error.None)
        free(client)
        free(server)
    }

    current := dump(t, &initial)
    defer delete(current)
    testing.expect(
        t,
        reflect.equal(initial.frame, configuration_before) && mem.compare(original, current) == 0,
        "admitted and rejected initializations preserve their borrowed checkpoint",
    )
    fmt.printf(
        "TIMING_REPLAY_CONFIG_OK history=%d active_smaller=4 ceiling=%d default=%d hz=%d\n",
        limits.HISTORY_FRAMES,
        net.PHYSICS_WINDOW,
        limits.REPLAY_PREDICTION_TICKS,
        limits.TICK_HZ,
    )
}
