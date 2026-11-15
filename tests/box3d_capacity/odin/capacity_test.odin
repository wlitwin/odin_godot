package box3d_capacity_test

import "core:fmt"
import "core:mem"
import "core:testing"
import b "godot:box3d"
import a "godot:box3d/authoring"
import p "godot:box3d/presentation"
import k "godot:kit/sim"
import ks "godot:kit/session"
import r "godot:replay"
import rp "godot:replay/physics"
import bcap "godot:box3d/limits"
import f "godot:tests/box3d_authoring/frameworks"

BODIES :: 1000
JOINTS :: 100

State :: struct {
    tick, changed: u64,
}

large_scene :: proc(t: ^testing.T, shapes_per_body: int = 1) -> a.Baked_Scene {
    scene := a.scene_input_default("box3d.capacity.1000.100", 2)
    scene.gravity = {}
    bodies := make([]a.Body_Input, BODIES)
    joints := make([]a.Joint_Input, JOINTS)
    keys := make([]string, BODIES)
    defer delete(bodies)
    defer delete(joints)
    defer delete(keys)

    defer {
        for key in keys {
            delete(key)
        }
    }

    defer {
        for joint in joints {
            delete(joint.stable_key)
        }
    }

    shapes := make([]a.Shape_Input, shapes_per_body)
    defer delete(shapes)

    defer {
        for shape in shapes {
            delete(shape.stable_key)
        }
    }

    for &shape, i in shapes {
        shape = a.shape_input_default(fmt.aprintf("cube-%d", i), "box")
        shape.half_extents = {.1, .1, .1}
    }

    floor := [1]a.Shape_Input{a.shape_input_default("floor", "box")}
    floor[0].half_extents = {8.5, .25, 8.5}

    for &body, i in bodies {
        keys[i] = fmt.aprintf("body-%04d", i)
        body = a.body_input_default(keys[i])
        body.enable_sleep = false
        body.body_type = i == 0 ? "static" : "dynamic"
        body.pose.position =
            i == 0 ? [3]f32{0, -.25, 0} : [3]f32{(f32((i - 1) % 32) - 15.5) * .5, .1, (f32((i - 1) / 32) - 15.5) * .5}
        body.shapes = i == 0 ? floor[:] : shapes[:]
    }

    for &joint, i in joints {
        joint = a.joint_input_default(fmt.aprintf("hinge-%03d", i), "hinge", keys[0], keys[i + 1])
        joint.local_frame_a.position = bodies[i + 1].pose.position
        joint.local_frame_a.position[1] += .25
    }

    scene.bodies = bodies
    scene.joints = joints
    baked, problem := a.bake(scene)
    testing.expect(t, problem.error == .None, fmt.tprintf("error=%v field=%s", problem.error, problem.field))
    return baked
}

@(test)
authoring_and_presentation_accept_a_thousand_bodies_and_a_hundred_joints :: proc(t: ^testing.T) {
    scene := large_scene(t)
    defer a.destroy(&scene)
    testing.expect_value(t, len(scene.data.bodies), BODIES)
    testing.expect_value(t, len(scene.data.joints), JOINTS)
    built, problem := a.build(&scene, 0x4341504143495459)
    testing.expect(
        t,
        problem.error == .None,
        fmt.tprintf("field=%s native=%v element=%d", problem.field, problem.native_status, problem.element),
    )

    if problem.error != .None {
        return
    }

    defer a.built_destroy(&built)
    testing.expect_value(t, b.world_step_fixed(built.world), b.Status.Ok)
    counts, status := b.world_counters(built.world)
    testing.expect_value(t, status, b.Status.Ok)
    testing.expect_value(t, counts.body_count, u32(BODIES))
    testing.expect_value(t, counts.joint_count, u32(JOINTS))
    bindings := make([]p.Binding, BODIES)
    samples := make([]p.Body_Sample, BODIES)
    changes := make([]p.Change, 2 * BODIES)
    defer delete(bindings)
    defer delete(samples)
    defer delete(changes)

    for &binding, i in bindings {
        binding = {
            id    = {u64(i + 1), 1},
            body  = p.Body_Key(i + 1),
            asset = 1,
            alive = true,
        }
        samples[i] = {
            body = p.Body_Key(i + 1),
            pose = {{f32(i), 0, 0}, {0, 0, 0, 1}},
        }
    }

    frame, frame_error := p.frame_make(1, 1, 0, .Confirmed, bindings, samples)
    testing.expect_value(t, frame_error, p.Error.None)
    view := new(p.View)
    defer free(view)
    required, present_error := p.present(view, nil, &frame, 0, changes)
    testing.expect_value(t, present_error, p.Error.None)
    testing.expect_value(t, required, u32(BODIES))
    required, present_error = p.view_clear(view, changes)
    testing.expect_value(t, present_error, p.Error.None)
    testing.expect_value(t, required, u32(BODIES))
    fmt.println("CAPACITY_AUTHORING_PRESENTATION_OK bodies=1000 joints=100")
}

replay_step :: proc(state: ^State, input: u8, ctx: ^r.Step(u8)) {
    if input != 0 {
        state.changed += 1

        if error := rp.gravity(ctx.execution, {0, -.01, 0}); error != .None {
            ctx.error = error
            return
        }
    }

    if error := rp.step(ctx.execution); error != .None {
        ctx.error = error
        return
    }

    state.tick = ctx.tick
}

@(test)
replay_large_world_corrects_input_and_retains_a_full_history :: proc(t: ^testing.T) {
    scene := large_scene(t)
    defer a.destroy(&scene)
    built, problem := a.build(&scene, 0x4341504143495459)
    testing.expect(
        t,
        problem.error == .None,
        fmt.tprintf("field=%s native=%v element=%d", problem.field, problem.native_status, problem.element),
    )

    if problem.error != .None {
        return
    }

    defer a.built_destroy(&built)
    config, config_error := rp.authoring_config(&scene)
    testing.expect_value(t, config_error, r.Error.None)
    initial, initial_error := rp.authoring_checkpoint(&built, config, r.Frame(State){}, u8)
    testing.expect_value(t, initial_error, r.Error.None)

    if initial_error != .None {
        return
    }

    defer r.complete_checkpoint_destroy(&initial)
    pointer, image_error := r.complete_checkpoint_image(&initial, rp.IDENTITY)
    testing.expect(t, image_error == .None && pointer != nil)

    for incompatible in ([?]u64{0x5245504c42334431, 0x5245504c42334432, rp.IDENTITY ~ 2}) {
        pointer, image_error = r.complete_checkpoint_image(&initial, incompatible)
        testing.expect(t, image_error != .None && pointer == nil)
    }

    timeline: r.Timeline(State, u8, u8)
    testing.expect_value(
        t,
        r.init_complete(&timeline, &initial, replay_step, rp.timeline_config_default()),
        r.Error.None,
    )
    defer r.destroy(&timeline)

    for _ in 0 ..< 8 {
        testing.expect_value(t, r.advance(&timeline, 0).error, r.Error.None)
    }

    revision := r.revise_input(&timeline, 3, 1)
    testing.expect_value(t, revision.error, r.Error.None)
    testing.expect_value(t, r.audit(&timeline, 1).error, r.Error.None)
    state, found := r.current_values(&timeline)
    testing.expect(t, found && state.state.tick == 8 && state.state.changed == 1)
    testing.expect_value(t, r.confirm_through(&timeline, 8), r.Error.None)

    for tick in 9 ..= bcap.HISTORY_FRAMES {
        result := r.advance(&timeline, 0)
        testing.expect_value(t, result.error, r.Error.None)

        if result.error != .None {
            return
        }

        testing.expect_value(t, r.confirm_through(&timeline, u64(tick)), r.Error.None)
    }

    checkpoint, checkpoint_error := r.capture_complete(&timeline, u64(bcap.HISTORY_FRAMES))
    testing.expect_value(t, checkpoint_error, r.Error.None)
    defer r.complete_checkpoint_destroy(&checkpoint)
    states := make([]b.Body_State, BODIES)
    defer delete(states)
    count, count_error := rp.body_states(&checkpoint, states)
    testing.expect_value(t, count_error, r.Error.None)
    testing.expect_value(t, count, u32(BODIES))
    fmt.printfln("CAPACITY_REPLAY_OK bodies=1000 joints=100 history=%d revised_tick=3", bcap.HISTORY_FRAMES)
}

@(test)
kit_large_authored_world_transfers_complete_state_and_resets :: proc(t: ^testing.T) {
    scene := large_scene(t, 4)
    defer a.destroy(&scene)
    host, client := new(f.Kit_Box), new(f.Kit_Box)
    defer free(host)
    defer free(client)
    defer f.kit_destroy(t, host)
    defer f.kit_destroy(t, client)
    host.peer = ks.HOST_PEER
    client.peer = 100

    for box in ([]^f.Kit_Box{host, client}) {
        box.ses.send = f.kit_send
        box.ses.send_user = box
    }

    ks.session_host_start(&host.ses, "authority")
    ks.session_client_start(&client.ses, 0xabc, "client")
    ks.session_client_join(&client.ses)
    f.kit_pump({host, client})

    if !f.kit_setup(t, host, &scene) || !f.kit_setup(t, client, &scene) {
        return
    }

    wire, export_error := k.lane_world_export(&host.lane, 0)
    testing.expect_value(t, export_error, k.World_Error.Ok)
    testing.expect(t, len(wire) > 32 * k.WORLD_NETWORK_CHUNK)
    fmt.printfln(
        "CAPACITY_KIT_TRANSFER bytes=%d parts=%d",
        len(wire),
        (len(wire) + k.WORLD_NETWORK_CHUNK - 1) / k.WORLD_NETWORK_CHUNK,
    )
    delete(wire)
    testing.expect_value(t, k.lane_world_send_checkpoint(&host.lane, client.peer, .Welcome), k.World_Error.Ok)
    f.kit_pump({host, client})
    _ = k.lane_frame(&client.lane, 0)
    testing.expect(t, f.kit_same(t, host, client, 0))

    for _ in 0 ..< 3 {
        _ = k.lane_frame(&client.lane, 1.0 / f64(b.FIXED_HZ))
    }

    f.kit_pump({host, client})

    for _ in 0 ..< 3 {
        testing.expect_value(t, k.lane_frame(&host.lane, 1.0 / f64(b.FIXED_HZ)), 1)
    }

    f.kit_pump({host, client})
    _ = k.lane_frame(&client.lane, 0)
    testing.expect(t, f.kit_same(t, host, client, 3))
    testing.expect_value(t, k.lane_world_request_reset(&client.lane), k.World_Error.Ok)
    f.kit_pump({host, client})
    _ = k.lane_frame(&host.lane, 0)
    f.kit_pump({host, client})
    _ = k.lane_frame(&client.lane, 0)
    testing.expect(t, f.kit_same(t, host, client, 3))
    fmt.println("CAPACITY_KIT_NETWORK_OK bodies=1000 joints=100 welcome=complete reset=complete")
}

@(test)
replay_large_authored_world_transfers_more_than_thirty_two_chunks :: proc(t: ^testing.T) {
    scene := large_scene(t, 4)
    defer a.destroy(&scene)
    f.replay_network_scene(t, &scene, 33)
    fmt.println("CAPACITY_REPLAY_NETWORK_OK bodies=1000 joints=100 shapes=3997")
}
