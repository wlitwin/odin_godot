package replay_play

// Engine-independent, axis-separated 2D kinematics against authored static AABBs.
// Displacement is in units per tick. Call order, axis order (X then Y), and
// obstacle order are explicit. Dynamic bodies must come from frame history.
Aabb2 :: struct {
    min, max: [2]f32,
}

Body2 :: struct {
    position, half_size: [2]f32,
}

move :: proc(body: ^Body2, displacement: [2]f32, walls: []Aabb2) -> [2]bool {
    hit: [2]bool

    for axis in 0 ..< 2 {
        other := 1 - axis
        start := body.position[axis]
        target := start + displacement[axis]

        for wall in walls {
            if body.position[other] + body.half_size[other] <= wall.min[other] ||
               body.position[other] - body.half_size[other] >= wall.max[other] {
                continue
            }

            if displacement[axis] > 0 {
                boundary := wall.min[axis] - body.half_size[axis]

                if start <= boundary && target > boundary {
                    target = boundary
                    hit[axis] = true
                }
            } else if displacement[axis] < 0 {
                boundary := wall.max[axis] + body.half_size[axis]

                if start >= boundary && target < boundary {
                    target = boundary
                    hit[axis] = true
                }
            }
        }

        body.position[axis] = target
    }

    return hit
}

// A frame-owned counter: ready before decrementing, arm on a successful action.
Cooldown :: struct {
    remaining: u32,
}

cooldown_tick :: proc(c: ^Cooldown) {
    if c.remaining > 0 {
        c.remaining -= 1
    }
}

cooldown_ready :: proc(c: ^Cooldown) -> bool {
    return c.remaining == 0
}

cooldown_arm :: proc(c: ^Cooldown, ticks: u32) {
    c.remaining = ticks
}

cooldown_try :: proc(c: ^Cooldown, ticks: u32) -> bool {
    if c.remaining != 0 || ticks == 0 {
        return false
    }

    c.remaining = ticks
    return true
}
