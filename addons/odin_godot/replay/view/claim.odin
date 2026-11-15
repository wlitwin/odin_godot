package replay_view

import "core:math"

// Presentation only. A local influence starts a claim; its fast flight retains
// it even outside reach. A fast ball alone never claims itself for an idle peer.
Claim2 :: struct {
    active: bool,
    weight: f32,
}

claim_update :: proc(
    c: ^Claim2,
    influencing: bool,
    speed_sq: f32,
    dt: f64,
    release_speed: f32 = 0.6,
    fade_seconds: f64 = 0.25,
    retain_reset: bool = false,
) -> bool {
    if dt < 0 ||
       math.is_nan(dt) ||
       math.is_inf(dt) ||
       speed_sq < 0 ||
       math.is_nan(speed_sq) ||
       math.is_inf(speed_sq) ||
       release_speed < 0 ||
       math.is_nan(release_speed) ||
       math.is_inf(release_speed) ||
       math.is_nan(fade_seconds) ||
       math.is_inf(fade_seconds) {
        return false
    }

    if influencing || retain_reset {
        c.active = true
    } else if speed_sq <= release_speed * release_speed {
        c.active = false
    }

    if c.active {
        c.weight = 1
    } else {
        c.weight = fade_seconds <= 0 ? 0 : max(0, c.weight - f32(dt / fade_seconds))
    }

    return true
}

claim_pose :: proc(c: Claim2, observed, predicted: Pose2) -> Pose2 {
    return pose_blend(observed, predicted, c.weight)
}
