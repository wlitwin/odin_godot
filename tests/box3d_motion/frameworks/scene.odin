package box3d_motion_frameworks_test

import b "godot:box3d"
import ba "godot:box3d/authoring"
import "core:testing"
import kp "godot:kit/physics"
import rp "godot:replay/physics"

PROFILE :: u64(0x4d4f54494f4e3031)
KINDS :: [8]string{"pin", "hinge", "slider", "spherical", "distance", "motor", "weld", "wheel"}

Input :: struct {
    turn:           u32,
    abort, invalid: bool,
}

State :: struct {
    tick, query_hash:   u64,
    query_count:        u32,
    character:          b.Character_State,
    joint:              b.Joint_Key,
    anchor, actor_body: b.Body_Key,
}

// Same immutable authored scene in both frameworks, one native joint per run.
scene_input :: proc(kind: string) -> ba.Scene_Input {
    input := ba.scene_input_default("box3d.motion.frameworks.v1", 2)
    input.gravity = {0, 0, 0}
    input.enable_sleep = false
    input.bodies = make([]ba.Body_Input, 3)
    shape_keys := [3]string{"geometry.anchor", "geometry.dynamic", "geometry.wall"}

    for key, i in ([3]string{"anchor", "dynamic", "wall"}) {
        body := ba.body_input_default(key)
        body.enable_sleep = false
        shape := ba.shape_input_default(shape_keys[i], "box")

        switch i {
        case 0:
            body.pose.position = {0, -0.5, 0}
            shape.half_extents = {8, 0.5, 8}
        case 1:
            body.body_type = "dynamic"
            body.pose.position = {-3, 2, 0}
            shape.half_extents = {0.25, 0.25, 0.25}
        case 2:
            body.pose.position = {2, 1, 0}
            shape.half_extents = {0.25, 1, 3}
        }

        body.shapes = make([]ba.Shape_Input, 1)
        body.shapes[0] = shape
        input.bodies[i] = body
    }

    input.joints = make([]ba.Joint_Input, 1)
    input.joints[0] = ba.joint_input_default("joint", kind, "anchor", "dynamic")
    input.joints[0].local_frame_a.position = {-3, 2.5, 0}
    input.characters = make([]ba.Character_Input, 1)
    input.characters[0] = ba.character_input_default("player")
    input.characters[0].config.capsule = {{0, 0.3, 0}, {0, 0.9, 0}, 0.3}
    input.characters[0].initial.position = {0, 0.02, 0}
    input.characters[0].initial.velocity = {1, -0.25, 0.25}
    return input
}

scene_input_destroy :: proc(input: ^ba.Scene_Input) {
    for body in input.bodies {
        delete(body.shapes)
    }

    delete(input.bodies)
    delete(input.joints)
    delete(input.characters)
    input^ = {}
}

initial_state :: proc(built: ^ba.Built_Scene) -> State {
    value := State {
        character = built.characters[0].initial,
        joint     = built.joints[0].key,
    }
    // The bake sorts by stable keys; use the copied logical map rather than a
    // world slot or a raw native handle in canonical Side/Game.
    value.anchor = built.bodies[0].key
    value.actor_body = built.bodies[1].key
    return value
}

query_hash :: proc(hits: []b.Motion_Hit) -> u64 {
    hash := u64(0xcbf29ce484222325)

    for hit in hits {
        hash = (hash ~ u64(hit.shape)) * 0x100000001b3
        hash = (hash ~ u64(hit.body)) * 0x100000001b3
    }

    return hash
}

expect_cleanup :: proc(t: ^testing.T) {
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
        "checked Native, snapshot and both adapter ownership return to zero",
    )
}
