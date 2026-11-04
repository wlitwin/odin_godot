package replay_owned

import "core:math"

Pose2 :: struct {
    position: [2]f32,
    rotation: f32,
    linear:   [2]f32,
    angular:  f32,
    sleeping: bool,
}

Pose3 :: struct {
    position:        [3]f32,
    rotation:        [4]f32,
    linear, angular: [3]f32,
    sleeping:        bool,
}

Limits2 :: struct {
    minimum, maximum: [2]f32,
    speed, spin:      f32,
}

Limits3 :: struct {
    minimum, maximum: [3]f32,
    speed, spin:      f32,
}

finite :: proc(v: f32) -> bool {
    return !math.is_nan(v) && !math.is_inf(v)
}

pose2_valid :: proc(value: Pose2, limits: Limits2) -> bool {
    if !finite(value.rotation) ||
       !finite(value.angular) ||
       !finite(limits.speed) ||
       !finite(limits.spin) ||
       limits.speed < 0 ||
       limits.spin < 0 ||
       abs(value.angular) > limits.spin {
        return false
    }

    speed := f64(0)

    for position, i in value.position {
        if !finite(position) ||
           !finite(value.linear[i]) ||
           !finite(limits.minimum[i]) ||
           !finite(limits.maximum[i]) ||
           limits.minimum[i] > limits.maximum[i] ||
           position < limits.minimum[i] ||
           position > limits.maximum[i] {
            return false
        }

        speed += f64(value.linear[i]) * f64(value.linear[i])
    }

    return speed <= f64(limits.speed) * f64(limits.speed)
}

pose3_valid :: proc(value: Pose3, limits: Limits3) -> bool {
    if !finite(limits.speed) || !finite(limits.spin) || limits.speed < 0 || limits.spin < 0 {
        return false
    }

    speed, spin, rotation := f64(0), f64(0), f64(0)

    for position, i in value.position {
        if !finite(position) ||
           !finite(value.linear[i]) ||
           !finite(value.angular[i]) ||
           !finite(limits.minimum[i]) ||
           !finite(limits.maximum[i]) ||
           limits.minimum[i] > limits.maximum[i] ||
           position < limits.minimum[i] ||
           position > limits.maximum[i] {
            return false
        }

        speed += f64(value.linear[i]) * f64(value.linear[i])
        spin += f64(value.angular[i]) * f64(value.angular[i])
    }

    for q in value.rotation {
        if !finite(q) {
            return false
        }

        rotation += f64(q) * f64(q)
    }

    return(
        speed <= f64(limits.speed) * f64(limits.speed) &&
        spin <= f64(limits.spin) * f64(limits.spin) &&
        abs(rotation - 1) <= 0.001 \
    )
}
