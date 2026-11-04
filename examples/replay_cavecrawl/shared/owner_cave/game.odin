package owner_cave

import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import o "godot:replay/owned"
import p "godot:replay/play"
import base "../cave"

OWNER_MOTION :: true
CONTENT :: u64(0x434156454f574e33)
SEATS :: base.SEATS
HZ :: base.HZ
REACH :: base.REACH
BODY_RADIUS :: base.BODY_RADIUS
WALK_SPEED :: base.WALK_SPEED
MAX_WAVES :: base.MAX_WAVES
GEM :: base.GEM
TORCH :: base.TORCH
Floor :: base.Floor
Event :: base.Event
scatter :: base.scatter
floor_valid :: base.floor_valid

World :: struct {
    using cave: base.World,
    epoch:      u64,
    avatars:    [SEATS]o.State(o.Pose2),
    prop:       o.State(o.Pose2),
}

Control :: struct {
    move:         [2]i8,
    avatar, prop: o.Sample(o.Pose2),
}

// Cooperative observations are bounded and scoped, not proof of honest motion.
// The original manual owner movement is not clipped to the viewport or rift.
pose_valid :: proc(_: rawptr, value: o.Pose2) -> bool {
    return o.pose2_valid(value, {{-65536, -65536}, {65536, 65536}, 256, 0}) && value.rotation == 0
}

rules :: proc() -> o.Rules(o.Pose2) {
    return {valid = pose_valid}
}

world_floor :: proc(w: ^World) -> Floor {
    return base.world_floor(&w.cave)
}

world_items :: proc(w: ^World, item: p.Item_Id) -> u32 {
    return base.world_items(&w.cave, item)
}

initial :: proc(
    seed: u32 = 1337,
    floors: [2]Floor = base.FLOORS,
    staging: bool = false,
    dedicated: bool = false,
) -> World {
    w := World {
        cave  = base.initial(seed, floors, staging, dedicated),
        epoch = 1,
    }
    assert(o.init(&w.prop, {2, 0, 1}, 1, 0, 0, o.Pose2{position = w.relic.position}, rules()) == .None)
    return w
}

control_valid :: proc(c: Control) -> bool {
    return base.control_valid({move = c.move}) && o.sample_valid(c.avatar, rules()) && o.sample_valid(c.prop, rules())
}

state_valid :: proc(w: World) -> bool {
    if !base.state_valid(w.cave) ||
       w.epoch == 0 ||
       !o.valid(w.prop, rules()) ||
       w.prop.epoch != w.epoch ||
       w.prop.key != (o.Key{2, 0, 1}) ||
       w.prop.owner != w.relic.carrier ||
       w.prop.value.position != w.relic.position {
        return false
    }

    for player, i in w.players {
        body := w.avatars[i]

        if !player.initialized {
            if !reflect.equal(body, o.State(o.Pose2){}) {
                return false
            }

            continue
        }

        if !o.valid(body, rules()) ||
           body.epoch != w.epoch ||
           body.key.kind != 1 ||
           body.key.index != u32(i) ||
           body.owner != u16(i + 1) ||
           body.value.position != player.position {
            return false
        }
    }

    return true
}

model :: proc() -> net.Model(World, Control, Action, Event, SEATS) {
    return {
        control_timing = .Latest_Observation,
        action_timing = .Receipt,
        step = step,
        action = act,
        reset_player = reset_player,
        control_valid = control_valid,
        action_valid = action_valid,
        state_valid = state_valid,
        hold = proc(c: Control) -> Control {
            return c
        },
        authority = {id = 1, apply = observe_authority},
    }
}

reset_player :: proc(w: ^World, seat: u16, ctx: ^r.Step(Event)) {
    body := &w.avatars[seat - 1]
    generation := body.key.generation

    if generation == max(u32) || w.relic.carrier == seat && w.relic.version == max(u32) {
        r.abort(ctx)
        return
    }

    base.reset_player(&w.cave, seat, ctx)

    if ctx.error != .None {
        return
    }

    body^ = {}

    if o.init(
           body,
           {1, u32(seat - 1), generation + 1},
           ctx.epoch,
           ctx.tick,
           seat,
           o.Pose2{position = w.players[seat - 1].position},
           rules(),
       ) !=
       .None {
        r.abort(ctx)
        return
    }

    reconcile(w, ctx, false)
}

observe_authority :: proc(w: ^World, authority: net.Authority_Observation, ctx: ^r.Step(Event)) {
    if ctx.epoch < w.epoch {
        r.abort(ctx)
        return
    }

    for &body in w.avatars {
        if body.key.generation != 0 && o.bind_epoch(&body, ctx.epoch, ctx.tick) != .None {
            r.abort(ctx)
            return
        }
    }

    if o.bind_epoch(&w.prop, ctx.epoch, ctx.tick) != .None {
        r.abort(ctx)
        return
    }

    w.epoch = ctx.epoch
    base.observe_authority(&w.cave, authority, ctx)
    reconcile(w, ctx, false)
}

// Gameplay teleports and ownership decisions cut observation scopes so an old
// in-flight sample cannot undo a floor transition, respawn, drop or fresh seat.
reconcile :: proc(w: ^World, ctx: ^r.Step(Event), floor_change: bool, revived: u64 = 0) {
    if ctx.error != .None {
        return
    }

    for player, i in w.players {
        if !player.initialized {
            continue
        }

        body := &w.avatars[i]

        if body.key.generation == 0 {
            if o.init(
                   body,
                   {1, u32(i), 1},
                   ctx.epoch,
                   ctx.tick,
                   u16(i + 1),
                   o.Pose2{position = player.position},
                   rules(),
               ) !=
               .None {
                r.abort(ctx)
                return
            }
        } else if floor_change || revived & (u64(1) << uint(i)) != 0 || body.value.position != player.position {
            if o.cut(body, u16(i + 1), o.Pose2{position = player.position}, ctx.tick, rules()) != .None {
                r.abort(ctx)
                return
            }
        }
    }

    if floor_change || w.prop.owner != w.relic.carrier || w.prop.value.position != w.relic.position {
        value := w.prop.value
        value.position = w.relic.position

        if floor_change {
            value.linear = {}
        }

        if o.cut(&w.prop, w.relic.carrier, value, ctx.tick, rules()) != .None {
            r.abort(ctx)
        }
    }
}

step :: proc(w: ^World, controls: [SEATS]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
    step_impacts(w, controls, joins, leaves, ctx, true)
}

// Explicit historical replay entry point; live model() always emits impacts.
step_impacts :: proc(
    w: ^World,
    controls: [SEATS]Control,
    joins, leaves: u64,
    ctx: ^r.Step(Event),
    impact_events: bool,
) {
    depth, run, phase := w.depth, w.lobby.run, w.lobby.phase
    dead := dead_mask(w)

    for control, i in controls {
        bit := u64(1) << uint(i)
        player := &w.players[i]

        if leaves & bit != 0 || (!player.connected && joins & bit == 0) || w.lobby.phase == .Waiting {
            continue
        }

        // Owners stop their local movement from observed health/stage. Late pose
        // samples still settle, as in the original owner lane; life/teleport cuts
        // prevent an earlier lineage from undoing a reset.
        if control.avatar.sequence != 0 {
            accepted := o.accept(&w.avatars[i], u16(i + 1), control.avatar, ctx.tick, rules())

            if accepted.applied {
                player.position = w.avatars[i].value.position
            }
        }

        if control.prop.sequence != 0 {
            accepted := o.accept(&w.prop, u16(i + 1), control.prop, ctx.tick, rules())

            if accepted.applied {
                w.relic.position = w.prop.value.position
            }
        }
    }

    base.step_motion(&w.cave, [SEATS]base.Control{}, joins, leaves, ctx, false, impact_events)
    reconcile(w, ctx, w.depth != depth || w.lobby.run != run || w.lobby.phase != phase, dead &~ dead_mask(w))
}

act :: proc(w: ^World, seat: u16, a: Action, ctx: ^r.Step(Event)) -> bool {
    depth, run, phase := w.depth, w.lobby.run, w.lobby.phase
    dead := dead_mask(w)

    if (a.verb == .Carry || a.verb == .Set_Down || a.verb == .Lobby) && w.relic.version == max(u32) {
        r.abort(ctx)
        return false
    }

    if seat < 1 || seat > SEATS {
        return false
    }

    origin := w.players[seat - 1].position

    if a.origin_kind == .Owner_Pose {
        value, error := o.read_context(&w.avatars[seat - 1], seat, a.origin, ctx.tick, rules())

        if error != .None {
            return false
        }

        origin = value.position

        if a.verb == .Throw {
            origin = cast_origin(origin, w.players[seat - 1].position)
        }
    }

    applied := base.act_at(&w.cave, seat, command(a), origin, ctx)

    if applied {
        reconcile(w, ctx, w.depth != depth || w.lobby.run != run || w.lobby.phase != phase, dead &~ dead_mask(w))
    }

    return applied
}

// A new life invalidates samples even when respawn/revive leaves the position
// unchanged. The owner may still hold a delayed pre-death local pose.
dead_mask :: proc(w: ^World) -> u64 {
    mask := u64(0)

    for player, i in w.players {
        if player.initialized && player.hp == 0 {
            mask |= u64(1) << uint(i)
        }
    }

    return mask
}
