package replay_view

import "core:math"
import "core:math/linalg"

Pose3 :: struct {
    position: [3]f32,
    rotation: [4]f32,
}

Smoother3 :: struct {
    shown:          Pose3,
    error:          [3]f32,
    rotation_error: [4]f32,
    initialized:    bool,
}

// Unit quaternions use x,y,z,w. Opposite signs represent the same rotation;
// choose a common hemisphere before blending and normalize the result.
quat_blend :: proc(a, b: [4]f32, alpha: f32) -> [4]f32 {
    other := b

    if linalg.dot(a, b) < 0 {
        other = -other
    }

    q := a + (other - a) * clamp(alpha, 0, 1)
    norm := linalg.length(q)

    if norm <= 0 || math.is_nan(norm) || math.is_inf(norm) {
        return {0, 0, 0, 1}
    }

    return q / norm
}

pose3_blend :: proc(a, b: Pose3, alpha: f32, cut: bool = false) -> Pose3 {
    if cut {
        return b
    }

    t := clamp(alpha, 0, 1)
    return {a.position + (b.position - a.position) * t, quat_blend(a.rotation, b.rotation, t)}
}

smooth3_present :: proc(s: ^Smoother3, truth: Pose3, dt: f64, half_life: f64 = 0.08) -> Pose3 {
    if !finite_pose3(truth) ||
       dt < 0 ||
       math.is_nan(dt) ||
       math.is_inf(dt) ||
       math.is_nan(half_life) ||
       math.is_inf(half_life) {
        return s.shown
    }

    if !s.initialized {
        s.shown, s.initialized = truth, true
    }

    if half_life <= 0 {
        s.error, s.rotation_error = {}, {}
    } else {
        remaining := f32(math.pow(0.5, dt / half_life))
        s.error *= remaining
        s.rotation_error = rotation_decay(s.rotation_error, remaining)
    }

    rotation := truth.rotation

    if s.rotation_error[0] != 0 || s.rotation_error[1] != 0 || s.rotation_error[2] != 0 {
        rotation = rotation_identity(rotation_product(s.rotation_error, rotation_identity(truth.rotation)))
    }

    s.shown = {truth.position + s.error, rotation}
    return s.shown
}

smooth3_correct :: proc(s: ^Smoother3, before, after: [3]f32, cut: f32 = 2.25, discontinuity: bool = false) {
    if !s.initialized {
        return
    }

    delta := before - after

    if discontinuity || cut <= 0 || linalg.length(delta) > cut {
        s.error, s.rotation_error = {}, {}
        return
    }

    s.error += delta
}
