package scrapyard_game

import "core:math"
import r "godot:replay"
import p "godot:replay/play"
import arena "../arena"
import content "../content"

Run_Rules :: struct {
    enabled: bool,
    base_count, growth, rest: u16,
    wave_count, barrels: u8,
    boss_every, horde_every: u8,
}

RUN_RULES :: Run_Rules{true, 10, 4, 300, 3, 5, 4, 3}

GATE :: [2]f32{arena.WIDTH - 70, arena.HEIGHT / 2}

GATE_RADIUS :: f32(80)

DEPART_TICKS :: u16(180)

OVER_TICKS :: u64(150)

REVIVE_TICKS :: u16(120)

SHOP_PRICES :: [6]u32{0, 5, 5, 3, 2, 0}

PART_PRICES :: [4]u32{2, 2, 3, 2}

has_part :: proc(parts, part: u8) -> bool {
    return parts & (u8(1) << uint(part)) != 0
}

max_health :: proc(parts: u8) -> u8 {
    return 10 + (has_part(parts, 1) ? 4 : 0)
}

boosted_damage :: proc(base, boost: u8) -> u8 {
    return u8(min(u16(base) + u16(boost), 255))
}

gun_cadence :: proc(w: ^World, player: ^Player) -> u16 {
    base := u32(w.catalog.guns[player.gun_id].cooldown)
    cut := u32(player.boost_rate) * 8 + (has_part(player.parts, 0) ? u32(3) : 0)
    return u16(base > cut + 4 ? base - cut : 4)
}

run_valid :: proc(w: World) -> bool {
    value := w
    return run_valid_borrowed(&value)
}

// Synchronous borrowed read; never retain or mutate the world.
@(private)
run_valid_borrowed :: proc(w: ^World) -> bool {
    for player in w.players {
        if player.parts & ~u8(15) != 0 ||
           player.revive.elapsed >= REVIVE_TICKS ||
           (player.revive.target == 0 && player.revive.elapsed != 0) {
            return false
        }
    }

    if !w.rules.enabled {
        return true
    }

    if w.rules.wave_count == 0 ||
       w.rules.wave_count > 3 ||
       w.rules.barrels > 32 ||
       u32(w.rules.base_count) + 254 * u32(w.rules.growth) > u32(max(u16)) / 3 ||
       w.wave_count > 3 ||
       w.depart.left > w.depart.wind ||
       w.depart.wind > DEPART_TICKS {
        return false
    }

    if w.stage == .Staging {
        return true
    }

    if w.wave_count == 0 || w.director.wave > u16(w.wave_count) {
        return false
    }

    if w.director.wave == 0 && (w.director.pending != 0 || w.director.alive != 0) {
        return false
    }

    if w.director.wave > 0 && w.director.pending > u32(w.waves[w.director.wave - 1].count) {
        return false
    }

    alive := u32(0)

    for live, i in w.mobs.alive {
        if live && w.mobs.values[i].hp > 0 && w.mobs.values[i].directed {
            alive += 1
        }
    }

    return alive == w.director.alive
}

wave_kind :: proc(index: u32, floor: u8, wave: u16) -> u8 {
    if wave == 2 {
        if index % 4 == 1 {
            return 3
        }

        if index % 4 == 3 {
            return 2
        }

        return 0
    }

    if wave == 3 {
        if index % 5 == 0 {
            return 1
        }

        if index % 5 == 2 {
            return floor >= 2 ? 2 : 3
        }

        return 0
    }

    if floor <= 1 {
        return 0
    }

    if index % 5 == 2 {
        return 2
    }

    if index % 5 == 4 {
        return 3
    }

    if floor >= 3 && index % 7 == 0 {
        return 1
    }

    return 0
}

arm_floor :: proc(w: ^World, ctx: ^r.Step(Event), reset: bool) {
    w.director, w.waves = {}, {}
    w.wave_count = w.rules.wave_count

    if w.rules.boss_every != 0 && w.floor % w.rules.boss_every == 0 {
        w.wave_count = 1
        w.waves[0] = {0, w.rules.rest}

        if !spawn_mob(w, 4, {arena.WIDTH / 2, 140}) {
            r.abort(ctx)
            return
        }
    } else {
        n := u32(w.rules.base_count) + u32(w.floor - 1) * u32(w.rules.growth)

        if w.rules.horde_every != 0 && w.floor % w.rules.horde_every == 0 {
            n *= 3
            w.wave_count = 1
        }

        w.waves = {{u16(n), w.rules.rest}, {u16(max(n / 2, 4)), w.rules.rest}, {u16(max(n * 2 / 3, 5)), w.rules.rest}}
    }

    if reset {
        w.director.rest_until = ctx.tick + u64(w.rules.rest)
    }

    for k in 0 ..< int(w.rules.barrels) {
        angle := f32(k) * 2.399 + f32(w.floor) * 1.7
        radius := f32(200 + (k * 97 + int(w.floor) * 61) % 340)
        point := [2]f32 {
            clamp(arena.WIDTH / 2 + math.cos(angle) * radius, arena.MARGIN, arena.WIDTH - arena.MARGIN),
            clamp(arena.HEIGHT / 2 + math.sin(angle) * radius, arena.MARGIN, arena.HEIGHT - arena.MARGIN),
        }
        blocked := false

        for cover in w.layout.covers {
            if point[0] > f32(cover.x) - 24 &&
               point[0] < f32(cover.x) + f32(cover.w) + 24 &&
               point[1] > f32(cover.y) - 24 &&
               point[1] < f32(cover.y) + f32(cover.h) + 24 {
                blocked = true
                break
            }
        }

        if !blocked && !spawn_mob(w, 5, point) {
            r.abort(ctx)
            return
        }
    }
}

director_step :: proc(w: ^World, ctx: ^r.Step(Event)) {
    prey: [SEATS]int
    count := 0

    for player, i in w.players {
        if player.connected && player.in_yard && player.hp > 0 {
            prey[count] = i
            count += 1
        }
    }

    if count == 0 {
        return
    }

    room := false

    for alive, i in w.mobs.alive {
        if !alive && w.mobs.generations[i] != max(u32) {
            room = true
            break
        }
    }

    next := w.director
    spawn_count, _ := p.director_tick(&next, ctx.tick, w.waves[:w.wave_count], room)

    if spawn_count > 0 {
        if w.spawn_index == max(u32) {
            r.abort(ctx)
            return
        }

        index := w.spawn_index + 1
        anchor := w.players[prey[index % u32(count)]].position
        angle := f32(index) * 2.399 + f32(ctx.tick / u64(HZ)) * 0.7
        point := [2]f32 {
            clamp(anchor[0] + math.cos(angle) * 460, arena.MARGIN, arena.WIDTH - arena.MARGIN),
            clamp(anchor[1] + math.sin(angle) * 460, arena.MARGIN, arena.HEIGHT - arena.MARGIN),
        }
        kind := wave_kind(w.spawn_index, w.floor, next.wave)

        if w.floor >= 2 &&
           w.spawn_index % 7 == 3 &&
           content.mob_present(&w.catalog, STORMCALLER) &&
           w.catalog.mobs[STORMCALLER].pulse.windup > 0 {
            kind = STORMCALLER
        }

        if !spawn_mob(w, kind, point, true) {
            return
        }

        w.spawn_index = index
    }

    w.director = next
}

living_enemies :: proc(w: ^World) -> u32 {
    count := u32(0)

    for alive, i in w.mobs.alive {
        if alive && w.mobs.values[i].hp > 0 && !w.catalog.mobs[w.mobs.values[i].kind].prop {
            count += 1
        }
    }

    return count
}

all_down :: proc(w: ^World) -> bool {
    any := false

    for player in w.players {
        if player.connected && player.in_yard {
            any = true

            if player.hp > 0 {
                return false
            }
        }
    }

    return any
}

on_gate :: proc(w: ^World) -> bool {
    any := false

    for player in w.players {
        if player.connected && player.in_yard {
            any = true

            if player.hp == 0 || !p.in_reach(player.position, GATE, GATE_RADIUS) {
                return false
            }
        }
    }

    return any
}

run_step :: proc(w: ^World, ctx: ^r.Step(Event)) {
    if w.stage != .Over && all_down(w) {
        w.stage, w.over_until = .Over, ctx.tick + OVER_TICKS
        p.telegraph_cancel(&w.depart)
        add_count(&w.wipes, 1, ctx)
        return
    }

    switch w.stage {
    case .Yard:
        if w.director.done && living_enemies(w) == 0 {
            w.stage = .Clear
            add_count(&w.clears, 1, ctx)

            for &player in w.players {
                if player.connected && player.in_yard {
                    add_count(&player.cores, 1, ctx)
                }
            }
        }
    case .Clear:
        if w.depart.left > 0 {
            if !on_gate(w) {
                p.telegraph_cancel(&w.depart)
            } else if p.telegraph_tick(&w.depart) {
                turn_floor(w, false, ctx)
            }
        } else if on_gate(w) {
            p.telegraph_start(&w.depart, DEPART_TICKS)
        }
    case .Over:
        if ctx.tick >= w.over_until {
            turn_floor(w, true, ctx)
        }
    case .Staging:
    }
}

turn_floor :: proc(w: ^World, reset: bool, ctx: ^r.Step(Event)) {
    if (!reset && w.floor == max(u8)) || (reset && w.run == max(u32)) {
        r.abort(ctx)
        return
    }

    r.pool_clear(&w.turrets)
    r.pool_clear(&w.mobs)
    r.pool_clear(&w.shots)
    r.pool_clear(&w.lobs)
    r.pool_clear(&w.zones)
    r.pool_clear(&w.drops)
    r.pool_clear(&w.flashes)
    w.hit_history, w.director, w.depart, w.over_until = {}, {}, {}, 0

    if reset {
        w.floor = 1
        w.run += 1
    } else {
        w.floor += 1
        add_count(&w.descents, 1, ctx)
    }

    w.layout = arena.generate(w.seed, w.floor)

    for &player, i in w.players {
        player.spray.stamp, player.spray.floor = 0, 0

        if !player.in_yard {
            continue
        }

        if player.warp == max(u32) {
            r.abort(ctx)
            return
        }

        player.warp += 1
        player.revive = {}

        if !player.connected {
            player.in_yard = false
            player.fx, player.fx_credit = {}, {}
            continue
        }

        player.position = {140 + f32((i + 1) % 8) * 44, arena.HEIGHT / 2}

        if reset {
            player.hp, player.scrap = max_health(player.parts), 0
            player.boost_damage, player.boost_rate, player.boost_speed = 0, 0, 0
            player.fx, player.fx_credit, player.ability_cd = {}, {}, {}
            player.next_pull = 0
            p.gun_equip(&player.gun, w.catalog.guns[player.gun_id].mechanism, u32(i + 1) * 2654435761 + 2246822519)
        } else {
            player.gun.salt = u32(i + 1) * 2654435761 + u32(w.floor) * 2246822519
        }
    }

    w.stage = .Yard
    arm_floor(w, ctx, reset)
}

buy :: proc(w: ^World, seat: u16, item: u8, ctx: ^r.Step(Event)) -> bool {
    if w.stage != .Clear || item < 1 || item > 5 {
        return false
    }

    player := &w.players[seat - 1]

    if !player.in_yard {
        return false
    }

    prices := SHOP_PRICES
    price := prices[item]

    if player.scrap < price {
        return false
    }

    if item == 1 && player.boost_damage == max(u8) ||
       item == 2 && player.boost_rate == max(u8) ||
       item == 3 && player.boost_speed == max(u8) {
        return false
    }

    player.scrap -= price

    switch item {
    case 1:
        player.boost_damage += 1
    case 2:
        player.boost_rate += 1
    case 3:
        player.boost_speed += 1
    case 4:
        player.hp = max_health(player.parts)
    case 5:
        player.gun_id = content.next_gun(&w.catalog, player.gun_id)
        p.gun_equip(
            &player.gun,
            w.catalog.guns[player.gun_id].mechanism,
            u32(seat) * 2654435761 + u32(w.floor) * 2246822519,
        )
        player.next_pull = 0
    case:
    }

    add_count(&player.purchases, 1, ctx)
    return true
}

workshop :: proc(w: ^World, seat: u16, part: u8) -> bool {
    if w.stage != .Clear || part >= 4 {
        return false
    }

    player := &w.players[seat - 1]
    prices := PART_PRICES

    if !player.in_yard || has_part(player.parts, part) || player.cores < prices[part] {
        return false
    }

    player.cores -= prices[part]
    player.parts |= u8(1) << uint(part)

    if part == 1 {
        player.hp = max_health(player.parts)
    }

    return true
}

revive_step :: proc(w: ^World, controls: [SEATS]Control, feedback: ^Notices, ctx: ^r.Step(Event)) {
    for &player, seat in w.players {
        if !player.connected ||
           !player.in_yard ||
           player.hp == 0 ||
           turret_operator(w, u16(seat + 1)) ||
           !controls[seat].revive {
            player.revive = {}
            continue
        }

        target := -1

        for other, i in w.players {
            if i != seat &&
               other.connected &&
               other.in_yard &&
               other.hp == 0 &&
               p.in_reach(player.position, other.position, 56) {
                target = i
                break
            }
        }

        if target < 0 {
            player.revive = {}
            continue
        }

        key := u64(w.players[target].generation) << 32 | u64(target + 1)

        if p.channel_tick(&player.revive, key, REVIVE_TICKS) {
            w.players[target].hp = 4
            add_count(&player.revives, 1, ctx)
            notice(feedback, 4, seat, 4, w.players[target].position, ctx)
        }
    }
}
