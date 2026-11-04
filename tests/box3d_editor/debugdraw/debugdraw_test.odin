package box3d_debugdraw_test

import "core:testing"
import d "godot:box3d/debugdraw"
import p "godot:box3d/presentation"

IDENTITY :: p.Pose {
    rotation = {0, 0, 0, 1},
}
RED :: d.Color{1, 0, 0, 1}
GREEN :: d.Color{0, 1, 0, 1}
MARKER :: d.Line{{77, 78, 79}, {80, 81, 82}, {0.1, 0.2, 0.3, 0.4}}

frame :: proc() -> p.Frame {
    bindings := [2]p.Binding {
        {id = {1, 1}, body = 11, asset = 1, alive = true},
        {id = {2, 1}, body = 22, asset = 2, alive = true},
    }
    samples := [2]p.Body_Sample {
        {body = 11, pose = {{10, 0, 0}, {0, 0, 0.70710677, 0.70710677}}, awake = true},
        {body = 22, pose = {{-2, 3, 0}, {0, 0, 0, 1}}, awake = true},
    }
    value, error := p.frame_make(7, 42, 3, .Confirmed, bindings[:], samples[:])
    assert(error == .None)
    return value
}

close :: proc(a, b: d.Vec3) -> bool {
    for i in 0 ..< 3 {
        if abs(a[i] - b[i]) > 0.0001 {
            return false
        }
    }

    return true
}

unchanged :: proc(t: ^testing.T, lines: []d.Line) {
    for line in lines {
        testing.expect(t, line == MARKER, "failure leaves entire output buffer untouched")
    }
}

fill :: proc(lines: []d.Line) {
    for &line in lines {
        line = MARKER
    }
}

@(test)
actual_frame_body_and_local_rigid_transforms :: proc(t: ^testing.T) {
    f := frame()
    before := f
    geometries := [1]d.Geometry{{id = 1, kind = .Box, a = {1, 1, 1}}}
    bindings := [1]d.Binding{{id = 10, body = 11, geometry = 1, local = {{1, 0, 0}, {0, 0, 0, 1}}, color = RED}}
    scene := d.Scene {
        geometries = geometries[:],
        bindings   = bindings[:],
    }
    out: [12]d.Line
    batch, error := d.generate(&f, scene, {enabled = true, expected = d.stamp_of(&f)}, out[:])
    testing.expect(t, error == .None && batch.count == 12 && batch.required == 12 && batch.stamp == d.stamp_of(&f))
    testing.expect(
        t,
        close(out[0].a, {11, 0, -1}) && close(out[0].b, {11, 2, -1}) && out[0].color == RED,
        "body rotation and local translation both applied",
    )
    testing.expect(t, f == before, "copied frame is read-only")
    short: [11]d.Line
    fill(short[:])
    batch, error = d.generate(&f, scene, {enabled = true, expected = d.stamp_of(&f)}, short[:])
    testing.expect(t, error == .Capacity && batch.required == 12 && batch.count == 0)
    unchanged(t, short[:])
}

@(test)
sphere_and_arbitrary_axis_capsule_surface_lines :: proc(t: ^testing.T) {
    out: [256]d.Line
    required, error := d.preview_geometry(
        {id = 1, kind = .Sphere, a = {2, 0, 0}, radius = 1},
        IDENTITY,
        RED,
        16,
        out[:],
    )
    testing.expect(t, error == .None && required == 48)

    for line in out[:required] {
        for endpoint in ([2]d.Vec3{line.a, line.b}) {
            delta := endpoint - d.Vec3{2, 0, 0}
            testing.expect(t, abs(delta.x * delta.x + delta.y * delta.y + delta.z * delta.z - 1) < 0.0001)
        }
    }

    geometry := d.Geometry {
        id     = 1,
        kind   = .Capsule,
        a      = {-1, 0, 0},
        b      = {1, 0, 0},
        radius = 0.25,
    }
    required, error = d.preview_geometry(geometry, IDENTITY, GREEN, 16, out[:])
    testing.expect(t, error == .None && required == 68)

    for line in out[:required] {
        for endpoint in ([2]d.Vec3{line.a, line.b}) {
            x := max(f32(-1), min(f32(1), endpoint.x))
            delta := endpoint - d.Vec3{x, 0, 0}
            testing.expect(
                t,
                abs(delta.x * delta.x + delta.y * delta.y + delta.z * delta.z - 0.0625) < 0.0001,
                "every endpoint lies on actual capsule surface",
            )
        }
    }

    geometry.b = geometry.a
    required, error = d.preview_geometry(geometry, IDENTITY, GREEN, 16, out[:])
    testing.expect(t, error == .None && required == 48, "zero-length capsule becomes sphere outline")
}

@(test)
hull_tetra_cube_crease_topology_and_input_order :: proc(t: ^testing.T) {
    tetra := [4]d.Vec3{{0, 0, 0}, {1, 0, 0}, {0, 1, 0}, {0, 0, 1}}
    out: [64]d.Line
    count, error := d.preview_geometry({id = 1, kind = .Hull, vertices = tetra[:]}, IDENTITY, RED, 16, out[:])
    testing.expect(t, error == .None && count == 6)
    points := [10]d.Vec3 {
        {-1, -1, -1},
        {-1, -1, 1},
        {-1, 1, -1},
        {-1, 1, 1},
        {1, -1, -1},
        {1, -1, 1},
        {1, 1, -1},
        {1, 1, 1},
        {0, 0, 0},
        {1, 1, 1},
    }
    geometry := d.Geometry {
        id       = 1,
        kind     = .Hull,
        vertices = points[:],
    }
    count, error = d.preview_geometry(geometry, IDENTITY, RED, 16, out[:])
    testing.expect(t, error == .None && count == 12, "coplanar triangulation diagonals and interior points omitted")

    for line in out[:count] {
        delta := line.b - line.a
        testing.expect(t, abs(delta.x) + abs(delta.y) + abs(delta.z) == 2, "only actual cube crease edges")
    }

    reversed: [10]d.Vec3

    for value, i in points {
        reversed[len(points) - i - 1] = value
    }

    other: [64]d.Line
    geometry.vertices = reversed[:]
    n, e := d.preview_geometry(geometry, IDENTITY, RED, 16, other[:])
    testing.expect(t, e == .None && n == count)

    for line, i in out[:count] {
        testing.expect(t, line == other[i], "input order cannot change Hull wireframe")
    }

    coplanar := [4]d.Vec3{{0, 0, 0}, {1, 0, 0}, {0, 1, 0}, {1, 1, 0}}
    geometry.vertices = coplanar[:]
    fill(out[:])
    _, error = d.preview_geometry(geometry, IDENTITY, RED, 16, out[:])
    testing.expect(t, error == .Invalid)
    unchanged(t, out[:])
}

@(test)
mesh_and_baked_heightfield_no_hidden_geometry_or_partial_write :: proc(t: ^testing.T) {
    vertices := [4]d.Vec3{{-1, 0, -1}, {-1, 0.25, 1}, {1, 0.5, -1}, {1, 0.75, 1}}
    indices := [6]u32{0, 1, 2, 2, 1, 3}
    out: [6]d.Line
    geometry := d.Geometry {
        id       = 1,
        kind     = .Mesh,
        vertices = vertices[:],
        indices  = indices[:],
    }
    count, error := d.preview_geometry(geometry, {{3, 2, 1}, {0, 0, 0, 1}}, RED, 16, out[:])
    testing.expect(
        t,
        error == .None && count == 6 && out[0].a == (d.Vec3{2, 2, 0}) && out[0].b == (d.Vec3{2, 2.25, 2}),
        "baked Mesh uses all actual triangle positions",
    )
    fill(out[:])
    indices[5] = 4
    _, error = d.preview_geometry(geometry, IDENTITY, RED, 16, out[:])
    testing.expect(t, error == .Invalid)
    unchanged(t, out[:])
    indices[5] = 3
    indices[1] = 0
    _, error = d.preview_geometry(geometry, IDENTITY, RED, 16, out[:])
    testing.expect(t, error == .Invalid)
    unchanged(t, out[:])
}

@(test)
disabled_stale_invalid_missing_and_duplicate_are_atomic :: proc(t: ^testing.T) {
    f := frame()
    geometries := [1]d.Geometry{{id = 1, kind = .Box, a = {1, 1, 1}}}
    bindings := [2]d.Binding {
        {id = 10, body = 11, geometry = 1, local = IDENTITY, color = RED},
        {id = 20, body = 22, geometry = 1, local = IDENTITY, color = GREEN},
    }
    scene := d.Scene {
        geometries = geometries[:],
        bindings   = bindings[:1],
    }
    out: [64]d.Line
    fill(out[:])
    batch, error := d.generate(nil, {}, {}, out[:])
    testing.expect(t, error == .None && batch.count == 0 && batch.required == 0)
    unchanged(t, out[:])
    options := d.Options {
        enabled  = true,
        expected = d.stamp_of(&f),
    }
    options.expected.revision += 1
    batch, error = d.generate(&f, scene, options, out[:])
    testing.expect(t, error == .Stale && batch.count == 0)
    unchanged(t, out[:])
    options.expected = d.stamp_of(&f)
    options.expected.epoch += 1
    _, error = d.generate(&f, scene, options, out[:])
    testing.expect(t, error == .Stale)
    unchanged(t, out[:])
    options.expected = d.stamp_of(&f)
    options.expected.source = .Predicted
    _, error = d.generate(&f, scene, options, out[:])
    testing.expect(t, error == .Stale)
    unchanged(t, out[:])
    options.expected = d.stamp_of(&f)
    bindings[0].body = 99
    _, error = d.generate(&f, scene, options, out[:])
    testing.expect(t, error == .Missing_Body)
    unchanged(t, out[:])
    bindings[0].body = 11
    bindings[0].geometry = 2
    _, error = d.generate(&f, scene, options, out[:])
    testing.expect(t, error == .Missing_Geometry)
    unchanged(t, out[:])
    bindings[0].geometry = 1
    bindings[1].id = bindings[0].id
    scene.bindings = bindings[:]
    _, error = d.generate(&f, scene, options, out[:])
    testing.expect(t, error == .Duplicate)
    unchanged(t, out[:])
    scene.bindings = bindings[:1]
    f.rows[0].pose.rotation = {0, 0, 0, 0}
    _, error = d.generate(&f, scene, options, out[:])
    testing.expect(t, error == .Invalid)
    unchanged(t, out[:])
    f = frame()
    geometries[0].a.x = transmute(f32)u32(0x7fc00000)
    _, error = d.generate(&f, scene, options, out[:])
    testing.expect(t, error == .Invalid)
    unchanged(t, out[:])
    geometries[0].a.x = 1
    bindings[0].color.x = 2
    _, error = d.generate(&f, scene, options, out[:])
    testing.expect(t, error == .Invalid)
    unchanged(t, out[:])
}

@(test)
source_lifetime_and_revision_are_value_only :: proc(t: ^testing.T) {
    vertices := make([]d.Vec3, 3)
    vertices[0] = {0, 0, 0}
    vertices[1] = {1, 0, 0}
    vertices[2] = {0, 1, 0}
    indices := make([]u32, 3)
    indices[0] = 0
    indices[1] = 1
    indices[2] = 2
    f := frame()
    geometries := [1]d.Geometry{{id = 1, kind = .Mesh, vertices = vertices, indices = indices}}
    bindings := [1]d.Binding{{id = 10, body = 22, geometry = 1, local = IDENTITY, color = RED}}
    out: [3]d.Line
    batch, error := d.generate(
        &f,
        {geometries = geometries[:], bindings = bindings[:]},
        {enabled = true, expected = d.stamp_of(&f)},
        out[:],
    )
    testing.expect(t, error == .None && batch.count == 3)
    saved := out
    stamp := batch.stamp
    delete(vertices)
    delete(indices)
    geometries = {}
    bindings = {}
    f = {}
    testing.expect(
        t,
        out == saved && stamp == (d.Stamp{7, 42, 3, .Confirmed}),
        "lines and stamp survive all source buffers/frame release",
    )
}

@(test)
joint_and_character_overlays_use_copied_frames_and_world_state :: proc(t: ^testing.T) {
    f := frame()
    joints := [1]d.Joint {
        {id = 1, kind = .Distance, body_a = 11, body_b = 22, local_a = IDENTITY, local_b = IDENTITY, color = RED},
    }
    characters := [1]d.Character {
        {
            id = 2,
            pose = {{3, 4, 5}, {0, 0, 0, 1}},
            a = {0, 0, 0},
            b = {0, 1, 0},
            radius = 0.5,
            up = {0, 1, 0},
            ground_normal = {0, 1, 0},
            grounded = true,
            color = GREEN,
        },
    }
    out: [77]d.Line
    batch, error := d.generate(
        &f,
        {joints = joints[:], characters = characters[:]},
        {enabled = true, expected = d.stamp_of(&f)},
        out[:],
    )
    testing.expect(
        t,
        error == .None && batch.count == 77 && out[0].a == (d.Vec3{10, 0, 0}) && out[0].b == (d.Vec3{-2, 3, 0}),
        "joint uses real copied anchor transforms",
    )
    testing.expect(
        t,
        out[75].a == (d.Vec3{3, 4, 5}) && out[75].b == (d.Vec3{3, 5, 5}) && out[76] == out[75],
        "up/ground values are supplied world-space observations",
    )
}

@(test)
stable_binding_frame_order_and_preview_limits :: proc(t: ^testing.T) {
    f := frame()
    geometries := [1]d.Geometry{{id = 1, kind = .Box, a = {1, 1, 1}}}
    bindings := [2]d.Binding {
        {id = 20, body = 11, geometry = 1, local = IDENTITY, color = RED},
        {id = 10, body = 22, geometry = 1, local = IDENTITY, color = GREEN},
    }
    scene := d.Scene {
        geometries = geometries[:],
        bindings   = bindings[:],
    }
    a, b: [24]d.Line
    first, e := d.generate(&f, scene, {enabled = true, expected = d.stamp_of(&f)}, a[:])
    testing.expect(t, e == .None && first.count == 24)
    bindings[0], bindings[1] = bindings[1], bindings[0]
    f.rows[0], f.rows[1] = f.rows[1], f.rows[0]
    second, error := d.generate(&f, scene, {enabled = true, expected = d.stamp_of(&f)}, b[:])
    testing.expect(t, error == .None && first == second && a == b, "frame/map traversal order does not alter output")
    fill(b[:])
    _, error = d.generate(&f, scene, {enabled = true, expected = d.stamp_of(&f), segments = 9}, b[:])
    testing.expect(t, error == .Invalid)
    unchanged(t, b[:])
    vertices: [d.MAX_VERTICES + 1]d.Vec3
    _, error = d.preview_geometry({id = 1, kind = .Mesh, vertices = vertices[:]}, IDENTITY, RED, 16, b[:])
    testing.expect(t, error == .Capacity)
    unchanged(t, b[:])
    // Many valid triangles explicitly exceed only the preview line budget.
    tri := [3]d.Vec3{{0, 0, 0}, {1, 0, 0}, {0, 1, 0}}
    indices: [3 * d.MAX_TRIANGLES]u32

    for i in 0 ..< d.MAX_TRIANGLES {
        indices[3 * i] = 0
        indices[3 * i + 1] = 1
        indices[3 * i + 2] = 2
    }

    required, limit_error := d.preview_geometry(
        {id = 1, kind = .Mesh, vertices = tri[:], indices = indices[:]},
        IDENTITY,
        RED,
        16,
        b[:],
    )
    testing.expect(t, limit_error == .Capacity && required == d.MAX_LINES + 1)
    unchanged(t, b[:])
}
