package scrapyard_game

import "core:math"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import p "godot:replay/play"
import arena "../arena"
import content "../content"

// Feedback is one aggregate per player/kind/tick. Dense collisions cannot
// overflow the network runner's 32-occurrence gameplay budget; entity lifetimes
// and exact per-target health remain in the world for presentation.
Notices :: struct {
    work: u32,
    amount: [6][SEATS]u32,
    position: [6][SEATS][2]f32,
    walls: [net.GAME_EVENTS]Wall_Notice,
    wall_count, wall_dropped: int,
}

Wall_Notice :: struct {
    value: Event,
    source, key: u64,
}

// Rails use player lifetimes; terminal slugs use projectile pool lifetimes.
// Distinct keys prevent their sources colliding in the same tick.
WALL_RAIL_KEY :: u64(Event_Kind.Wall) | 0x100

notice :: proc(n: ^Notices, kind, seat: int, amount: u32, position: [2]f32, ctx: ^r.Step(Event)) {
    if n.amount[kind][seat] > max(u32) - amount {
        r.abort(ctx)
        return
    }

    n.amount[kind][seat] += amount
    n.position[kind][seat] = position
}

flush :: proc(w: ^World, n: ^Notices, ctx: ^r.Step(Event)) {
    kinds := [6]Event_Kind{.Hit, .Killed, .Hurt, .Pickup, .Healed, .Blast}

    for kind in 0 ..< 6 {
        for seat in 0 ..< SEATS {
            if n.amount[kind][seat] > 0 {
                player := w.players[seat]
                r.emit_fold(
                    ctx,
                    u64(player.generation) << 32 | u64(seat + 1),
                    u64(kinds[kind]),
                    Event {
                        kinds[kind],
                        u16(seat + 1),
                        player.generation,
                        n.amount[kind][seat],
                        n.position[kind][seat],
                        0,
                    },
                    proc(a, b: Event) -> (Event, bool) {
                        if a.kind != b.kind ||
                           a.seat != b.seat ||
                           a.generation != b.generation ||
                           a.serial > max(u32) - b.serial {
                            return {}, false
                        }

                        result := b
                        result.serial += a.serial
                        return result, true
                    },
                )
            }
        }
    }

    if n.wall_count == 0 {
        return
    }

    // Actions execute after step_view. Reserve every action-emittable identity
    // not already present: five aggregates/player, Entered/player and Started.
    // This deliberately conservative budget keeps later casts/development edits
    // safe too. Cosmetic contacts consume the remainder in projectile-pool order.
    reserve := SEATS * 6 + 1

    for occurrence in ctx.events[:ctx.count] {
        event := occurrence.value

        if event.kind == .Started {
            reserve -= 1
            continue
        }

        if event.seat == 0 || event.seat > SEATS || event.generation != w.players[event.seat - 1].generation {
            continue
        }

        #partial switch event.kind {
        case .Hit, .Killed, .Hurt, .Healed, .Blast, .Entered:
            reserve -= 1
        case:
        }
    }

    for wall in n.walls[:n.wall_count] {
        if ctx.count >= len(ctx.events) - reserve {
            n.wall_dropped += 1
            continue
        }

        r.emit(ctx, wall.source, wall.key, wall.value)
    }

    n.wall_count = 0
}

wall_notice :: proc(w: ^World, index: int, normal: [2]f32, n: ^Notices) {
    shot := w.shots.values[index]
    value := Event {
        kind = .Wall,
        seat = shot.seat,
        generation = w.shots.generations[index],
        serial = u32(index + 1),
        position = shot.position,
    }
    wall_append(
        n,
        value,
        normal,
        shot.kind == .Spit,
        u64(value.generation) << 32 | u64(value.serial),
        u64(Event_Kind.Wall),
    )
}

wall_append :: proc(n: ^Notices, value: Event, normal: [2]f32, spit: bool, source, key: u64) {
    if n.wall_count == len(n.walls) {
        n.wall_dropped += 1
        return
    }

    value := value
    // 0..3 = west/east/north/south; bit 2 identifies spit.
    face: u8

    if normal[0] != 0 {
        face = normal[0] < 0 ? 0 : 1
    } else {
        face = normal[1] < 0 ? 2 : 3
    }

    if spit {
        face |= 4
    }

    value.detail = face
    n.walls[n.wall_count] = {value, source, key}
    n.wall_count += 1
}

wall_normal :: proc(event: Event) -> [2]f32 {
    if event.kind != .Wall || event.detail > 7 {
        return {}
    }

    normals := [4][2]f32{{-1, 0}, {1, 0}, {0, -1}, {0, 1}}
    return normals[event.detail & 3]
}

MAX_MOBS :: 64

MAX_SHOTS :: 128

MAX_DROPS :: 128

Mob :: struct {
    directed: bool,
    kind: u8,
    hp, max_hp: u16,
    position: [2]f32,
    next_act, next_add, reap_at: u64,
    tele: p.Telegraph,
    shots: u32,
    fx: [4]p.Effect,
    fx_credit: [4]Credit,
}

Shot_Kind :: enum u8 {
    Ballistic,
    Grenade,
    Spit,
}

Shot :: struct {
    kind: Shot_Kind,
    seat: u16,
    generation, serial: u32,
    position, velocity: [2]f32,
    ttl: u16,
    damage: u8,
}

Drop :: struct {
    position: [2]f32,
    amount: u32,
}

pool_valid :: proc(pool: r.Pool($T, $N)) -> bool {
    count := u32(0)

    for alive, i in pool.alive {
        if alive {
            count += 1

            if pool.generations[i] == 0 {
                return false
            }
        } else if !reflect.equal(pool.values[i], T{}) {
            return false
        }
    }

    return count == pool.count
}

position_valid :: proc(position: [2]f32) -> bool {
    return(
        content.finite(position[0]) &&
        content.finite(position[1]) &&
        position[0] >= -100 &&
        position[0] <= arena.WIDTH + 100 &&
        position[1] >= -100 &&
        position[1] <= arena.HEIGHT + 100 \
    )
}

combat_valid :: proc(w: World) -> bool {
    value := w
    return combat_valid_borrowed(&value)
}

// Synchronous borrowed read; never retain or mutate the world.
@(private)
combat_valid_borrowed :: proc(w: ^World) -> bool {
    if !pool_valid(w.mobs) || !pool_valid(w.shots) || !pool_valid(w.drops) {
        return false
    }

    for player in w.players {
        if !content.gun_present(&w.catalog, player.gun_id) {
            return false
        }

        if player.in_yard && (!p.gun_valid(player.gun, w.catalog.guns[player.gun_id].mechanism)) {
            return false
        }
    }

    for alive, i in w.mobs.alive {
        if alive {
            m := w.mobs.values[i]

            if !content.mob_present(&w.catalog, m.kind) ||
               m.max_hp == 0 ||
               m.hp > m.max_hp ||
               m.tele.left > m.tele.wind ||
               m.tele.wind >
                   (w.catalog.mobs[m.kind].pulse.windup > 0 ? w.catalog.mobs[m.kind].pulse.windup : u16(48)) ||
               !position_valid(m.position) ||
               (m.hp == 0) != (m.reap_at > 0) {
                return false
            }
        }
    }

    for alive, i in w.shots.alive {
        if alive {
            s := w.shots.values[i]

            if s.kind > .Spit ||
               (s.kind == .Spit) != (s.seat == 0) ||
               s.seat > SEATS ||
               s.generation == 0 ||
               s.serial == 0 ||
               s.ttl == 0 ||
               s.ttl > 600 ||
               !position_valid(s.position) {
                return false
            }

            for value in s.velocity {
                if !content.finite(value) || abs(value) > 100 {
                    return false
                }
            }
        }
    }

    for alive, i in w.drops.alive {
        if alive {
            if w.drops.values[i].amount == 0 || !position_valid(w.drops.values[i].position) {
                return false
            }
        }
    }

    return ordnance_valid_borrowed(w) && effects_valid_borrowed(w)
}

spawn_mob :: proc(w: ^World, kind: u8, position: [2]f32, directed: bool = false) -> bool {
    if !content.mob_present(&w.catalog, kind) || !position_valid(position) {
        return false
    }

    hp := kind == 4 && w.boss_hp != 0 ? w.boss_hp : w.catalog.mobs[kind].hp
    mob := Mob {
        directed = directed,
        kind = kind,
        hp = hp,
        max_hp = hp,
        position = position,
    }

    if w.catalog.mobs[kind].pulse.windup > 0 {
        mob.next_act = w.clock + 60
    }

    if kind == 2 {
        mob.next_act = w.clock + 90
    }

    if kind == 4 {
        mob.next_act = w.clock + 60
    }

    _, ok := r.pool_insert(&w.mobs, mob)
    return ok
}

encounter_start :: proc(w: ^World, ctx: ^r.Step(Event)) {
    // Initial encounter only; full wave/director progression is a separate slice.
    // Spawn flavor is derived from saved run identity, never host wall time.
    rng := r.rng_make(u64(w.seed) << 8 | u64(w.floor))

    for i in 0 ..< int(w.encounter_count) {
        angle := f32(r.rng_next(&rng) % 62832) * 0.0001
        position := [2]f32{arena.WIDTH / 2, arena.HEIGHT / 2} + [2]f32{math.cos(angle), math.sin(angle)} * 460

        if w.encounter_placed {
            position = w.encounter_positions[i]
        }

        if !spawn_mob(w, w.encounter_kinds[i % 4], position) {
            r.abort(ctx)
            return
        }
    }
}

// At capacity defer this pull, consuming neither ammo nor the jam sequence.
fire :: proc(w: ^World, seat: u16, ctx: ^r.Step(Event)) {
    feedback: Notices
    fire_view(w, seat, net.View_Time{ctx.tick, ctx.tick, 0, .Live}, &feedback, ctx)
    flush(w, &feedback, ctx)
}

fire_view :: proc(w: ^World, seat: u16, view: net.View_Time, feedback: ^Notices, ctx: ^r.Step(Event)) {
    player := &w.players[seat - 1]
    def := w.catalog.guns[player.gun_id]

    if ctx.tick < player.next_pull {
        return
    }

    gun := player.gun
    result := p.gun_pull(&gun, def.mechanism)

    if result.error != .None {
        r.abort(ctx)
        return
    }

    if result.pull == .Fired {
        if player.shots == max(u32) {
            r.abort(ctx)
            return
        }

        shot := Shot {
            kind = def.family == 2 ? .Grenade : .Ballistic,
            seat = seat,
            generation = player.generation,
            serial = player.shots + 1,
            position = player.position + player.aim * 24,
            velocity = player.aim * def.speed,
            ttl = def.ttl,
            damage = (def.family < 2 || def.family == 3) ? scaled_damage(boosted_damage(def.damage, player.boost_damage), status_multiplier(w, player.fx[:], .Dealt)) : def.damage,
        }

        if def.family < 3 {
            if _, ok := r.pool_insert(&w.shots, shot); !ok {
                return
            }
        }

        player.shots += 1

        if def.family >= 3 {
            rail_land(w, shot, def.family == 4, view, feedback, ctx)
        }

        r.emit(
            ctx,
            u64(player.generation) << 32 | u64(seat),
            u64(Event_Kind.Shot),
            Event{.Shot, seat, player.generation, player.shots, shot.position, def.family},
        )
    } else if result.pull == .Jammed {
        r.emit(
            ctx,
            u64(player.generation) << 32 | u64(seat),
            u64(Event_Kind.Jam),
            Event{.Jam, seat, player.generation, gun.spent, player.position, player.gun_id},
        )
    }

    player.gun = gun
    player.next_pull = ctx.tick + (gun.mode == .Reloading ? u64(gun.reload_left) : u64(gun_cadence(w, player))) + 1
}

mob_move :: proc(w: ^World, mob: ^Mob, toward: [2]f32, speed, radius: f32, away: bool = false) {
    wanted := p.step_toward(mob.position, toward, speed)

    if away {
        wanted = mob.position + p.unit2(mob.position - toward) * speed
    }

    next := arena.move(&w.layout, mob.position, wanted - mob.position, 1, radius)

    if abs(next[0] - mob.position[0]) + abs(next[1] - mob.position[1]) < speed * 0.15 {
        delta := toward - mob.position
        length := max(math.sqrt(delta[0] * delta[0] + delta[1] * delta[1]), 1)
        perpendicular := [2]f32{-delta[1], delta[0]} / length * speed

        for _ in 0 ..< 2 {
            candidate := arena.move(&w.layout, mob.position, perpendicular, 1, radius)

            if abs(candidate[0] - mob.position[0]) + abs(candidate[1] - mob.position[1]) >= speed * 0.15 {
                next = candidate
                break
            }

            perpendicular = -perpendicular
        }
    }

    mob.position = next
}

mob_step :: proc(w: ^World, feedback: ^Notices, ctx: ^r.Step(Event)) {
    membership, generations := w.mobs.alive, w.mobs.generations

    for alive, i in membership {
        if alive && w.mobs.alive[i] && w.mobs.generations[i] == generations[i] {
            mob := &w.mobs.values[i]

            if mob.hp == 0 {
                if ctx.tick >= mob.reap_at {
                    r.pool_remove(&w.mobs, r.Handle(Mob){u32(i), w.mobs.generations[i]})
                }

                continue
            }

            mob_upkeep(w, i, feedback, ctx)

            if mob.hp > 0 && !w.catalog.mobs[mob.kind].prop {
                mob_brain(w, i, feedback, ctx)
            }
        }
    }

    for i in 0 ..< MAX_MOBS {
        if !w.mobs.alive[i] || w.mobs.values[i].hp == 0 || w.catalog.mobs[w.mobs.values[i].kind].prop {
            continue
        }

        for j in i + 1 ..< MAX_MOBS {
            if !w.mobs.alive[j] || w.mobs.values[j].hp == 0 || w.catalog.mobs[w.mobs.values[j].kind].prop {
                continue
            }

            a, b := &w.mobs.values[i], &w.mobs.values[j]
            want := (w.catalog.mobs[a.kind].radius + w.catalog.mobs[b.kind].radius) * 0.9
            delta := b.position - a.position
            d := math.sqrt(delta[0] * delta[0] + delta[1] * delta[1])

            if d >= want {
                continue
            }

            direction := d > 0.01 ? delta / d : [2]f32{1, 0}
            push := direction * ((want - d) * 0.18)
            a.position -= push
            b.position += push

            for body in ([2]^Mob{a, b}) {
                body.position[0] = clamp(body.position[0], arena.MARGIN, arena.WIDTH - arena.MARGIN)
                body.position[1] = clamp(body.position[1], arena.MARGIN, arena.HEIGHT - arena.MARGIN)
            }
        }
    }
}

drop_scrap :: proc(w: ^World, position: [2]f32, amount: u32) -> bool {
    if amount == 0 {
        return false
    }

    if _, ok := r.pool_insert(&w.drops, Drop{position, amount}); ok {
        return true
    }

    // Bounded storage must not destroy money or freeze combat. At saturation,
    // coalesce into the nearest existing pile; stable slot order breaks ties.
    best := f32(1e30)
    target := -1

    for alive, i in w.drops.alive {
        if alive && w.drops.values[i].amount <= max(u32) - amount {
            d := w.drops.values[i].position - position
            distance := d[0] * d[0] + d[1] * d[1]

            if distance < best {
                best, target = distance, i
            }
        }
    }

    if target < 0 {
        return false
    }

    w.drops.values[target].amount += amount
    return true
}

damage_mob :: proc(w: ^World, index: int, shot: Shot, feedback: ^Notices, ctx: ^r.Step(Event)) {
    wound_mob(w, index, shot.damage, Credit{shot.seat, shot.generation}, feedback, ctx)
}

shot_step :: proc(w: ^World, feedback: ^Notices, ctx: ^r.Step(Event)) {
    for alive, i in w.shots.alive {
        if alive {
            shot := &w.shots.values[i]

            if shot.kind == .Spit {
                spit_step(w, i, feedback, ctx)
                continue
            }

            if shot.kind == .Grenade {
                if grenade_step(w, shot, feedback, ctx) {
                    r.pool_remove(&w.shots, r.Handle(Shot){u32(i), w.shots.generations[i]})
                }

                continue
            }

            nearest, blocked, normal := arena.contact(&w.layout, shot.position, shot.velocity)
            target := -1

            // Census each flight after prior wounds: a corpse cannot absorb another slug.
            for live, j in w.mobs.alive {
                if live && w.mobs.values[j].hp > 0 {
                    mob := w.mobs.values[j]
                    at, hit := p.segment_circle(
                        shot.position,
                        shot.position + shot.velocity,
                        mob.position,
                        w.catalog.mobs[mob.kind].radius,
                    )

                    if hit && (at < nearest || at == nearest && !blocked && target < 0) {
                        nearest, target = at, j
                    }
                }
            }

            if target >= 0 {
                damage_mob(w, target, shot^, feedback, ctx)
            }

            shot.position += shot.velocity * nearest

            if blocked && target < 0 {
                wall_notice(w, i, normal, feedback)
            }

            shot.ttl -= 1

            if target >= 0 ||
               blocked ||
               shot.ttl == 0 ||
               shot.position[0] < 0 ||
               shot.position[0] > arena.WIDTH ||
               shot.position[1] < 0 ||
               shot.position[1] > arena.HEIGHT {
                r.pool_remove(&w.shots, r.Handle(Shot){u32(i), w.shots.generations[i]})
            }
        }
    }
}

pickup_step :: proc(w: ^World, feedback: ^Notices, ctx: ^r.Step(Event)) {
    for alive, i in w.drops.alive {
        if alive {
            drop := &w.drops.values[i]

            for &player, seat in w.players {
                if !player.connected || !player.in_yard || player.hp == 0 {
                    continue
                }

                delta := player.position - drop.position
                distance := math.sqrt(delta[0] * delta[0] + delta[1] * delta[1])
                reach := f32(52) + (has_part(player.parts, 3) ? 28 : 0)

                if distance > reach {
                    continue
                }

                if distance <= 14 {
                    if player.scrap > max(u32) - drop.amount {
                        r.abort(ctx)
                        return
                    }

                    player.scrap += drop.amount
                    notice(feedback, 3, seat, drop.amount, drop.position, ctx)
                    r.pool_remove(&w.drops, r.Handle(Drop){u32(i), w.drops.generations[i]})
                } else {
                    drop.position += delta / distance * min(5 + (reach - distance) * 0.08, distance)
                }

                break
            }
        }
    }
}

combat_step :: proc(
    w: ^World,
    controls: [SEATS]Control,
    views: [SEATS]net.View_Time,
    feedback: ^Notices,
    ctx: ^r.Step(Event),
) {
    flash_step(w, ctx.tick)

    for &player, i in w.players {
        if !player.connected || !player.in_yard || player.hp == 0 {
            continue
        }

        if turret_operator(w, u16(i + 1)) {
            if controls[i].fire {
                turret_fire(w, u16(i + 1), ctx)
            }

            continue
        }

        if controls[i].fire {
            fire_view(w, u16(i + 1), views[i], feedback, ctx)
        }
    }

    zone_step(w, feedback, ctx)
    mob_step(w, feedback, ctx)
    lob_step(w, feedback, ctx)
    shot_step(w, feedback, ctx)
    pickup_step(w, feedback, ctx)
}
