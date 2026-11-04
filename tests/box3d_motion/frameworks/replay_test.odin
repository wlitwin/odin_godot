package box3d_motion_frameworks_test

import "core:mem"
import "core:reflect"
import "core:testing"
import "core:fmt"
import b "godot:box3d"
import ba "godot:box3d/authoring"
import r "godot:replay"
import rp "godot:replay/physics"
import rn "godot:replay/net"

replay_step :: proc(value: ^State, input: Input, ctx: ^r.Step(u8)) {
    config := (cast(^b.Character_Config)ctx.user)^

    if input.invalid {
        config.max_slides = 0
    }

    value.character.velocity = {1 + f32(input.turn), -0.25, 0.25}
    result, error := rp.character_step(ctx.execution, config, value.character)

    if error != .None {
        return
    }

    value.character = result.state
    hits: [b.MOTION_MAX_HITS]b.Motion_Hit
    count, qe := rp.motion_ray(ctx.execution, {-5, 2, 0}, {10, 0, 0}, config.filter, hits[:])

    if qe != .None {
        r.abort(ctx)
        return
    }

    value.query_hash = query_hash(hits[:count])
    value.query_count = count

    if rp.step(ctx.execution) != .None {
        return
    }

    value.tick = ctx.tick

    if input.abort {
        r.abort(ctx)
    }
}

replay_save :: proc(
    t: ^testing.T,
    timeline: ^r.Timeline(State, Input, u8),
    tick: u64,
) -> r.Complete_Checkpoint(State, u8) {
    checkpoint, error := r.capture_complete(timeline, tick)
    testing.expect_value(t, error, r.Error.None)
    return checkpoint
}

replay_dump :: proc(t: ^testing.T, checkpoint: ^r.Complete_Checkpoint(State, $E)) -> []u8 {
    size, error := rp.dump(checkpoint, nil)
    testing.expect_value(t, error, r.Error.None)
    bytes := make([]u8, int(size))
    _, error = rp.dump(checkpoint, bytes)
    testing.expect_value(t, error, r.Error.None)
    return bytes
}

replay_same :: proc(t: ^testing.T, left, right: ^r.Complete_Checkpoint(State, $E)) {
    a, z := replay_dump(t, left), replay_dump(t, right)
    defer delete(a)
    defer delete(z)
    testing.expect(
        t,
        mem.compare(a, z) == 0 && reflect.equal(left.frame, right.frame),
        "complete solver, character Game, query values and joint state match",
    )
}

replay_family :: proc(t: ^testing.T, kind: string) {
    input := scene_input(kind)
    defer scene_input_destroy(&input)
    scene, diagnostic := ba.bake(input)
    testing.expect_value(t, diagnostic.error, ba.Error.None)

    if diagnostic.error != .None {
        return
    }

    defer ba.destroy(&scene)
    config, ce := rp.authoring_config(&scene)
    testing.expect_value(t, ce, r.Error.None)

    if ce != .None {
        return
    }

    built, problem := ba.build(&scene, PROFILE)
    testing.expect_value(t, problem.error, ba.Error.None)

    if problem.error != .None {
        return
    }

    defer ba.built_destroy(&built)
    movement := built.characters[0].config
    initial, error := rp.authoring_checkpoint(&built, config, r.Frame(State){state = initial_state(&built)}, u8)
    testing.expect_value(t, error, r.Error.None)

    if error != .None {
        return
    }

    defer r.complete_checkpoint_destroy(&initial)
    ba.destroy(&scene)
    timeline: r.Timeline(State, Input, u8)
    testing.expect_value(
        t,
        r.init_complete(&timeline, &initial, replay_step, {128, 70}, user = &movement),
        r.Error.None,
    )
    defer r.destroy(&timeline)

    for tick in 1 ..= 8 {
        error := r.advance(&timeline, Input{}).error
        testing.expect_value(t, error, r.Error.None)

        if error != .None {
            fmt.printf(
                "MOTION_FRAMEWORK_FAILURE framework=replay kind=%s stage=advance tick=%d error=%v\n",
                kind,
                tick,
                error,
            )
            return
        }
    }

    before := replay_save(t, &timeline, 8)
    defer r.complete_checkpoint_destroy(&before)
    testing.expect_value(t, r.revise_input(&timeline, 4, Input{abort = true}).error, r.Error.Aborted)
    failed := replay_save(t, &timeline, 8)
    replay_same(t, &before, &failed)
    r.complete_checkpoint_destroy(&failed)
    testing.expect_value(t, r.revise_input(&timeline, 3, Input{turn = 1}).error, r.Error.None)
    revised := replay_save(t, &timeline, 8)
    defer r.complete_checkpoint_destroy(&revised)
    testing.expect(
        t,
        revised.frame.state.character.position.x > 0 &&
        revised.frame.state.query_hash != 0 &&
        revised.frame.state.query_count > 0 &&
        revised.frame.state.joint != 0,
    )
    branch: r.Timeline(State, Input, u8)
    testing.expect_value(t, r.init_complete(&branch, &initial, replay_step, {128, 70}, user = &movement), r.Error.None)
    defer r.destroy(&branch)

    for tick in 1 ..= 8 {
        testing.expect_value(t, r.advance(&branch, Input{turn = tick == 3 ? 1 : 0}).error, r.Error.None)
    }

    expected := replay_save(t, &branch, 8)
    defer r.complete_checkpoint_destroy(&expected)
    replay_same(t, &expected, &revised)
    testing.expect_value(t, r.audit(&timeline, 1).error, r.Error.None)
    testing.expect_value(t, r.confirm_through(&timeline, 8), r.Error.None)
    testing.expect_value(t, r.advance(&timeline, Input{}, r.Commit_Gate {
            allow = proc(_: rawptr, _: u64) -> bool {
                return false
            },
        }).error, r.Error.Commit_Rejected)
    unchanged := replay_save(t, &timeline, 8)
    defer r.complete_checkpoint_destroy(&unchanged)
    replay_same(t, &revised, &unchanged)
    _, stale := rp.character_step(r.Execution{}, movement, revised.frame.state.character)
    testing.expect_value(t, stale, r.Error.Stale_Execution)
}

@(test)
replay_all_joint_families_character_queries_and_complete_revisions :: proc(t: ^testing.T) {
    defer expect_cleanup(t)

    for kind in KINDS {
        replay_family(t, kind)
    }
}

Action :: struct {
    replace, accept, abort: bool,
}

net_step :: proc(value: ^State, inputs: [1]Input, _, _: u64, ctx: ^r.Step(u8)) {
    replay_step(value, inputs[0], ctx)
}

net_action :: proc(value: ^State, _: u16, action: Action, ctx: ^r.Step(u8)) -> bool {
    if action.replace {
        if rp.motion_joint_destroy(ctx.execution, value.joint) != .None {
            return false
        }

        definition, status := b.motion_joint_default(.Motor)

        if status != .Ok {
            r.abort(ctx)
            return false
        }

        definition.body_a = value.anchor
        definition.body_b = value.actor_body
        definition.local_frame_a.position = {-3, 2.5, 0}
        replacement, error := rp.motion_joint_create(ctx.execution, definition)

        if error != .None {
            return false
        }

        value.joint = replacement
        value.character.position.x += 4
    }

    if action.abort {
        r.abort(ctx)
    }

    return action.accept
}

@(test)
replay_actual_action_savepoint_restores_joint_replacement_and_character :: proc(t: ^testing.T) {
    defer expect_cleanup(t)
    input := scene_input("wheel")
    defer scene_input_destroy(&input)
    scene, diagnostic := ba.bake(input)
    testing.expect_value(t, diagnostic.error, ba.Error.None)

    if diagnostic.error != .None {
        return
    }

    defer ba.destroy(&scene)
    config, ce := rp.authoring_config(&scene)
    testing.expect_value(t, ce, r.Error.None)

    if ce != .None {
        return
    }

    built, problem := ba.build(&scene, PROFILE)
    testing.expect_value(t, problem.error, ba.Error.None)

    if problem.error != .None {
        return
    }

    defer ba.built_destroy(&built)
    movement := built.characters[0].config
    initial, error := rp.authoring_checkpoint(
        &built,
        config,
        r.Frame(State){state = initial_state(&built)},
        rn.Net_Event(u8),
    )
    testing.expect_value(t, error, r.Error.None)

    if error != .None {
        return
    }

    defer r.complete_checkpoint_destroy(&initial)
    model := rn.Model(State, Input, Action, u8, 1) {
        complete_state = true,
        step = net_step,
        action = net_action,
        user = &movement,
        control_valid = proc(_: Input) -> bool {
            return true
        },
    }
    callback := rn.model_callback(State, Input, Action, u8, 1)
    baseline: r.Timeline(State, rn.Batch(Input, Action, 1), rn.Net_Event(u8))
    testing.expect_value(t, r.init_complete(&baseline, &initial, callback, {128, 78}, user = &model), r.Error.None)
    testing.expect_value(t, r.advance(&baseline, rn.Batch(Input, Action, 1){}).error, r.Error.None)
    expected, ee := r.capture_complete(&baseline, 1)
    testing.expect_value(t, ee, r.Error.None)
    defer r.complete_checkpoint_destroy(&expected)
    r.destroy(&baseline)
    candidate: r.Timeline(State, rn.Batch(Input, Action, 1), rn.Net_Event(u8))
    testing.expect_value(t, r.init_complete(&candidate, &initial, callback, {128, 78}, user = &model), r.Error.None)
    defer r.destroy(&candidate)
    batch := rn.Batch(Input, Action, 1) {
        has_action = {true},
        actions    = {{replace = true}},
        sequences  = {1},
    }
    testing.expect_value(t, r.advance(&candidate, batch).error, r.Error.None)
    actual, ae := r.capture_complete(&candidate, 1)
    testing.expect_value(t, ae, r.Error.None)
    defer r.complete_checkpoint_destroy(&actual)
    replay_same(t, &expected, &actual)
    testing.expect_value(t, len(actual.events), len(expected.events) + 1)
    batch.actions[0] = {
        replace = true,
        accept  = true,
        abort   = true,
    }
    testing.expect_value(t, r.advance(&candidate, batch).error, r.Error.Aborted)
    after, fe := r.capture_complete(&candidate, 1)
    testing.expect_value(t, fe, r.Error.None)
    defer r.complete_checkpoint_destroy(&after)
    replay_same(t, &actual, &after)
}

@(test)
replay_ignored_invalid_character_result_cannot_commit :: proc(t: ^testing.T) {
    defer expect_cleanup(t)
    input := scene_input("pin")
    defer scene_input_destroy(&input)
    scene, diagnostic := ba.bake(input)
    testing.expect_value(t, diagnostic.error, ba.Error.None)

    if diagnostic.error != .None {
        return
    }

    defer ba.destroy(&scene)
    config, ce := rp.authoring_config(&scene)
    testing.expect_value(t, ce, r.Error.None)

    if ce != .None {
        return
    }

    built, problem := ba.build(&scene, PROFILE)
    testing.expect_value(t, problem.error, ba.Error.None)

    if problem.error != .None {
        return
    }

    defer ba.built_destroy(&built)
    movement := built.characters[0].config
    initial, error := rp.authoring_checkpoint(&built, config, r.Frame(State){state = initial_state(&built)}, u8)
    testing.expect_value(t, error, r.Error.None)

    if error != .None {
        return
    }

    defer r.complete_checkpoint_destroy(&initial)
    timeline: r.Timeline(State, Input, u8)
    testing.expect_value(
        t,
        r.init_complete(&timeline, &initial, replay_step, {128, 70}, user = &movement),
        r.Error.None,
    )
    defer r.destroy(&timeline)
    testing.expect_value(t, r.advance(&timeline, Input{invalid = true}).error, r.Error.External_State)
    unchanged := replay_save(t, &timeline, 0)
    defer r.complete_checkpoint_destroy(&unchanged)
    replay_same(t, &initial, &unchanged)
}
