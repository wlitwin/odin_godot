package replay_physics_fixture

import b "godot:box3d"
import ph "godot:replay/physics"
import r "godot:replay"

Game :: struct {
    tick, begins, ends, births, deaths, queries: u64,
    rng:                                         u32,
    initial:                                     u32,
    bodies:                                      [35]b.Body_Key,
    alive:                                       [35]bool,
    generation:                                  [35]u32,
    floor, sensor:                               b.Body_Key,
    joint:                                       b.Joint_Key,
}

Input :: struct {
    impulse:                                                             f32,
    spawn:                                                               u32,
    despawn, sleep, wake, abort, skip_step, double_step, change_gravity: bool,
    gravity:                                                             b.Vec3,
    motor:                                                               f32,
}

Event :: struct {
    sensor, visitor: b.Shape_Key,
    began:           bool,
}

check :: proc(status: b.Status) {
    if status != .Ok {
        panic("native fixture failure")
    }
}

// Same bounded immutable geometry and construction order as the accepted spike.
// Smaller counts are test subsets; count32 is the measured alpha fixture.
world :: proc(count: u32 = 4) -> (b.World, Game, ph.Config) {
    world, status := b.world_create(b.world_def_default())
    check(status)
    game := Game {
        rng     = 1,
        initial = count,
        births  = u64(count),
    }
    def := b.body_def_default()
    floor, floor_status := b.body_create(world, def)
    check(floor_status)
    vertices := [?]b.Vec3{{-7, 0, -7}, {7, 0, -7}, {7, 0, 7}, {-7, 0, 7}}
    indices := [?]u32{0, 2, 1, 0, 3, 2}
    geometry, geometry_status := b.geometry_mesh(vertices[:], indices[:])
    check(geometry_status)
    _, floor_shape := b.shape_geometry(floor, b.shape_def_default(), &geometry)
    check(floor_shape)
    check(b.geometry_destroy(&geometry))
    game.floor, status = b.body_key(floor)
    check(status)
    def.pose.position = {0, 1, 0}
    sensor, sensor_status := b.body_create(world, def)
    check(sensor_status)
    sensor_shape := b.shape_def_default()
    sensor_shape.is_sensor = 1
    sensor_shape.enable_sensor_events = 1
    _, sensor_shape_status := b.shape_box(sensor, sensor_shape, {1.5, 1, 1.5})
    check(sensor_shape_status)
    game.sensor, status = b.body_key(sensor)
    check(status)

    for index in 0 ..< int(count) {
        body_def := b.body_def_default()
        body_def.type = .Dynamic
        body_def.pose.position = {
            f32(index % 5 - 2) * 0.6,
            0.45 + f32(index / 25) * 0.55,
            f32(index / 5 % 5 - 2) * 0.6,
        }
        body, body_status := b.body_create(world, body_def)
        check(body_status)
        shape_def := b.shape_def_default()
        shape_def.enable_sensor_events = 1
        _, shape_status := b.shape_box(body, shape_def, {0.25, 0.25, 0.25})
        check(shape_status)
        game.bodies[index], status = b.body_key(body)
        check(status)
        game.alive[index] = true
        game.generation[index] = 1
    }

    hinge := b.hinge_def_default()
    hinge.body_a = floor
    hinge.body_b, status = b.body_resolve(world, game.bodies[0])
    check(status)
    hinge.local_frame_a.position = {-1.2, 0.45, -1.2}
    hinge.enable_limit = 1
    hinge.lower_angle = -0.5
    hinge.upper_angle = 0.5
    hinge.enable_motor = 1
    hinge.max_motor_torque = 2
    joint, joint_status := b.joint_hinge_create(world, hinge)
    check(joint_status)
    game.joint, status = b.joint_key(joint)
    check(status)
    config := ph.config_default(0x746573742d617373, 0x746573742d627569)
    config.initial_dynamic_bodies = count
    return world, game, config
}

checkpoint :: proc($E: typeid, count: u32 = 4) -> (r.Complete_Checkpoint(Game, E), r.Error) {
    world, game, config := world(count)
    defer b.world_destroy(&world)
    return ph.checkpoint_make(r.Frame(Game){state = game}, E, world, config)
}

step :: proc(game: ^Game, input: Input, ctx: ^r.Step(Event)) {
    game.tick += 1
    x := game.rng
    x ~= x << 13
    x ~= x >> 17
    x ~= x << 5
    game.rng = x

    if input.impulse != 0 {
        if err := ph.body_impulse(ctx.execution, game.bodies[0], {input.impulse, 0.1, 0}); err != .None {
            ctx.error = err
            return
        }
    }

    for _ in 0 ..< int(input.spawn) {
        def := b.body_def_default()
        def.type = .Dynamic
        def.pose.position = {0.1, 7, 0.1}
        key, err := ph.spawn(ctx.execution, 2, def)

        if err != .None {
            ctx.error = err
            return
        }

        game.bodies[game.initial] = key
        game.alive[game.initial] = true
        game.generation[game.initial] += 1
        game.births += 1
    }

    if input.despawn {
        if err := ph.body_destroy(ctx.execution, game.bodies[game.initial]); err != .None {
            ctx.error = err
            return
        }

        game.alive[game.initial] = false
        game.bodies[game.initial] = 0
        game.deaths += 1
    }

    if input.sleep {
        if err := ph.body_awake(ctx.execution, game.bodies[0], false); err != .None {
            ctx.error = err
            return
        }
    }

    if input.wake {
        if err := ph.body_awake(ctx.execution, game.bodies[0], true); err != .None {
            ctx.error = err
            return
        }
    }

    if input.motor != 0 {
        if err := ph.hinge_motor(ctx.execution, game.joint, true, input.motor, 2); err != .None {
            ctx.error = err
            return
        }
    }

    if input.change_gravity {
        if err := ph.gravity(ctx.execution, input.gravity); err != .None {
            ctx.error = err
            return
        }
    }

    if !input.skip_step {
        if err := ph.step(ctx.execution); err != .None {
            ctx.error = err
            return
        }
    }

    if input.double_step {
        _ = ph.step(ctx.execution)
    } // ignored failure must still reject staging

    if game.tick % 4 == 0 {
        shapes: [35]b.Shape_Key
        count, error := ph.overlap(ctx.execution, {-3, -1, -3}, {3, 6, 3}, shapes[:])

        if error != .None {
            ctx.error = error
            return
        }

        game.queries += u64(count)
    }

    events: [70]ph.Sensor_Event
    count, err := ph.sensor_events(ctx.execution, events[:])

    if err != .None {
        ctx.error = err
        return
    }

    for event in events[:count] {
        if event.began {
            game.begins += 1
        } else {
            game.ends += 1
        }

        r.emit(ctx, event.began ? 1 : 2, u64(event.visitor), Event{event.sensor, event.visitor, event.began})
    }

    if input.abort {
        r.abort(ctx)
    }
}
