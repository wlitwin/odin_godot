// Test-only rules shared by sibling adapter tests. No Kit or Replay runtime.
package physics_network_fixture

import b "godot:box3d"
import bd "godot:box3d/diagnostics"

PROFILE :: u64(0x504859534e455431)
ASSET_DECLARATION :: u64(0x5052494d464c5231)

Asset_Kind :: enum u32 {
    Box     = 1,
    Sphere  = 2,
    Capsule = 3,
}

Asset :: struct {
    id:     u32,
    kind:   Asset_Kind,
    a, b:   b.Vec3,
    radius: f32,
}

Game :: struct {
    tick, births, deaths, begins, ends: u64,
    rng:                                u32,
    initial:                            u32,
    bodies:                             [35]b.Body_Key,
    alive:                              [35]bool,
    generation:                         [35]u32,
    floor, sensor:                      b.Body_Key,
    joint:                              b.Joint_Key,
}

Control :: struct {
    x, z: i16,
}

Action_Kind :: enum u8 {
    None,
    Spawn,
    Remove,
    Motor,
}

Action :: struct {
    kind: Action_Kind,
}

Observation :: struct {
    sensor, visitor: b.Shape_Key,
    began:           bool,
}

Event :: struct {
    source: u16,
    kind:   u8,
    key:    u64,
}

// Explicit callback-local execution argument, never an immutable model pointer.
Operations :: struct {
    execution:    rawptr,
    impulse:      proc(_: rawptr, _: b.Body_Key, _: b.Vec3) -> bool,
    spawn:        proc(_: rawptr, _: b.Vec3) -> (b.Body_Key, bool),
    remove:       proc(_: rawptr, _: b.Body_Key) -> bool,
    motor:        proc(_: rawptr, _: b.Joint_Key, _: f32) -> bool,
    step:         proc(_: rawptr) -> bool,
    observations: proc(_: rawptr, _: []Observation) -> (int, bool),
}

assets :: proc() -> [4]Asset {
    return {
        {id = 1, kind = .Box, a = {7, 1, 7}},
        {id = 2, kind = .Box, a = {1.5, 1, 1.5}},
        {id = 3, kind = .Box, a = {0.25, 0.25, 0.25}},
        {id = 4, kind = .Sphere, radius = 0.25},
    }
}

// This verified test rule descriptor includes the actual source and immutable
// parameters. Production callers must bind their own verified code/parameter set.
game_rules :: proc() -> bd.Digest {
    return bd.hash_bytes(transmute([]u8)#load("fixture.odin"))
}

control_valid :: proc(value: Control) -> bool {
    return value.x >= -100 && value.x <= 100 && value.z >= -100 && value.z <= 100
}

hold :: proc(value: Control) -> Control {
    return value
}

action_valid :: proc(value: Action) -> bool {
    return value.kind <= .Motor
}

world :: proc(count: u32 = 4) -> (world: b.World, game: Game, status: b.Status) {
    if count < 2 || count > 32 {
        return 0, {}, .Invalid_Argument
    }

    world, status = b.world_create(b.world_def_default())

    if status != .Ok {
        return
    }

    created := world
    committed := false

    defer if !committed {
        b.world_destroy(&created)
    }

    game = {
        initial = count,
        rng     = 1,
        births  = u64(count),
    }
    def := b.body_def_default()
    def.pose.position = {0, -1, 0}
    floor, fs := b.body_create(world, def)

    if fs != .Ok {
        return 0, {}, fs
    }

    _, floor_shape := b.shape_box(floor, b.shape_def_default(), {7, 1, 7})

    if floor_shape != .Ok {
        return 0, {}, floor_shape
    }

    game.floor, status = b.body_key(floor)

    if status != .Ok {
        return
    }

    def.pose.position = {0, 1, 0}
    sensor, ss := b.body_create(world, def)

    if ss != .Ok {
        return 0, {}, ss
    }

    shape := b.shape_def_default()
    shape.is_sensor = 1
    shape.enable_sensor_events = 1
    _, sensor_shape := b.shape_box(sensor, shape, {1.5, 1, 1.5})

    if sensor_shape != .Ok {
        return 0, {}, sensor_shape
    }

    game.sensor, status = b.body_key(sensor)

    if status != .Ok {
        return
    }

    for i in 0 ..< int(count) {
        body_def := b.body_def_default()
        body_def.type = .Dynamic
        body_def.pose.position = {f32(i % 5 - 2) * 0.6, 0.45 + f32(i / 25) * 0.55, f32(i / 5 % 5 - 2) * 0.6}
        body, bs := b.body_create(world, body_def)

        if bs != .Ok {
            return 0, {}, bs
        }

        shape_def := b.shape_def_default()
        shape_def.enable_sensor_events = 1
        _, shape_status := b.shape_box(body, shape_def, {0.25, 0.25, 0.25})

        if shape_status != .Ok {
            return 0, {}, shape_status
        }

        game.bodies[i], status = b.body_key(body)

        if status != .Ok {
            return
        }

        game.alive[i] = true
        game.generation[i] = 1
    }

    hinge := b.hinge_def_default()
    hinge.body_a = floor
    hinge.body_b, status = b.body_resolve(world, game.bodies[0])

    if status != .Ok {
        return
    }

    hinge.local_frame_a.position = {-1.2, 0.45, -1.2}
    hinge.enable_limit = 1
    hinge.lower_angle = -0.5
    hinge.upper_angle = 0.5
    hinge.enable_motor = 1
    hinge.max_motor_torque = 2
    joint, js := b.joint_hinge_create(world, hinge)

    if js != .Ok {
        return 0, {}, js
    }

    game.joint, status = b.joint_key(joint)

    if status != .Ok {
        return
    }

    committed = true
    return
}

advance :: proc(game: ^Game, controls: [2]Control, ops: Operations, out: []Event) -> (count: int, ok: bool) {
    game.tick += 1
    x := game.rng
    x ~= x << 13
    x ~= x >> 17
    x ~= x << 5
    game.rng = x

    for control, seat in controls {
        if !control_valid(control) {
            return 0, false
        }

        if control.x != 0 || control.z != 0 {
            if !ops.impulse(ops.execution, game.bodies[seat], {f32(control.x) * 0.001, 0, f32(control.z) * 0.001}) {
                return 0, false
            }
        }
    }

    if !ops.step(ops.execution) {
        return 0, false
    }

    observations: [70]Observation
    available, observed := ops.observations(ops.execution, observations[:])

    if !observed || available > len(out) {
        return 0, false
    }

    for observation, index in observations[:available] {
        if observation.began {
            game.begins += 1
        } else {
            game.ends += 1
        }

        out[index] = {
            source = observation.began ? 1 : 2,
            kind   = observation.began ? 1 : 2,
            key    = u64(observation.visitor),
        }
    }

    return available, true
}

apply_action :: proc(game: ^Game, seat: u16, value: Action, ops: Operations) -> bool {
    if seat < 1 || seat > 2 || !action_valid(value) {
        return false
    }

    #partial switch value.kind {
    case .None:
        return true
    case .Spawn:
        if game.alive[game.initial] {
            return false
        }

        key, spawned := ops.spawn(ops.execution, {0.1, 7, 0.1})

        if !spawned {
            return false
        }

        game.bodies[game.initial] = key
        game.alive[game.initial] = true
        game.generation[game.initial] += 1
        game.births += 1
    case .Remove:
        if !game.alive[game.initial] || !ops.remove(ops.execution, game.bodies[game.initial]) {
            return false
        }

        game.bodies[game.initial] = 0
        game.alive[game.initial] = false
        game.deaths += 1
    case .Motor:
        if !ops.motor(ops.execution, game.joint, seat == 1 ? 0.25 : -0.25) {
            return false
        }
    }

    return true
}
