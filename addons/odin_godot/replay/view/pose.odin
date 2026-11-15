package replay_view

import "core:math"
import "core:math/linalg"

Pose2 :: struct {
    position: [2]f32,
    angle:    f32,
}

pose_blend :: proc(a, b: Pose2, alpha: f32, teleport: bool = false) -> Pose2 {
    if teleport {
        return b
    }

    t := clamp(alpha, 0, 1)
    return {a.position + (b.position - a.position) * t, a.angle + angle_delta(a.angle, b.angle) * t}
}

// Pure presentation state. Rebase on a changed prediction to preserve the
// visible pose; decaying the offset never writes to the simulation frame.
Smoother2 :: struct {
    shown:       Pose2,
    error:       [2]f32,
    angle_error: f32,
    initialized: bool,
}

smooth_rebase :: proc(s: ^Smoother2, truth: Pose2, cut: f32 = 48, angle_cut: f32 = math.PI / 2) {
    if !finite_pose2(truth) ||
       math.is_nan(cut) ||
       math.is_inf(cut) ||
       math.is_nan(angle_cut) ||
       math.is_inf(angle_cut) {
        return
    }

    if !s.initialized ||
       cut <= 0 ||
       angle_cut <= 0 ||
       linalg.length(s.shown.position - truth.position) > cut ||
       abs(angle_delta(truth.angle, s.shown.angle)) > angle_cut {
        s.shown = truth
        s.error, s.angle_error = {}, 0
        s.initialized = true
        return
    }

    s.error = s.shown.position - truth.position
    s.angle_error = angle_delta(truth.angle, s.shown.angle)
}

smooth_present :: proc(s: ^Smoother2, truth: Pose2, dt: f64, half_life: f64 = 0.08) -> Pose2 {
    if !finite_pose2(truth) ||
       dt < 0 ||
       math.is_nan(dt) ||
       math.is_inf(dt) ||
       math.is_nan(half_life) ||
       math.is_inf(half_life) {
        return s.shown
    }

    if !s.initialized {
        s.shown = truth
        s.initialized = true
    }

    if half_life <= 0 {
        s.error, s.angle_error = {}, 0
    } else {
        remaining := f32(math.pow(0.5, dt / half_life))
        s.error *= remaining
        s.angle_error *= remaining
    }

    s.shown = {truth.position + s.error, truth.angle + s.angle_error}
    return s.shown
}

// Feed positions from the SAME simulation tick before/after correction. Preserve
// the existing visual offset; ordinary movement between render frames still
// proceeds. A discontinuity or large correction explicitly cuts the glide.
smooth_correct :: proc(s: ^Smoother2, before, after: [2]f32, cut: f32 = 60, discontinuity: bool = false) {
    if !s.initialized {
        return
    }

    delta := before - after

    if discontinuity || cut <= 0 || linalg.length(delta) > cut {
        s.error, s.angle_error = {}, 0
        return
    }

    s.error += delta
}
