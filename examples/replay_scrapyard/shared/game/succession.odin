package scrapyard_game

import r "godot:replay"
import net "godot:replay/net"

SUCCESSION_GRACE :: u64(150)

SUCCESSION_POLICY :: u64(0x5253595355434331)

succession_policy :: proc() -> net.Authority_Policy(World, Event) {
    return {id = SUCCESSION_POLICY, apply = observe_authority}
}

// Original succ_fixups rearms these host-local timers at the restored tick.
// Record the epoch in the world so replay, a second recovery before stepping,
// and dedicated-to-dedicated takeover all observe the same transition.
observe_authority :: proc(w: ^World, _: net.Authority_Observation, ctx: ^r.Step(Event)) {
    if ctx.epoch == 0 || ctx.epoch < w.authority_epoch {
        r.abort(ctx)
        return
    }

    if w.authority_epoch == ctx.epoch {
        return
    }

    if w.authority_epoch != 0 {
        if ctx.tick == 0 || ctx.tick - 1 > max(u64) - SUCCESSION_GRACE {
            r.abort(ctx)
            return
        }

        boundary := ctx.tick - 1
        w.director.rest_until = boundary + SUCCESSION_GRACE

        for alive, i in w.mobs.alive {
            if !alive {
                continue
            }

            w.mobs.values[i].next_act = boundary + SUCCESSION_GRACE
            w.mobs.values[i].next_add = boundary + SUCCESSION_GRACE
        }

        if w.stage == .Over {
            w.over_until = boundary + OVER_TICKS
        }
    }

    // Initial startup has no takeover grace. Existing telegraphs, projectiles,
    // status effects and movement are left to their ordinary simulation steps.
    w.authority_epoch = ctx.epoch
}
