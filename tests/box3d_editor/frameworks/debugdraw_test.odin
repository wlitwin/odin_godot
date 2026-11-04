package box3d_editor_frameworks_test

// Actual existing framework checkpoint readers feed one detached draw contract.
// Explicit static Native/nilOwner scope; the separate SDK case covers Godot.
import "core:mem"
import "core:testing"
import "core:os"
import b "godot:box3d"
import a "godot:box3d/authoring"
import d "godot:box3d/debugdraw"
import p "godot:box3d/presentation"
import kp "godot:kit/physics"
import k "godot:kit/sim"
import ks "godot:kit/session"
import r "godot:replay"
import rp "godot:replay/physics"
import rg "godot:replay/godot"
import wire "godot:box3d/godot/debugdraw"

PROFILE :: u64(0x454449544f523031)

Game :: struct {
    tick:   u64,
    keys:   [3]b.Body_Key,
    ids:    [3]u64,
    assets: [3]u32,
}

Kit :: struct {
    session: ks.Session,
    lane:    k.Lane,
    physics: kp.Instance(Game),
}

definition :: proc() -> a.Scene_Input {
    input := a.scene_input_default("box3d.editor.frames")
    input.bodies = make([]a.Body_Input, 3)
    keys := [3]string{"floor", "sphere", "capsule"}
    kinds := [3]string{"box", "sphere", "capsule"}

    for key, index in keys {
        body := a.body_input_default(key)
        body.shapes = make([]a.Shape_Input, 1)
        body.shapes[0] = a.shape_input_default(key, kinds[index])

        if index == 0 {
            body.pose.position = {0, -0.5, 0}
            body.shapes[0].half_extents = {6, 0.5, 6}
        } else {
            body.body_type = "dynamic"
            body.pose.position = {f32(index), 2, 0}
        }

        input.bodies[index] = body
    }

    return input
}

definition_destroy :: proc(input: ^a.Scene_Input) {
    for body in input.bodies {
        delete(body.shapes)
    }

    delete(input.bodies)
    input^ = {}
}

game_from_maps :: proc(built: ^a.Built_Scene) -> Game {
    value: Game

    for body, index in built.bodies {
        value.keys[index] = body.key
        value.ids[index] = body.logical_id

        for shape in built.shapes {
            if shape.body_id == body.logical_id {
                value.assets[index] = shape.asset_id
                break
            }
        }
    }

    return value
}

project :: proc(value: Game, out: []p.Binding) -> (u32, p.Error) {
    if len(out) < 3 {
        return 3, .Capacity
    }

    for key, index in value.keys {
        out[index] = {
            id    = {value.ids[index], 1},
            body  = p.Body_Key(key),
            asset = value.assets[index],
            alive = true,
        }
    }

    return 3, .None
}

sample :: proc(_: rawptr, _: u64, out: rawptr) {
    (cast(^u8)out)^ = 0
}

kit_step :: proc(user: rawptr, tick: u64) {
    box := cast(^Kit)user
    kp.state(&box.physics).tick = tick
}

replay_step :: proc(value: ^Game, _: u8, ctx: ^r.Step(u8)) {
    if rp.step(ctx.execution) != .None {
        return
    }

    value.tick = ctx.tick
}

draw :: proc(t: ^testing.T, frame: ^p.Frame, scene: d.Scene, out: []d.Line) -> d.Batch {
    engine, es := b.engine_allocation_stats()
    wrapper, ws := b.snapshot_allocation_stats()
    testing.expect(t, es == .Ok && ws == .Ok)
    before := frame^
    batch, error := d.generate(frame, scene, {enabled = true, expected = d.stamp_of(frame)}, out)
    testing.expect_value(t, error, d.Error.None)
    testing.expect(t, batch.count > 0 && batch.count == batch.required)
    after_engine, _ := b.engine_allocation_stats()
    after_wrapper, _ := b.snapshot_allocation_stats()
    testing.expect(
        t,
        frame^ == before &&
        after_engine.total_calls == engine.total_calls &&
        after_wrapper.total_calls == wrapper.total_calls,
        "drawing reads copied values, allocates no Native storage and changes no frame",
    )
    return batch
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
        kp.owned_bytes() == 0 &&
        rp.allocation_stats().live_bytes == 0,
    )
}

save_draw_frame :: proc(t: ^testing.T, name: string, batch: d.Batch, lines: []d.Line) {
    bytes, error := wire.frame_json(batch, lines)
    testing.expect_value(t, error, wire.Error.None)

    if error != .None {
        return
    }

    defer delete(bytes)
    testing.expect(
        t,
        os.write_entire_file(name, bytes) == nil,
        "save actual detached framework drawing for the Godot renderer fixture",
    )
}

@(test)
kit_copied_checkpoint_geometry_draws_after_all_sources_are_destroyed :: proc(t: ^testing.T) {
    defer cleanup(t)
    input := definition()
    scene, problem := a.bake(input)
    definition_destroy(&input)
    testing.expect_value(t, problem.error, a.Error.None)

    if problem.error != .None {
        return
    }

    defer a.destroy(&scene)
    built, be := a.build(&scene, PROFILE)
    testing.expect_value(t, be.error, a.Error.None)

    if be.error != .None {
        return
    }

    defer a.built_destroy(&built)
    geometry, ge := a.debug_scene_create(&scene, &built)
    testing.expect_value(t, ge.error, a.Error.None)

    if ge.error != .None {
        return
    }

    defer a.debug_scene_destroy(&geometry)
    value := game_from_maps(&built)
    a.destroy(&scene)
    box := new(Kit)
    defer free(box)
    box.session.is_host = true
    box.session.me = 1
    k.lane_init(&box.lane, &box.session, size_of(u8))
    k.lane_set_sim(&box.lane, box, sample, kit_step)
    testing.expect_value(t, kp.authoring_attach(&box.physics, &box.lane, &built, value, nil, {}), k.World_Error.Ok)

    for _ in 0 ..< 3 {
        testing.expect_value(t, k.lane_frame(&box.lane, 1.0 / 60), 1)
    }

    checkpoint, ce := k.lane_world_checkpoint(&box.lane, 3)
    testing.expect_value(t, ce, k.World_Error.Ok)
    frame, pe, fe := kp.presentation_frame(&checkpoint, k.lane_world_epoch(&box.lane), Game, project, 1, .Predicted)
    testing.expect(t, pe == .None && fe == .Ok)
    lines := make([]d.Line, d.MAX_LINES)
    defer delete(lines)
    batch := draw(t, &frame, geometry.scene, lines)
    after, ae := k.lane_world_checkpoint(&box.lane, 3)
    testing.expect_value(t, ae, k.World_Error.Ok)
    same, se := k.world_checkpoint_equal(&checkpoint, &after)
    testing.expect(t, se == .Ok && same)
    k.world_checkpoint_destroy(&after)
    k.world_checkpoint_destroy(&checkpoint)
    k.lane_destroy(&box.lane)
    testing.expect_value(t, kp.detach(&box.physics), k.World_Error.Ok)
    ks.session_destroy(&box.session)
    testing.expect_value(t, a.built_destroy(&built), b.Status.Ok)
    other := make([]d.Line, d.MAX_LINES)
    defer delete(other)
    detached := draw(t, &frame, geometry.scene, other)
    testing.expect_value(t, detached.count, batch.count)

    for line, index in lines[:batch.count] {
        testing.expect(t, line == other[index])
    }

    save_draw_frame(t, "kit-frame.json", detached, other[:detached.count])
}

@(test)
replay_copied_checkpoint_geometry_draws_without_live_solver_or_mutation :: proc(t: ^testing.T) {
    defer cleanup(t)
    input := definition()
    scene, problem := a.bake(input)
    definition_destroy(&input)
    testing.expect_value(t, problem.error, a.Error.None)

    if problem.error != .None {
        return
    }

    defer a.destroy(&scene)
    cfg, ce := rp.authoring_config(&scene)
    testing.expect_value(t, ce, r.Error.None)

    if ce != .None {
        return
    }

    built, be := a.build(&scene, PROFILE)
    testing.expect_value(t, be.error, a.Error.None)

    if be.error != .None {
        return
    }

    defer a.built_destroy(&built)
    geometry, ge := a.debug_scene_create(&scene, &built)
    testing.expect_value(t, ge.error, a.Error.None)

    if ge.error != .None {
        return
    }

    defer a.debug_scene_destroy(&geometry)
    initial, ie := rp.authoring_checkpoint(&built, cfg, r.Frame(Game){state = game_from_maps(&built)}, u8)
    testing.expect_value(t, ie, r.Error.None)

    if ie != .None {
        return
    }

    defer r.complete_checkpoint_destroy(&initial)
    a.destroy(&scene)
    timeline: r.Timeline(Game, u8, u8)
    testing.expect_value(t, r.init_complete(&timeline, &initial, replay_step, {128, 4}), r.Error.None)
    r.complete_checkpoint_destroy(&initial)

    for _ in 0 ..< 3 {
        testing.expect_value(t, r.advance(&timeline, u8(0)).error, r.Error.None)
    }

    checkpoint, xe := r.capture_complete(&timeline, 3)
    testing.expect_value(t, xe, r.Error.None)
    frame, pe, fe := rg.physics_presentation_frame(&checkpoint, project, 1, .Predicted)
    testing.expect(t, pe == .None && fe == .None)
    lines := make([]d.Line, d.MAX_LINES)
    defer delete(lines)
    batch := draw(t, &frame, geometry.scene, lines)
    size, de := rp.dump(&checkpoint, nil)
    testing.expect_value(t, de, r.Error.None)
    before := make([]u8, int(size))
    defer delete(before)
    _, de = rp.dump(&checkpoint, before)
    testing.expect_value(t, de, r.Error.None)
    _ = draw(t, &frame, geometry.scene, lines)
    after := make([]u8, int(size))
    defer delete(after)
    _, de = rp.dump(&checkpoint, after)
    testing.expect_value(t, de, r.Error.None)
    testing.expect(t, mem.compare(before, after) == 0)
    r.complete_checkpoint_destroy(&checkpoint)
    r.destroy(&timeline)
    testing.expect_value(t, a.built_destroy(&built), b.Status.Ok)
    other := make([]d.Line, d.MAX_LINES)
    defer delete(other)
    detached := draw(t, &frame, geometry.scene, other)
    testing.expect_value(t, detached.count, batch.count)

    for line, index in lines[:batch.count] {
        testing.expect(t, line == other[index])
    }

    save_draw_frame(t, "replay-frame.json", detached, other[:detached.count])
    stale := d.stamp_of(&frame)
    stale.revision += 1
    sentinel := other[0]
    _, error := d.generate(&frame, geometry.scene, {enabled = true, expected = stale}, other)
    testing.expect(t, error == .Stale && other[0] == sentinel)
}
