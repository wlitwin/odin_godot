package scrapyard_game

import r "godot:replay"
import p "godot:replay/play"
import content "../content"

STORMCALLER :: u8(6)

Pulse_Phase :: enum {
    Waiting,
    Started,
    Charging,
    Fired,
}

// Composes the existing saved telegraph and cooldown fields. All transitions
// depend on supplied state/ticks; there are no engine timers or hidden counters.
pulse_step :: proc(tele: ^p.Telegraph, next: ^u64, tick: u64, can_start: bool, def: content.Pulse_Def) -> Pulse_Phase {
    if tele.left > 0 {
        if !p.telegraph_tick(tele) {
            return .Charging
        }

        next^ = tick + u64(def.cooldown)
        return .Fired
    }

    if tick < next^ || !can_start {
        return .Waiting
    }

    p.telegraph_start(tele, def.windup)
    return .Started
}

stormcaller_brain :: proc(
    w: ^World,
    index: int,
    target: int,
    distance, speed: f32,
    feedback: ^Notices,
    ctx: ^r.Step(Event),
) {
    mob := &w.mobs.values[index]
    def := w.catalog.mobs[mob.kind].pulse

    if ctx.tick > max(u64) - u64(def.cooldown) {
        r.abort(ctx)
        return
    }

    phase := pulse_step(&mob.tele, &mob.next_act, ctx.tick, distance <= def.radius * .9, def)

    switch phase {
    case .Started, .Charging:
        return
    case .Fired:
        for player, seat in w.players {
            if player.connected &&
               player.in_yard &&
               player.hp > 0 &&
               p.in_reach(mob.position, player.position, def.radius) {
                hurt_player(w, seat, def.damage, mob.position, feedback, ctx)
            }
        }

        world_flash(w, mob.position, def.radius, 6, Credit{}, ctx)
    case .Waiting:
        // Commit to the warning while charging. Between attacks, close the gap.
        mob_move(w, mob, w.players[target].position, speed, w.catalog.mobs[mob.kind].radius)
    }
}
