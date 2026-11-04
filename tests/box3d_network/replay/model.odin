// Test-only rules adapted from tests/replay_physics_net/{fixture,native/codec_test}.
// Production net.Server/Client, Timeline, physics provider and codec are reused.
package main
import "core:fmt"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import net "godot:replay/net"
import ph "godot:replay/physics"
import view "godot:replay/view"
import f "godot:tests/replay_physics_net/fixture"

SCHEMA_VARIANT :: #config(BOX3D_NETWORK_SCHEMA_VARIANT, false)

when SCHEMA_VARIANT {
    Control :: struct {
        x, z: i16,
        mode: u32,
    }
} else {
    Control :: struct {
        x, z: i16,
    }
}

Action_Kind :: enum u8 {
    None,
    Spawn,
    Remove,
    Motor,
    Reverse,
    Sleep,
    Wake,
}

Action :: struct {
    kind: Action_Kind,
}

Event :: struct {
    kind: u8,
    key:  u64,
}

Game :: struct {
    base:                                                f.Game,
    extra_shape, retired_shape:                          b.Shape_Key,
    expected_end_tick, exact_extra_ends, last_extra_end: u64,
    last_counts, peak:                                   b.World_Counters,
}

// Process-local diagnostics only; never serialized, hashed as game state, or
// consulted for simulation/admission decisions.
Process_Observation :: struct {
    peak:    b.World_Counters,
    samples: u64,
}

Parameters :: struct {
    scale:    i16,
    variant:  u8,
    fault:    bool,
    observer: ^Process_Observation,
}

script_control :: proc(tick: u64, seat: u16) -> Control {
    value := Control {
        x = i16(i32((tick / u64(7 + seat)) % 5) - 2),
        z = i16(i32((tick / u64(11 + seat)) % 3) - 1),
    }

    when SCHEMA_VARIANT {
        value.mode = 1
    }

    return value
}

script_action :: proc(tick: u64, seat: u16) -> Action {
    if seat != 1 {
        return {}
    }

    switch tick {
    case 24, 40, 160, 176, 392, 408:
        return {.Spawn}
    case 32, 48, 168, 184, 400, 416:
        return {.Remove}
    case 80, 260:
        return {.Sleep}
    case 84, 264:
        return {.Wake}
    case 96:
        return {.Motor}
    case 104:
        return {.Reverse}
    }

    return {}
}

control_valid :: proc(c: Control) -> bool {
    when SCHEMA_VARIANT {
        if c.mode != 1 {
            return false
        }
    }

    return abs(c.x) <= 2 && abs(c.z) <= 2
}

action_valid :: proc(a: Action) -> bool {
    return a.kind <= .Wake
}

model_step :: proc(game: ^Game, controls: [2]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
    parameters := cast(^Parameters)ctx.user
    assert(parameters != nil)

    if parameters.fault && ctx.tick == 35 {
        if ph.gravity(ctx.execution, {0, -9.75, 0}) != .None {
            r.abort(ctx)
            return
        }
    } // deliberate model-contract violation negative control only

    game.base.tick += 1
    x := game.base.rng
    x ~= x << 13
    x ~= x >> 17
    x ~= x << 5
    game.base.rng = x

    for control, seat in controls {
        if !control_valid(control) {
            r.abort(ctx)
            return
        }

        if control.x != 0 || control.z != 0 {
            if ph.body_impulse(
                   ctx.execution,
                   game.base.bodies[seat],
                   {f32(control.x * parameters.scale) * .001, 0, f32(control.z * parameters.scale) * .001},
               ) !=
               .None {
                r.abort(ctx)
                return
            }
        }
    }

    if ph.step(ctx.execution) != .None {
        r.abort(ctx)
        return
    }

    observe_counts(game, ctx.execution, parameters.observer)
    obs: [70]ph.Sensor_Event
    count, error := ph.sensor_events(ctx.execution, obs[:])

    if error != .None {
        r.abort(ctx)
        return
    }

    for event in obs[:count] {
        if event.began {
            game.base.begins += 1
        } else {
            game.base.ends += 1
        }

        if !event.began && event.visitor == game.retired_shape && game.expected_end_tick != 0 {
            if ctx.tick != game.expected_end_tick || game.last_extra_end == ctx.tick {
                r.abort(ctx)
                return
            }

            game.exact_extra_ends += 1
            game.last_extra_end = ctx.tick
        }

        r.emit(
            ctx,
            event.began ? u64(1) : u64(2),
            u64(event.visitor),
            Event{event.began ? u8(1) : u8(2), u64(event.visitor)},
        )
    }

    if game.expected_end_tick == ctx.tick && game.last_extra_end != ctx.tick {
        r.abort(ctx)
        return
    }

    // Test presentation payloads exercise real speculative Update/Cancel/Confirm.
    if ctx.tick > 1 {
        if controls[0].x > 0 {
            r.emit(ctx, 3, 1, Event{3, u64(u16(controls[0].x))})
        }

        r.emit(ctx, 4, 1, Event{4, u64(u16(controls[0].x))})
    }
}

model_action :: proc(game: ^Game, seat: u16, action: Action, ctx: ^r.Step(Event)) -> bool {
    parameters := cast(^Parameters)ctx.user
    assert(parameters != nil)

    if seat < 1 || seat > 2 || !action_valid(action) {
        return false
    }

    slot := game.base.initial

    switch action.kind {
    case .None:
        return true
    case .Spawn:
        if game.base.alive[slot] {
            return false
        }

        def := b.body_def_default()
        def.type = .Dynamic
        def.pose.position = {.1, 1, .1}
        key, error := ph.spawn(ctx.execution, 4, def)

        if error != .None {
            fmt.eprintf("SPAWN_ERROR tick=%d error=%v\n", ctx.tick, error)
            return false
        }

        hits: [35]ph.Ray_Hit
        count, re := ph.ray(ctx.execution, {.1, 1, -.4}, {0, 0, 1}, hits[:])

        if re != .None {
            return false
        }

        matches := 0

        for hit in hits[:count] {
            if abs(hit.fraction - .25) < .00001 && abs(hit.point.z + .15) < .00001 {
                game.extra_shape = hit.shape
                matches += 1
            }
        }

        if matches != 1 {
            fmt.eprintf(
                "SPAWN_RAY expected sphere surface tick=%d matches=%d hits=%v\n",
                ctx.tick,
                matches,
                hits[:count],
            )
            return false
        }

        game.base.bodies[slot] = key
        game.base.alive[slot] = true
        game.base.generation[slot] += 1
        game.base.births += 1
        observe_counts(game, ctx.execution, parameters.observer)
    case .Remove:
        if !game.base.alive[slot] {
            return false
        }

        before, after: [70]ph.Sensor_Event
        nc, ce := ph.sensor_events(ctx.execution, before[:])

        if ce != .None {
            return false
        }

        if ph.body_destroy(ctx.execution, game.base.bodies[slot]) != .None {
            return false
        }

        na, ae := ph.sensor_events(ctx.execution, after[:])

        if ae != .None || na != nc {
            return false
        }

        for event, index in before[:nc] {
            if event != after[index] {
                return false
            }
        }

        if game.expected_end_tick != 0 && game.last_extra_end != game.expected_end_tick {
            return false
        }

        game.retired_shape = game.extra_shape
        game.expected_end_tick = ctx.tick + 1
        game.base.bodies[slot] = 0
        game.base.alive[slot] = false
        game.base.deaths += 1
    case .Motor, .Reverse:
        return(
            ph.hinge_motor(ctx.execution, game.base.joint, true, action.kind == .Motor ? f32(.25) : f32(-.25), 2) ==
            .None \
        )
    case .Sleep, .Wake:
        return ph.body_awake(ctx.execution, game.base.bodies[31], action.kind == .Wake) == .None
    }

    return true
}

rules :: proc(params: Parameters) -> bd.Digest {
    data := [4]u8{u8(u16(params.scale)), u8(u16(params.scale) >> 8), params.variant, 0}
    fields := []bd.Descriptor {
        {"model", transmute([]u8)#load("model.odin")},
        {"parameters", data[:]},
        {"world", transmute([]u8)#load("../../replay_physics_net/fixture/fixture.odin")},
    }
    result, error := bd.hash_descriptors("box3d-network.replay.rules.v1", fields)
    assert(error == .None)
    return result
}

model :: proc(
    codec: ^ph.Network_Codec(Game, Control, Action, Event, 2),
    params: ^Parameters,
) -> net.Model(Game, Control, Action, Event, 2) {
    return {
        complete_state = true,
        complete_codec = codec.value,
        user = params,
        step = model_step,
        action = model_action,
        event_policy = proc(event: Event) -> view.Policy {
            return event.kind >= 3 ? .Speculative : .Confirmed
        },
        control_valid = control_valid,
        action_valid = action_valid,
        hold = proc(c: Control) -> Control {
            return c
        },
        state_valid = proc(g: Game) -> bool {
            return g.base.initial == 32
        },
    }
}

observe_counts :: proc(game: ^Game, execution: r.Execution, local: ^Process_Observation) {
    observed, error := ph.observe(execution)
    assert(error == .None)

    if local != nil {
        local.samples += 1
        local.peak.body_count = max(local.peak.body_count, observed.counts.body_count)
        local.peak.shape_count = max(local.peak.shape_count, observed.counts.shape_count)
        local.peak.contact_count = max(local.peak.contact_count, observed.counts.contact_count)
        local.peak.joint_count = max(local.peak.joint_count, observed.counts.joint_count)
    }

    game.last_counts = observed.counts
    game.peak.body_count = max(game.peak.body_count, observed.counts.body_count)
    game.peak.shape_count = max(game.peak.shape_count, observed.counts.shape_count)
    game.peak.contact_count = max(game.peak.contact_count, observed.counts.contact_count)
    game.peak.joint_count = max(game.peak.joint_count, observed.counts.joint_count)
}
