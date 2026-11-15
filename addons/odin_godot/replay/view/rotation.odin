package replay_view

import "core:math"

// Short signed rotation from before to after, in radians. Compute in f64 so
// finite f32 angles cannot overflow during subtraction.
angle_delta :: proc(before, after: f32) -> f32 {
    value := math.mod(f64(after) - f64(before) + math.PI, 2 * math.PI)

    if value < 0 {
        value += 2 * math.PI
    }

    return f32(value - math.PI)
}

@(private)
finite_pose2 :: proc(p: Pose2) -> bool {
    for value in p.position {
        if math.is_nan(value) || math.is_inf(value) {
            return false
        }
    }

    return !math.is_nan(p.angle) && !math.is_inf(p.angle)
}

@(private)
rotation_unit :: proc(value: [4]f32) -> (q: [4]f32, ok: bool) {
    norm: f64

    for v in value {
        if math.is_nan(v) || math.is_inf(v) {
            return
        }

        norm += f64(v) * f64(v)
    }

    if norm <= 0 {
        return
    }

    norm = math.sqrt(norm)

    for v, i in value {
        q[i] = f32(f64(v) / norm)
    }

    // Stable representative, including the exactly-180-degree sign tie.
    negative := q[3] < 0

    if q[3] == 0 {
        for v in q[:3] {
            if v != 0 {
                negative = v < 0
                break
            }
        }
    }

    if negative {
        q = -q
    }

    return q, true
}

@(private)
rotation_identity :: proc(q: [4]f32) -> [4]f32 {
    value, ok := rotation_unit(q)
    return ok ? value : [4]f32{0, 0, 0, 1}
}

@(private)
rotation_inverse :: proc(q: [4]f32) -> [4]f32 {
    return {-q[0], -q[1], -q[2], q[3]}
}

@(private)
rotation_product :: proc(a, b: [4]f32) -> [4]f32 {
    return {
        a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1],
        a[3] * b[1] - a[0] * b[2] + a[1] * b[3] + a[2] * b[0],
        a[3] * b[2] + a[0] * b[1] - a[1] * b[0] + a[2] * b[3],
        a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2],
    }
}

@(private)
rotation_decay :: proc(error: [4]f32, remaining: f32) -> [4]f32 {
    q := rotation_identity(error)
    sine := math.sqrt(f64(q[0]) * f64(q[0]) + f64(q[1]) * f64(q[1]) + f64(q[2]) * f64(q[2]))

    if sine == 0 || remaining <= 0 {
        return {0, 0, 0, 1}
    }

    angle := math.atan2(sine, f64(q[3])) * f64(remaining)
    scale := f32(math.sin(angle) / sine)
    return rotation_identity({q[0] * scale, q[1] * scale, q[2] * scale, f32(math.cos(angle))})
}

@(private)
finite_pose3 :: proc(p: Pose3) -> bool {
    for v in p.position {
        if math.is_nan(v) || math.is_inf(v) {
            return false
        }
    }

    _, valid := rotation_unit(p.rotation)
    return valid
}

// Same-tick before/after poses. Preserve existing visual error while normal
// future motion proceeds. Any explicit/large cut retires the complete pose error.
// Invalid inputs are transactional; false leaves the smoother unchanged.
smooth_correct_pose :: proc(
    s: ^Smoother2,
    before, after: Pose2,
    cut: f32 = 60,
    angle_cut: f32 = math.PI / 2,
    discontinuity: bool = false,
) -> bool {
    if !finite_pose2(before) ||
       !finite_pose2(after) ||
       math.is_nan(cut) ||
       math.is_inf(cut) ||
       math.is_nan(angle_cut) ||
       math.is_inf(angle_cut) {
        return false
    }

    if !s.initialized {
        return true
    }

    delta := before.position - after.position
    angle := angle_delta(after.angle, before.angle)

    if discontinuity ||
       cut <= 0 ||
       angle_cut <= 0 ||
       f64(delta[0]) * f64(delta[0]) + f64(delta[1]) * f64(delta[1]) > f64(cut) * f64(cut) ||
       abs(angle) > angle_cut {
        s.error, s.angle_error = {}, 0
        return true
    }

    s.error += delta
    s.angle_error = angle_delta(0, s.angle_error + angle)
    return true
}

smooth3_correct_pose :: proc(
    s: ^Smoother3,
    before, after: Pose3,
    cut: f32 = 2.25,
    angle_cut: f32 = math.PI / 2,
    discontinuity: bool = false,
) -> bool {
    if !finite_pose3(before) ||
       !finite_pose3(after) ||
       math.is_nan(cut) ||
       math.is_inf(cut) ||
       math.is_nan(angle_cut) ||
       math.is_inf(angle_cut) {
        return false
    }

    if !s.initialized {
        return true
    }

    a, _ := rotation_unit(before.rotation)
    b, _ := rotation_unit(after.rotation)
    delta := before.position - after.position
    distance: f64

    for v in delta {
        distance += f64(v) * f64(v)
    }

    error := rotation_identity(rotation_product(a, rotation_inverse(b)))
    angle := 2 * math.acos(clamp(error[3], 0, 1))

    if discontinuity || cut <= 0 || angle_cut <= 0 || distance > f64(cut) * f64(cut) || angle > angle_cut {
        s.error, s.rotation_error = {}, {}
        return true
    }

    s.error += delta
    // shown = old_error * before = new_error * after. Order matters in 3D.
    s.rotation_error = rotation_identity(rotation_product(rotation_identity(s.rotation_error), error))
    return true
}
