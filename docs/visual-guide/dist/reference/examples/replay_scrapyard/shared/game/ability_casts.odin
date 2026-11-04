package scrapyard_game

import "core:math"
import r "godot:replay"
import p "godot:replay/play"
import content "../content"

// Resolved inputs for one cast. Helpers may adjust the feedback point (Buff),
// but this value is never stored in World or sent as an action payload.
Ability_Cast :: struct {
    id: u8,
    origin, direction, point: [2]f32,
    has_direction: bool,
    credit: Credit,
    serial: u32,
    wound: u8,
}

apply_ability_cast :: proc(w: ^World, resolved: ^Ability_Cast, feedback: ^Notices, ctx: ^r.Step(Event)) -> bool {
    row := &w.catalog.abilities[resolved.id]

    switch row.family {
    case .Turret:
        return turret_deploy(w, resolved.point, resolved.id, resolved.credit, ctx)
    case .Lob:
        return ability_lob(w, resolved, row)
    case .Zone:
        return ability_zone(w, resolved, row, ctx)
    case .Cone:
        ability_cone(w, resolved, row, feedback, ctx)
    case .Nova:
        ability_nova(w, resolved, row, feedback, ctx)
    case .Buff:
        ability_buff(w, resolved, row, feedback, ctx)
    }

    return true
}

ability_lob :: proc(w: ^World, resolved: ^Ability_Cast, row: ^content.Ability) -> bool {
    delta := resolved.point - resolved.origin
    distance := math.sqrt(delta[0] * delta[0] + delta[1] * delta[1])

    if distance < 1 {
        return true
    } // A cast at the hand still consumes its cooldown.

    hand := min(f32(14), distance * 0.5)
    lob := Lob {
        position = resolved.origin + delta / distance * hand,
        velocity = delta / distance * row.speed,
        left = u16(max((distance - hand) / row.speed, 1)),
        ability = resolved.id,
        credit = resolved.credit,
        serial = resolved.serial,
    }
    _, inserted := r.pool_insert(&w.lobs, lob)
    return inserted
}

ability_zone :: proc(w: ^World, resolved: ^Ability_Cast, row: ^content.Ability, ctx: ^r.Step(Event)) -> bool {
    zone := Zone {
        position = resolved.point,
        left = row.duration,
        ability = resolved.id,
        wound = resolved.wound,
        credit = resolved.credit,
        serial = resolved.serial,
    }

    if _, inserted := r.pool_insert(&w.zones, zone); !inserted {
        return false
    }

    add_count(&w.zones_spawned, 1, ctx)
    return true
}

// Immediate damage resolves first. A killing hit cannot also apply a status to
// the removed target; both cone and nova follow this same attribution rule.
ability_hit_mob :: proc(
    w: ^World,
    index: int,
    resolved: ^Ability_Cast,
    row: ^content.Ability,
    feedback: ^Notices,
    ctx: ^r.Step(Event),
) {
    if resolved.wound > 0 && wound_mob(w, index, resolved.wound, resolved.credit, feedback, ctx) {
        return
    }

    if row.status != 0 {
        apply_status(w, mob_target(w, index), row.status, resolved.credit, feedback, ctx)
    }
}

ability_cone :: proc(
    w: ^World,
    resolved: ^Ability_Cast,
    row: ^content.Ability,
    feedback: ^Notices,
    ctx: ^r.Step(Event),
) {
    if !resolved.has_direction {
        return
    }

    for alive, index in w.mobs.alive {
        if !alive || w.mobs.values[index].hp == 0 {
            continue
        }

        delta := w.mobs.values[index].position - resolved.origin
        distance := math.sqrt(delta[0] * delta[0] + delta[1] * delta[1])

        if distance > row.range ||
           distance < 1 ||
           (delta[0] / distance * resolved.direction[0] + delta[1] / distance * resolved.direction[1]) < row.arc_cos {
            continue
        }

        ability_hit_mob(w, index, resolved, row, feedback, ctx)
    }
}

ability_nova :: proc(
    w: ^World,
    resolved: ^Ability_Cast,
    row: ^content.Ability,
    feedback: ^Notices,
    ctx: ^r.Step(Event),
) {
    for alive, index in w.mobs.alive {
        if !alive || w.mobs.values[index].hp == 0 {
            continue
        }

        if p.in_reach(resolved.origin, w.mobs.values[index].position, row.radius) {
            ability_hit_mob(w, index, resolved, row, feedback, ctx)
        }
    }
}

ability_buff :: proc(
    w: ^World,
    resolved: ^Ability_Cast,
    row: ^content.Ability,
    feedback: ^Notices,
    ctx: ^r.Step(Event),
) {
    target := int(resolved.credit.seat - 1)

    if !row.self_buff {
        best := row.range * row.range

        for other, index in w.players {
            if index == int(resolved.credit.seat - 1) || !other.connected || !other.in_yard || other.hp == 0 {
                continue
            }

            delta := other.position - resolved.origin
            distance := delta[0] * delta[0] + delta[1] * delta[1]

            if distance <= best {
                best, target = distance, index
            }
        }
    }

    if row.status != 0 {
        apply_status(w, player_target(w, target), row.status, resolved.credit, feedback, ctx)
    }

    resolved.point = w.players[target].position
}
