package replay_play

import "core:math"

Hurtbox2 :: struct {
    id:       u64,
    position: [2]f32,
    radius:   f32,
    active:   bool,
}

// A changed lifetime is a discontinuity. Do not draw/query a new incarnation
// halfway between the dead body's old position and its new spawn.
hurtbox_blend :: proc(a, b: Hurtbox2, fraction: u16) -> Hurtbox2 {
    if a.id != b.id || a.active != b.active {
        return fraction == max(u16) ? b : a
    }

    result := a
    result.position = a.position + (b.position - a.position) * (f32(fraction) / 65535)
    return result
}

ray_aabb :: proc(origin, direction: [2]f32, box: Aabb2, limit: f32) -> f32 {
    lo, hi := f32(0), limit

    for axis in 0 ..< 2 {
        if abs(direction[axis]) < 1e-6 {
            if origin[axis] < box.min[axis] || origin[axis] > box.max[axis] {
                return limit
            }
        } else {
            a, b := (box.min[axis] - origin[axis]) / direction[axis], (box.max[axis] - origin[axis]) / direction[axis]

            if a > b {
                a, b = b, a
            }

            lo, hi = max(lo, a), min(hi, b)
        }
    }

    return hi < lo ? limit : lo
}

ray_circle :: proc(origin, direction, center: [2]f32, radius, limit: f32) -> f32 {
    d := center - origin
    projected := d[0] * direction[0] + d[1] * direction[1]

    if projected < 0 || projected > limit + radius {
        return limit
    }

    distance2 := d[0] * d[0] + d[1] * d[1] - projected * projected

    if distance2 > radius * radius {
        return limit
    }

    at := projected - math.sqrt(max(radius * radius - distance2, 0))
    return at < 0 || at > limit ? limit : at
}

circle_pushout :: proc(position: ^[2]f32, radius: f32, box: Aabb2) {
    p := position^

    if p[0] <= box.min[0] - radius ||
       p[0] >= box.max[0] + radius ||
       p[1] <= box.min[1] - radius ||
       p[1] >= box.max[1] + radius {
        return
    }

    left, right := p[0] - (box.min[0] - radius), box.max[0] + radius - p[0]
    top, bottom := p[1] - (box.min[1] - radius), box.max[1] + radius - p[1]
    minimum := min(left, right, top, bottom)

    if minimum == left {
        position[0] = box.min[0] - radius
    } else if minimum == right {
        position[0] = box.max[0] + radius
    } else if minimum == top {
        position[1] = box.min[1] - radius
    } else {
        position[1] = box.max[1] + radius
    }
}

// Tick-owned semantic identity; independent of which pool slot prediction used.
spawn_key :: proc(tick: u64, seat, ordinal: u8) -> (u64, bool) {
    if tick == 0 || tick > max(u64) >> 8 || seat == 0 || seat > 15 || ordinal > 15 {
        return 0, false
    }

    return tick << 8 | u64(seat) << 4 | u64(ordinal), true
}
