package duel

import r "godot:replay"
import p "godot:replay/play"
import h "godot:replay/history"
import net "godot:replay/net"
import lb "godot:replay/lobby"

reset_player :: proc(w: ^World, seat: u16, ctx: ^r.Step(Event)) {
    player := &w.players[seat - 1]

    if player.life == max(u32) {
        r.abort(ctx)
        return
    }

    life := player.life + 1
    position := spawn(w, seat)
    names := [SEATS]string{"Gunner 1", "Gunner 2", "Gunner 3", "Gunner 4"}
    w.names[seat - 1], _ = lb.name(names[seat - 1])
    player^ = {
        initialized = true,
        connected   = true,
        life        = life,
        hp          = 3,
        gold        = w.starting_gold,
        position    = position,
        drone       = {position[0], clamp(position[1] - 40, 12, 348)},
    }
}

step :: proc(
    w: ^World,
    controls: [SEATS]Controls,
    views: [SEATS]net.View_Time,
    joins, leaves: u64,
    ctx: ^r.Step(Event),
) {
    w.clock = ctx.tick
    fired, lobbed: [SEATS]bool

    for &player, i in w.players {
        bit := u64(1) << uint(i)

        if leaves & bit != 0 {
            player.connected = false
        }

        if joins & bit != 0 {
            if !player.initialized {
                reset_player(w, u16(i + 1), ctx)
            }

            player.connected = true
        }

        if !player.connected || !w.started {
            continue
        }

        c := controls[i]
        player.drone += [2]f32{f32(c.drone[0]), f32(c.drone[1])} * 1.6
        player.drone = {clamp(player.drone[0], 12, 628), clamp(player.drone[1], 12, 348)}

        if player.hp <= 0 {
            player.velocity = {}

            if player.respawn_at != 0 && ctx.tick >= player.respawn_at {
                if player.life == max(u32) {
                    r.abort(ctx)
                    return
                }

                player.life += 1
                player.hp, player.respawn_at, player.position = 3, 0, spawn(w, u16(i + 1))
                r.emit(ctx, u64(i + 1), 3, Event{kind = .Respawned, seat = u8(i + 1), position = player.position})
            }

            continue
        }

        player.aim = c.aim

        if c.buttons & FIRE != 0 && player.fire_cd == 0 {
            fired[i] = true
            player.fire_cd = FIRE_CD
        }

        if c.buttons & LOB != 0 && player.lob_cd == 0 {
            lobbed[i] = true
            player.lob_cd = LOB_CD
        }

        dashing := player.dash_cd > DASH_CD - DASH_LEN

        if !dashing {
            dir := normalize({f32(c.move[0]), f32(c.move[1])})
            player.velocity = dir * RUN_SPEED * (player.boots ? f32(1.3) : f32(1))

            if c.buttons & DASH != 0 && player.dash_cd == 0 && dir != ([2]f32{}) {
                player.velocity = dir * DASH_SPEED
                player.dash_cd = DASH_CD
            }
        }

        if player.dash_cd > 0 {
            player.dash_cd -= 1
        }

        player.position += player.velocity
        player.position = {clamp(player.position[0], 21, 619), clamp(player.position[1], 21, 339)}
        crates := CRATES

        for crate in crates {
            p.circle_pushout(&player.position, BODY_RADIUS, crate)
        }

        if player.fire_cd > 0 {
            player.fire_cd -= 1
        }

        if player.lob_cd > 0 {
            player.lob_cd -= 1
        }
    }

    boxes := hurtboxes(w)
    h.record(&w.history, ctx.tick, boxes)
    step_bullets(w, ctx)

    for player, i in w.players {
        if fired[i] && player.hp > 0 {
            shoot(w, i, views[i], boxes, ctx)
        }

        if lobbed[i] && player.hp > 0 {
            key, valid := p.spawn_key(ctx.tick, u8(i + 1), 2)

            if !valid {
                r.abort(ctx)
                return
            }

            dir := direction(player.aim)

            if _, added := r.pool_insert(
                &w.bullets,
                Bullet{key, player.position + dir * 13, dir * 2.6, LOB_LIFE, u8(i + 1)},
            ); !added {
                r.abort(ctx)
                return
            }

            w.lobs += 1
            r.emit(ctx, u64(i + 1), 2, Event{kind = .Lobbed, seat = u8(i + 1), position = player.position, key = key})
        }
    }
}

hurtboxes :: proc(w: ^World) -> [SEATS]p.Hurtbox2 {
    boxes: [SEATS]p.Hurtbox2

    for player, i in w.players {
        boxes[i] = {
            u64(player.life) << 8 | u64(i + 1),
            player.position,
            BODY_RADIUS,
            player.connected && player.hp > 0,
        }
    }

    return boxes
}

wall_limit :: proc(origin, dir: [2]f32) -> f32 {
    limit := f32(800)

    if dir[0] > 1e-6 {
        limit = min(limit, (628 - origin[0]) / dir[0])
    }

    if dir[0] < -1e-6 {
        limit = min(limit, (12 - origin[0]) / dir[0])
    }

    if dir[1] > 1e-6 {
        limit = min(limit, (348 - origin[1]) / dir[1])
    }

    if dir[1] < -1e-6 {
        limit = min(limit, (12 - origin[1]) / dir[1])
    }

    crates := CRATES

    for crate in crates {
        limit = min(limit, p.ray_aabb(origin, dir, crate, limit))
    }

    return max(limit, 0)
}

shoot :: proc(w: ^World, index: int, view: net.View_Time, live: [SEATS]p.Hurtbox2, ctx: ^r.Step(Event)) {
    player := w.players[index]
    request := w.rewind ? view : net.View_Time{status = .Live}
    query := net.query_view(
        &w.history,
        request,
        live,
        ctx.tick,
        proc(a, b: [SEATS]p.Hurtbox2, fraction: u16) -> [SEATS]p.Hurtbox2 {
            result := a

            for &box, i in result {
                box = p.hurtbox_blend(a[i], b[i], fraction)
            }

            return result
        },
    )
    boxes, judged, status, can_judge := query.value, query.tick, query.status, query.available
    w.shots += 1

    if !can_judge {
        w.expired_queries += 1
    }

    dir := direction(player.aim)
    nearest, victim := wall_limit(player.position, dir), -1

    if can_judge {
        for box, i in boxes {
            if i == index || !box.active || !w.players[i].connected || w.players[i].hp <= 0 || box.id != live[i].id {
                continue
            }

            if distance := p.ray_circle(player.position, dir, box.position, box.radius, nearest); distance < nearest {
                nearest, victim = distance, i
            }
        }
    }

    r.emit(
        ctx,
        u64(index + 1),
        1,
        Event {
            kind = .Shot,
            seat = u8(index + 1),
            target = victim < 0 ? 0 : u8(victim + 1),
            position = player.position,
            aim = player.aim,
            judged_tick = judged,
            query = status,
        },
    )

    if victim >= 0 {
        w.hits += 1
        damage(w, victim, index, true, 100 + u64(index), ctx)
    }
}

damage :: proc(w: ^World, victim, shooter: int, bounty: bool, cause: u64, ctx: ^r.Step(Event)) {
    player := &w.players[victim]

    if player.hp <= 0 {
        return
    }

    player.hp -= 1
    r.emit(
        ctx,
        cause,
        u64(victim + 1),
        Event{kind = .Hit, seat = u8(shooter + 1), target = u8(victim + 1), position = player.position},
    )

    if player.hp == 0 {
        player.deaths += 1
        w.players[shooter].kills += 1

        if bounty {
            w.players[shooter].gold += 1
        }

        player.respawn_at = ctx.tick + 120
        r.emit(
            ctx,
            cause,
            16 + u64(victim),
            Event{kind = .Killed, seat = u8(shooter + 1), target = u8(victim + 1), position = player.position},
        )
    }
}

step_bullets :: proc(w: ^World, ctx: ^r.Step(Event)) {
    for &bullet, i in w.bullets.values {
        if !w.bullets.alive[i] {
            continue
        }

        bullet.position += bullet.velocity
        bullet.life -= 1

        if bullet.life == 0 ||
           bullet.position[0] < 12 ||
           bullet.position[0] > 628 ||
           bullet.position[1] < 12 ||
           bullet.position[1] > 348 {
            w.lands += 1
            r.emit(
                ctx,
                bullet.key,
                100,
                Event{kind = .Landed, seat = bullet.owner, position = bullet.position, key = bullet.key},
            )

            for player, victim in w.players {
                if player.connected &&
                   player.hp > 0 &&
                   victim + 1 != int(bullet.owner) &&
                   p.in_reach(player.position, bullet.position, 26) {
                    damage(w, victim, int(bullet.owner - 1), false, bullet.key, ctx)
                }
            }

            r.pool_remove(&w.bullets, r.Handle(Bullet){u32(i), w.bullets.generations[i]})
        }
    }
}

buy :: proc(w: ^World, seat: u16, action: Action, ctx: ^r.Step(Event)) -> bool {
    if seat < 1 || seat > SEATS || !action_valid(action) || !w.players[seat - 1].connected {
        return false
    }

    if action.name.length > 0 {
        w.names[seat - 1] = action.name
        return true
    }

    if action.start {
        if !w.manual_start || w.started || seat != leader(w) {
            return false
        }

        w.started = true
        return true
    }

    if !w.started {
        return false
    }

    player := &w.players[seat - 1]

    if action.item != 1 || player.boots || player.gold == 0 {
        return false
    }

    player.gold -= 1
    player.boots = true
    w.buys += 1
    r.emit(ctx, u64(seat), 4, Event{kind = .Bought, seat = u8(seat)})
    return true
}
