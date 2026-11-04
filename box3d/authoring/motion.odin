package box3d_authoring

import "core:encoding/json"
import "core:math"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"

@(private)
schema_supported :: proc(version: u32) -> bool {
    return version == LEGACY_SCHEMA_VERSION || version == SCHEMA_VERSION
}

@(private)
scene_hash :: proc(data: Scene_Data) -> (bd.Digest, bool) {
    // Preserve the exact schema1 field order/representation. Appended motion
    // fields must not change a saved P5.1 scene's content identity.
    if data.schema_version == LEGACY_SCHEMA_VERSION {
        legacy := struct {
            schema_version: u32,
            namespace:      string,
            world:          b.World_Def,
            bodies:         []Baked_Body,
            shapes:         []Baked_Shape,
            assets:         []Baked_Asset,
            resources:      []Baked_Resource,
        }{data.schema_version, data.namespace, data.world, data.bodies, data.shapes, data.assets, data.resources}
        bytes, error := json.marshal(legacy)

        if error != nil {
            return {}, false
        }

        defer delete(bytes)
        return bd.hash_bytes(bytes), true
    }

    bytes, error := json.marshal(data)

    if error != nil {
        return {}, false
    }

    defer delete(bytes)
    return bd.hash_bytes(bytes), true
}

@(private)
nonnegative :: proc(value: f32) -> bool {
    return finite(value) && value >= 0
}

@(private)
motion_vector :: proc(v: b.Vec3) -> bool {
    return finite3({v.x, v.y, v.z}) && math.abs(v.x) <= 1e8 && math.abs(v.y) <= 1e8 && math.abs(v.z) <= 1e8
}

@(private)
axis_valid :: proc(axis: b.Motion_Joint_Axis) -> bool {
    return(
        (axis.flags &~ u32(7)) == 0 &&
        nonnegative(axis.hertz) &&
        nonnegative(axis.damping_ratio) &&
        finite(axis.target) &&
        finite(axis.lower) &&
        finite(axis.upper) &&
        axis.lower <= axis.upper &&
        finite(axis.motor_speed) &&
        nonnegative(axis.max_motor) \
    )
}

@(private)
axis_clean :: proc(axis: b.Motion_Joint_Axis) -> b.Motion_Joint_Axis {
    return {
        axis.flags,
        clean(axis.hertz),
        clean(axis.damping_ratio),
        clean(axis.target),
        clean(axis.lower),
        clean(axis.upper),
        clean(axis.motor_speed),
        clean(axis.max_motor),
    }
}

@(private)
body_id_for_key :: proc(scene: ^Baked_Scene, key: string) -> u64 {
    for body in scene.data.bodies {
        if body.stable_key == key {
            return body.logical_id
        }
    }

    return 0
}

@(private)
bake_joint :: proc(scene: ^Baked_Scene, input: Joint_Input) -> (Baked_Joint, Diagnostic) {
    result: Baked_Joint

    if !key_valid(input.stable_key) {
        return {}, fail(.Key, "joint.stable_key")
    }

    if !key_valid(input.body_a) || !key_valid(input.body_b) || input.body_a == input.body_b {
        return {}, fail(.Reference, "joint.body_a/body_b")
    }

    result.body_a_id = body_id_for_key(scene, input.body_a)
    result.body_b_id = body_id_for_key(scene, input.body_b)

    if result.body_a_id == 0 || result.body_b_id == 0 {
        return {}, fail(.Reference, "joint.body_a/body_b")
    }

    dynamic_or_kinematic := false

    for body in scene.data.bodies {
        if (body.logical_id == result.body_a_id || body.logical_id == result.body_b_id) &&
           body.definition.type != .Static {
            dynamic_or_kinematic = true
        }
    }

    if !dynamic_or_kinematic {
        return {}, fail(.Unsupported, "joint.two_static_bodies")
    }

    frame_a, aok := normalize_pose(input.local_frame_a)
    frame_b, bok := normalize_pose(input.local_frame_b)

    if !aok || !bok || !motion_vector(frame_a.position) || !motion_vector(frame_b.position) {
        return {}, fail(.Pose, "joint.local_frames")
    }

    for v in ([4]f32 {
            input.force_threshold,
            input.torque_threshold,
            input.constraint_hertz,
            input.constraint_damping_ratio,
        }) {
        if !nonnegative(v) {
            return {}, fail(.Dimension, "joint.constraint_settings")
        }
    }

    definition := b.Motion_Joint_Def {
        version                  = b.MOTION_VERSION,
        local_frame_a            = frame_a,
        local_frame_b            = frame_b,
        force_threshold          = clean(input.force_threshold),
        torque_threshold         = clean(input.torque_threshold),
        constraint_hertz         = clean(input.constraint_hertz),
        constraint_damping_ratio = clean(input.constraint_damping_ratio),
        collide_connected        = u32(input.collide_connected),
    }
    unused := b.Motion_Joint_Def {
        axis      = input.axis,
        distance  = input.distance,
        spherical = input.spherical,
        motor     = input.motor,
        weld      = input.weld,
        wheel     = input.wheel,
    }

    switch input.kind {
    case "hinge", "slider":
        if !axis_valid(input.axis) {
            return {}, fail(.Dimension, "joint.axis")
        }

        definition.kind = input.kind == "hinge" ? .Hinge : .Slider

        if definition.kind == .Hinge &&
           (input.axis.lower < -3.1101767 || input.axis.upper > 3.1101767 || math.abs(input.axis.target) > 3.1415927) {
            return {}, fail(.Dimension, "joint.hinge_angles")
        }

        definition.axis = axis_clean(input.axis)
        unused.axis = {}
    case "distance":
        s := input.distance

        if !axis_valid(s.axis) ||
           s.axis.target != 0 ||
           s.axis.lower < 0 ||
           !finite(s.length) ||
           s.length <= 0 ||
           !finite(s.lower_spring_force) ||
           !finite(s.upper_spring_force) ||
           s.lower_spring_force > s.upper_spring_force ||
           ((s.axis.flags & 6) != 0 && (s.axis.flags & 1) == 0) {
            return {}, fail(.Dimension, "joint.distance")
        }

        definition.kind = .Distance
        definition.distance = {
            axis_clean(s.axis),
            clean(s.length),
            clean(s.lower_spring_force),
            clean(s.upper_spring_force),
        }
        unused.distance = {}
    case "pin", "spherical":
        s := input.spherical

        if (s.flags &~ u32(15)) != 0 ||
           (input.kind == "pin" && s.flags != 0) ||
           !nonnegative(s.hertz) ||
           !nonnegative(s.damping_ratio) ||
           !nonnegative(s.max_motor_torque) ||
           !nonnegative(s.cone_angle) ||
           s.cone_angle > 1.5707964 ||
           !finite(s.lower_twist) ||
           !finite(s.upper_twist) ||
           s.lower_twist > s.upper_twist ||
           s.lower_twist < -3.1101767 ||
           s.upper_twist > 3.1101767 ||
           !motion_vector(s.motor_velocity) {
            return {}, fail(.Dimension, "joint.spherical")
        }

        rotation, rok := normalize_pose(
            {rotation = {s.target_rotation.x, s.target_rotation.y, s.target_rotation.z, s.target_rotation.w}},
        )

        if !rok {
            return {}, fail(.Pose, "joint.spherical.target_rotation")
        }

        definition.kind = input.kind == "pin" ? .Pin : .Spherical
        definition.spherical = {
            s.flags,
            clean(s.hertz),
            clean(s.damping_ratio),
            clean(s.cone_angle),
            clean(s.lower_twist),
            clean(s.upper_twist),
            clean(s.max_motor_torque),
            rotation.rotation,
            vector({s.motor_velocity.x, s.motor_velocity.y, s.motor_velocity.z}),
        }
        unused.spherical = {}
    case "motor":
        s := input.motor

        if !motion_vector(s.linear_velocity) || !motion_vector(s.angular_velocity) {
            return {}, fail(.Nonfinite, "joint.motor.velocities")
        }

        for v in ([8]f32 {
                s.max_velocity_force,
                s.max_velocity_torque,
                s.linear_hertz,
                s.linear_damping_ratio,
                s.angular_hertz,
                s.angular_damping_ratio,
                s.max_spring_force,
                s.max_spring_torque,
            }) {
            if !nonnegative(v) {
                return {}, fail(.Dimension, "joint.motor")
            }
        }

        definition.kind = .Motor
        definition.motor = {
            vector({s.linear_velocity.x, s.linear_velocity.y, s.linear_velocity.z}),
            vector({s.angular_velocity.x, s.angular_velocity.y, s.angular_velocity.z}),
            clean(s.max_velocity_force),
            clean(s.max_velocity_torque),
            clean(s.linear_hertz),
            clean(s.linear_damping_ratio),
            clean(s.angular_hertz),
            clean(s.angular_damping_ratio),
            clean(s.max_spring_force),
            clean(s.max_spring_torque),
        }
        unused.motor = {}
    case "weld":
        s := input.weld

        for v in ([4]f32{s.linear_hertz, s.angular_hertz, s.linear_damping_ratio, s.angular_damping_ratio}) {
            if !nonnegative(v) {
                return {}, fail(.Dimension, "joint.weld")
            }
        }

        definition.kind = .Weld
        definition.weld = {
            clean(s.linear_hertz),
            clean(s.angular_hertz),
            clean(s.linear_damping_ratio),
            clean(s.angular_damping_ratio),
        }
        unused.weld = {}
    case "wheel":
        s := input.wheel

        if (s.flags &~ u32(31)) != 0 ||
           !finite(s.lower_suspension) ||
           !finite(s.upper_suspension) ||
           s.lower_suspension > s.upper_suspension ||
           !finite(s.spin_speed) ||
           !finite(s.target_steering_angle) ||
           !finite(s.lower_steering) ||
           !finite(s.upper_steering) ||
           s.lower_steering > s.upper_steering {
            return {}, fail(.Dimension, "joint.wheel.limits")
        }

        for v in ([6]f32 {
                s.suspension_hertz,
                s.suspension_damping_ratio,
                s.max_spin_torque,
                s.steering_hertz,
                s.steering_damping_ratio,
                s.max_steering_torque,
            }) {
            if !nonnegative(v) {
                return {}, fail(.Dimension, "joint.wheel")
            }
        }

        definition.kind = .Wheel
        definition.wheel = {
            s.flags,
            clean(s.suspension_hertz),
            clean(s.suspension_damping_ratio),
            clean(s.lower_suspension),
            clean(s.upper_suspension),
            clean(s.max_spin_torque),
            clean(s.spin_speed),
            clean(s.steering_hertz),
            clean(s.steering_damping_ratio),
            clean(s.target_steering_angle),
            clean(s.max_steering_torque),
            clean(s.lower_steering),
            clean(s.upper_steering),
        }
        unused.wheel = {}
    case:
        return {}, fail(.Unsupported, "joint.kind")
    }

    if unused.axis != (b.Motion_Joint_Axis{}) ||
       unused.distance != (b.Motion_Joint_Distance{}) ||
       unused.spherical != (b.Motion_Joint_Spherical{}) ||
       unused.motor != (b.Motion_Joint_Motor{}) ||
       unused.weld != (b.Motion_Joint_Weld{}) ||
       unused.wheel != (b.Motion_Joint_Wheel{}) {
        return {}, fail(.Unsupported, "joint.unused_settings_must_be_zero")
    }

    result.logical_id = stable_id(scene.data.namespace, "joint", input.stable_key)
    result.definition = definition
    return result, {}
}

@(private)
bake_character :: proc(scene: ^Baked_Scene, input: Character_Input) -> (Baked_Character, Diagnostic) {
    if !key_valid(input.stable_key) {
        return {}, fail(.Key, "character.stable_key")
    }

    config := input.config

    if config.max_slides < 1 ||
       config.max_slides > 8 ||
       !finite3(config.capsule.center1) ||
       !finite3(config.capsule.center2) ||
       !finite(config.capsule.radius) ||
       config.capsule.radius <= 0 ||
       config.capsule.radius > 1e6 {
        return {}, fail(.Dimension, "character.capsule/slides")
    }

    if !finite3(config.up) || !finite(config.floor_cosine) || config.floor_cosine < 0 || config.floor_cosine > 1 {
        return {}, fail(.Dimension, "character.up/floor_cosine")
    }

    up := vector(config.up)
    norm := dot(up, up)

    if norm < 1e-20 {
        return {}, fail(.Dimension, "character.up")
    }

    inverse := 1 / math.sqrt(norm)
    up = vector({f32(f64(up.x) * inverse), f32(f64(up.y) * inverse), f32(f64(up.z) * inverse)})

    if !motion_vector(vector(config.capsule.center1)) ||
       !motion_vector(vector(config.capsule.center2)) ||
       !motion_vector(vector(input.initial.position)) ||
       !motion_vector(vector(input.initial.velocity)) {
        return {}, fail(.Nonfinite, "character.position/velocity/endpoints")
    }

    excluded: u64

    if input.exclude_body != "" {
        excluded = body_id_for_key(scene, input.exclude_body)

        if excluded == 0 {
            return {}, fail(.Reference, "character.exclude_body")
        }
    }

    result := Baked_Character {
        logical_id = stable_id(scene.data.namespace, "character", input.stable_key),
        exclude_body_id = excluded,
        config = {
            version = b.MOTION_VERSION,
            max_slides = config.max_slides,
            capsule = {vector(config.capsule.center1), vector(config.capsule.center2), clean(config.capsule.radius)},
            up = up,
            floor_cosine = clean(config.floor_cosine),
            filter = {
                category_bits = config.category_bits,
                mask_bits = config.mask_bits,
                include_sensors = u32(config.include_sensors),
            },
        },
        initial = {position = vector(input.initial.position), velocity = vector(input.initial.velocity)},
    }
    return result, {}
}

@(private)
bake_motion :: proc(scene: ^Baked_Scene, input: Scene_Input) -> Diagnostic {
    if len(input.joints) > MAX_JOINTS || len(input.characters) > MAX_CHARACTERS {
        return fail(.Capacity, "motion.counts")
    }

    if input.schema_version == LEGACY_SCHEMA_VERSION && (len(input.joints) != 0 || len(input.characters) != 0) {
        return fail(.Schema, "schema1.motion_not_supported")
    }

    ok := false
    scene.data.joints, ok = allocate(Baked_Joint, len(input.joints), scene.allocator)

    if !ok {
        return fail(.Allocation, "joints")
    }

    scene.data.characters, ok = allocate(Baked_Character, len(input.characters), scene.allocator)

    if !ok {
        return fail(.Allocation, "characters")
    }

    for joint, i in input.joints {
        for prior in input.joints[:i] {
            if joint.stable_key == prior.stable_key {
                return fail(.Duplicate, "joint.stable_key", element = i)
            }
        }

        baked, problem := bake_joint(scene, joint)

        if problem.error != .None {
            problem.element = i
            return problem
        }

        baked.stable_key, ok = copy_key(joint.stable_key, scene.allocator)

        if !ok {
            return fail(.Allocation, "joint.key", element = i)
        }

        scene.data.joints[i] = baked
    }

    for character, i in input.characters {
        for prior in input.characters[:i] {
            if character.stable_key == prior.stable_key {
                return fail(.Duplicate, "character.stable_key", element = i)
            }
        }

        baked, problem := bake_character(scene, character)

        if problem.error != .None {
            problem.element = i
            return problem
        }

        baked.stable_key, ok = copy_key(character.stable_key, scene.allocator)

        if !ok {
            return fail(.Allocation, "character.key", element = i)
        }

        scene.data.characters[i] = baked
    }

    for i in 1 ..< len(scene.data.joints) {
        j := i

        for j > 0 && scene.data.joints[j].stable_key < scene.data.joints[j - 1].stable_key {
            scene.data.joints[j], scene.data.joints[j - 1] = scene.data.joints[j - 1], scene.data.joints[j]
            j -= 1
        }
    }

    for i in 1 ..< len(scene.data.characters) {
        j := i

        for j > 0 && scene.data.characters[j].stable_key < scene.data.characters[j - 1].stable_key {
            scene.data.characters[j], scene.data.characters[j - 1] =
                scene.data.characters[j - 1], scene.data.characters[j]
            j -= 1
        }
    }

    return {}
}
