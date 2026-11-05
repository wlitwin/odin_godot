package dockyard_duo

import "core:math"
import b "godot:box3d"
import a "godot:box3d/authoring"
import bd "godot:box3d/diagnostics"
import bp "godot:box3d/presentation"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"

PROFILE :: u64(0x444f434b44554f31)
BODY_COUNT :: 19
BODY_NAMES :: [BODY_COUNT]string {
    "ground",
    "robot_a",
    "robot_b",
    "cargo_a",
    "cargo_b",
    "cargo_long",
    "crane_anchor",
    "crane",
    "barge",
    "ramp",
    "delivery",
    "barge_backstop",
    "barge_rail_a",
    "barge_rail_b",
    "barge_rail_c",
    "barge_rail_d",
    "barge_backstop_b",
    "barge_rail_e",
    "barge_rail_f",
}

Control :: struct {
    x, z, aim_x, aim_y, aim_z: i16,
    grab, pulse:               bool,
}

Action :: struct {
    kind: Action_Kind,
    x, z: i16,
}

Event :: struct {
    seat:  u16,
    kind:  u8,
    count: u32,
}

Game :: struct {
    tick:                  u64,
    round:                 u32,
    layout:                u8,
    phase:                 Round_Phase,
    round_ticks:           u32,
    departure_ticks:       u16,
    payout:                u32,
    recovered:             [2]u16,
    lost:                  [3]bool,
    home:                  [BODY_COUNT]b.Pose,
    cargo_defs:            [3]b.Body_Def,
    lives:                 [BODY_COUNT]u32,
    logical:               [BODY_COUNT]u64,
    bodies:                [BODY_COUNT]b.Body_Key,
    shapes:                [BODY_COUNT]b.Shape_Key,
    assets:                [BODY_COUNT]u32,
    joint:                 b.Joint_Key,
    queries:               u32,
    sensor_events, pulses: u64,
    magnet:                [2]u8,
    cooldown:              [2]u16,
    inside, delivered:     [3]bool,
    dwell:                 [3]u16,
    previous:              [3]b.Vec3,
    score:                 u8,
}

Codec :: ph.Network_Codec(Game, Control, Action, Event, 2)

initial_game :: proc(scene: ^a.Baked_Scene, built: ^a.Built_Scene) -> (Game, bool) {
    if len(scene.data.bodies) != BODY_COUNT || len(scene.data.shapes) != BODY_COUNT || len(scene.data.joints) != 1 {
        return {}, false
    }

    game: Game

    for name, i in BODY_NAMES {
        for body in scene.data.bodies {
            if body.stable_key == name {
                game.logical[i] = body.logical_id
                game.home[i] = body.definition.pose
                game.lives[i] = 1

                if i >= 3 && i < 6 {
                    game.cargo_defs[i - 3] = body.definition
                }

                if i >= 3 && i < 6 {
                    game.previous[i - 3] = body.definition.pose.position
                }

                break
            }
        }

        if game.logical[i] == 0 {
            return {}, false
        }

        for mapping in built.bodies {
            if mapping.logical_id == game.logical[i] {
                game.bodies[i] = mapping.key
                break
            }
        }

        for mapping in built.shapes {
            if mapping.body_id == game.logical[i] {
                game.assets[i] = mapping.asset_id
                game.shapes[i] = mapping.key
                break
            }
        }

        if game.bodies[i] == 0 || game.shapes[i] == 0 || game.assets[i] == 0 {
            return {}, false
        }
    }

    game.joint = built.joints[0].key
    return game, game.joint != 0
}

control_valid :: proc(value: Control) -> bool {
    return(
        value.x >= -100 &&
        value.x <= 100 &&
        value.z >= -100 &&
        value.z <= 100 &&
        value.aim_x >= -1400 &&
        value.aim_x <= 1400 &&
        value.aim_y >= -1000 &&
        value.aim_y <= 1000 &&
        value.aim_z >= -1400 &&
        value.aim_z <= 1400 \
    )
}

magnet :: proc(game: ^Game, value: Control, seat: int, pose: b.Pose, ctx: ^r.Step(Event)) {
    game.magnet[seat] = 0

    if !value.grab {
        return
    }

    origin := pose.position
    origin.y += 0.25
    target := b.Vec3{f32(value.aim_x) * .01, f32(value.aim_y) * .01, f32(value.aim_z) * .01}
    dx, dy, dz := target.x - origin.x, target.y - origin.y, target.z - origin.z
    distance := math.sqrt(dx * dx + dy * dy + dz * dz)

    if distance < .05 {
        return
    }

    reach := min(distance, f32(3.4))
    scale := reach / distance
    hits: [b.MOTION_MAX_HITS]b.Motion_Hit
    count, error := ph.motion_ray(
        ctx.execution,
        origin,
        {dx * scale, dy * scale, dz * scale},
        {category_bits = 1, mask_bits = max(u64), exclude_body = game.bodies[seat + 1]},
        hits[:],
    )

    if error != .None {
        r.execution_fail(ctx.execution, error)
        r.abort(ctx)
        return
    }

    game.queries += 1

    if count == 0 {
        return
    }

    cargo := -1

    for key, i in game.bodies[3:6] {
        if hits[0].body == key {
            cargo = i
            break
        }
    }

    if cargo < 0 || game.delivered[cargo] {
        return
    }

    cargo_pose, pose_error := ph.body_pose(ctx.execution, game.bodies[cargo + 3])

    if pose_error != .None {
        r.abort(ctx)
        return
    }

    anchor := b.Vec3{origin.x + dx / distance * .45, origin.y + dy / distance * .45, origin.z + dz / distance * .45}
    point := hits[0].point
    velocity, angular, ve := ph.body_velocities(ctx.execution, game.bodies[cargo + 3])
    robot_velocity, _, re := ph.body_velocities(ctx.execution, game.bodies[seat + 1])

    if ve != .None || re != .None {
        r.abort(ctx)
        return
    }

    lever := b.Vec3{point.x - cargo_pose.position.x, point.y - cargo_pose.position.y, point.z - cargo_pose.position.z}
    point_velocity := b.Vec3 {
        velocity.x + angular.y * lever.z - angular.z * lever.y,
        velocity.y + angular.z * lever.x - angular.x * lever.z,
        velocity.z + angular.x * lever.y - angular.y * lever.x,
    }
    impulse := b.Vec3 {
        (anchor.x - point.x) * .18 + (robot_velocity.x - point_velocity.x) * .04,
        (anchor.y - point.y) * .18 + (robot_velocity.y - point_velocity.y) * .04,
        (anchor.z - point.z) * .18 + (robot_velocity.z - point_velocity.z) * .04,
    }
    length := math.sqrt(impulse.x * impulse.x + impulse.y * impulse.y + impulse.z * impulse.z)

    if length > .11 {
        factor := f32(.11) / length
        impulse = {impulse.x * factor, impulse.y * factor, impulse.z * factor}
    }

    if ph.body_impulse_at(ctx.execution, game.bodies[cargo + 3], impulse, point) != .None {
        r.abort(ctx)
        return
    }

    if ph.body_impulse(ctx.execution, game.bodies[seat + 1], {-impulse.x * .45, 0, -impulse.z * .45}) != .None {
        r.abort(ctx)
        return
    }

    game.magnet[seat] = u8(cargo + 1)
}

model_step :: proc(game: ^Game, controls: [2]Control, _, _: u64, ctx: ^r.Step(Event)) {
    game.queries = 0
    round_before(game, ctx)

    if ctx.error != .None {
        return
    }

    for value, seat in controls {
        if !control_valid(value) {
            r.abort(ctx)
            return
        }

        if game.cooldown[seat] > 0 {
            game.cooldown[seat] -= 1
        }

        x, z := f32(value.x) * .01, f32(value.z) * .01
        length := math.sqrt(x * x + z * z)

        if length > 1 {
            x /= length
            z /= length
        }

        force := f32(.15)

        if game.phase != .Working {
            x = 0
            z = 0
        }

        if ph.body_impulse(ctx.execution, game.bodies[seat + 1], {x * force, 0, z * force}) != .None {
            r.abort(ctx)
            return
        }

        pose, error := ph.body_pose(ctx.execution, game.bodies[seat + 1])

        if error != .None {
            r.abort(ctx)
            return
        }

        if game.phase == .Working {
            magnet(game, value, seat, pose, ctx)
        } else {
            game.magnet[seat] = 0
        }
    }

    if ph.step(ctx.execution) != .None {
        r.abort(ctx)
        return
    }

    events: [70]ph.Sensor_Event
    count, error := ph.sensor_events(ctx.execution, events[:])

    if error != .None {
        r.abort(ctx)
        return
    }

    game.sensor_events += u64(count)

    for event in events[:count] {
        if event.sensor == game.shapes[10] {
            for key, i in game.shapes[3:6] {
                if event.visitor == key {
                    game.inside[i] = event.began
                    break
                }
            }
        }
    }

    for key, i in game.bodies[3:6] {
        if game.lost[i] {
            continue
        }

        pose, pose_error := ph.body_pose(ctx.execution, key)

        if pose_error != .None {
            r.abort(ctx)
            return
        }

        last := game.previous[i]
        dx, dy, dz := pose.position.x - last.x, pose.position.y - last.y, pose.position.z - last.z
        settled := dx * dx + dy * dy + dz * dz < .00018
        game.previous[i] = pose.position

        if game.phase == .Working && !game.delivered[i] {
            half_x := i == 2 ? f32(1.4) : f32(.6)
            half_z := i == 2 ? f32(.5) : f32(.6)
            pads := CARGO_PADS
            pad := pads[i]
            in_bay := abs(pose.position.x - pad.x) < .35 && abs(pose.position.z - pad.z) < .35

            if game.inside[i] &&
               in_bay &&
               settled &&
               pose.position.x > 2.4 + half_x &&
               pose.position.x < 9.6 - half_x &&
               pose.position.z > -2 + half_z &&
               pose.position.z < 4 - half_z {
                game.dwell[i] = min(game.dwell[i] + 1, 120)
            } else {
                game.dwell[i] = 0
            }

            if game.dwell[i] == 120 {
                if ph.body_type(ctx.execution, key, .Kinematic) != .None ||
                   ph.body_velocity(ctx.execution, key, {}, {}) != .None {
                    r.abort(ctx)
                    return
                }

                game.delivered[i] = true
                game.score += 1
                r.emit(ctx, 2, u64(i + 1), Event{0, 2, u32(i + 1)})
            }
        }
    }

    round_after(game, ctx)
    game.tick = ctx.tick
}

boost_valid :: proc(value: Action) -> bool {
    return value.x >= -100 && value.x <= 100 && value.z >= -100 && value.z <= 100 && (value.x != 0 || value.z != 0)
}

boost :: proc(game: ^Game, seat: u16, value: Action, ctx: ^r.Step(Event)) -> bool {
    if seat < 1 || seat > 2 || !boost_valid(value) || game.cooldown[seat - 1] != 0 {
        return false
    }

    x, z := f32(value.x) * .01, f32(value.z) * .01
    length := math.sqrt(x * x + z * z)

    if length > 1 {
        x /= length
        z /= length
    }

    if ph.body_impulse(ctx.execution, game.bodies[seat], {x * .51, 0, z * .51}) != .None {
        r.abort(ctx)
        return false
    }

    game.cooldown[seat - 1] = 60
    game.pulses += 1
    r.emit(ctx, 1, u64(seat), Event{seat, 1, 1})
    return true
}

// Aim only steers the magnet while grab is held (see magnet). Zero aim
// otherwise keeps the predicted (held) input of a remote driver exact while
// they just drive, so confirming their real inputs needs no re-simulation.
canonical_control :: proc(value: Control) -> Control {
    result := value

    if !result.grab {
        result.aim_x, result.aim_y, result.aim_z = 0, 0, 0
    }

    return result
}

state_valid :: proc(game: Game) -> bool {
    if game.joint == 0 ||
       game.score > 3 ||
       game.round == 0 ||
       game.layout >= 3 ||
       game.round_ticks > ROUND_TICKS ||
       game.departure_ticks > DEPARTURE_TICKS ||
       game.payout > 1500 {
        return false
    }

    score := u8(0)

    for key, i in game.bodies {
        if game.logical[i] == 0 || game.assets[i] == 0 || game.lives[i] == 0 {
            return false
        }

        missing := i >= 3 && i < 6 && game.lost[i - 3]

        if missing {
            if key != 0 || game.shapes[i] != 0 {
                return false
            }
        } else if key == 0 || game.shapes[i] == 0 {
            return false
        }

        for other in 0 ..< i {
            if (key != 0 && key == game.bodies[other]) ||
               (game.shapes[i] != 0 && game.shapes[i] == game.shapes[other]) ||
               game.logical[i] == game.logical[other] {
                return false
            }
        }
    }

    for value, i in game.delivered {
        if value {
            score += 1
        }

        if game.dwell[i] > 120 || value && game.lost[i] {
            return false
        }
    }

    for value, i in game.magnet {
        if value > 3 || game.cooldown[i] > 60 {
            return false
        }
    }

    return score == game.score
}

model :: proc(codec: ^Codec) -> net.Model(Game, Control, Action, Event, 2) {
    return {
        complete_state = true,
        complete_codec = codec.value,
        step = model_step,
        action = game_action,
        control_valid = control_valid,
        action_valid = action_valid,
        state_valid = state_valid,
        hold = proc(value: Control) -> Control {
            result := value
            result.pulse = false
            return result
        },
        event_owner = proc(value: Event) -> u16 {
            return value.seat
        },
    }
}

rules :: proc() -> bd.Digest {
    digest, error := bd.hash_descriptors(
        "dockyard-duo-rounds.v1",
        []bd.Descriptor {
            {"controller", transmute([]u8)#load("controller.odin")},
            {"model", transmute([]u8)#load("model.odin")},
            {"round", transmute([]u8)#load("round.odin")},
        },
    )

    if error != .None {
        panic("Dockyard rules hash")
    }

    return digest
}

project :: proc(game: Game, out: []bp.Binding) -> (u32, bp.Error) {
    if len(out) < BODY_COUNT {
        return BODY_COUNT, .Capacity
    }

    count := 0

    for key, i in game.bodies {
        if key != 0 {
            out[count] = {
                id    = {game.logical[i], u64(game.lives[i])},
                body  = bp.Body_Key(key),
                asset = game.assets[i],
                alive = true,
            }
            count += 1
        }
    }

    return u32(count), .None
}
