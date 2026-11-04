package replay_physics_abi1

import b "godot:box3d"
import r "godot:replay"

// Read-only queries use the exact world named by the current execution
// capability. Complete sorted copied results contain allocation keys only.
motion_aabb :: proc(
    capability: r.Execution,
    lower, upper: b.Vec3,
    filter: b.Motion_Filter,
    out: []b.Motion_Hit,
) -> (
    u32,
    r.Error,
) {
    work, error := working(capability)

    if error != .None {
        return 0, error
    }

    count, status := b.query_aabb(work.stage.world, lower, upper, filter, out)
    return count, status_error(status)
}

motion_ray :: proc(
    capability: r.Execution,
    origin, translation: b.Vec3,
    filter: b.Motion_Filter,
    out: []b.Motion_Hit,
) -> (
    u32,
    r.Error,
) {
    work, error := working(capability)

    if error != .None {
        return 0, error
    }

    count, status := b.query_ray_sorted(work.stage.world, origin, translation, filter, out)
    return count, status_error(status)
}

motion_capsule :: proc(
    capability: r.Execution,
    origin: b.Vec3,
    capsule: b.Motion_Capsule,
    filter: b.Motion_Filter,
    out: []b.Motion_Hit,
) -> (
    u32,
    r.Error,
) {
    work, error := working(capability)

    if error != .None {
        return 0, error
    }

    count, status := b.query_capsule(work.stage.world, origin, capsule, filter, out)
    return count, status_error(status)
}

motion_capsule_cast :: proc(
    capability: r.Execution,
    origin: b.Vec3,
    capsule: b.Motion_Capsule,
    translation: b.Vec3,
    filter: b.Motion_Filter,
    out: []b.Motion_Hit,
) -> (
    u32,
    r.Error,
) {
    work, error := working(capability)

    if error != .None {
        return 0, error
    }

    count, status := b.query_capsule_cast(work.stage.world, origin, capsule, translation, filter, out)
    return count, status_error(status)
}

// State is returned by value for rollback-owned Game. A failed movement cannot
// accidentally commit if a callback ignores its returned error.
character_step :: proc(
    capability: r.Execution,
    config: b.Character_Config,
    value: b.Character_State,
) -> (
    b.Character_Result,
    r.Error,
) {
    work, error := working(capability)

    if error != .None {
        return {}, error
    }

    result, status := b.character_step(work.stage.world, config, value, f32(1.0 / 60))

    if status != .Ok {
        return {}, r.execution_fail(capability, status_error(status))
    }

    return result, .None
}

motion_joint_create :: proc(capability: r.Execution, definition: b.Motion_Joint_Def) -> (b.Joint_Key, r.Error) {
    owner, owner_error := working(capability)

    if owner_error != .None {
        return 0, owner_error
    }

    if owner.commands.motion_joint_create != motion_joint_create {
        return owner.commands.motion_joint_create(capability, definition)
    }

    work, operation, error := command_begin(capability)

    if error != .None {
        return 0, error
    }

    defer operation_end(&operation)
    key, status := b.motion_joint_create(work.stage.world, definition)

    if error := command_finish(capability, work, operation, status); error != .None {
        return 0, error
    }

    return key, .None
}

motion_joint_destroy :: proc(capability: r.Execution, key: Joint_Key) -> r.Error {
    owner, owner_error := working(capability)

    if owner_error != .None {
        return owner_error
    }

    if owner.commands.motion_joint_destroy != motion_joint_destroy {
        return owner.commands.motion_joint_destroy(capability, key)
    }

    work, operation, error := command_begin(capability)

    if error != .None {
        return error
    }

    defer operation_end(&operation)
    joint, status := b.joint_resolve(work.stage.world, key)

    if status == .Ok {
        status = b.joint_destroy(&joint)
    }

    return command_finish(capability, work, operation, status)
}
