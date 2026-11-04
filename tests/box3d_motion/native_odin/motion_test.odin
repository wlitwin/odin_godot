package box3d_motion_native_test

import "core:fmt"
import "core:mem"
import "core:testing"
import a "godot:box3d/authoring"
import b "godot:box3d"
import f "godot:tests/box3d_motion/pure"

PROFILE :: 0x4d4f54494f4e0001

ok :: proc(t: ^testing.T, status: b.Status, label: string) -> bool {
    testing.expect(t, status == .Ok, fmt.tprintf("%s status=%v", label, status))
    return status == .Ok
}

dump :: proc(t: ^testing.T, world: b.World) -> []u8 {
    size, status := b.world_dump(world, {})

    if !ok(t, status, "dump size") {
        return {}
    }

    bytes := make([]u8, int(size))
    _, status = b.world_dump(world, bytes)

    if !ok(t, status, "dump") {
        delete(bytes)
        return {}
    }

    return bytes
}

cleanup0 :: proc(t: ^testing.T) {
    engine, e := b.engine_allocation_stats()
    wrapper, w := b.snapshot_allocation_stats()
    testing.expect(t, e == .Ok && w == .Ok && engine.live_bytes == 0 && wrapper.live_bytes == 0)
    fmt.printf("MOTION_CLEANUP native=%d wrapper=%d\n", engine.live_bytes, wrapper.live_bytes)
}

joint_case :: proc(t: ^testing.T, kind: string) {
    input: f.Fixture
    f.fixture_init(&input, kind)
    // Exercise nondefault enabled settings, not just zero-initialized union arms.
    j := &input.joints[0]

    switch kind {
    case "hinge", "slider":
        j.axis = {
            flags         = 7,
            hertz         = 2,
            damping_ratio = 0.7,
            target        = 0.1,
            lower         = -0.4,
            upper         = 0.5,
            motor_speed   = 0.2,
            max_motor     = 2,
        }
    case "distance":
        j.distance = {
            axis = {
                flags = 7,
                hertz = 2,
                damping_ratio = 0.7,
                lower = 0.5,
                upper = 2,
                motor_speed = 0.2,
                max_motor = 2,
            },
            length = 1,
            lower_spring_force = -10,
            upper_spring_force = 10,
        }
    case "spherical":
        j.spherical = {
            flags            = 15,
            hertz            = 2,
            damping_ratio    = 0.7,
            cone_angle       = 0.4,
            lower_twist      = -0.3,
            upper_twist      = 0.3,
            max_motor_torque = 2,
            target_rotation  = {0, 0.04997917, 0, 0.99875026},
            motor_velocity   = {0.1, 0.2, 0.3},
        }
    case "motor":
        j.motor = {
            linear_velocity       = {0.2, 0, 0},
            angular_velocity      = {0, 0.1, 0},
            max_velocity_force    = 3,
            max_velocity_torque   = 3,
            linear_hertz          = 2,
            linear_damping_ratio  = 0.7,
            angular_hertz         = 2,
            angular_damping_ratio = 0.7,
            max_spring_force      = 3,
            max_spring_torque     = 3,
        }
    case "weld":
        j.weld = {2, 2, 0.7, 0.7}
    case "wheel":
        j.wheel = {
            flags                    = 31,
            suspension_hertz         = 2,
            suspension_damping_ratio = 0.7,
            lower_suspension         = -0.3,
            upper_suspension         = 0.4,
            max_spin_torque          = 3,
            spin_speed               = 0.2,
            steering_hertz           = 2,
            steering_damping_ratio   = 0.7,
            target_steering_angle    = 0.1,
            max_steering_torque      = 3,
            lower_steering           = -0.4,
            upper_steering           = 0.4,
        }
    }

    baked, p := a.bake(input.scene)
    defer a.destroy(&baked)

    if !f.valid(t, p) {
        return
    }

    built, pb := a.build(&baked, PROFILE)

    defer {
        ok(t, a.built_destroy(&built), "built drop")
        cleanup0(t)
    }

    if !f.valid(t, pb) {
        return
    }

    testing.expect(t, len(built.joints) == 1 && built.joints[0].key != 0)
    counts, cs := b.world_counters(built.world)

    if !ok(t, cs, "actual one joint") {
        return
    }

    testing.expect_value(t, counts.joint_count, u32(1))
    identity, is := b.recovery_catalog_identity(&built.catalog)

    if !ok(t, is, "catalog3 identity") {
        return
    }

    testing.expect_value(t, identity.recovery_format, u32(3))

    for _ in 0 ..< 3 {
        if !ok(t, b.world_step_fixed(built.world), "actual constrained step") {
            return
        }
    }

    original := dump(t, built.world)
    defer delete(original)
    snapshot, ss := b.snapshot_capture(built.world)

    if !ok(t, ss, "joint snapshot") {
        return
    }

    defer ok(t, b.snapshot_destroy(&snapshot), "snapshot drop")

    if !ok(t, b.world_step_fixed(built.world), "mutate step") ||
       !ok(t, b.snapshot_restore(built.world, &snapshot), "same-world restore") {
        return
    }

    restored := dump(t, built.world)
    defer delete(restored)
    testing.expect(t, mem.compare(original, restored) == 0)
    required, ws := b.recovery_write(&built.catalog, &snapshot, {})

    if !ok(t, ws, "canonical3 size") {
        return
    }

    wire := make([]u8, int(required))
    defer delete(wire)
    _, ws = b.recovery_write(&built.catalog, &snapshot, wire)

    if !ok(t, ws, "canonical3 write") {
        return
    }

    decoded, ds := b.recovery_read(&built.catalog, wire)

    if !ok(t, ds, "full joint import") {
        return
    }

    defer ok(t, b.snapshot_destroy(&decoded), "decoded drop")
    again := make([]u8, len(wire))
    defer delete(again)
    _, ws = b.recovery_write(&built.catalog, &decoded, again)

    if !ok(t, ws, "joint canonical reencode") {
        return
    }

    testing.expect(t, mem.compare(wire, again) == 0)
    scratch, sc := b.world_create(b.world_def_default())

    if !ok(t, sc, "scratch world") {
        return
    }

    defer ok(t, b.world_destroy(&scratch), "scratch drop")

    if !ok(t, b.snapshot_restore(scratch, &decoded), "scratch full solver restore") {
        return
    }

    copied := dump(t, scratch)
    defer delete(copied)
    testing.expect(t, mem.compare(original, copied) == 0, "all settings/impulses/native joint state preserved")
    rejected, rs := b.recovery_read(&built.catalog, wire[:len(wire) - 1])
    testing.expect(t, rs != .Ok && b.snapshot_is_empty(&rejected))
    fmt.printf(
        "MOTION_JOINT kind=%s joint_key=%d format=%d full_dump_equal=true bytes=%d\n",
        kind,
        built.joints[0].key,
        identity.recovery_format,
        len(wire),
    )
}

@(test)
all_eight_native_constraints_roundtrip_separately_with_one_joint_cap :: proc(t: ^testing.T) {
    if !ok(t, b.motion_abi_check(), "all13 C/Odin motion layouts") {
        return
    }

    for kind in f.KINDS {
        joint_case(t, kind)
    }
}

@(test)
complete_sorted_actual_queries_filter_self_exclusion_and_capacity :: proc(t: ^testing.T) {
    input: f.Fixture
    f.fixture_init(&input)
    baked, p := a.bake(input.scene)
    defer a.destroy(&baked)

    if !f.valid(t, p) {
        return
    }

    built, pb := a.build(&baked, PROFILE)

    defer {
        ok(t, a.built_destroy(&built), "built drop")
        cleanup0(t)
    }

    if !f.valid(t, pb) {
        return
    }

    before := dump(t, built.world)
    defer delete(before)
    lo, hi := b.Vec3{-8, -8, -8}, b.Vec3{8, 8, 8}
    filter := b.MOTION_FILTER_ALL
    count, s := b.query_aabb(built.world, lo, hi, filter, {})
    testing.expect(t, s == .Capacity && count == 3)
    hits: [b.MOTION_MAX_HITS]b.Motion_Hit
    count, s = b.query_aabb(built.world, lo, hi, filter, hits[:])

    if !ok(t, s, "complete sorted AABB") {
        return
    }

    testing.expect_value(t, count, u32(3))

    for i in 1 ..< int(count) {
        testing.expect(t, hits[i - 1].shape < hits[i].shape)
    }

    short := [1]b.Motion_Hit{{shape = b.Shape_Key(0xffff), body = b.Body_Key(0xffff)}}
    old := short
    count, s = b.query_aabb(built.world, lo, hi, filter, short[:])
    testing.expect(t, s == .Capacity && count == 3 && short == old, "no arbitrary truncated prefix on Capacity")
    filter.exclude_body = built.characters[0].config.filter.exclude_body
    count, s = b.query_aabb(built.world, lo, hi, filter, hits[:])

    if !ok(t, s, "self-excluded AABB") {
        return
    }

    testing.expect_value(t, count, u32(2))
    count, s = b.query_ray_sorted(built.world, {0, 5, 0}, {0, -10, 0}, b.MOTION_FILTER_ALL, hits[:])

    if !ok(t, s, "actual ray") {
        return
    }

    testing.expect(t, count > 0)

    for i in 1 ..< int(count) {
        testing.expect(
            t,
            hits[i - 1].fraction < hits[i].fraction ||
            (hits[i - 1].fraction == hits[i].fraction && hits[i - 1].shape <= hits[i].shape),
        )
    }

    capsule := b.Motion_Capsule{{0, -0.2, 0}, {0, 0.2, 0}, 0.3}
    count, s = b.query_capsule(built.world, {2, 1, 0}, capsule, b.MOTION_FILTER_ALL, hits[:])

    if !ok(t, s, "actual capsule overlap") {
        return
    }

    testing.expect(t, count > 0)
    count, s = b.query_capsule_cast(built.world, {0, 3, 0}, capsule, {0, -5, 0}, b.MOTION_FILTER_ALL, hits[:])

    if !ok(t, s, "actual capsule cast") {
        return
    }

    testing.expect(t, count > 0)
    after := dump(t, built.world)
    defer delete(after)
    testing.expect(t, mem.compare(before, after) == 0, "all queries are world-read-only")
}

@(test)
actual_capsule_mover_floor_wall_slide_explicit_pod_and_zero_invalid_dt :: proc(t: ^testing.T) {
    input: f.Fixture
    f.fixture_init(&input)
    baked, p := a.bake(input.scene)
    defer a.destroy(&baked)

    if !f.valid(t, p) {
        return
    }

    built, pb := a.build(&baked, PROFILE)

    defer {
        ok(t, a.built_destroy(&built), "built drop")
        cleanup0(t)
    }

    if !f.valid(t, pb) {
        return
    }

    character := built.characters[0]
    state := character.initial
    original := state
    zero, zs := b.character_step(built.world, character.config, state, 0)

    if !ok(t, zs, "dt0") {
        return
    }

    testing.expect(t, zero.state == state && zero.displacement == (b.Vec3{}) && zero.iterations == 0)
    _, invalid := b.character_step(built.world, character.config, state, 0.1)
    testing.expect(t, invalid != .Ok && state == original)
    before := dump(t, built.world)
    defer delete(before)
    grounded := false

    for _ in 0 ..< 120 {
        next, s := b.character_step(built.world, character.config, state, b.FIXED_SECONDS)

        if !ok(t, s, "actual fixed-dt engine mover") {
            return
        }

        testing.expect(t, next.iterations <= character.config.max_slides && next.plane_count <= b.MOTION_MAX_PLANES)
        state = next.state
        grounded = grounded || state.grounded != 0
    }

    testing.expect(
        t,
        grounded &&
        state.ground_shape != 0 &&
        state.position.z > 0.5 &&
        state.position.x < 1.8 &&
        state.position.y >= -0.01,
        "actual floor classification and wall sliding",
    )
    after := dump(t, built.world)
    defer delete(after)
    testing.expect(
        t,
        mem.compare(before, after) == 0,
        "character output changes only caller-owned POD, no body step/mutation",
    )
    fmt.printf(
        "MOTION_CHARACTER x=%f y=%f z=%f grounded=%d floor=%d\n",
        state.position.x,
        state.position.y,
        state.position.z,
        state.grounded,
        state.ground_shape,
    )
}
