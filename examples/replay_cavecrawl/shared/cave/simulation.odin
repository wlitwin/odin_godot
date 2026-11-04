package cave

import r "godot:replay"
import p "godot:replay/play"
import lb "godot:replay/lobby"

Floor_Entry :: enum {
    Descent,
    Initial,
    Restart,
}

enter_floor :: proc(w: ^World, entry: Floor_Entry = .Descent) {
    def := world_floor(w)
    w.chest = {}

    if def.gems > 0 {
        w.chest[0] = p.Stack{GEM, def.gems}
    }

    if def.torches > 0 {
        w.chest[1] = p.Stack{TORCH, def.torches}
    }

    w.door_open = false
    r.pool_clear(&w.dwellers)
    r.pool_clear(&w.rocks)
    r.pool_clear(&w.pickups)
    w.director = {}
    w.dens_used = 0

    switch entry {
    case .Initial:
        w.relic = {
            position = {120, 80},
            version  = w.relic.version + 1,
        }
    case .Restart:
        // Restart releases the existing relic at its last simulated position.
        if w.relic.carrier != 0 {
            w.relic.carrier = 0
            w.relic.version += 1
        }
    case .Descent:
    // The same relic survives floor cleanup, including its carrier/version.
    }

    for &player, i in w.players {
        if !player.initialized {
            continue
        }

        player.position = {80 + f32(i) * 22, 120}

        if entry != .Descent {
            player.hp, player.stamina = MAX_HP, MAX_STAMINA
            player.bag = {}
            player.rock_cd, player.heal_cd, player.respawn_at = 0, 0, 0

            // Original restart resets abilities but leaves active status effects.
            if entry == .Initial {
                player.chill = 0
            }
        }
        // Descent preserves the complete avatar state after this tick's normal
        // decay. Reserved disconnected players also retain their respawn deadline.
    }

    if entry == .Descent && w.relic.carrier != 0 && w.players[w.relic.carrier - 1].connected {
        w.relic.position = w.players[w.relic.carrier - 1].position + [2]f32{10, -12}
    }
}

step :: proc(w: ^World, controls: [SEATS]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
    step_motion(w, controls, joins, leaves, ctx, true)
}

// The owner-observation profile supplies accepted avatar/relic positions before
// this reducer. All inventory, combat, roster and progression rules stay shared.
step_motion :: proc(
    w: ^World,
    controls: [SEATS]Control,
    joins, leaves: u64,
    ctx: ^r.Step(Event),
    simulated_motion: bool,
    impact_events: bool = true,
) {
    w.clock = ctx.tick
    lb.roster(&w.lobby, joins, leaves)

    if lb.auto_start(&w.lobby) {
        enter_floor(w, .Initial)
    }

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

        if !player.connected || w.lobby.phase == .Waiting {
            continue
        }

        if player.rock_cd > 0 {
            player.rock_cd -= 1
        }

        if player.heal_cd > 0 {
            player.heal_cd -= 1
        }

        if player.chill > 0 {
            player.chill -= 1
        }

        if player.hp == 0 {
            if player.respawn_at != 0 && w.clock >= player.respawn_at {
                player.hp, player.stamina, player.respawn_at = MAX_HP, MAX_STAMINA, 0
                player.position = {80, 120}
                r.emit(ctx, u64(i + 1), 2, Event{.Respawned, player.position, u16(i + 1), MAX_HP})
            }

            continue
        }

        if w.clock % HZ == 0 {
            player.stamina = min(player.stamina + 1, MAX_STAMINA)
        }

        if w.won || !simulated_motion {
            continue
        }

        movement := [2]f32{f32(controls[i].move[0]), f32(controls[i].move[1])}

        if movement[0] != 0 && movement[1] != 0 {
            movement *= 0.70710678
        }

        player.position += movement * (WALK_SPEED / HZ) * (player.chill > 0 ? f32(0.5) : f32(1))
        player.position[0] = clamp(player.position[0], 20, 620)
        player.position[1] = clamp(player.position[1], 20, 350)
    }

    if w.lobby.phase == .Waiting {
        return
    }

    if simulated_motion && w.relic.carrier != 0 {
        carrier := &w.players[w.relic.carrier - 1]

        // Ownership survives death and a reserved connection loss. An absent
        // carrier leaves the prop parked; its returning identity resumes carrying.
        if carrier.connected {
            w.relic.position = carrier.position + [2]f32{10, -12}
        }
    }

    if w.won {
        return
    }

    step_rocks(w, ctx, impact_events)
    step_director(w, ctx)
    step_dwellers(w, ctx)

    if w.director.done && w.door_open {
        present, ready := 0, 0
        def := world_floor(w)

        for player in w.players {
            if !player.connected {
                continue
            }

            present += 1

            if player.hp > 0 && p.in_reach(player.position, def.door, REACH) {
                ready += 1
            }
        }

        if present > 0 && ready == present {
            if w.depth == 2 {
                w.won = true
                r.emit(ctx, 1000, 1, Event{kind = .Victory})
            } else {
                w.depth += 1
                enter_floor(w)
                r.emit(ctx, 1000, 1, Event{kind = .Floor, amount = i32(w.depth)})
            }
        }
    }
}

hurt_player :: proc(w: ^World, victim: int, damage: i32, shooter: u16, chill: bool, cause: u64, ctx: ^r.Step(Event)) {
    player := &w.players[victim]

    if player.hp <= 0 {
        return
    }

    if shooter != 0 {
        w.players[shooter - 1].damage += u32(damage)
    }

    player.hp = max(player.hp - damage, 0)
    r.emit(ctx, cause, 1, Event{.Hit, player.position, u16(victim + 1), damage})

    if player.hp == 0 {
        player.deaths += 1

        if shooter != 0 {
            w.players[shooter - 1].kills += 1
        }

        spill(w, player)
        player.respawn_at = w.clock + 60
        r.emit(ctx, cause, 2, Event{.Died, player.position, u16(victim + 1), 0})
    } else if chill {
        player.chill = 40
    }
}

step_rocks :: proc(w: ^World, ctx: ^r.Step(Event), impact_events: bool = true) {
    for &rock, i in w.rocks.values {
        if !w.rocks.alive[i] {
            continue
        }

        from, to := rock.position, rock.position + rock.velocity
        closest := f32(2)
        victim, dweller := -1, -1

        for player, j in w.players {
            if !player.connected || player.hp <= 0 || j + 1 == int(rock.shooter) {
                continue
            }

            if at, hit := p.segment_circle(from, to, player.position, BODY_RADIUS); hit && at < closest {
                closest, victim, dweller = at, j, -1
            }
        }

        for target, j in w.dwellers.values {
            if !w.dwellers.alive[j] {
                continue
            }

            if at, hit := p.segment_circle(from, to, target.position, BODY_RADIUS); hit && at < closest {
                closest, dweller, victim = at, j, -1
            }
        }

        if victim >= 0 {
            hurt_player(
                w,
                victim,
                ROCK_DAMAGE,
                rock.shooter,
                true,
                u64(1) << 60 | u64(w.rocks.generations[i]) << 16 | u64(i),
                ctx,
            )
        }

        if dweller >= 0 {
            target := &w.dwellers.values[dweller]

            if impact_events {
                // The projectile identifies this occurrence; its key retains the
                // victim's exact generation even if the pool slot is recycled.
                target_key := u64(w.dwellers.generations[dweller]) << 32 | u64(dweller + 1)
                r.emit(
                    ctx,
                    u64(1) << 60 | u64(w.rocks.generations[i]) << 16 | u64(i),
                    target_key,
                    Event{.Hit, target.position, 0, ROCK_DAMAGE},
                )
            }

            target.hp = max(target.hp - ROCK_DAMAGE, 0)
            w.players[rock.shooter - 1].damage += u32(ROCK_DAMAGE)

            if target.hp == 0 {
                position := target.position
                w.players[rock.shooter - 1].slain += 1
                spawn_pickup(w, position, p.Stack{TORCH, 1})
                r.pool_remove(&w.dwellers, r.Handle(Dweller){u32(dweller), w.dwellers.generations[dweller]})
                director_note_death(w, ctx)
                r.emit(
                    ctx,
                    2000 + u64(dweller),
                    u64(w.dwellers.generations[dweller]),
                    Event{.Slain, position, rock.shooter, 1},
                )
            }
        }

        rock.position = to
        rock.left -= 1

        if victim >= 0 || dweller >= 0 || rock.left == 0 {
            r.pool_remove(&w.rocks, r.Handle(Rock){u32(i), w.rocks.generations[i]})
        }
    }
}

step_director :: proc(w: ^World, ctx: ^r.Step(Event)) {
    if w.director.done {
        return
    }

    // A direct server has no started party before its first join. Once running,
    // the original director continues even if every player temporarily leaves.
    if w.director.wave == 0 {
        present := false

        for player in w.players {
            if player.connected {
                present = true
            }
        }

        if !present {
            return
        }
    }

    def := world_floor(w)

    if w.director.remaining > 0 {
        // Explicit conversion from C1–C3 retains an already scheduled deadline.
        if w.clock < w.director.next_spawn {
            return
        }

        position := def.dens[w.dens_used % 2]

        if _, ok := r.pool_insert(&w.dwellers, Dweller{position = position, home = position, hp = 70}); ok {
            w.dens_used += 1
            w.director.remaining -= 1
            w.director.next_spawn = w.clock // one spawn per invocation, not a burst
        }

        return
    }

    if w.dwellers.count > 0 || w.clock < w.director.rest_until {
        return
    }

    if w.director.wave == def.wave_count {
        w.director.done = true
        return
    }

    w.director.wave += 1
    w.director.remaining = def.waves[w.director.wave - 1]
    w.director.next_spawn = w.clock
    // Announcement consumes this tick. The first spawn occurs next tick. Empty
    // waves advance on the next call; with no death, they do not start a rest.
}

director_note_death :: proc(w: ^World, ctx: ^r.Step(Event)) {
    if w.dwellers.count != 0 || w.director.remaining != 0 || w.director.wave == 0 {
        return
    }

    rest := u64(world_floor(w).rests[w.director.wave - 1])

    if rest > max(u64) - w.clock {
        r.abort(ctx)
        return
    }

    w.director.rest_until = w.clock + rest
}

step_dwellers :: proc(w: ^World, ctx: ^r.Step(Event)) {
    def := world_floor(w)

    for &dweller, i in w.dwellers.values {
        if !w.dwellers.alive[i] {
            continue
        }

        if dweller.bite_cd > 0 {
            dweller.bite_cd -= 1
        }

        nearest := -1
        best := f32(100 * 100)

        for player, j in w.players {
            if !player.connected || player.hp <= 0 {
                continue
            }

            d := player.position - dweller.position
            distance := d[0] * d[0] + d[1] * d[1]

            if distance <= best {
                nearest, best = j, distance
            }
        }

        dweller.mood = 0

        if nearest >= 0 {
            target := w.players[nearest].position

            if dweller.hp <= 35 {
                dweller.mood = 2
                dweller.position = p.step_toward(dweller.position, dweller.position * 2 - target, 2)
            } else if best <= 24 * 24 {
                dweller.mood = 1

                if dweller.bite_cd == 0 {
                    dweller.bite_cd = 30
                    hurt_player(
                        w,
                        nearest,
                        10,
                        0,
                        false,
                        u64(2) << 60 | u64(w.dwellers.generations[i]) << 16 | u64(i),
                        ctx,
                    )
                }
            } else {
                dweller.mood = 1
                dweller.position = p.around_rect(dweller.position, target, def.rift, 4)
            }
        } else {
            dweller.position = p.around_rect(dweller.position, dweller.home, def.rift, 4)
        }
    }
}
