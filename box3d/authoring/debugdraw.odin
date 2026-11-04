package box3d_authoring

import "core:mem"
import d "godot:box3d/debugdraw"
import p "godot:box3d/presentation"

// Independent copied draw configuration. It borrows no bake, native world,
// catalog or runtime map. Assignment aliases this owner; destroy once.
Debug_Scene :: struct {
    scene:     d.Scene,
    allocator: mem.Allocator,
}

debug_scene_destroy :: proc(owner: ^Debug_Scene) {
    if owner == nil {
        return
    }

    for geometry in owner.scene.geometries {
        delete(geometry.vertices, owner.allocator)
        delete(geometry.indices, owner.allocator)
    }

    delete(owner.scene.geometries, owner.allocator)
    delete(owner.scene.bindings, owner.allocator)
    delete(owner.scene.joints, owner.allocator)
    delete(owner.scene.characters, owner.allocator)
    owner^ = {}
}

@(private)
debug_body_key :: proc(built: ^Built_Scene, id: u64) -> p.Body_Key {
    for body in built.bodies {
        if body.logical_id == id {
            return p.Body_Key(body.key)
        }
    }

    return 0
}

// A transferred built.world may already be zero: only its local maps are read.
// Character overlays intentionally come from current Game/Side, not an initial
// authored pose mislabeled as live state. Supply those to Scene.characters for
// the one generation call when needed.
debug_scene_create :: proc(
    scene: ^Baked_Scene,
    built: ^Built_Scene,
    allocator: mem.Allocator = context.allocator,
) -> (
    Debug_Scene,
    Diagnostic,
) {
    if scene == nil || built == nil {
        return {}, fail(.Reference, "debug.scene_maps")
    }

    if problem := validate_ids(scene.data); problem.error != .None {
        return {}, problem
    }

    hash, hashed := scene_hash(scene.data)

    if !hashed {
        return {}, fail(.Allocation, "debug.identity")
    }

    if hash != scene.content_hash || hash != built.content_hash {
        return {}, fail(.Corrupt, "debug.identity")
    }

    if len(scene.data.assets) > d.MAX_GEOMETRIES ||
       len(scene.data.shapes) > d.MAX_BINDINGS ||
       len(scene.data.joints) > d.MAX_JOINTS {
        return {}, fail(.Capacity, "debug.counts")
    }

    owner := Debug_Scene {
        allocator = allocator,
    }
    complete := false

    defer if !complete {
        debug_scene_destroy(&owner)
    }

    ok := false
    owner.scene.geometries, ok = allocate(d.Geometry, len(scene.data.assets), allocator)

    if !ok {
        return {}, fail(.Allocation, "debug.geometries")
    }

    owner.scene.bindings, ok = allocate(d.Binding, len(scene.data.shapes), allocator)

    if !ok {
        return {}, fail(.Allocation, "debug.bindings")
    }

    owner.scene.joints, ok = allocate(d.Joint, len(scene.data.joints), allocator)

    if !ok {
        return {}, fail(.Allocation, "debug.joints")
    }

    for asset, index in scene.data.assets {
        if len(asset.vertices) > d.MAX_VERTICES || len(asset.indices) / 3 > d.MAX_TRIANGLES {
            return {}, fail(.Capacity, "debug.geometry_preview")
        }

        geometry := &owner.scene.geometries[index]
        geometry.id = asset.catalog_id
        geometry.a = {asset.a.x, asset.a.y, asset.a.z}
        geometry.b = {asset.b.x, asset.b.y, asset.b.z}
        geometry.radius = asset.radius

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

        geometry.vertices, ok = allocate(d.Vec3, len(asset.vertices), allocator)

        if !ok {
            return {}, fail(.Allocation, "debug.vertices")
        }

        geometry.indices, ok = allocate(u32, len(asset.indices), allocator)

        if !ok {
            return {}, fail(.Allocation, "debug.indices")
        }

        for vertex, i in asset.vertices {
            geometry.vertices[i] = {vertex.x, vertex.y, vertex.z}
        }

        copy(geometry.indices, asset.indices)
    }

    for shape, index in scene.data.shapes {
        key := debug_body_key(built, shape.body_id)

        if key == 0 {
            return {}, fail(.Reference, "debug.shape_body")
        }

        color := d.Color{0.45, 0.7, 1, 1}

        if shape.definition.is_sensor != 0 {
            color = {0.2, 1, 0.4, 1}
        }

        owner.scene.bindings[index] = {
            id = shape.logical_id,
            body = key,
            geometry = shape.asset_id,
            local = {rotation = {0, 0, 0, 1}},
            color = color,
        }
    }

    for joint, index in scene.data.joints {
        value := &owner.scene.joints[index]
        value.id = joint.logical_id
        value.body_a = debug_body_key(built, joint.body_a_id)
        value.body_b = debug_body_key(built, joint.body_b_id)

        if value.body_a == 0 || value.body_b == 0 {
            return {}, fail(.Reference, "debug.joint_bodies")
        }

        definition := joint.definition
        value.local_a = {
            {
                definition.local_frame_a.position.x,
                definition.local_frame_a.position.y,
                definition.local_frame_a.position.z,
            },
            {
                definition.local_frame_a.rotation.x,
                definition.local_frame_a.rotation.y,
                definition.local_frame_a.rotation.z,
                definition.local_frame_a.rotation.w,
            },
        }
        value.local_b = {
            {
                definition.local_frame_b.position.x,
                definition.local_frame_b.position.y,
                definition.local_frame_b.position.z,
            },
            {
                definition.local_frame_b.rotation.x,
                definition.local_frame_b.rotation.y,
                definition.local_frame_b.rotation.z,
                definition.local_frame_b.rotation.w,
            },
        }
        value.color = {1, 0.7, 0.15, 1}

        switch definition.kind {
        case .Pin:
            value.kind = .Pin
        case .Hinge:
            value.kind = .Hinge
        case .Slider:
            value.kind = .Slider
        case .Spherical:
            value.kind = .Spherical
        case .Distance:
            value.kind = .Distance
        case .Motor:
            value.kind = .Motor
        case .Weld:
            value.kind = .Weld
        case .Wheel:
            value.kind = .Wheel
        }
    }

    complete = true
    return owner, {}
}

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

    if len(asset.vertices) > len(vertices) || len(asset.indices) / 3 > d.MAX_TRIANGLES {
        return {}, {}, {}, .Capacity
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
