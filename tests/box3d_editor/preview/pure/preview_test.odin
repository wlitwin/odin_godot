package editor_preview_test

import "core:encoding/json"
import "core:mem"
import "core:strings"
import "core:testing"
import a "godot:box3d/authoring"
import d "godot:box3d/debugdraw"

inspect :: proc(t: ^testing.T, request: a.Editor_Preview_Request, arena: ^mem.Arena) -> a.Editor_Preview_Result {
    encoded, error := json.marshal(request)
    testing.expect(t, error == nil)
    defer delete(encoded)
    reply := a.editor_preview_json(encoded)
    defer delete(reply)
    result: a.Editor_Preview_Result
    testing.expect(t, json.unmarshal(reply, &result, allocator = mem.arena_allocator(arena)) == nil)
    testing.expect_value(t, result.scope, a.EDITOR_PREVIEW_SCOPE)

    for forbidden in ([]string{"artifact_base64", "metadata", "content_hash", "id_hex"}) {
        testing.expect(
            t,
            !strings.contains(string(reply), forbidden),
            "preview cannot impersonate a baked artifact or identity result",
        )
    }

    return result
}

unit :: proc(kind: string, key := "shape") -> a.Editor_Preview_Shape {
    return {pose = a.IDENTITY_POSE, body_type = "static", shape = a.shape_input_default(key, kind)}
}

@(test)
invalid_shape_does_not_erase_neighbors_and_keys_do_not_gate_preview :: proc(t: ^testing.T) {
    scratch: [65536]u8
    arena: mem.Arena
    mem.arena_init(&arena, scratch[:])
    items := [3]a.Editor_Preview_Shape{unit("box", ""), unit("sphere"), unit("sphere", "")}
    items[1].shape.radius = -1
    result := inspect(t, {version = 1, max_lines = 1000, items = items[:]}, &arena)
    testing.expect(t, result.ok && !result.complete && result.omitted_items == 1)

    if !testing.expect(t, len(result.items) == 3) {
        return
    }

    testing.expect(t, result.items[0].available && !result.items[1].available && result.items[2].available)
    testing.expect_value(t, result.items[0].count, u32(12))
    testing.expect_value(t, result.items[2].start, u32(12))
    testing.expect(t, result.items[1].error == "Dimension" && result.items[1].field == "radius")
    testing.expect_value(t, items[0].shape.stable_key, "")
    testing.expect_value(t, items[2].shape.stable_key, "")
}

@(test)
whole_fragment_capacity_keeps_later_small_shapes :: proc(t: ^testing.T) {
    scratch: [65536]u8
    arena: mem.Arena
    mem.arena_init(&arena, scratch[:])
    items := [2]a.Editor_Preview_Shape{unit("sphere"), unit("box")}
    result := inspect(t, {version = 1, max_lines = 12, items = items[:]}, &arena)
    testing.expect(t, result.ok && !result.complete && result.capacity_exceeded)

    if !testing.expect(t, len(result.items) == 2) {
        return
    }

    testing.expect(t, !result.items[0].available && result.items[0].count == 0 && result.items[0].required > 12)
    testing.expect(t, result.items[1].available && result.items[1].start == 0 && result.items[1].count == 12)
    testing.expect_value(t, len(result.lines), 12)
}

@(test)
preview_matches_strict_geometry_but_does_not_weaken_strict_validation :: proc(t: ^testing.T) {
    scratch: [65536]u8
    arena: mem.Arena
    mem.arena_init(&arena, scratch[:])
    item := unit("box")
    item.pose.position = {3, 4, 5}
    item.shape.local_pose.position = {0.25, 0, 0}
    item.shape.scale = {1, 2, 3}
    items := [1]a.Editor_Preview_Shape{item}
    result := inspect(t, {version = 1, max_lines = 1000, items = items[:]}, &arena)
    testing.expect(t, result.ok && result.complete)
    body := a.body_input_default("body")
    body.pose = item.pose
    shapes := [1]a.Shape_Input{item.shape}
    body.shapes = shapes[:]
    bodies := [1]a.Body_Input{body}
    input := a.scene_input_default("strict")
    input.bodies = bodies[:]
    scene, error := a.bake(input)
    defer a.destroy(&scene)

    if !testing.expect(t, error.error == .None) {
        return
    }

    lines := make([]d.Line, len(result.lines))
    defer delete(lines)
    count, draw_error := a.debug_preview(&scene, 16, lines)
    testing.expect(t, draw_error == .None && int(count) == len(result.lines))
    testing.expect(t, mem.compare(mem.slice_to_bytes(lines), mem.slice_to_bytes(result.lines)) == 0)
    bodies[0].stable_key = ""
    invalid, failure := a.bake(input)
    defer a.destroy(&invalid)
    testing.expect(t, failure.error == .Key && len(invalid.data.bodies) == 0)
    canary := [1]d.Line{{a = {91, 92, 93}}}
    _, short := a.debug_preview(&scene, 16, canary[:])
    testing.expect(t, short == .Capacity && canary[0].a == ([3]f32{91, 92, 93}), "strict preview remains atomic")
}

@(test)
bad_pose_has_no_identity_fallback_and_malformed_requests_publish_nothing :: proc(t: ^testing.T) {
    scratch: [65536]u8
    arena: mem.Arena
    mem.arena_init(&arena, scratch[:])
    items := [2]a.Editor_Preview_Shape{unit("box"), unit("box")}
    items[0].pose.rotation = {}
    result := inspect(t, {version = 1, max_lines = 100, items = items[:]}, &arena)
    testing.expect(t, result.ok && result.omitted_items == 1 && len(result.lines) == 12)

    if testing.expect(t, len(result.items) == 2) {
        testing.expect_value(t, result.items[0].field, "body.pose")
    }

    for text in ([]string {
            "{",
            "{\"version\":2,\"max_lines\":12}",
            "[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[0]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]",
        }) {
        reply := a.editor_preview_json(transmute([]u8)text)
        defer delete(reply)
        bad: a.Editor_Preview_Result
        testing.expect(t, json.unmarshal(reply, &bad, allocator = mem.arena_allocator(&arena)) == nil)
        testing.expect(t, !bad.ok && len(bad.lines) == 0 && len(bad.items) == 0)
    }
}
