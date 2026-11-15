package replay_play

import "core:math"

// Value-owned motion, with immutable laws supplied separately by the game.
// These helpers use units per simulation tick; they do not read engine poses.
Motion2 :: struct {
    position, velocity: [2]f32,
}

Roll_Law2 :: struct {
    friction, max_speed, restitution: f32,
    bounds:                           Aabb2,
}

length_sq2 :: proc(v: [2]f32) -> f32 {
    return v[0] * v[0] + v[1] * v[1]
}

unit2 :: proc(v: [2]f32) -> [2]f32 {
    length := math.sqrt(length_sq2(v))
    return length <= 0.00001 ? [2]f32{} : v / length
}

momentum_step :: proc(m: ^Motion2, target: [2]f32, response: f32, bounds: Aabb2) {
    m.velocity += (target - m.velocity) * response

    for axis in 0 ..< 2 {
        m.position[axis] = clamp(m.position[axis] + m.velocity[axis], bounds.min[axis], bounds.max[axis])
    }
}

roll_step :: proc(m: ^Motion2, law: Roll_Law2) {
    m.velocity *= law.friction

    if speed_sq := length_sq2(m.velocity); speed_sq > law.max_speed * law.max_speed {
        m.velocity *= law.max_speed / math.sqrt(speed_sq)
    }

    m.position += m.velocity

    for axis in 0 ..< 2 {
        if m.position[axis] <= law.bounds.min[axis] {
            m.position[axis] = law.bounds.min[axis]
            m.velocity[axis] *= -law.restitution
        }

        if m.position[axis] >= law.bounds.max[axis] {
            m.position[axis] = law.bounds.max[axis]
            m.velocity[axis] *= -law.restitution
        }
    }
}

// Half-overlap separation, stable at coincident centers. The push follows the
// actor's motion and stops accelerating a ball already moving at dribble speed.
soft_contact :: proc(ball: ^Motion2, actor: Motion2, reach, push, dribble_speed: f32) -> bool {
    d := ball.position - actor.position
    q := length_sq2(d)

    if q >= reach * reach {
        return false
    }

    distance := math.sqrt(q)
    separation := distance > 0.5 ? d / distance : unit2(actor.velocity)

    if separation == ([2]f32{}) {
        separation = {1, 0}
    }

    ball.position += separation * (reach - distance) * 0.5
    direction := unit2(actor.velocity)

    if direction != ([2]f32{}) && length_sq2(ball.velocity) < dribble_speed * dribble_speed {
        ball.velocity += direction * push
    }

    return true
}
