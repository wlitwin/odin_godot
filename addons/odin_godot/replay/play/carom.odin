package replay_play

import "core:math"

Carom2 :: struct {
    position, velocity: [2]f32,
}

Face2 :: struct {
    time:   f32,
    normal: [2]f32,
    hit:    bool,
}

// Nearest strict entry before limit. An origin already inside a box can leave
// it. The normal belongs to the later entering slab; axis order resolves ties.
first_face2 :: proc(origin, velocity: [2]f32, limit: f32, boxes: []Aabb2) -> Face2 {
    result := Face2 {
        time = limit,
    }

    for box in boxes {
        near, far := f32(0), result.time
        normal: [2]f32
        ok := true

        for axis in 0 ..< 2 {
            if velocity[axis] == 0 {
                if origin[axis] < box.min[axis] || origin[axis] > box.max[axis] {
                    ok = false
                }

                continue
            }

            a, b := (box.min[axis] - origin[axis]) / velocity[axis], (box.max[axis] - origin[axis]) / velocity[axis]
            n := f32(-1)

            if a > b {
                a, b = b, a
                n = 1
            }

            if a > near {
                near = a
                normal = {}
                normal[axis] = n
            }

            far = min(far, b)
        }

        if ok && near < far && near > 0 && near < result.time {
            result = {near, normal, true}
        }
    }

    return result
}

// Original Scrapyard carom law as values: at most three cover legs, stop a
// fraction of a tick before the face, reflect its velocity component, then
// clamp/reflect against arena bounds. Timers and contact effects are the caller's.
// Returns false without mutation for invalid inputs. Units are pixels/tick.
carom2_step :: proc(body: ^Carom2, dt, restitution, skin: f32, bounds: Aabb2, boxes: []Aabb2) -> bool {
    finite :: proc(v: f32) -> bool {
        return !math.is_nan(v) && !math.is_inf(v)
    }

    if !finite(dt) ||
       dt < 0 ||
       !finite(restitution) ||
       restitution < 0 ||
       restitution > 1 ||
       !finite(skin) ||
       skin < 0 {
        return false
    }

    for axis in 0 ..< 2 {
        if !finite(body.position[axis]) ||
           !finite(body.velocity[axis]) ||
           !finite(bounds.min[axis]) ||
           !finite(bounds.max[axis]) ||
           bounds.min[axis] > bounds.max[axis] {
            return false
        }
    }

    for box in boxes {
        for axis in 0 ..< 2 {
            if !finite(box.min[axis]) || !finite(box.max[axis]) || box.min[axis] > box.max[axis] {
                return false
            }
        }
    }

    next := body^
    left := dt

    for _ in 0 ..< 3 {
        if left <= 0 {
            break
        }

        face := first_face2(next.position, next.velocity, left, boxes)

        if !face.hit {
            next.position += next.velocity * left
            break
        }

        travel := max(face.time - skin, 0)
        next.position += next.velocity * travel

        for axis in 0 ..< 2 {
            if face.normal[axis] != 0 {
                next.velocity[axis] = -next.velocity[axis] * restitution
            }
        }

        left -= face.time
    }

    for axis in 0 ..< 2 {
        if next.position[axis] < bounds.min[axis] {
            next.position[axis] = bounds.min[axis]
            next.velocity[axis] = abs(next.velocity[axis]) * restitution
        }

        if next.position[axis] > bounds.max[axis] {
            next.position[axis] = bounds.max[axis]
            next.velocity[axis] = -abs(next.velocity[axis]) * restitution
        }

        if !finite(next.position[axis]) || !finite(next.velocity[axis]) {
            return false
        }
    }

    body^ = next
    return true
}

// The original rail judge uses the nearest point on a segment (including its
// endpoints). Its fraction orders targets by center projection, not first surface
// contact. Games choose this deliberately when preserving that weapon rule.
beam_circle :: proc(from, segment, center: [2]f32, radius: f32) -> (fraction: f32, hit: bool) {
    length2 := segment[0] * segment[0] + segment[1] * segment[1]
    delta := center - from

    if length2 > 0 {
        fraction = clamp((delta[0] * segment[0] + delta[1] * segment[1]) / length2, 0, 1)
    }

    offset := from + segment * fraction - center
    return fraction, offset[0] * offset[0] + offset[1] * offset[1] <= radius * radius
}
