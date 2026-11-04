package scrapyard_game

import "core:math"
import r "godot:replay"
import p "godot:replay/play"
import arena "../arena"

world_flash :: proc(w: ^World, position: [2]f32, radius: f32, status: u8, credit: Credit, ctx: ^r.Step(Event)) {
    if !add_count(&w.visual_serial, 1, ctx) {
        return
    }

    flash_add(
        w,
        Flash {
            kind = .Reaction,
            status = status,
            seat = credit.seat,
            generation = max(credit.generation, 1),
            serial = w.visual_serial,
            origin = position,
            radius = radius,
            until = ctx.tick + 17,
        },
        ctx,
    )
}

// One tick's target selection, shared by the concrete brains. This is scratch
// input to a brain, never additional simulation state.
Mob_Pursuit :: struct {
    target: int,
    position: [2]f32,
    distance, speed: f32,
}

mob_pursuit :: proc(w: ^World, index: int) -> (Mob_Pursuit, bool) {
    best := f32(1e18)
    target := -1

    for player, seat in w.players {
        if !player.connected || !player.in_yard || player.hp == 0 {
            continue
        }

        delta := player.position - w.mobs.values[index].position
        distance := delta[0] * delta[0] + delta[1] * delta[1]

        if distance < best {
            best, target = distance, seat
        }
    }

    if target < 0 {
        return {}, false
    }

    prey := w.players[target].position
    distance := math.sqrt(best)
    mob := &w.mobs.values[index]
    speed := w.catalog.mobs[mob.kind].speed / f32(HZ) * status_multiplier(w, mob.fx[:], .Move)
    return Mob_Pursuit{target, prey, distance, speed}, true
}

mob_brain :: proc(w: ^World, index: int, feedback: ^Notices, ctx: ^r.Step(Event)) {
    pursuit, found := mob_pursuit(w, index)

    if !found {
        return
    }

    mob := &w.mobs.values[index]

    if w.catalog.mobs[mob.kind].pulse.windup > 0 {
        stormcaller_brain(w, index, pursuit.target, pursuit.distance, pursuit.speed, feedback, ctx)
        return
    }

    switch mob.kind {
    case 2:
        spitter_brain(w, index, pursuit, ctx)
    case 3:
        popper_brain(w, index, pursuit, feedback, ctx)
    case 4:
        titan_brain(w, index, pursuit, feedback, ctx)
    case:
        melee_brain(w, index, pursuit, feedback, ctx)
    }
}

spitter_brain :: proc(w: ^World, index: int, pursuit: Mob_Pursuit, ctx: ^r.Step(Event)) {
    mob := &w.mobs.values[index]
    row := w.catalog.mobs[mob.kind]
    prey := pursuit.position
    distance := pursuit.distance
    speed := pursuit.speed

    if distance > 300 {
        mob_move(w, mob, prey, speed, row.radius)
        return
    }

    delta := prey - mob.position

    if _, blocked := arena.clip(&w.layout, mob.position, delta); blocked {
        side := f32((index % 2) * 2 - 1)
        mob_move(
            w,
            mob,
            mob.position + [2]f32{-delta[1] * side + delta[0] * 0.35, delta[0] * side + delta[1] * 0.35},
            speed,
            row.radius,
        )
        return
    }

    if distance < 190 {
        mob_move(w, mob, prey, speed, row.radius, away = true)
    }

    if ctx.tick >= mob.next_act {
        if d := prey - mob.position; d[0] * d[0] + d[1] * d[1] < 1 {
            mob.next_act = ctx.tick + 150
            return
        }

        if mob.shots == max(u32) {
            r.abort(ctx)
            return
        }

        delta = prey - mob.position
        distance = math.sqrt(delta[0] * delta[0] + delta[1] * delta[1])
        direction := delta / distance
        shot := Shot {
            kind = .Spit,
            generation = w.mobs.generations[index],
            serial = mob.shots + 1,
            position = mob.position + direction * min(f32(14), distance * 0.5),
            velocity = direction * 8,
            ttl = 60,
            damage = 1,
        }

        if _, ok := r.pool_insert(&w.shots, shot); ok {
            mob.shots += 1
            mob.next_act = ctx.tick + 150
            add_count(&w.spits, 1, ctx)
        }
    }
}

popper_brain :: proc(w: ^World, index: int, pursuit: Mob_Pursuit, feedback: ^Notices, ctx: ^r.Step(Event)) {
    mob := &w.mobs.values[index]
    row := w.catalog.mobs[mob.kind]
    prey := pursuit.position
    distance := pursuit.distance
    speed := pursuit.speed

    if distance > 42 {
        mob_move(w, mob, prey, speed, row.radius)
        return
    }

    for player, seat in w.players {
        if player.connected && player.in_yard && player.hp > 0 && p.in_reach(mob.position, player.position, 100) {
            hurt_player(w, seat, 2, mob.position, feedback, ctx)
        }
    }

    mob.hp, mob.reap_at = 0, ctx.tick + 30
    add_count(&w.pops, 1, ctx)
    add_count(&w.defeated, 1, ctx)

    if mob.directed && !p.director_note_death(&w.director, ctx.tick, w.waves[:w.wave_count]) {
        r.abort(ctx)
    }

    world_flash(w, mob.position, 100, 0, Credit{}, ctx)
}

titan_brain :: proc(w: ^World, index: int, pursuit: Mob_Pursuit, feedback: ^Notices, ctx: ^r.Step(Event)) {
    mob := &w.mobs.values[index]
    row := w.catalog.mobs[mob.kind]
    prey := pursuit.position
    distance := pursuit.distance
    speed := pursuit.speed
    fraction := f32(mob.hp) / f32(mob.max_hp)
    enraged := fraction <= 0.33

    if mob.tele.left > 0 {
        if p.telegraph_tick(&mob.tele) {
            for player, seat in w.players {
                if player.connected &&
                   player.in_yard &&
                   player.hp > 0 &&
                   p.in_reach(mob.position, player.position, 180) {
                    hurt_player(w, seat, 2, mob.position, feedback, ctx)
                }
            }

            mob.next_act = ctx.tick + (enraged ? 90 : 180)
            add_count(&w.slams, 1, ctx)
            world_flash(w, mob.position, 180, 0, Credit{}, ctx)
        }

        return
    }

    if fraction <= 0.66 && ctx.tick >= mob.next_add {
        titan_spawn_adds(w, index, ctx)
        mob = &w.mobs.values[index]
    }

    if ctx.tick >= mob.next_act && distance <= 180 * 0.9 {
        p.telegraph_start(&mob.tele, enraged ? 24 : 48)
        return
    }

    mob_move(w, mob, prey, speed * (enraged ? 1.6 : 1), row.radius)
}

melee_brain :: proc(w: ^World, index: int, pursuit: Mob_Pursuit, feedback: ^Notices, ctx: ^r.Step(Event)) {
    mob := &w.mobs.values[index]
    row := w.catalog.mobs[mob.kind]
    prey := pursuit.position
    distance := pursuit.distance
    speed := pursuit.speed
    target := pursuit.target

    if distance <= 24 + row.radius - 14 {
        if ctx.tick >= mob.next_act {
            mob.next_act = ctx.tick + u64(HZ)
            hurt_player(w, target, row.bite, mob.position, feedback, ctx)
        }
    } else {
        mob_move(w, mob, prey, speed, row.radius)
    }
}

titan_spawn_adds :: proc(w: ^World, index: int, ctx: ^r.Step(Event)) {
    mob := &w.mobs.values[index]
    // Reserve the pair together. A saturated pool retries on the next tick.
    candidate := w.mobs
    left := Mob {
        hp = w.catalog.mobs[0].hp,
        max_hp = w.catalog.mobs[0].hp,
        position = {clamp(mob.position[0] - 40, arena.MARGIN, arena.WIDTH - arena.MARGIN), mob.position[1]},
    }
    right := left
    right.position[0] = clamp(mob.position[0] + 40, arena.MARGIN, arena.WIDTH - arena.MARGIN)
    _, a := r.pool_insert(&candidate, right)
    _, b := r.pool_insert(&candidate, left)

    if a && b {
        w.mobs = candidate
        mob = &w.mobs.values[index]
        mob.next_add = ctx.tick + 210
        add_count(&w.adds, 2, ctx)
    }
}

spit_step :: proc(w: ^World, index: int, feedback: ^Notices, ctx: ^r.Step(Event)) {
    shot := &w.shots.values[index]
    nearest, blocked, normal := arena.contact(&w.layout, shot.position, shot.velocity)
    target := -1

    for player, seat in w.players {
        if !player.connected || !player.in_yard || player.hp == 0 {
            continue
        }

        at, hit := p.segment_circle(shot.position, shot.position + shot.velocity, player.position, 14)

        if hit && (at < nearest || at == nearest && !blocked && target < 0) {
            nearest, target = at, seat
        }
    }

    if target >= 0 {
        hurt_player(w, target, shot.damage, shot.position, feedback, ctx)
    }

    shot.position += shot.velocity * nearest
    shot.ttl -= 1

    if blocked && target < 0 {
        wall_notice(w, index, normal, feedback)
    }

    if target >= 0 ||
       blocked ||
       shot.ttl == 0 ||
       shot.position[0] < 0 ||
       shot.position[0] > arena.WIDTH ||
       shot.position[1] < 0 ||
       shot.position[1] > arena.HEIGHT {
        r.pool_remove(&w.shots, r.Handle(Shot){u32(index), w.shots.generations[index]})
    }
}
