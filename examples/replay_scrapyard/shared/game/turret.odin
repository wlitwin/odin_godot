package scrapyard_game

import "core:math"
import r "godot:replay"
import p "godot:replay/play"
import content "../content"
import arena "../arena"

MAX_TURRETS :: 8

TURRET_SHOT_KEY :: u64(0x54555252)

Turret :: struct {
    position, aim: [2]f32,
    ability: u8,
    ammo: u16,
    deployed_by, operator: Credit,
    operator_warp: u32,
    next_shot, last_shot: u64,
}

turret_for :: proc(w: ^World, seat: u16) -> (r.Handle(Turret), bool) {
    if seat < 1 || seat > SEATS {
        return {}, false
    }

    for alive, i in w.turrets.alive {
        if alive && w.turrets.values[i].operator == (Credit{seat, w.players[seat - 1].generation}) {
            return {u32(i), w.turrets.generations[i]}, true
        }
    }

    return {}, false
}

turret_operator :: proc(w: ^World, seat: u16) -> bool {
    _, found := turret_for(w, seat)
    return found
}

turret_release_player :: proc(w: ^World, seat: u16) {
    for alive, i in w.turrets.alive {
        if alive && w.turrets.values[i].operator.seat == seat {
            w.turrets.values[i].operator = {}
            w.turrets.values[i].operator_warp = 0
        }
    }
}

turret_cleanup :: proc(w: ^World) {
    for alive, i in w.turrets.alive {
        if alive {
            t := &w.turrets.values[i]

            if t.operator.seat == 0 {
                continue
            }

            player := &w.players[t.operator.seat - 1]
            radius := w.catalog.abilities[t.ability].turret.use_radius

            if !player.connected ||
               !player.in_yard ||
               player.hp == 0 ||
               player.generation != t.operator.generation ||
               player.warp != t.operator_warp ||
               !p.in_reach(player.position, t.position, radius) {
                t.operator = {}
                t.operator_warp = 0
            }
        }
    }
}

turret_deploy :: proc(w: ^World, point: [2]f32, ability: u8, credit: Credit, ctx: ^r.Step(Event)) -> bool {
    if !content.ability_present(&w.catalog, ability) {
        return false
    }

    if !position_valid(point) ||
       point[0] < arena.MARGIN ||
       point[0] > arena.WIDTH - arena.MARGIN ||
       point[1] < arena.MARGIN ||
       point[1] > arena.HEIGHT - arena.MARGIN {
        return false
    }

    if !credit_valid(credit) || credit.seat == 0 || w.players[credit.seat - 1].generation != credit.generation {
        return false
    }

    for cover in w.layout.covers {
        if point[0] > f32(cover.x) - 16 &&
           point[0] < (f32(cover.x) + f32(cover.w)) + 16 &&
           point[1] > f32(cover.y) - 16 &&
           point[1] < (f32(cover.y) + f32(cover.h)) + 16 {
            return false
        }
    }

    origin := w.players[credit.seat - 1].position

    if _, hit := arena.clip(&w.layout, origin, point - origin); hit {
        return false
    }

    for alive, i in w.turrets.alive {
        if alive && p.in_reach(point, w.turrets.values[i].position, 32) {
            return false
        }
    }

    row := w.catalog.abilities[ability]

    if row.family != .Turret || !content.turret_valid(row.turret) {
        return false
    }

    _, ok := r.pool_insert(
        &w.turrets,
        Turret{position = point, aim = {1, 0}, ability = ability, ammo = row.turret.ammo, deployed_by = credit},
    )
    return ok
}

turret_mount :: proc(w: ^World, seat: u16, handle: r.Handle(Turret)) -> bool {
    if seat < 1 || seat > SEATS || w.stage == .Staging || w.stage == .Over || turret_operator(w, seat) {
        return false
    }

    t, ok := r.pool_get(&w.turrets, handle)

    if !ok {
        return false
    }

    player := &w.players[seat - 1]

    if !player.connected ||
       !player.in_yard ||
       player.hp == 0 ||
       t.operator.seat != 0 ||
       t.ammo == 0 ||
       !p.in_reach(player.position, t.position, w.catalog.abilities[t.ability].turret.use_radius) {
        return false
    }

    if _, hit := arena.clip(&w.layout, player.position, t.position - player.position); hit {
        return false
    }

    t.operator = {seat, player.generation}
    t.operator_warp = player.warp
    t.aim = player.aim
    player.dash_until = 0
    player.dash_velocity = {}
    player.revive = {}
    return true
}

turret_dismount :: proc(w: ^World, seat: u16, handle: r.Handle(Turret)) -> bool {
    t, ok := r.pool_get(&w.turrets, handle)

    if !ok || seat < 1 || seat > SEATS || t.operator != (Credit{seat, w.players[seat - 1].generation}) {
        return false
    }

    t.operator = {}
    t.operator_warp = 0
    return true
}

turret_nearest :: proc(w: ^World, seat: u16) -> (r.Handle(Turret), bool) {
    if seat < 1 || seat > SEATS {
        return {}, false
    }

    best := f32(max(f32))
    result: r.Handle(Turret)
    found := false

    for alive, i in w.turrets.alive {
        if alive {
            t := w.turrets.values[i]
            delta := t.position - w.players[seat - 1].position
            distance := delta[0] * delta[0] + delta[1] * delta[1]
            radius := w.catalog.abilities[t.ability].turret.use_radius

            if distance <= radius * radius && distance < best {
                best = distance
                result = {u32(i), w.turrets.generations[i]}
                found = true
            }
        }
    }

    return result, found
}

turret_fire :: proc(w: ^World, seat: u16, ctx: ^r.Step(Event)) {
    handle, found := turret_for(w, seat)

    if !found {
        return
    }

    t, _ := r.pool_get(&w.turrets, handle)
    player := &w.players[seat - 1]
    t.aim = player.aim

    if ctx.tick < t.next_shot {
        return
    }

    def := w.catalog.abilities[t.ability].turret

    if player.shots == max(u32) || ctx.tick > max(u64) - u64(def.cadence) {
        r.abort(ctx)
        return
    }

    // Start inside the deployment clearance so the first sweep cannot skip cover.
    shot := Shot {
        kind = .Ballistic,
        seat = seat,
        generation = player.generation,
        serial = player.shots + 1,
        position = t.position + t.aim * 12,
        velocity = t.aim * def.speed,
        ttl = def.ttl,
        damage = def.damage,
    }

    if _, ok := r.pool_insert(&w.shots, shot); !ok {
        return
    } // No projectile: spend no ammo/cadence.

    player.shots += 1
    t.ammo -= 1
    t.next_shot = ctx.tick + u64(def.cadence)
    t.last_shot = ctx.tick
    r.emit(
        ctx,
        u64(player.generation) << 32 | u64(seat),
        TURRET_SHOT_KEY,
        Event{.Shot, seat, player.generation, player.shots, shot.position, 0},
    )

    if t.ammo == 0 {
        r.pool_remove(&w.turrets, handle)
    } // Occupancy lives in the removed entity.
}

turrets_valid :: proc(w: ^World) -> bool {
    if !pool_valid(w.turrets) {
        return false
    }

    occupied: [SEATS]bool

    for alive, i in w.turrets.alive {
        if alive {
            t := w.turrets.values[i]

            if !content.ability_present(&w.catalog, t.ability) ||
               w.catalog.abilities[t.ability].family != .Turret ||
               !position_valid(t.position) ||
               !credit_valid(t.deployed_by) ||
               t.deployed_by.seat == 0 {
                return false
            }

            def := w.catalog.abilities[t.ability].turret

            if t.ammo == 0 || t.ammo > def.ammo || !credit_valid(t.operator) {
                return false
            }

            for x in t.aim {
                if math.is_nan(x) || math.is_inf(x) || abs(x) > 1 {
                    return false
                }
            }

            if t.operator.seat == 0 {
                if t.operator_warp != 0 {
                    return false
                }

                continue
            }

            player := w.players[t.operator.seat - 1]

            if occupied[t.operator.seat - 1] ||
               !player.connected ||
               !player.in_yard ||
               player.hp == 0 ||
               player.generation != t.operator.generation ||
               player.warp != t.operator_warp ||
               !p.in_reach(player.position, t.position, def.use_radius) {
                return false
            }

            occupied[t.operator.seat - 1] = true
        }
    }

    return true
}
