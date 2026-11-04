package scrapyard_game

import "core:reflect"
import r "godot:replay"
import h "godot:replay/history"
import net "godot:replay/net"
import p "godot:replay/play"
import arena "../arena"
import content "../content"

// Radius comes from the immutable catalog/current lifetime, so historical
// proxies retain only positions, generation and active state. No live pointers.
Proxy :: struct {
    position: [2]f32,
    generation: u32,
    active: bool,
}

MAX_FLASHES :: 64

Flash_Kind :: enum u8 {
    Lance,
    Mend,
    Boom,
    Reaction,
    Cast,
    Arc,
}

Flash :: struct {
    kind: Flash_Kind,
    status, ability: u8,
    seat: u16,
    generation, serial: u32,
    origin, end: [2]f32,
    radius: f32,
    until: u64,
}

proxies :: proc(w: ^World) -> [SEATS + MAX_MOBS]Proxy {
    result: [SEATS + MAX_MOBS]Proxy

    for player, i in w.players {
        result[i] = {player.position, player.generation, player.connected && player.in_yard && player.hp > 0}
    }

    for alive, i in w.mobs.alive {
        if alive {
            mob := w.mobs.values[i]
            result[SEATS + i] = {mob.position, w.mobs.generations[i], mob.hp > 0}
        }
    }

    return result
}

proxy_blend :: proc(a, b: Proxy, fraction: u16) -> Proxy {
    if a.generation != b.generation || a.active != b.active {
        return fraction == max(u16) ? b : a
    }

    result := a
    result.position += (b.position - a.position) * (f32(fraction) / 65535)
    return result
}

ordnance_valid :: proc(w: World) -> bool {
    value := w
    return ordnance_valid_borrowed(&value)
}

// Synchronous borrowed read; never retain or mutate the world.
@(private)
ordnance_valid_borrowed :: proc(w: ^World) -> bool {
    if !pool_valid(w.flashes) {
        return false
    }

    for player in w.players {
        if player.last_query > .Invalid || player.last_judged > w.clock {
            return false
        }
    }

    for entry, slot in w.hit_history.entries {
        if !entry.valid {
            if !reflect.equal(entry, h.Entry([SEATS + MAX_MOBS]Proxy){}) {
                return false
            }

            continue
        }

        if entry.tick > w.clock || entry.tick % 32 != u64(slot) {
            return false
        }

        for proxy in entry.value {
            if !position_valid(proxy.position) || proxy.active && proxy.generation == 0 {
                return false
            }
        }
    }

    for alive, i in w.flashes.alive {
        if alive {
            f := w.flashes.values[i]

            if f.kind > .Arc ||
               (f.seat == 0 && f.kind != .Reaction && f.kind != .Arc) ||
               (f.status != 0 && !content.status_present(&w.catalog, f.status)) ||
               f.seat > SEATS ||
               f.generation == 0 ||
               f.serial == 0 ||
               !point_valid(f.origin) ||
               !content.finite(f.radius) ||
               f.radius < 0 ||
               f.radius > 1000 ||
               f.until == 0 ||
               (f.ability != 0 && !content.ability_present(&w.catalog, f.ability)) {
                return false
            }

            if f.kind == .Arc && (f.status == 0 || f.radius != 0 || f.ability != 0 || !point_valid(f.end)) {
                return false
            }

            // Beams may end outside the arena, at the longest permitted gun's reach.
            for value in f.end {
                if !content.finite(value) || abs(value) > 65536 {
                    return false
                }
            }
        }
    }

    return true
}

flash_step :: proc(w: ^World, tick: u64) {
    for alive, i in w.flashes.alive {
        if alive && w.flashes.values[i].until <= tick {
            r.pool_remove(&w.flashes, r.Handle(Flash){u32(i), w.flashes.generations[i]})
        }
    }
}

flash_add :: proc(w: ^World, flash: Flash, ctx: ^r.Step(Event)) {
    if _, ok := r.pool_insert(&w.flashes, flash); ok {
        return
    }

    // Dense simultaneous blasts shorten the oldest visual, never cancel damage.
    target := -1

    for alive, i in w.flashes.alive {
        if alive && (target < 0 || w.flashes.values[i].until < w.flashes.values[target].until) {
            target = i
        }
    }

    if target < 0 || w.flash_evictions == max(u32) {
        r.abort(ctx)
        return
    }

    r.pool_remove(&w.flashes, r.Handle(Flash){u32(target), w.flashes.generations[target]})

    if _, ok := r.pool_insert(&w.flashes, flash); !ok {
        r.abort(ctx)
        return
    }

    w.flash_evictions += 1
}

rail_land :: proc(w: ^World, shot: Shot, mend: bool, view: net.View_Time, feedback: ^Notices, ctx: ^r.Step(Event)) {
    player := &w.players[shot.seat - 1]

    if player.rail_queries == max(u32) {
        r.abort(ctx)
        return
    }

    player.rail_queries += 1
    live := proxies(w)
    query := net.query_view(
        &w.hit_history,
        view,
        live,
        ctx.tick,
        proc(a, b: [SEATS + MAX_MOBS]Proxy, fraction: u16) -> [SEATS + MAX_MOBS]Proxy {
            result := a

            for &proxy, i in result {
                proxy = proxy_blend(a[i], b[i], fraction)
            }

            return result
        },
    )
    judged, status, at, can_judge := query.value, query.status, query.tick, query.available
    player.last_query, player.last_judged = status, can_judge ? at : 0

    if can_judge && status == .Historical {
        if player.historical_queries == max(u32) {
            r.abort(ctx)
            return
        }

        player.historical_queries += 1
    }

    if !can_judge {
        if player.rejected_queries == max(u32) {
            r.abort(ctx)
            return
        }

        player.rejected_queries += 1
    }

    segment := shot.velocity * f32(shot.ttl)

    if fraction, hit, normal := arena.contact(&w.layout, shot.position, segment); hit {
        segment *= fraction
        wall_append(
            feedback,
            Event {
                kind = .Wall,
                seat = shot.seat,
                generation = shot.generation,
                serial = shot.serial,
                position = shot.position + segment,
            },
            normal,
            false,
            u64(shot.generation) << 32 | u64(shot.seat),
            WALL_RAIL_KEY,
        )
    }

    flash_add(
        w,
        Flash {
            kind = mend ? .Mend : .Lance,
            seat = shot.seat,
            generation = shot.generation,
            serial = shot.serial,
            origin = shot.position,
            end = shot.position + segment,
            until = ctx.tick + 9,
        },
        ctx,
    )

    if !can_judge {
        return
    }

    if !mend {
        for alive, i in w.mobs.alive {
            if alive {
                proxy := judged[SEATS + i]
                mob := w.mobs.values[i]

                if mob.hp == 0 || !proxy.active || proxy.generation != w.mobs.generations[i] {
                    continue
                }

                if _, hit := p.beam_circle(shot.position, segment, proxy.position, w.catalog.mobs[mob.kind].radius);
                   hit {
                    damage_mob(w, i, shot, feedback, ctx)
                }
            }
        }

        return
    }

    nearest := f32(2)
    target := -1

    for current, i in live {
        if i >= SEATS {
            break
        }

        proxy := judged[i]

        if i == int(shot.seat - 1) || !current.active || !proxy.active || current.generation != proxy.generation {
            continue
        }

        if at, hit := p.beam_circle(shot.position, segment, proxy.position, 14); hit && at < nearest {
            nearest, target = at, i
        }
    }

    if target < 0 {
        return
    }

    friend := &w.players[target]
    amount := min(boosted_damage(shot.damage, player.boost_damage), max_health(friend.parts) - friend.hp)

    if player.healed > max(u32) - u32(amount) {
        r.abort(ctx)
        return
    }

    friend.hp += amount
    player.healed += u32(amount)
    notice(feedback, 4, int(shot.seat - 1), u32(amount), friend.position, ctx)
}

grenade_step :: proc(w: ^World, shot: ^Shot, feedback: ^Notices, ctx: ^r.Step(Event)) -> bool {
    boxes: [arena.COVER_COUNT]p.Aabb2

    for c, i in w.layout.covers {
        boxes[i] = {{f32(c.x), f32(c.y)}, {f32(c.x) + f32(c.w), f32(c.y) + f32(c.h)}}
    }

    body := p.Carom2{shot.position, shot.velocity}

    if !p.carom2_step(&body, 1, 0.72, 0.1, {{24, 24}, {arena.WIDTH - 24, arena.HEIGHT - 24}}, boxes[:]) {
        r.abort(ctx)
        return false
    }

    shot.position, shot.velocity = body.position, body.velocity
    shot.ttl -= 1
    detonate := shot.ttl == 0

    for alive, i in w.mobs.alive {
        if alive && w.mobs.values[i].hp > 0 && p.in_reach(w.mobs.values[i].position, shot.position, 22) {
            detonate = true
            break
        }
    }

    if !detonate {
        return false
    }

    flash_add(
        w,
        Flash {
            kind = .Boom,
            seat = shot.seat,
            generation = shot.generation,
            serial = shot.serial,
            origin = shot.position,
            radius = 72,
            until = ctx.tick + 17,
        },
        ctx,
    )
    player := &w.players[shot.seat - 1]

    if player.generation == shot.generation {
        if player.blasts == max(u32) {
            r.abort(ctx)
            return false
        }

        player.blasts += 1
        notice(feedback, 5, int(shot.seat - 1), 1, shot.position, ctx)
    }

    for alive, i in w.mobs.alive {
        if alive && w.mobs.values[i].hp > 0 && p.in_reach(w.mobs.values[i].position, shot.position, 72) {
            payload := shot^

            if source := credited(w, Credit{shot.seat, shot.generation}); source != nil {
                payload.damage = boosted_damage(payload.damage, source.boost_damage)
            }

            damage_mob(w, i, payload, feedback, ctx)
        }
    }

    return true
}
