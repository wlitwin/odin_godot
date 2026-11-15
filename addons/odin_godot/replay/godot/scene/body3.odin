package replay_godot_scene

import "core:math"
import gd "godot:godot"
import own "godot:replay/owned"
import view "godot:replay/view"

Body3_Kind :: enum {
    Rigid,
    Character,
}

// Borrows scene nodes. Keep out of simulation state; dispose before freeing the
// nodes. Physics state is imposed through PhysicsServer, including frozen bodies.
Body3 :: struct {
    ready:                          bool,
    kind:                           Body3_Kind,
    body:                           gd.Physics_Body3d,
    skin:                           gd.Node3d,
    skin_origin:                    gd.Vector3,
    skin_rotation:                  gd.Quaternion,
    driver:                         own.Driver,
    latest:                         own.Sample(own.Pose3),
    frame_seen, fresh:              bool,
    physics_frame:                  u64,
    smoothing:                      view.Smoother3,
    preview:                        bool,
    preview_scope:                  own.Scope,
    preview_left, preview_cooldown: f64,
    local_owner:                    u16,
    live:                           bool,
}

body3_attach :: proc(p: ^Body3, body: gd.Physics_Body3d, kind: Body3_Kind, skin: gd.Node3d = nil) -> bool {
    if p.ready || body == nil {
        return false
    }

    p.body, p.kind, p.skin, p.ready = body, kind, skin, true

    if skin != nil {
        p.skin_origin = gd.node3d_get_position(skin)
        p.skin_rotation = gd.node3d_get_quaternion(skin)
    }

    if kind == .Rigid {
        gd.rigid_body3d_set_freeze_mode(cast(gd.Rigid_Body3d)body, .Freeze_Mode_Kinematic)
        gd.rigid_body3d_set_freeze_enabled(cast(gd.Rigid_Body3d)body, true)
    }

    return true
}

body3_destroy :: proc(p: ^Body3) {
    p^ = {}
}

body3_simulating :: proc(p: ^Body3) -> bool {
    return p.ready && (p.driver.role != .Observer || p.preview)
}

// No current authority frame: stop publication/solving without assigning a new
// epoch or tick to cached presentation state. A recovered epoch may start earlier.
body3_suspend :: proc(p: ^Body3, dt: f64 = 0) {
    if !p.ready {
        return
    }

    p.driver.role, p.preview, p.live, p.latest = .Observer, false, false, {}

    if p.kind == .Rigid {
        gd.rigid_body3d_set_freeze_enabled(cast(gd.Rigid_Body3d)p.body, true)
    }

    body3_present(p, dt)
}

body3_read :: proc(p: ^Body3) -> own.Pose3 {
    if !p.ready {
        return {}
    }

    server := gd.singleton_physics_server3d()
    rid := gd.collision_object3d_get_rid(cast(gd.Collision_Object3d)p.body)
    transform := gd.physics_server3d_body_get_state(server, rid, .Body_State_Transform)
    defer gd.variant_destroy(&transform)
    xf := gd.variant_to_transform3d(&transform)
    q := gd.basis_get_rotation_quaternion(&xf.basis)
    pose := own.Pose3 {
        position = xf.origin,
        rotation = transmute([4]f32)q,
    }

    if p.kind == .Rigid {
        linear := gd.physics_server3d_body_get_state(server, rid, .Body_State_Linear_Velocity)
        defer gd.variant_destroy(&linear)
        angular := gd.physics_server3d_body_get_state(server, rid, .Body_State_Angular_Velocity)
        defer gd.variant_destroy(&angular)
        sleeping := gd.physics_server3d_body_get_state(server, rid, .Body_State_Sleeping)
        defer gd.variant_destroy(&sleeping)
        pose.linear, pose.angular, pose.sleeping =
            gd.variant_to_vector3(&linear), gd.variant_to_vector3(&angular), gd.variant_to_bool(&sleeping)
    } else {
        pose.linear = gd.character_body3d_get_real_velocity(cast(gd.Character_Body3d)p.body)
    }

    return pose
}

body3_place :: proc(p: ^Body3, pose: own.Pose3, cut: bool = false) {
    if !p.ready {
        return
    }

    xf := gd.node3d_get_global_transform(cast(gd.Node3d)p.body)
    scale := gd.basis_get_scale(&xf.basis)
    q := view.quat_blend(pose.rotation, pose.rotation, 0)
    x, y, z, w := q[0], q[1], q[2], q[3]
    xf.basis = {
        {1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)},
        {2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)},
        {2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)},
    }

    for row in 0 ..< 3 {
        for column in 0 ..< 3 {
            xf.basis[row][column] *= scale[column]
        }
    }

    xf.origin = pose.position
    gd.node3d_set_global_transform(cast(gd.Node3d)p.body, xf)
    transform := gd.variant_from_transform3d(&xf)
    defer gd.variant_destroy(&transform)
    linear_value := gd.Vector3(pose.linear)
    linear := gd.variant_from_vector3(&linear_value)
    defer gd.variant_destroy(&linear)
    server := gd.singleton_physics_server3d()
    rid := gd.collision_object3d_get_rid(cast(gd.Collision_Object3d)p.body)
    gd.physics_server3d_body_set_state(server, rid, .Body_State_Transform, transform)
    gd.physics_server3d_body_set_state(server, rid, .Body_State_Linear_Velocity, linear)

    if p.kind == .Rigid {
        angular_value, sleeping_value := gd.Vector3(pose.angular), pose.sleeping
        angular := gd.variant_from_vector3(&angular_value)
        defer gd.variant_destroy(&angular)
        sleeping := gd.variant_from_bool(&sleeping_value)
        defer gd.variant_destroy(&sleeping)
        gd.physics_server3d_body_set_state(server, rid, .Body_State_Angular_Velocity, angular)
        gd.physics_server3d_body_set_state(server, rid, .Body_State_Sleeping, sleeping)
    } else {
        gd.character_body3d_set_velocity(cast(gd.Character_Body3d)p.body, linear_value)
    }

    if cut {
        gd.node_reset_physics_interpolation(cast(gd.Node)p.body)
    }
}

// Permission comes from the latest AUTHORITATIVE state. An optional older pose
// may interpolate observers only within the same object/revision/cut scope.
body3_sync :: proc(
    p: ^Body3,
    state: own.State(own.Pose3),
    local_owner: u16,
    epoch, tick: u64,
    live: bool,
    dt: f64,
    presentation: ^own.State(own.Pose3) = nil,
) -> own.Error {
    if !p.ready {
        return .Not_Ready
    }

    if dt < 0 || math.is_nan(dt) || math.is_inf(dt) {
        return .Invalid_Time
    }

    p.preview_cooldown = max(0, p.preview_cooldown - dt)
    p.local_owner, p.live = local_owner, live
    choice := own.drive(&p.driver, state, local_owner, epoch, tick, live)

    if choice.error != .None {
        p.driver.role, p.preview, p.live = .Observer, false, false

        if p.kind == .Rigid {
            gd.rigid_body3d_set_freeze_enabled(cast(gd.Rigid_Body3d)p.body, true)
        }

        return choice.error
    }

    keep_preview := false

    if p.preview {
        p.preview_left -= dt
        denied :=
            !live ||
            state.epoch != epoch ||
            own.scope(state) != p.preview_scope ||
            (state.pending.revision != 0 && state.pending.owner != local_owner) ||
            choice.cut ||
            p.preview_left <= 0
        keep_preview = choice.role == .Preparing && !denied

        if denied || choice.role != .Observer {
            p.preview = false

            if denied {
                p.preview_cooldown = 0.3
            }
        }
    }

    if p.kind == .Rigid {
        gd.rigid_body3d_set_freeze_enabled(cast(gd.Rigid_Body3d)p.body, !body3_simulating(p))
    }

    before := body3_visual_pose(p)

    if choice.reseed && !keep_preview {
        // Freeze is lifted before seeding; otherwise Godot can restore the old
        // solver pose when the new owner wakes the body.
        body3_place(p, choice.baseline, true)
        view.smooth3_correct_pose(
            &p.smoothing,
            {before.position, before.rotation},
            {choice.baseline.position, choice.baseline.rotation},
            discontinuity = choice.cut,
        )
    } else if choice.role == .Observer && !p.preview {
        pose := state.value

        if presentation != nil &&
           own.scope(presentation^) == own.scope(state) &&
           presentation.discontinuity == state.discontinuity {
            pose = presentation.value
        }

        body3_place(p, pose)
        jump :=
            abs(before.position[0] - pose.position[0]) +
            abs(before.position[1] - pose.position[1]) +
            abs(before.position[2] - pose.position[2])
        dot := f32(0)

        for value, i in before.rotation {
            dot += value * pose.rotation[i]
        }

        if jump >= 0.15 || abs(dot) <= math.cos(f32(0.06)) {
            view.smooth3_correct_pose(&p.smoothing, {before.position, before.rotation}, {pose.position, pose.rotation})
        }
    }

    if choice.reseed {
        p.fresh, p.latest, p.frame_seen = true, {}, false
    }

    if p.driver.role == .Observer {
        p.latest = {}
    }

    body3_present(p, dt)
    return .None
}

// Provisional possession is local-only until an authority offer arrives. The
// driver still forbids publication while this flag is the only permission.
body3_preview :: proc(p: ^Body3, state: own.State(own.Pose3), hold_seconds: f64 = 0.6) -> bool {
    if !p.ready ||
       !p.live ||
       p.local_owner == 0 ||
       p.kind != .Rigid ||
       body3_simulating(p) ||
       p.preview_cooldown > 0 ||
       hold_seconds <= 0 ||
       math.is_nan(hold_seconds) ||
       math.is_inf(hold_seconds) ||
       state.epoch != p.driver.epoch {
        return false
    }

    p.preview, p.preview_scope, p.preview_left = true, own.scope(state), hold_seconds
    gd.rigid_body3d_set_freeze_enabled(cast(gd.Rigid_Body3d)p.body, false)
    body3_place(p, state.value, true)
    return true
}

// Repeated render frames reuse the same immutable sample. This avoids losing
// the newest observation when the network and solver clocks do not coincide.
body3_sample :: proc(p: ^Body3, physics_frame: u64) -> (own.Sample(own.Pose3), own.Error) {
    if !p.ready {
        return {}, .Not_Ready
    }

    if p.driver.role == .Observer {
        return {}, .None
    }

    if p.frame_seen && physics_frame < p.physics_frame {
        return {}, .Invalid_Time
    }

    if p.frame_seen && physics_frame == p.physics_frame && !p.fresh {
        return p.latest, .None
    }

    steps := p.frame_seen ? physics_frame - p.physics_frame : 1
    sample, err := own.capture(&p.driver, body3_read(p), steps)

    if err != .None {
        return {}, err
    }

    p.physics_frame, p.frame_seen, p.fresh, p.latest = physics_frame, true, false, sample
    return sample, .None
}

@(private)
body3_present :: proc(p: ^Body3, dt: f64) {
    pose := body3_visual_pose(p)
    shown := view.smooth3_present(&p.smoothing, pose, dt, 0.063)

    if p.skin == nil {
        return
    }

    truth := transmute(gd.Quaternion)pose.rotation
    inverse := gd.quaternion_inverse(&truth)
    correction := gd.quaternion_multiply(inverse, transmute(gd.Quaternion)shown.rotation)
    local := gd.node3d_to_local(cast(gd.Node3d)p.body, shown.position)
    gd.node3d_set_position(p.skin, gd.quaternion_multiply(correction, p.skin_origin) + local)
    gd.node3d_set_quaternion(p.skin, gd.quaternion_multiply(correction, p.skin_rotation))
}

@(private)
body3_visual_pose :: proc(p: ^Body3) -> view.Pose3 {
    // Keep rendering relative to the node; PhysicsServer publication remains a
    // separate fixed-step read, including when an imposed kinematic pose is pending.
    transform := gd.node3d_get_global_transform(cast(gd.Node3d)p.body)
    return {transform.origin, transmute([4]f32)gd.basis_get_rotation_quaternion(&transform.basis)}
}
