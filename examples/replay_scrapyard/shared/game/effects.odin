package scrapyard_game

import "core:reflect"
import r "godot:replay"
import p "godot:replay/play"
import content "../content"

Credit :: struct {
    seat: u16,
    generation: u32,
}

Target_Kind :: enum u8 {
    Player,
    Mob,
}

Target :: struct {
    kind: Target_Kind,
    index: u8,
    generation: u32,
}

Multiplier :: enum {
    Move,
    Taken,
    Dealt,
}

CHAIN_DEPTH :: u8(4)

REACTION_WORK :: u32(65536)

add_count :: proc(value: ^u32, amount: u32, ctx: ^r.Step(Event)) -> bool {
    if value^ > max(u32) - amount {
        r.abort(ctx)
        return false
    }

    value^ += amount
    return true
}

spend_work :: proc(feedback: ^Notices, ctx: ^r.Step(Event)) -> bool {
    if feedback.work >= REACTION_WORK {
        r.abort(ctx)
        return false
    }

    feedback.work += 1
    return true
}

credit_valid :: proc(c: Credit) -> bool {
    return c.seat == 0 ? c.generation == 0 : c.seat <= SEATS && c.generation > 0
}

credited :: proc(w: ^World, c: Credit) -> ^Player {
    if c.seat == 0 || c.seat > SEATS || w.players[c.seat - 1].generation != c.generation {
        return nil
    }

    return &w.players[c.seat - 1]
}

player_target :: proc(w: ^World, index: int) -> Target {
    return {.Player, u8(index), w.players[index].generation}
}

mob_target :: proc(w: ^World, index: int) -> Target {
    return {.Mob, u8(index), w.mobs.generations[index]}
}

effects_for :: proc(w: ^World, target: Target) -> (fx: []p.Effect, credits: []Credit, position: [2]f32, ok: bool) {
    if target.kind == .Player && target.index < SEATS {
        player := &w.players[target.index]

        if player.generation == target.generation && player.in_yard {
            return player.fx[:], player.fx_credit[:], player.position, true
        }
    } else if target.kind == .Mob &&
       target.index < MAX_MOBS &&
       w.mobs.alive[target.index] &&
       w.mobs.generations[target.index] == target.generation {
        mob := &w.mobs.values[target.index]
        return mob.fx[:], mob.fx_credit[:], mob.position, true
    }

    return
}

effects_valid :: proc(w: World) -> bool {
    value := w
    return effects_valid_borrowed(&value)
}

// Synchronous borrowed read; never retain or mutate the world.
@(private)
effects_valid_borrowed :: proc(w: ^World) -> bool {
    valid_set :: proc(catalog: ^content.Catalog, effects: []p.Effect, credits: []Credit) -> bool {
        seen := u16(0)

        for e, i in effects {
            if !credit_valid(credits[i]) {
                return false
            }

            if e.kind == 0 {
                if !reflect.equal(e, p.Effect{}) || !reflect.equal(credits[i], Credit{}) {
                    return false
                }

                continue
            }

            if !content.status_present(catalog, e.kind) ||
               e.left == 0 ||
               e.power == 0 ||
               e.power > catalog.statuses[e.kind].max_stacks ||
               seen & (u16(1) << uint(e.kind)) != 0 {
                return false
            }

            seen |= u16(1) << uint(e.kind)
        }

        return true
    }

    for &player in w.players {
        if !valid_set(&w.catalog, player.fx[:], player.fx_credit[:]) {
            return false
        }
    }

    for &mob, i in w.mobs.values {
        if w.mobs.alive[i] && !valid_set(&w.catalog, mob.fx[:], mob.fx_credit[:]) {
            return false
        }
    }

    for kind in w.encounter_kinds {
        if !content.mob_present(&w.catalog, kind) {
            return false
        }
    }

    if w.encounter_placed {
        if w.encounter_count > 4 {
            return false
        }

        for point in w.encounter_positions {
            if !position_valid(point) {
                return false
            }
        }
    }

    return true
}

status_multiplier :: proc(w: ^World, effects: []p.Effect, which: Multiplier) -> f32 {
    result := f32(1)

    for e in effects {
        if e.kind == 0 {
            continue
        }

        row := w.catalog.statuses[e.kind]

        switch which {
        case .Move:
            result *= row.move_mult
        case .Taken:
            result *= row.taken_mult
        case .Dealt:
            result *= row.dealt_mult
        }
    }

    return result
}

scaled_damage :: proc(damage: u8, multiplier: f32) -> u8 {
    return u8(clamp(int(f32(damage) * multiplier + 0.5), 0, 255))
}

// Preserve original slot-order priority, then the first matching authored row.
// Credit lives beside the effect slot and is updated even by a capped refresh.
apply_status :: proc(
    w: ^World,
    target: Target,
    kind: u8,
    credit: Credit,
    feedback: ^Notices,
    ctx: ^r.Step(Event),
    depth: u8 = CHAIN_DEPTH,
) {
    if !spend_work(feedback, ctx) || !content.status_present(&w.catalog, kind) {
        return
    }

    fx, credits, position, found := effects_for(w, target)

    if !found {
        return
    }

    if depth > 0 {
        for e in fx {
            if e.kind == 0 {
                continue
            }

            row, has := content.combo_find(&w.catalog, e.kind, kind)

            if !has {
                continue
            }

            if row.consume {
                for &effect, i in fx {
                    if effect.kind == e.kind {
                        effect = {}
                        credits[i] = {}
                    }
                }
            }

            if !add_count(&w.reactions, 1, ctx) {
                return
            }

            switch row.reaction {
            case .Detonate:
                area_damage(w, position, row.radius, row.damage, 0, credit, feedback, ctx)
                world_flash(w, position, row.radius, e.kind, credit, ctx)
            case .Transmute:
                if row.output != 0 {
                    apply_status(w, target, row.output, credit, feedback, ctx, depth - 1)
                }
            case .Spread:
                out := row.output != 0 ? row.output : kind

                for alive, i in w.mobs.alive {
                    if alive &&
                       w.mobs.values[i].hp > 0 &&
                       p.in_reach(position, w.mobs.values[i].position, row.radius) {
                        spread_arc(w, position, w.mobs.values[i].position, out, credit, ctx)
                        apply_status(w, mob_target(w, i), out, credit, feedback, ctx, depth - 1)
                    }
                }

                for player, i in w.players {
                    if player.connected &&
                       player.in_yard &&
                       player.hp > 0 &&
                       p.in_reach(position, player.position, row.radius) {
                        spread_arc(w, position, player.position, out, credit, ctx)
                        apply_status(w, player_target(w, i), out, credit, feedback, ctx, depth - 1)
                    }
                }
            }

            return
        }
    }

    row := w.catalog.statuses[kind]
    duration := row.duration

    if target.kind == .Mob {
        if source := credited(w, credit); source != nil && has_part(source.parts, 2) {
            duration = u16(min(u32(duration) * 3 / 2, u32(max(u16))))
        }
    }

    if index, ok := p.effect_stack(fx, kind, row.max_stacks, duration); ok {
        credits[index] = credit
        add_count(&w.status_applied, 1, ctx)
    } else {
        add_count(&w.status_refused, 1, ctx)
    }
}

hurt_player :: proc(w: ^World, index: int, damage: u8, origin: [2]f32, feedback: ^Notices, ctx: ^r.Step(Event)) {
    if !spend_work(feedback, ctx) {
        return
    }

    player := &w.players[index]
    dealt := min(player.hp, damage)
    player.hp -= dealt

    if player.hp == 0 {
        turret_release_player(w, u16(index + 1))
    }

    notice(feedback, 2, index, u32(dealt), origin, ctx)
}

wound_mob :: proc(w: ^World, index: int, damage: u8, credit: Credit, feedback: ^Notices, ctx: ^r.Step(Event)) -> bool {
    if !spend_work(feedback, ctx) || !w.mobs.alive[index] {
        return false
    }

    mob := &w.mobs.values[index]
    dealt := min(u16(scaled_damage(damage, status_multiplier(w, mob.fx[:], .Taken))), mob.hp)

    if dealt == 0 {
        return false
    }

    mob.hp -= dealt
    player := credited(w, credit)

    if player != nil {
        add_count(&player.damage, u32(dealt), ctx)
        notice(feedback, 0, int(credit.seat - 1), u32(dealt), mob.position, ctx)
    }

    if mob.hp > 0 {
        return false
    }

    p.telegraph_cancel(&mob.tele)
    row := w.catalog.mobs[mob.kind]

    if row.prop {
        mob.reap_at = ctx.tick + 12
        add_count(&w.barrel_blasts, 1, ctx)
        area_damage(w, mob.position, row.boom_radius, row.boom_damage, row.boom_status, credit, feedback, ctx)
        world_flash(w, mob.position, row.boom_radius, row.boom_status, credit, ctx)
        return true
    }

    add_count(&w.defeated, 1, ctx)

    if mob.directed && !p.director_note_death(&w.director, ctx.tick, w.waves[:w.wave_count]) {
        r.abort(ctx)
    }

    if player != nil {
        add_count(&player.kills, 1, ctx)
        notice(feedback, 1, int(credit.seat - 1), 1, mob.position, ctx)
    }

    mob.reap_at = ctx.tick + (mob.kind == 4 ? 72 : 42)

    if mob.kind == 4 {
        for &runner in w.players {
            if runner.connected && runner.in_yard {
                add_count(&runner.cores, 3, ctx)
            }
        }

        for k in 0 ..< 5 {
            if !drop_scrap(w, mob.position + [2]f32{(f32(k) - 2) * 24, 0}, 3) {
                r.abort(ctx)
            }
        }
    } else if !drop_scrap(w, mob.position, 3) {
        r.abort(ctx)
    }

    return true
}

area_damage :: proc(
    w: ^World,
    position: [2]f32,
    radius: f32,
    damage, status: u8,
    credit: Credit,
    feedback: ^Notices,
    ctx: ^r.Step(Event),
) {
    for alive, i in w.mobs.alive {
        if alive && w.mobs.values[i].hp > 0 && p.in_reach(position, w.mobs.values[i].position, radius) {
            if damage > 0 && wound_mob(w, i, damage, credit, feedback, ctx) {
                continue
            }

            if status != 0 {
                apply_status(w, mob_target(w, i), status, credit, feedback, ctx)
            }
        }
    }

    for player, i in w.players {
        if player.connected && player.in_yard && player.hp > 0 && p.in_reach(position, player.position, radius) {
            if damage > 0 {
                hurt_player(w, i, damage, position, feedback, ctx)
            }

            if status != 0 {
                apply_status(w, player_target(w, i), status, credit, feedback, ctx)
            }
        }
    }
}

decay_effects :: proc(effects: []p.Effect, credits: []Credit) {
    p.effects_tick(effects)

    for e, i in effects {
        if e.kind == 0 {
            credits[i] = {}
        }
    }
}

player_upkeep :: proc(w: ^World, feedback: ^Notices, ctx: ^r.Step(Event)) {
    for &player, i in w.players {
        if !player.in_yard {
            continue
        }

        for &cooldown in player.ability_cd {
            p.cooldown_tick(&cooldown)
        }

        if p.gun_tick(&player.gun, w.catalog.guns[player.gun_id].mechanism) != .None {
            r.abort(ctx)
            return
        }

        decay_effects(player.fx[:], player.fx_credit[:])

        if player.hp == 0 {
            continue
        }

        for e in player.fx {
            if e.kind == 0 {
                continue
            }

            row := w.catalog.statuses[e.kind]

            if row.dot_every == 0 || row.dot_damage == 0 || e.left % row.dot_every != 0 {
                continue
            }

            amount := int(row.dot_damage) * int(e.power)
            add_count(&w.dot_pulses, 1, ctx)

            if amount > 0 {
                hurt_player(w, i, u8(clamp(amount, 1, 255)), player.position, feedback, ctx)
            } else {
                player.hp += min(u8(clamp(-amount, 1, 255)), max_health(player.parts) - player.hp)
            }
        }
    }
}

mob_upkeep :: proc(w: ^World, index: int, feedback: ^Notices, ctx: ^r.Step(Event)) {
    mob := &w.mobs.values[index]
    decay_effects(mob.fx[:], mob.fx_credit[:])

    for e, slot in mob.fx {
        if e.kind == 0 {
            continue
        }

        row := w.catalog.statuses[e.kind]

        // Match the original: negative DOT regenerates runners, not mobs.
        if row.dot_every == 0 || row.dot_damage <= 0 || e.left % row.dot_every != 0 {
            continue
        }

        add_count(&w.dot_pulses, 1, ctx)

        if wound_mob(
            w,
            index,
            u8(clamp(int(row.dot_damage) * int(e.power), 1, 255)),
            mob.fx_credit[slot],
            feedback,
            ctx,
        ) {
            break
        }
    }
}

// Capture the actual hop before the target recursively re-enters the rulebook.
// The existing bounded flash pool shortens old visuals when full; damage and
// status application still use the original order and recursion/work limits.
spread_arc :: proc(w: ^World, origin, end: [2]f32, status: u8, credit: Credit, ctx: ^r.Step(Event)) {
    if !add_count(&w.visual_serial, 1, ctx) {
        return
    }

    flash_add(
        w,
        Flash {
            kind = .Arc,
            status = status,
            seat = credit.seat,
            generation = max(credit.generation, 1),
            serial = w.visual_serial,
            origin = origin,
            end = end,
            until = ctx.tick + 17,
        },
        ctx,
    )
}
