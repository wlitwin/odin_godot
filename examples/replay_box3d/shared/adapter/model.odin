// Replay adapter only. Common owns immutable gameplay, never a session/loop.
package replay_box3d_model
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"
import common "godot:examples/box3d_common"
Codec :: ph.Network_Codec(common.Game, common.Control, common.Action, common.Event, 2)
Session_Game :: common.Game

operations :: proc(execution: ^r.Execution) -> common.Operations {
    return {user = execution, impulse = proc(p: rawptr, key: b.Body_Key, value: b.Vec3) -> bool {
            return ph.body_impulse((cast(^r.Execution)p)^, key, value) == .None
        }, spawn = proc(p: rawptr, asset: u32, definition: b.Body_Def) -> (b.Body_Key, b.Shape_Key, bool) {
            body, shape, error := ph.spawn_with_shape((cast(^r.Execution)p)^, asset, definition)
            return body, shape, error == .None
        }, remove = proc(p: rawptr, key: b.Body_Key) -> bool {
            return ph.body_destroy((cast(^r.Execution)p)^, key) == .None
        }, motor = proc(p: rawptr, key: b.Joint_Key, speed: f32) -> bool {
            return ph.hinge_motor((cast(^r.Execution)p)^, key, true, speed, 2) == .None
        }, awake = proc(p: rawptr, key: b.Body_Key, value: bool) -> bool {
            return ph.body_awake((cast(^r.Execution)p)^, key, value) == .None
        }, query = proc(p: rawptr, key: b.Body_Key) -> (u32, bool) {
            capability := (cast(^r.Execution)p)^
            pose, error := ph.body_pose(capability, key)

            if error != .None {
                r.execution_fail(capability, error)
                return 0, false
            }

            origin := pose.position
            origin.y += 0.5
            hits: [35]ph.Ray_Hit
            count, query_error := ph.ray(capability, origin, {0, -2, 0}, hits[:])

            if query_error != .None {
                r.execution_fail(capability, query_error)
                return 0, false
            }

            return count, true
        }}
}

step :: proc(game: ^common.Game, controls: [2]common.Control, joins, leaves: u64, ctx: ^r.Step(common.Event)) {
    execution := ctx.execution
    ops := operations(&execution)

    if !common.pre_step(game, controls, ops) {
        r.abort(ctx)
        return
    }

    if ph.step(execution) != .None {
        r.abort(ctx)
        return
    }

    observed: [70]ph.Sensor_Event
    count, error := ph.sensor_events(execution, observed[:])

    if error != .None {
        r.abort(ctx)
        return
    }

    observations: [70]common.Observation

    for event, index in observed[:count] {
        observations[index] = {event.sensor, event.visitor, event.began}
    }

    events: [net.GAME_EVENTS]common.Event
    n, ok := common.post_step(game, observations[:count], events[:])

    if !ok {
        r.abort(ctx)
        return
    }

    for event in events[:n] {
        r.emit(ctx, 1, event.serial, event)
    }
}

action :: proc(game: ^common.Game, seat: u16, value: common.Action, ctx: ^r.Step(common.Event)) -> bool {
    execution := ctx.execution
    event, applied := common.apply_action(game, seat, value, operations(&execution))

    if r.execution_status(execution) != .None {
        return false
    }

    if applied && event.serial != 0 {
        r.emit(ctx, 1, event.serial, event)
    }

    return applied
}

model :: proc(codec: ^Codec) -> net.Model(common.Game, common.Control, common.Action, common.Event, 2) {
    return {
        complete_state = true,
        complete_codec = codec.value,
        action_timing = .Receipt,
        step = step,
        action = action,
        control_valid = common.control_valid,
        action_valid = common.action_valid,
        state_valid = common.game_valid,
        hold = proc(value: common.Control) -> common.Control {
            return value
        },
        event_owner = proc(event: common.Event) -> u16 {
            return event.seat
        },
    }
}

config :: proc(catalog: ^b.Recovery_Catalog, initial: u32) -> ph.Config {
    identity, status := b.recovery_catalog_identity(catalog)
    assert(status == .Ok)
    build: u64

    for value, index in identity.build_target[:8] {
        build |= u64(value) << uint(index * 8)
    }

    result := ph.config_default(common.ASSET_DECLARATION, build)
    result.initial_dynamic_bodies = initial
    result.asset_count = 5

    for asset, index in common.assets() {
        shape := b.shape_def_default()
        shape.enable_sensor_events = 1
        kind: ph.Asset_Kind

        switch asset.kind {
        case .Box:
            kind = .Box
        case .Sphere:
            kind = .Sphere
        case .Capsule:
            kind = .Capsule
        case .Hull, .Mesh:
            panic("Replay Box3D slice config requires primitive assets")
        }

        result.assets[index] = {
            id     = asset.id,
            kind   = kind,
            shape  = shape,
            radius = asset.radius,
        }

        if kind == .Box {
            result.assets[index].half_extents = asset.a
        } else {
            result.assets[index].center_a = asset.a
            result.assets[index].center_b = asset.b
        }
    }

    return result
}

rules :: proc(initial, seed: u32) -> bd.Digest {
    adapter := bd.hash_bytes(transmute([]u8)#load("model.odin"))
    shared := common.game_rules()
    launch: [8]u8

    for i in 0 ..< 4 {
        launch[i] = u8(initial >> uint(i * 8))
        launch[i + 4] = u8(seed >> uint(i * 8))
    }

    result, error := bd.hash_descriptors(
        "odin-godot.replay-box3d-slice.v1",
        []bd.Descriptor {
            {tag = "adapter", bytes = adapter[:]},
            {tag = "common", bytes = shared[:]},
            {tag = "launch", bytes = launch[:]},
        },
    )
    assert(error == .None)
    return result
}
