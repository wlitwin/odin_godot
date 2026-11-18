package main

import "core:encoding/json"
import "core:math"
import "core:mem"
import "core:os"
import "core:fmt"
import a "godot:box3d/authoring"
import b "godot:box3d/types"

same_pose :: proc(input: a.Pose_Input, actual: b.Pose) -> bool {
    p := [3]f32{actual.position.x, actual.position.y, actual.position.z}
    q := [4]f32{actual.rotation.x, actual.rotation.y, actual.rotation.z, actual.rotation.w}

    for value, i in p {
        if math.abs(value - input.position[i]) > 0.00001 {
            return false
        }
    }

    for value, i in q {
        if math.abs(value - input.rotation[i]) > 0.00001 {
            return false
        }
    }

    return true
}

main :: proc() {
    assert(len(os.args) == 2)
    bytes, error := os.read_entire_file(os.args[1], context.allocator)
    assert(error == nil)
    defer delete(bytes)
    scene, problem := a.parse_and_bake(bytes)
    assert(problem.error == .None, fmt.tprintf("%v %s", problem.error, problem.field))
    defer a.destroy(&scene)
    scratch := make([]u8, len(bytes) * 64 + 65536)
    defer delete(scratch)
    arena: mem.Arena
    mem.arena_init(&arena, scratch)
    input: a.Scene_Input
    assert(json.unmarshal(bytes, &input, allocator = mem.arena_allocator(&arena)) == nil)
    assert(len(scene.data.joints) == 2 && len(scene.data.bodies) == 4)

    for source in input.joints {
        found := false

        for joint in scene.data.joints {
            if source.stable_key != joint.stable_key {
                continue
            }

            assert(same_pose(source.local_frame_a, joint.definition.local_frame_a))
            assert(same_pose(source.local_frame_b, joint.definition.local_frame_b))
            assert(joint.body_a_id != 0 && joint.body_b_id != 0 && joint.body_a_id != joint.body_b_id)
            found = true
        }

        assert(found)
    }

    fmt.println("BOX3D_JOINT_BAKE_OK bodies=4 joints=2 frames_preserved=true")
}
