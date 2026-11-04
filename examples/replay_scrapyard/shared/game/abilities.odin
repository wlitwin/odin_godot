package scrapyard_game

import "core:math"
import r "godot:replay"
import p "godot:replay/play"
import content "../content"

MAX_LOBS :: 64

MAX_ZONES :: 32

Lob :: struct {
    position, velocity: [2]f32,
    left: u16,
    ability: u8,
    credit: Credit,
    serial: u32,
}

Zone :: struct {
    position: [2]f32,
    left: u16,
    ability, wound: u8,
    credit: Credit,
    serial: u32,
}

point_valid :: proc(point: [2]f32) -> bool {
    return content.finite(point[0]) && content.finite(point[1]) && abs(point[0]) <= 65536 && abs(point[1]) <= 65536
}

action_valid :: proc(a: Action) -> bool {
    if a.kind > .Turret_Dismount || !profile_valid(a.profile) {
        return false
    }

    if a.kind == .Turret_Mount || a.kind == .Turret_Dismount {
        return a.turret.generation != 0 && a.turret.index < MAX_TURRETS && a.development == (Development{})
    }

    if a.turret != (r.Handle(Turret){}) {
        return false
    }

    if a.kind == .Dev_Edit {
        return development_valid(a.development)
    }

    if a.development != (Development{}) {
        return false
    }

    if a.kind == .Dash {
        return !a.aim_is_point && point_valid(a.aim) && abs(a.aim[0]) <= 1 && abs(a.aim[1]) <= 1
    }

    if a.kind == .Dev_Spawn {
        return a.slot < SEATS && a.item < content.MAX_MOBS && point_valid(a.aim)
    }

    if a.kind == .Set_Spray {
        return spray_ref_valid(a.image)
    }

    if a.kind == .Buy {
        return a.item >= 1 && a.item <= 5
    }

    if a.kind == .Workshop {
        return a.item < 4
    }

    if a.kind != .Cast {
        return true
    }

    if a.slot >= 2 || !point_valid(a.aim) {
        return false
    }

    return a.aim_is_point || (abs(a.aim[0]) <= 1 && abs(a.aim[1]) <= 1)
}

ability_id :: proc(player: ^Player, slot: int) -> u8 {
    id := player.profile.abilities[slot]
    return id == 0 ? u8(slot + 1) : id
}

abilities_valid :: proc(w: World) -> bool {
    value := w
    return abilities_valid_borrowed(&value)
}

// Synchronous borrowed read; never retain or mutate the world.
@(private)
abilities_valid_borrowed :: proc(w: ^World) -> bool {
    if !pool_valid(w.lobs) || !pool_valid(w.zones) {
        return false
    }

    for &player in w.players {
        for slot in 0 ..< 2 {
            id := ability_id(&player, slot)

            if !content.ability_present(&w.catalog, id) ||
               player.ability_cd[slot].remaining > u32(w.catalog.abilities[id].cooldown) {
                return false
            }
        }
    }

    for alive, i in w.lobs.alive {
        if alive {
            lob := w.lobs.values[i]

            if !content.ability_present(&w.catalog, lob.ability) ||
               w.catalog.abilities[lob.ability].family != .Lob ||
               lob.left == 0 ||
               !point_valid(lob.position) ||
               !credit_valid(lob.credit) ||
               lob.credit.seat == 0 ||
               lob.serial == 0 {
                return false
            }

            for value in lob.velocity {
                if !content.finite(value) || abs(value) > 100 {
                    return false
                }
            }
        }
    }

    for alive, i in w.zones.alive {
        if alive {
            zone := w.zones.values[i]

            if !content.ability_present(&w.catalog, zone.ability) ||
               w.catalog.abilities[zone.ability].family != .Zone ||
               zone.left == 0 ||
               zone.left > w.catalog.abilities[zone.ability].duration ||
               !point_valid(zone.position) ||
               !credit_valid(zone.credit) ||
               zone.credit.seat == 0 ||
               zone.serial == 0 {
                return false
            }
        }
    }

    return true
}

leash :: proc(claimed, anchor: [2]f32, radius: f32) -> [2]f32 {
    delta := claimed - anchor
    length := math.sqrt(delta[0] * delta[0] + delta[1] * delta[1])

    if length <= radius {
        return claimed
    }

    return anchor + delta * (radius / length)
}

// Action admission owns identity/reliability. This ordinary reducer owns the
// slot gate and all cross-entity consequences; no claimed caster origin is needed.
cast_ability :: proc(w: ^World, seat: u16, slot: u8, aim: [2]f32, aim_is_point: bool, ctx: ^r.Step(Event)) -> bool {
    if seat == 0 ||
       seat > SEATS ||
       !action_valid(Action{kind = .Cast, slot = slot, aim = aim, aim_is_point = aim_is_point}) {
        return false
    }

    player := &w.players[seat - 1]

    if !player.connected ||
       !player.in_yard ||
       player.hp == 0 ||
       turret_operator(w, seat) ||
       player.ability_cd[slot].remaining != 0 {
        return false
    }

    id := ability_id(player, int(slot))

    if !content.ability_present(&w.catalog, id) {
        return false
    }

    row := w.catalog.abilities[id]
    origin := player.position
    direction := aim_is_point ? aim - origin : aim
    point := aim_is_point ? aim : origin + aim * row.range
    length := math.sqrt(direction[0] * direction[0] + direction[1] * direction[1])

    if length > 0 {
        direction /= length
    }

    point = leash(point, origin, row.range)
    credit := Credit{seat, player.generation}

    if player.casts == max(u32) || player.casts_by_ability[id] == max(u32) {
        r.abort(ctx)
        return false
    }

    serial := player.casts + 1
    wound := scaled_damage(row.damage, status_multiplier(w, player.fx[:], .Dealt))
    resolved := Ability_Cast {
        id = id,
        origin = origin,
        direction = direction,
        point = point,
        has_direction = length > 0,
        credit = credit,
        serial = serial,
        wound = wound,
    }
    feedback: Notices

    if !apply_ability_cast(w, &resolved, &feedback, ctx) {
        return false
    }

    point = resolved.point

    if !p.cooldown_try(&player.ability_cd[slot], u32(row.cooldown)) {
        r.abort(ctx)
        return false
    }

    player.casts = serial
    player.casts_by_ability[id] += 1

    if row.family != .Lob && row.family != .Zone && row.family != .Turret {
        flash_add(
            w,
            Flash {
                kind = .Cast,
                ability = id,
                status = row.status,
                seat = seat,
                generation = player.generation,
                serial = serial,
                origin = row.family == .Buff ? point : origin,
                end = origin + direction * row.range,
                radius = row.radius,
                until = ctx.tick + 17,
            },
            ctx,
        )
    }

    flush(w, &feedback, ctx)
    return true
}

lob_step :: proc(w: ^World, feedback: ^Notices, ctx: ^r.Step(Event)) {
    for alive, i in w.lobs.alive {
        if alive {
            lob := &w.lobs.values[i]
            lob.position += lob.velocity
            lob.left -= 1

            if lob.left > 0 {
                continue
            }

            row := w.catalog.abilities[lob.ability]

            // The original lob delivers status only, despite the shared damage column.
            if row.status != 0 {
                for live, target in w.mobs.alive {
                    if live &&
                       w.mobs.values[target].hp > 0 &&
                       p.in_reach(lob.position, w.mobs.values[target].position, row.radius) {
                        apply_status(w, mob_target(w, target), row.status, lob.credit, feedback, ctx)
                    }
                }
            }

            world_flash(w, lob.position, row.radius, row.status, lob.credit, ctx)
            add_count(&w.lobs_landed, 1, ctx)
            r.pool_remove(&w.lobs, r.Handle(Lob){u32(i), w.lobs.generations[i]})
        }
    }
}

zone_step :: proc(w: ^World, feedback: ^Notices, ctx: ^r.Step(Event)) {
    for alive, i in w.zones.alive {
        if alive {
            zone := &w.zones.values[i]
            row := w.catalog.abilities[zone.ability]
            zone.left -= 1

            if zone.left == 0 {
                r.pool_remove(&w.zones, r.Handle(Zone){u32(i), w.zones.generations[i]})
                continue
            }

            if zone.left % row.pulse != 0 {
                continue
            }

            area_damage(w, zone.position, row.radius, zone.wound, row.status, zone.credit, feedback, ctx)
            add_count(&w.zone_pulses, 1, ctx)
        }
    }
}
