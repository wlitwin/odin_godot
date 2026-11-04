package kit_physics

import b "godot:box3d"
import sim "godot:kit/sim"

// These doors borrow only the actual staged execution world. A query's
// Capacity result is useful for sizing and does not poison the transaction.
motion_aabb :: proc(
    a: ^Instance($Side),
    lower, upper: b.Vec3,
    filter: b.Motion_Filter,
    out: []b.Motion_Hit,
) -> (
    u32,
    sim.World_Error,
) {
    w, error := world(a)

    if error != .Ok {
        return 0, error
    }

    count, status := b.query_aabb(w, lower, upper, filter, out)
    return count, map_status(status)
}

motion_ray :: proc(
    a: ^Instance($Side),
    origin, translation: b.Vec3,
    filter: b.Motion_Filter,
    out: []b.Motion_Hit,
) -> (
    u32,
    sim.World_Error,
) {
    w, error := world(a)

    if error != .Ok {
        return 0, error
    }

    count, status := b.query_ray_sorted(w, origin, translation, filter, out)
    return count, map_status(status)
}

motion_capsule :: proc(
    a: ^Instance($Side),
    origin: b.Vec3,
    capsule: b.Motion_Capsule,
    filter: b.Motion_Filter,
    out: []b.Motion_Hit,
) -> (
    u32,
    sim.World_Error,
) {
    w, error := world(a)

    if error != .Ok {
        return 0, error
    }

    count, status := b.query_capsule(w, origin, capsule, filter, out)
    return count, map_status(status)
}

motion_capsule_cast :: proc(
    a: ^Instance($Side),
    origin: b.Vec3,
    capsule: b.Motion_Capsule,
    translation: b.Vec3,
    filter: b.Motion_Filter,
    out: []b.Motion_Hit,
) -> (
    u32,
    sim.World_Error,
) {
    w, error := world(a)

    if error != .Ok {
        return 0, error
    }

    count, status := b.query_capsule_cast(w, origin, capsule, translation, filter, out)
    return count, map_status(status)
}

// The returned value belongs in Side. The node is never consulted here and
// this does not step the solver: Kit's participant remains its sole tick owner.
character_step :: proc(
    a: ^Instance($Side),
    config: b.Character_Config,
    value: b.Character_State,
) -> (
    b.Character_Result,
    sim.World_Error,
) {
    w, error := world(a)

    if error != .Ok {
        return {}, error
    }

    result, status := b.character_step(w, config, value, f32(1.0 / 60))

    if !require(a, status) {
        return {}, map_status(status)
    }

    return result, .Ok
}

motion_joint_create :: proc(a: ^Instance($Side), definition: b.Motion_Joint_Def) -> (b.Joint_Key, sim.World_Error) {
    w, error := world(a)

    if error != .Ok {
        return 0, error
    }

    key, status := b.motion_joint_create(w, definition)

    if !require(a, status) {
        return 0, map_status(status)
    }

    return key, .Ok
}

motion_joint_destroy :: proc(a: ^Instance($Side), key: b.Joint_Key) -> sim.World_Error {
    w, error := world(a)

    if error != .Ok {
        return error
    }

    joint, status := b.joint_resolve(w, key)

    if status == .Ok {
        status = b.joint_destroy(&joint)
    }

    if !require(a, status) {
        return map_status(status)
    }

    return .Ok
}
