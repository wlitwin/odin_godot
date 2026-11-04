package replay_godot_scene

import "core:math"
import gd "godot:godot"
import own "godot:replay/owned"
import view "godot:replay/view"

Body2_Kind :: enum {
    Rigid,
    Character,
}

// Borrows scene nodes. Keep out of simulation state; dispose before freeing the
// nodes. Physics state is imposed through PhysicsServer, including frozen bodies.
Body2 :: struct {
    ready:                          bool,
    kind:                           Body2_Kind,
    body:                           gd.Physics_Body2d,
    skin:                           gd.Node2d,
    skin_origin:                    gd.Vector2,
    skin_angle:                     f32,
    driver:                         own.Driver,
    latest:                         own.Sample(own.Pose2),
    frame_seen, fresh:              bool,
    physics_frame:                  u64,
    smoothing:                      view.Smoother2,
    preview:                        bool,
    preview_scope:                  own.Scope,
    preview_left, preview_cooldown: f64,
    local_owner:                    u16,
    live:                           bool,
}

body2_attach :: proc(p: ^Body2, body: gd.Physics_Body2d, kind: Body2_Kind, skin: gd.Node2d = nil) -> bool {
    if p.ready || body == nil {
        return false
    }

    p.body, p.kind, p.skin, p.ready = body, kind, skin, true

    if skin != nil {
        p.skin_origin = gd.node2d_get_position(skin)
        p.skin_angle = f32(gd.node2d_get_rotation(skin))
    }

    if kind == .Rigid {
        gd.rigid_body2d_set_freeze_mode(cast(gd.Rigid_Body2d)body, .Freeze_Mode_Kinematic)
        gd.rigid_body2d_set_freeze_enabled(cast(gd.Rigid_Body2d)body, true)
    }

    return true
}

body2_destroy :: proc(p: ^Body2) {
    p^ = {}
}

body2_simulating :: proc(p: ^Body2) -> bool {
    return p.ready && (p.driver.role != .Observer || p.preview)
}

// No current authority frame: stop publication/solving without assigning a new
// epoch or tick to cached presentation state. A recovered epoch may start earlier.
body2_suspend :: proc(p: ^Body2, dt: f64 = 0) {
    if !p.ready {
        return
    }

    p.driver.role, p.preview, p.live, p.latest = .Observer, false, false, {}

    if p.kind == .Rigid {
        gd.rigid_body2d_set_freeze_enabled(cast(gd.Rigid_Body2d)p.body, true)
    }

    body2_present(p, dt)
}

body2_read :: proc(p: ^Body2) -> own.Pose2 {
    if !p.ready {
        return {}
    }

    server := gd.singleton_physics_server2d()
    rid := gd.collision_object2d_get_rid(cast(gd.Collision_Object2d)p.body)
    transform := gd.physics_server2d_body_get_state(server, rid, .Body_State_Transform)
    defer gd.variant_destroy(&transform)
    xf := gd.variant_to_transform2d(&transform)
    pose := own.Pose2 {
        position = {xf.origin.x, xf.origin.y},
        rotation = math.atan2(xf.x.y, xf.x.x),
    }

    if p.kind == .Rigid {
        linear := gd.physics_server2d_body_get_state(server, rid, .Body_State_Linear_Velocity)
        defer gd.variant_destroy(&linear)
        angular := gd.physics_server2d_body_get_state(server, rid, .Body_State_Angular_Velocity)
        defer gd.variant_destroy(&angular)
        sleeping := gd.physics_server2d_body_get_state(server, rid, .Body_State_Sleeping)
        defer gd.variant_destroy(&sleeping)
        v := gd.variant_to_vector2(&linear)
        pose.linear, pose.angular, pose.sleeping =
            {v.x, v.y}, f32(gd.variant_to_float(&angular)), gd.variant_to_bool(&sleeping)
    } else {
        v := gd.character_body2d_get_real_velocity(cast(gd.Character_Body2d)p.body)
        pose.linear = {v.x, v.y}
    }

    return pose
}

body2_place :: proc(p: ^Body2, pose: own.Pose2, cut: bool = false) {
    if !p.ready {
        return
    }

    gd.node2d_set_global_position(cast(gd.Node2d)p.body, {pose.position[0], pose.position[1]})
    gd.node2d_set_global_rotation(cast(gd.Node2d)p.body, gd.Float(pose.rotation))
    xf := gd.canvas_item_get_global_transform(cast(gd.Canvas_Item)p.body)
    transform := gd.variant_from_transform2d(&xf)
    defer gd.variant_destroy(&transform)
    linear_value := gd.Vector2{pose.linear[0], pose.linear[1]}
    linear := gd.variant_from_vector2(&linear_value)
    defer gd.variant_destroy(&linear)
    server := gd.singleton_physics_server2d()
    rid := gd.collision_object2d_get_rid(cast(gd.Collision_Object2d)p.body)
    gd.physics_server2d_body_set_state(server, rid, .Body_State_Transform, transform)
    gd.physics_server2d_body_set_state(server, rid, .Body_State_Linear_Velocity, linear)

    if p.kind == .Rigid {
        angular_value, sleeping_value := gd.Float(pose.angular), pose.sleeping
        angular := gd.variant_from_float(&angular_value)
        defer gd.variant_destroy(&angular)
        sleeping := gd.variant_from_bool(&sleeping_value)
        defer gd.variant_destroy(&sleeping)
        gd.physics_server2d_body_set_state(server, rid, .Body_State_Angular_Velocity, angular)
        gd.physics_server2d_body_set_state(server, rid, .Body_State_Sleeping, sleeping)
    } else {
        gd.character_body2d_set_velocity(cast(gd.Character_Body2d)p.body, linear_value)
    }

    if cut {
        gd.node_reset_physics_interpolation(cast(gd.Node)p.body)
    }
}

// Permission comes from the latest AUTHORITATIVE state. An optional older pose
// may interpolate observers only within the same object/revision/cut scope.
body2_sync :: proc(
    p: ^Body2,
    state: own.State(own.Pose2),
    local_owner: u16,
    epoch, tick: u64,
    live: bool,
    dt: f64,
    presentation: ^own.State(own.Pose2) = nil,
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
            gd.rigid_body2d_set_freeze_enabled(cast(gd.Rigid_Body2d)p.body, true)
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
        gd.rigid_body2d_set_freeze_enabled(cast(gd.Rigid_Body2d)p.body, !body2_simulating(p))
    }

    before := body2_visual_pose(p)

    if choice.reseed && !keep_preview {
        // Freeze is lifted before seeding; otherwise Godot can restore the old
        // solver pose when the new owner wakes the body.
        body2_place(p, choice.baseline, true)
        view.smooth_correct_pose(
            &p.smoothing,
            before,
            {choice.baseline.position, choice.baseline.rotation},
            cut = 90,
            discontinuity = choice.cut,
        )
    } else if choice.role == .Observer && !p.preview {
        pose := state.value

        if presentation != nil &&
           own.scope(presentation^) == own.scope(state) &&
           presentation.discontinuity == state.discontinuity {
            pose = presentation.value
        }

        body2_place(p, pose)
        jump := abs(before.position[0] - pose.position[0]) + abs(before.position[1] - pose.position[1])

        if jump >= 6 || abs(view.angle_delta(before.angle, pose.rotation)) >= 0.12 {
            view.smooth_correct_pose(&p.smoothing, before, {pose.position, pose.rotation}, cut = 90)
        }
    }

    if choice.reseed {
        p.fresh, p.latest, p.frame_seen = true, {}, false
    }

    if p.driver.role == .Observer {
        p.latest = {}
    }

    body2_present(p, dt)
    return .None
}

// Provisional possession is local-only until an authority offer arrives. The
// driver still forbids publication while this flag is the only permission.
body2_preview :: proc(p: ^Body2, state: own.State(own.Pose2), hold_seconds: f64 = 0.6) -> bool {
    if !p.ready ||
       !p.live ||
       p.local_owner == 0 ||
       p.kind != .Rigid ||
       body2_simulating(p) ||
       p.preview_cooldown > 0 ||
       hold_seconds <= 0 ||
       math.is_nan(hold_seconds) ||
       math.is_inf(hold_seconds) ||
       state.epoch != p.driver.epoch {
        return false
    }

    p.preview, p.preview_scope, p.preview_left = true, own.scope(state), hold_seconds
    gd.rigid_body2d_set_freeze_enabled(cast(gd.Rigid_Body2d)p.body, false)
    body2_place(p, state.value, true)
    return true
}

// Repeated render frames reuse the same immutable sample. This avoids losing
// the newest observation when the network and solver clocks do not coincide.
body2_sample :: proc(p: ^Body2, physics_frame: u64) -> (own.Sample(own.Pose2), own.Error) {
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
    sample, err := own.capture(&p.driver, body2_read(p), steps)

    if err != .None {
        return {}, err
    }

    p.physics_frame, p.frame_seen, p.fresh, p.latest = physics_frame, true, false, sample
    return sample, .None
}

@(private)
body2_present :: proc(p: ^Body2, dt: f64) {
    pose := body2_visual_pose(p)
    shown := view.smooth_present(&p.smoothing, pose, dt, 0.063)

    if p.skin == nil {
        return
    }

    delta_angle := view.angle_delta(pose.angle, shown.angle)
    c, s := math.cos(delta_angle), math.sin(delta_angle)
    offset := gd.Vector2{c * p.skin_origin.x - s * p.skin_origin.y, s * p.skin_origin.x + c * p.skin_origin.y}
    local := gd.node2d_to_local(cast(gd.Node2d)p.body, shown.position)
    gd.node2d_set_position(p.skin, offset + local)
    gd.node2d_set_rotation(p.skin, gd.Float(p.skin_angle + delta_angle))
}

@(private)
body2_visual_pose :: proc(p: ^Body2) -> view.Pose2 {
    // Frozen kinematic PhysicsServer transforms can lag a newly placed node until
    // the next physics step. Skin correction must use its actual parent transform;
    // publication continues to read the solver through body2_read.
    return {
        gd.node2d_get_global_position(cast(gd.Node2d)p.body),
        f32(gd.node2d_get_global_rotation(cast(gd.Node2d)p.body)),
    }
}
