package replay_play

import "core:math"

in_reach :: proc(a, b: [2]f32, radius: f32) -> bool {
    d := a - b
    return d[0] * d[0] + d[1] * d[1] <= radius * radius
}

step_toward :: proc(from, to: [2]f32, distance: f32) -> [2]f32 {
    d := to - from
    n := math.sqrt(d[0] * d[0] + d[1] * d[1])

    if n <= distance || n == 0 {
        return to
    }

    return from + d * (distance / n)
}

// First contact along a segment, including a segment starting inside the circle.
segment_circle :: proc(from, to, center: [2]f32, radius: f32) -> (fraction: f32, hit: bool) {
    d, offset := to - from, from - center
    a := d[0] * d[0] + d[1] * d[1]
    c := offset[0] * offset[0] + offset[1] * offset[1] - radius * radius

    if c <= 0 {
        return 0, true
    }

    if a == 0 {
        return 0, false
    }

    b := 2 * (offset[0] * d[0] + offset[1] * d[1])
    disc := b * b - 4 * a * c

    if disc < 0 {
        return 0, false
    }

    t := (-b - math.sqrt(disc)) / (2 * a)
    return t, t >= 0 && t <= 1
}

// A small pure visibility-graph query around one static rectangular obstacle.
// Cavecrawl's authored rifts use it; general polygon navigation is separate work.
around_rect :: proc(from, to: [2]f32, obstacle: Aabb2, distance: f32) -> [2]f32 {
    points := [6][2]f32 {
        from,
        to,
        {obstacle.min[0] - 1, obstacle.min[1] - 1},
        {obstacle.max[0] + 1, obstacle.min[1] - 1},
        {obstacle.min[0] - 1, obstacle.max[1] + 1},
        {obstacle.max[0] + 1, obstacle.max[1] + 1},
    }
    cost: [6]f32
    previous: [6]int
    visited: [6]bool

    for &v in cost {
        v = 1e30
    }

    for &v in previous {
        v = -1
    }

    cost[0] = 0

    for _ in 0 ..< 6 {
        best := -1

        for value, i in cost {
            if !visited[i] && (best < 0 || value < cost[best]) {
                best = i
            }
        }

        if best < 0 || best == 1 {
            break
        }

        visited[best] = true

        for target, i in points {
            if visited[i] || i == best || segment_rect(points[best], target, obstacle) {
                continue
            }

            d := target - points[best]
            candidate := cost[best] + math.sqrt(d[0] * d[0] + d[1] * d[1])

            if candidate < cost[i] {
                cost[i], previous[i] = candidate, best
            }
        }
    }

    if previous[1] < 0 {
        return step_toward(from, to, distance)
    }

    next := 1

    for previous[next] > 0 {
        next = previous[next]
    }

    return step_toward(from, points[next], distance)
}

@(private)
segment_rect :: proc(from, to: [2]f32, box: Aabb2) -> bool {
    lo, hi := f32(0), f32(1)

    for axis in 0 ..< 2 {
        d := to[axis] - from[axis]

        if d == 0 {
            if from[axis] <= box.min[axis] || from[axis] >= box.max[axis] {
                return false
            }

            continue
        }

        a, b := (box.min[axis] - from[axis]) / d, (box.max[axis] - from[axis]) / d

        if a > b {
            a, b = b, a
        }

        lo, hi = max(lo, a), min(hi, b)

        if lo >= hi {
            return false
        }
    }

    return lo < hi
}
