package box3d_authoring_frameworks_test

import "core:fmt"
import ba "godot:box3d/authoring"

PROFILE :: u64(0x4155544846523031)

// The same authored values feed both existing adapters. No model/kernel copy.
scene_input :: proc() -> ba.Scene_Input {
    scene := ba.scene_input_default("box3d.authoring.frameworks.v1")
    scene.gravity = {0, 0, 0}
    scene.enable_sleep = false
    scene.bodies = make([]ba.Body_Input, 7)
    keys := [7]string{"box", "sphere", "capsule", "hull", "mesh", "heightfield", "sensor"}
    kinds := [7]string{"box", "sphere", "capsule", "hull", "mesh", "heightfield", "box"}

    for i in 0 ..< 7 {
        body := ba.body_input_default(keys[i])

        if i < 4 {
            body.body_type = "dynamic"
        }

        body.enable_sleep = false
        body.pose.position = {f32(i) * 3, 2, 0}

        if i >= 4 {
            body.pose.position.y = 0
        }

        if i == 0 {
            body.pose.position = {0, 0.3, 0}
        }

        if i == 4 {
            body.pose.position = {0, 0, 0}
        }

        body.shapes = make([]ba.Shape_Input, 1)
        shape := ba.shape_input_default(fmt.aprintf("asset.%s", keys[i]), kinds[i])
        shape.half_extents = {0.4, 0.4, 0.4}
        shape.radius = 0.35

        if i == 3 {
            shape.vertices = make([][3]f32, 4)
            shape.vertices[0] = {-0.5, -0.5, -0.5}
            shape.vertices[1] = {0.5, -0.5, 0.5}
            shape.vertices[2] = {-0.5, 0.5, 0.5}
            shape.vertices[3] = {0.5, 0.5, -0.5}
        }

        if i == 4 {
            shape.vertices = make([][3]f32, 4)
            shape.vertices[0] = {-1, 0, -1}
            shape.vertices[1] = {1, 0, -1}
            shape.vertices[2] = {1, 0, 1}
            shape.vertices[3] = {-1, 0, 1}
            shape.indices = make([]u32, 6)
            copy(shape.indices, []u32{0, 2, 1, 0, 3, 2})
        }

        if i == 5 {
            shape.columns = 3
            shape.rows = 3
            shape.spacing = {0.5, 0.5}
            shape.heights = make([]f32, 9)
            shape.heights[4] = 0.125
        }

        if i == 6 {
            body.sensor = true
            body.pose.position = {3, 2, 0}
            shape.half_extents = {0.75, 0.75, 0.75}
        }

        body.shapes[0] = shape
        scene.bodies[i] = body
    }

    return scene
}

scene_input_destroy :: proc(scene: ^ba.Scene_Input) {
    for body in scene.bodies {
        for shape in body.shapes {
            delete(shape.vertices)
            delete(shape.indices)
            delete(shape.heights)
            delete(shape.stable_key)
        }

        delete(body.shapes)
    }

    delete(scene.bodies)
    scene^ = {}
}
