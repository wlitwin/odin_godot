package box3d_authoring

import d "godot:box3d/debugdraw"
import p "godot:box3d/presentation"

// Authored shape outlines only, before any native construction or frame exists.
// It uses the same pure outline implementation as runtime drawing. Joint and
// character gizmos have their explicitly labeled authoring inputs separately.
// All count/validation work precedes output publication; no partial preview.
debug_preview :: proc(scene: ^Baked_Scene, segments: u32, out: []d.Line) -> (required: u32, error: d.Error) {
    if scene == nil {
        return 0, .Invalid
    }

    if problem := validate_ids(scene.data); problem.error != .None {
        return 0, .Invalid
    }

    hash, hashed := scene_hash(scene.data)

    if !hashed || hash != scene.content_hash {
        return 0, .Invalid
    }

    vertices: [d.MAX_VERTICES]d.Vec3

    for shape in scene.data.shapes {
        geometry, pose, color, ge := debug_preview_input(scene, shape, vertices[:])

        if ge != .None {
            return 0, ge
        }

        count, ce := d.preview_geometry(geometry, pose, color, segments, nil)

        if ce != .None && ce != .Capacity {
            return 0, ce
        }

        if count > d.MAX_LINES - required {
            return d.MAX_LINES + 1, .Capacity
        }

        required += count
    }

    if u64(len(out)) < u64(required) {
        return required, .Capacity
    }

    written: u32

    for shape in scene.data.shapes {
        geometry, pose, color, ge := debug_preview_input(scene, shape, vertices[:])

        if ge != .None {
            return 0, ge
        }

        count, ce := d.preview_geometry(geometry, pose, color, segments, out[written:])

        if ce != .None {
            return 0, ce
        }

        written += count
    }

    return required, .None
}

@(private)
debug_preview_input :: proc(
    scene: ^Baked_Scene,
    shape: Baked_Shape,
    vertices: []d.Vec3,
) -> (
    d.Geometry,
    p.Pose,
    d.Color,
    d.Error,
) {
    asset: ^Baked_Asset

    for &value in scene.data.assets {
        if value.catalog_id == shape.asset_id {
            asset = &value
            break
        }
    }

    if asset == nil {
        return {}, {}, {}, .Missing_Geometry
    }

    geometry, error := debug_asset_geometry(asset, vertices)

    if error != .None {
        return {}, {}, {}, error
    }

    pose: p.Pose
    found := false

    for body in scene.data.bodies {
        if body.logical_id == shape.body_id {
            value := body.definition.pose
            pose = {
                {value.position.x, value.position.y, value.position.z},
                {value.rotation.x, value.rotation.y, value.rotation.z, value.rotation.w},
            }
            found = true
            break
        }
    }

    if !found {
        return {}, {}, {}, .Missing_Body
    }

    color := d.Color{0.45, 0.7, 1, 1}

    if shape.definition.is_sensor != 0 {
        color = {0.2, 1, 0.4, 1}
    }

    return geometry, pose, color, .None
}

@(private)
debug_asset_geometry :: proc(asset: ^Baked_Asset, vertices: []d.Vec3) -> (d.Geometry, d.Error) {
    if len(asset.vertices) > len(vertices) || len(asset.indices) / 3 > d.MAX_TRIANGLES {
        return {}, .Capacity
    }

    geometry := d.Geometry {
        id       = asset.catalog_id,
        a        = {asset.a.x, asset.a.y, asset.a.z},
        b        = {asset.b.x, asset.b.y, asset.b.z},
        radius   = asset.radius,
        vertices = vertices[:len(asset.vertices)],
        indices  = asset.indices,
    }

    for point, index in asset.vertices {
        geometry.vertices[index] = {point.x, point.y, point.z}
    }

    switch asset.native_kind {
    case .Box:
        geometry.kind = .Box
    case .Sphere:
        geometry.kind = .Sphere
    case .Capsule:
        geometry.kind = .Capsule
    case .Hull:
        geometry.kind = .Hull
    case .Mesh:
        geometry.kind = .Mesh
    }

    return geometry, .None
}
