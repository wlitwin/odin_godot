package main

import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import a "godot:box3d/authoring"

body_id :: proc(scene: ^a.Baked_Scene, key: string) -> u64 {
    for body in scene.data.bodies {
        if body.stable_key == key {
            return body.logical_id
        }
    }

    return 0
}

load_scene :: proc(path: string) -> a.Baked_Scene {
    bytes, error := os.read_entire_file(path, context.allocator)
    assert(error == nil, path)
    defer delete(bytes)
    scene, problem := a.parse_and_bake(bytes)
    assert(problem.error == .None, fmt.tprintf("%s: %v %s", path, problem.error, problem.field))

    scratch := make([]u8, len(bytes) * 64 + 65536)
    defer delete(scratch)
    arena: mem.Arena
    mem.arena_init(&arena, scratch)
    input: a.Scene_Input
    assert(json.unmarshal(bytes, &input, allocator = mem.arena_allocator(&arena)) == nil)
    assert(len(input.bodies) == len(scene.data.bodies))
    assert(len(input.joints) == len(scene.data.joints))
    assert(len(input.characters) == len(scene.data.characters))
    ids := make(map[u64]bool)
    defer delete(ids)

    for body in scene.data.bodies {
        assert(body.logical_id != 0 && !ids[body.logical_id])
        ids[body.logical_id] = true
    }

    for shape in scene.data.shapes {
        assert(ids[shape.body_id], "every shape resolves its actual body")
        assert(shape.logical_id != 0 && !ids[shape.logical_id])
        ids[shape.logical_id] = true
    }

    for joint in input.joints {
        found := false

        for baked in scene.data.joints {
            if baked.stable_key == joint.stable_key {
                assert(baked.body_a_id == body_id(&scene, joint.body_a))
                assert(baked.body_b_id == body_id(&scene, joint.body_b))
                assert(baked.body_a_id != 0 && baked.body_b_id != 0)
                found = true
            }
        }

        assert(found)
    }

    for character in input.characters {
        found := false

        for baked in scene.data.characters {
            if baked.stable_key == character.stable_key {
                assert(baked.exclude_body_id == body_id(&scene, character.exclude_body))
                found = true
            }
        }

        assert(found)
    }

    assert(len(scene.data.assets) == 1, "equivalent sphere geometry remains one catalog asset")
    return scene
}

main :: proc() {
    assert(len(os.args) == 3, "expected before and after editor definition JSON paths")
    before := load_scene(os.args[1])
    defer a.destroy(&before)
    after := load_scene(os.args[2])
    defer a.destroy(&after)
    assert(len(before.data.bodies) == 3 && len(before.data.resources) == 1)
    assert(len(after.data.bodies) == 11 && len(after.data.shapes) == 12)
    assert(len(after.data.resources) == 6 && len(after.data.joints) == 6 && len(after.data.characters) == 2)
    unchanged := 0

    for body in before.data.bodies {
        if final := body_id(&after, body.stable_key); final != 0 {
            assert(final == body.logical_id, "unmodified authoring identities retain their baked IDs")
            unchanged += 1
        }
    }

    assert(unchanged == 2, "only the explicitly rekeyed original body changes its identity")
    fmt.println("BOX3D_IDENTITY_BAKE_OK bodies=11 shapes=12 assets=1 resources=6 joints=6 characters=2")
}
