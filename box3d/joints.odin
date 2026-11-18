package box3d

import types "godot:box3d/types"

MOTION_VERSION :: types.MOTION_VERSION
MOTION_MAX_HITS :: 256
MOTION_MAX_PLANES :: 256

Motion_Joint_Kind :: types.Motion_Joint_Kind

Motion_Joint_Axis :: types.Motion_Joint_Axis

Motion_Joint_Distance :: types.Motion_Joint_Distance

Motion_Joint_Spherical :: types.Motion_Joint_Spherical

Motion_Joint_Motor :: types.Motion_Joint_Motor

Motion_Joint_Weld :: types.Motion_Joint_Weld

Motion_Joint_Wheel :: types.Motion_Joint_Wheel

// Body_Key is an execution-world allocation key, not an authored logical ID.
Motion_Joint_Def :: types.Motion_Joint_Def

Motion_Filter :: types.Motion_Filter

Motion_Capsule :: types.Motion_Capsule

Motion_Hit :: struct {
    shape:           Shape_Key,
    body:            Body_Key,
    point, normal:   Vec3,
    fraction:        f32,
    triangle, child: i32,
    reserved:        u32,
}

motion_joint_default :: proc(kind: Motion_Joint_Kind) -> (definition: Motion_Joint_Def, status: Status) {
    if status = motion_abi_check(); status != .Ok {
        return
    }

    if status = domain_access_check(); status != .Ok {
        return
    }

    status = raw_motion_joint_default(u32(kind), &definition)
    return
}

motion_joint_create :: proc(world: World, definition: Motion_Joint_Def) -> (key: Joint_Key, status: Status) {
    if status = motion_abi_check(); status != .Ok {
        return
    }

    if status = domain_access_check(); status != .Ok {
        return
    }

    definition := definition
    status = raw_motion_joint_create(world, &definition, &key)
    return
}

// Independently query every public C POD field/size/alignment before use.
motion_abi_check :: proc() -> Status {
    if status := abi_check(); status != .Ok {
        return status
    }

    checks := [?]struct {
        id, size, alignment: u32,
        offsets:             []uintptr,
    } {
        {
            1,
            u32(size_of(Motion_Joint_Axis)),
            u32(align_of(Motion_Joint_Axis)),
            []uintptr {
                offset_of(Motion_Joint_Axis, flags),
                offset_of(Motion_Joint_Axis, hertz),
                offset_of(Motion_Joint_Axis, damping_ratio),
                offset_of(Motion_Joint_Axis, target),
                offset_of(Motion_Joint_Axis, lower),
                offset_of(Motion_Joint_Axis, upper),
                offset_of(Motion_Joint_Axis, motor_speed),
                offset_of(Motion_Joint_Axis, max_motor),
            },
        },
        {
            2,
            u32(size_of(Motion_Joint_Distance)),
            u32(align_of(Motion_Joint_Distance)),
            []uintptr {
                offset_of(Motion_Joint_Distance, axis),
                offset_of(Motion_Joint_Distance, length),
                offset_of(Motion_Joint_Distance, lower_spring_force),
                offset_of(Motion_Joint_Distance, upper_spring_force),
            },
        },
        {
            3,
            u32(size_of(Motion_Joint_Spherical)),
            u32(align_of(Motion_Joint_Spherical)),
            []uintptr {
                offset_of(Motion_Joint_Spherical, flags),
                offset_of(Motion_Joint_Spherical, hertz),
                offset_of(Motion_Joint_Spherical, damping_ratio),
                offset_of(Motion_Joint_Spherical, cone_angle),
                offset_of(Motion_Joint_Spherical, lower_twist),
                offset_of(Motion_Joint_Spherical, upper_twist),
                offset_of(Motion_Joint_Spherical, max_motor_torque),
                offset_of(Motion_Joint_Spherical, target_rotation),
                offset_of(Motion_Joint_Spherical, motor_velocity),
            },
        },
        {
            4,
            u32(size_of(Motion_Joint_Motor)),
            u32(align_of(Motion_Joint_Motor)),
            []uintptr {
                offset_of(Motion_Joint_Motor, linear_velocity),
                offset_of(Motion_Joint_Motor, angular_velocity),
                offset_of(Motion_Joint_Motor, max_velocity_force),
                offset_of(Motion_Joint_Motor, max_velocity_torque),
                offset_of(Motion_Joint_Motor, linear_hertz),
                offset_of(Motion_Joint_Motor, linear_damping_ratio),
                offset_of(Motion_Joint_Motor, angular_hertz),
                offset_of(Motion_Joint_Motor, angular_damping_ratio),
                offset_of(Motion_Joint_Motor, max_spring_force),
                offset_of(Motion_Joint_Motor, max_spring_torque),
            },
        },
        {
            5,
            u32(size_of(Motion_Joint_Weld)),
            u32(align_of(Motion_Joint_Weld)),
            []uintptr {
                offset_of(Motion_Joint_Weld, linear_hertz),
                offset_of(Motion_Joint_Weld, angular_hertz),
                offset_of(Motion_Joint_Weld, linear_damping_ratio),
                offset_of(Motion_Joint_Weld, angular_damping_ratio),
            },
        },
        {
            6,
            u32(size_of(Motion_Joint_Wheel)),
            u32(align_of(Motion_Joint_Wheel)),
            []uintptr {
                offset_of(Motion_Joint_Wheel, flags),
                offset_of(Motion_Joint_Wheel, suspension_hertz),
                offset_of(Motion_Joint_Wheel, suspension_damping_ratio),
                offset_of(Motion_Joint_Wheel, lower_suspension),
                offset_of(Motion_Joint_Wheel, upper_suspension),
                offset_of(Motion_Joint_Wheel, max_spin_torque),
                offset_of(Motion_Joint_Wheel, spin_speed),
                offset_of(Motion_Joint_Wheel, steering_hertz),
                offset_of(Motion_Joint_Wheel, steering_damping_ratio),
                offset_of(Motion_Joint_Wheel, target_steering_angle),
                offset_of(Motion_Joint_Wheel, max_steering_torque),
                offset_of(Motion_Joint_Wheel, lower_steering),
                offset_of(Motion_Joint_Wheel, upper_steering),
            },
        },
        {
            7,
            u32(size_of(Motion_Joint_Def)),
            u32(align_of(Motion_Joint_Def)),
            []uintptr {
                offset_of(Motion_Joint_Def, version),
                offset_of(Motion_Joint_Def, kind),
                offset_of(Motion_Joint_Def, body_a),
                offset_of(Motion_Joint_Def, body_b),
                offset_of(Motion_Joint_Def, local_frame_a),
                offset_of(Motion_Joint_Def, local_frame_b),
                offset_of(Motion_Joint_Def, force_threshold),
                offset_of(Motion_Joint_Def, torque_threshold),
                offset_of(Motion_Joint_Def, constraint_hertz),
                offset_of(Motion_Joint_Def, constraint_damping_ratio),
                offset_of(Motion_Joint_Def, collide_connected),
                offset_of(Motion_Joint_Def, reserved),
                offset_of(Motion_Joint_Def, axis),
                offset_of(Motion_Joint_Def, distance),
                offset_of(Motion_Joint_Def, spherical),
                offset_of(Motion_Joint_Def, motor),
                offset_of(Motion_Joint_Def, weld),
                offset_of(Motion_Joint_Def, wheel),
            },
        },
        {
            8,
            u32(size_of(Motion_Filter)),
            u32(align_of(Motion_Filter)),
            []uintptr {
                offset_of(Motion_Filter, category_bits),
                offset_of(Motion_Filter, mask_bits),
                offset_of(Motion_Filter, exclude_body),
                offset_of(Motion_Filter, include_sensors),
                offset_of(Motion_Filter, reserved),
            },
        },
        {
            9,
            u32(size_of(Motion_Capsule)),
            u32(align_of(Motion_Capsule)),
            []uintptr {
                offset_of(Motion_Capsule, center1),
                offset_of(Motion_Capsule, center2),
                offset_of(Motion_Capsule, radius),
            },
        },
        {
            10,
            u32(size_of(Motion_Hit)),
            u32(align_of(Motion_Hit)),
            []uintptr {
                offset_of(Motion_Hit, shape),
                offset_of(Motion_Hit, body),
                offset_of(Motion_Hit, point),
                offset_of(Motion_Hit, normal),
                offset_of(Motion_Hit, fraction),
                offset_of(Motion_Hit, triangle),
                offset_of(Motion_Hit, child),
                offset_of(Motion_Hit, reserved),
            },
        },
        {
            11,
            u32(size_of(Character_Config)),
            u32(align_of(Character_Config)),
            []uintptr {
                offset_of(Character_Config, version),
                offset_of(Character_Config, max_slides),
                offset_of(Character_Config, capsule),
                offset_of(Character_Config, up),
                offset_of(Character_Config, floor_cosine),
                offset_of(Character_Config, filter),
            },
        },
        {
            12,
            u32(size_of(Character_State)),
            u32(align_of(Character_State)),
            []uintptr {
                offset_of(Character_State, position),
                offset_of(Character_State, velocity),
                offset_of(Character_State, ground_normal),
                offset_of(Character_State, ground_shape),
                offset_of(Character_State, grounded),
                offset_of(Character_State, reserved),
            },
        },
        {
            13,
            u32(size_of(Character_Result)),
            u32(align_of(Character_Result)),
            []uintptr {
                offset_of(Character_Result, state),
                offset_of(Character_Result, displacement),
                offset_of(Character_Result, iterations),
                offset_of(Character_Result, plane_count),
            },
        },
    }

    for check in checks {
        for expected, i in check.offsets {
            size, alignment, offset: u32
            status := raw_motion_layout(check.id, u32(i), &size, &alignment, &offset)

            if status != .Ok {
                return status
            }

            if size != check.size || alignment != check.alignment || uintptr(offset) != expected {
                return .Incompatible
            }
        }
    }

    return .Ok
}
