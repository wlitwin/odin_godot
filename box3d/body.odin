package box3d

body_def_default :: proc() -> (def: Body_Def) {
    require_abi()
    status := c_body_def_default(&def)

    if status != .Ok {
        panic("Box3D native default initialization failed")
    }

    return
}

shape_def_default :: proc() -> (def: Shape_Def) {
    require_abi()
    status := c_shape_def_default(&def)

    if status != .Ok {
        panic("Box3D native default initialization failed")
    }

    return
}

body_create :: proc(world: World, def: Body_Def) -> (body: Body, status: Status) {
    def := def
    status = c_body_create(world, &def, &body)
    return
}

body_destroy :: proc(body: ^Body) -> Status {
    if body == nil {
        return .Invalid_Argument
    }

    status := c_body_destroy(body^)

    if status == .Ok {
        body^ = 0
    }

    return status
}

body_valid :: proc(body: Body) -> (valid: bool, status: Status) {
    value: u32
    status = c_body_valid(body, &value)
    valid = value != 0
    return
}

// Native identity normalized independently of the host world slot. This remains
// an allocation identity, not a durable gameplay ID across alternative branches.
body_identity :: proc(body: Body) -> (index, generation: u32, status: Status) {
    status = c_body_identity(body, &index, &generation)
    return
}

// Retarget snapshot-era handles after cross-world restore. Native code rewrites
// the world component and validates the destination; restore stable game maps
// separately. The source need not remain valid in its original world.
body_retarget :: proc(world: World, source: Body) -> (body: Body, status: Status) {
    status = c_body_retarget(world, source, &body)
    return
}

shape_retarget :: proc(world: World, source: Shape) -> (shape: Shape, status: Status) {
    status = c_shape_retarget(world, source, &shape)
    return
}

joint_retarget :: proc(world: World, source: Joint) -> (joint: Joint, status: Status) {
    status = c_joint_retarget(world, source, &joint)
    return
}

body_get_pose :: proc(body: Body) -> (pose: Pose, status: Status) {
    status = c_body_get_pose(body, &pose)
    return
}

body_set_pose :: proc(body: Body, pose: Pose) -> Status {
    pose := pose
    return c_body_set_pose(body, &pose)
}

// Native type transition preserves the allocation identity and recomputes mass.
// The C boundary refuses non-static compound/height geometry before mutation.
body_set_type :: proc(body: Body, kind: Body_Type) -> Status {
    return c_body_set_type(body, kind)
}

body_get_velocity :: proc(body: Body) -> (linear, angular: Vec3, status: Status) {
    status = c_body_get_velocity(body, &linear, &angular)
    return
}

body_set_velocity :: proc(body: Body, linear, angular: Vec3) -> Status {
    linear := linear
    angular := angular
    return c_body_set_velocity(body, &linear, &angular)
}

// A nil world_point applies the impulse at the body's center of mass.
body_apply_impulse :: proc(body: Body, impulse: Vec3, world_point: ^Vec3 = nil, wake := true) -> Status {
    impulse := impulse
    return c_body_apply_impulse(body, &impulse, world_point, u32(wake))
}

body_apply_angular_impulse :: proc(body: Body, impulse: Vec3, wake := true) -> Status {
    impulse := impulse
    return c_body_apply_angular_impulse(body, &impulse, u32(wake))
}

body_set_awake :: proc(body: Body, awake: bool) -> Status {
    return c_body_set_awake(body, u32(awake))
}

body_get_awake :: proc(body: Body) -> (awake: bool, status: Status) {
    value: u32
    status = c_body_get_awake(body, &value)
    awake = value != 0
    return
}

body_get_mass :: proc(body: Body) -> (mass: f32, status: Status) {
    status = c_body_get_mass(body, &mass)
    return
}

// Geometry owns copied immutable inputs. After shape creation the caller can
// release this owner: the world retains a lease until destruction. Use bounded,
// predeclared assets; destroyed shape history also retains the world's lease.
Geometry :: struct {
    _handle: rawptr,
}

geometry_hull :: proc(points: []Vec3) -> (geometry: Geometry, status: Status) {
    if u64(len(points)) > u64(max(u32)) {
        return {}, .Capacity
    }

    status = c_geometry_hull(raw_data(points), u32(len(points)), &geometry._handle)
    return
}

// Indices are triangle triples, not bytes. Native code validates vertex indices.
geometry_mesh :: proc(vertices: []Vec3, indices: []u32) -> (geometry: Geometry, status: Status) {
    if len(indices) % 3 != 0 {
        return {}, .Invalid_Argument
    }

    if u64(len(vertices)) > u64(max(u32)) || u64(len(indices) / 3) > u64(max(u32)) {
        return {}, .Capacity
    }

    status = c_geometry_mesh(
        raw_data(vertices),
        u32(len(vertices)),
        raw_data(indices),
        u32(len(indices) / 3),
        &geometry._handle,
    )
    return
}

geometry_destroy :: proc(geometry: ^Geometry) -> Status {
    if geometry == nil {
        return .Invalid_Argument
    }

    if status := c_geometry_release(geometry._handle); status != .Ok {
        return status
    }

    geometry^ = {}
    return .Ok
}

geometry_is_empty :: proc(geometry: ^Geometry) -> bool {
    return geometry == nil || geometry._handle == nil
}

shape_box :: proc(body: Body, def: Shape_Def, half_extents: Vec3) -> (shape: Shape, status: Status) {
    def := def
    half_extents := half_extents
    status = c_shape_box(body, &def, &half_extents, &shape)
    return
}

shape_sphere :: proc(body: Body, def: Shape_Def, radius: f32, center: Vec3 = {}) -> (shape: Shape, status: Status) {
    def := def
    center := center
    status = c_shape_sphere(body, &def, &center, radius, &shape)
    return
}

shape_capsule :: proc(
    body: Body,
    def: Shape_Def,
    center_a, center_b: Vec3,
    radius: f32,
) -> (
    shape: Shape,
    status: Status,
) {
    def := def
    center_a := center_a
    center_b := center_b
    status = c_shape_capsule(body, &def, &center_a, &center_b, radius, &shape)
    return
}

shape_geometry :: proc(body: Body, def: Shape_Def, geometry: ^Geometry) -> (shape: Shape, status: Status) {
    def := def

    if geometry == nil || geometry._handle == nil {
        return 0, .Invalid_Argument
    }

    status = c_shape_geometry(body, &def, geometry._handle, &shape)
    return
}

shape_destroy :: proc(shape: ^Shape) -> Status {
    if shape == nil {
        return .Invalid_Argument
    }

    status := c_shape_destroy(shape^)

    if status == .Ok {
        shape^ = 0
    }

    return status
}

shape_valid :: proc(shape: Shape) -> (valid: bool, status: Status) {
    value: u32
    status = c_shape_valid(shape, &value)
    valid = value != 0
    return
}

shape_get_body :: proc(shape: Shape) -> (body: Body, status: Status) {
    status = c_shape_get_body(shape, &body)
    return
}

shape_get_aabb :: proc(shape: Shape) -> (lower, upper: Vec3, status: Status) {
    status = c_shape_get_aabb(shape, &lower, &upper)
    return
}

hinge_def_default :: proc() -> (def: Hinge_Def) {
    require_abi()
    status := c_hinge_def_default(&def)

    if status != .Ok {
        panic("Box3D native default initialization failed")
    }

    return
}

// The hinge axis is the local Z axis of each local frame.
joint_hinge_create :: proc(world: World, def: Hinge_Def) -> (joint: Joint, status: Status) {
    def := def
    status = c_joint_hinge_create(world, &def, &joint)
    return
}

joint_destroy :: proc(joint: ^Joint) -> Status {
    if joint == nil {
        return .Invalid_Argument
    }

    status := c_joint_destroy(joint^)

    if status == .Ok {
        joint^ = 0
    }

    return status
}

joint_valid :: proc(joint: Joint) -> (valid: bool, status: Status) {
    value: u32
    status = c_joint_valid(joint, &value)
    valid = value != 0
    return
}

joint_hinge_set_motor :: proc(joint: Joint, enabled: bool, speed, max_torque: f32) -> Status {
    return c_joint_hinge_set_motor(joint, u32(enabled), speed, max_torque)
}

joint_hinge_get_angle :: proc(joint: Joint) -> (angle: f32, status: Status) {
    status = c_joint_hinge_get_angle(joint, &angle)
    return
}

// Keys are world-independent native allocation identities, not durable game IDs.
body_key :: proc(body: Body) -> (key: Body_Key, status: Status) {
    status = c_body_get_key(body, &key)
    return
}

shape_key :: proc(shape: Shape) -> (key: Shape_Key, status: Status) {
    status = c_shape_get_key(shape, &key)
    return
}

joint_key :: proc(joint: Joint) -> (key: Joint_Key, status: Status) {
    status = c_joint_get_key(joint, &key)
    return
}

body_resolve :: proc(world: World, key: Body_Key) -> (body: Body, status: Status) {
    status = c_body_resolve(world, key, &body)
    return
}

shape_resolve :: proc(world: World, key: Shape_Key) -> (shape: Shape, status: Status) {
    status = c_shape_resolve(world, key, &shape)
    return
}

joint_resolve :: proc(world: World, key: Joint_Key) -> (joint: Joint, status: Status) {
    status = c_joint_resolve(world, key, &joint)
    return
}

// Structural decoding for copied sensor end IDs after destruction. This does
// not assert liveness; shape_resolve remains the checked execution boundary.
shape_key_from_handle :: proc(shape: Shape) -> (key: Shape_Key, status: Status) {
    status = c_shape_key_from_handle(shape, &key)
    return
}
