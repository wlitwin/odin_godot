package dedicated_room_probe
import "core:math"
import "core:fmt"
import "core:mem"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import game "godot:examples/replay_scrapyard/shared/game"
import arena "godot:examples/replay_scrapyard/shared/arena"

combat_initial :: proc() -> game.World {
    w := game.initial(dedicated = true)
    w.rules = game.RUN_RULES
    w.rules.base_count, w.rules.wave_count, w.rules.barrels = 40, 1, 0
    // Original stress-harness gun overrides; damage, health and enemies are stock.
    w.catalog.guns[1].mechanism.mag = 255
    w.catalog.guns[1].mechanism.jam_per_mille = 0
    return w
}

unit :: proc(v: [2]f32) -> [2]f32 {
    length := math.sqrt(v[0] * v[0] + v[1] * v[1])
    return length > 0.0001 ? v / length : [2]f32{1, 0}
}

combat_counts :: proc(w: ^game.World) -> (shots, casts, kills, cooldowns: u64) {
    for p in w.players {
        shots += u64(p.shots)
        casts += u64(p.casts)
        kills += u64(p.kills)

        for c in p.ability_cd {
            if c.remaining > 0 {
                cooldowns += 1
            }
        }
    }

    return
}

combat_active :: proc(w: ^game.World) -> bool {
    shots, casts, _, cooldowns := combat_counts(w)
    return(
        w.stage == .Yard &&
        game.living_enemies(w) > 0 &&
        w.shots.count + w.lobs.count + w.zones.count > 0 &&
        shots >= 8 &&
        casts >= 2 &&
        cooldowns > 0 \
    )
}

combat_input :: #force_no_inline proc(self: ^DedicatedRoomProbe) -> game.Control {
    if self.member < 3 || !self.room.session.ready || !seen(self, "combat-start") {
        return {}
    }

    seat := rgd.session_seat(&self.room.session)

    if seat == 0 {
        return {}
    }

    observed, ok := rgd.session_authority_state(&self.room.session)

    if !ok {
        return {}
    }

    predicted, valid := rgd.session_state(&self.room.session)

    if !valid {
        return {}
    }

    position := predicted.state.players[seat - 1].position

    if !observed.state.players[seat - 1].in_yard || observed.state.players[seat - 1].hp == 0 {
        return {}
    }

    return combat_drive(&observed.state, seat, position)
}

combat_drive :: #force_no_inline proc(w: ^game.World, seat: u16, position: [2]f32) -> game.Control {
    control := game.Control {
        fire   = true,
        revive = true,
        aim    = {1, 0},
    }
    best := f32(1e30)
    target := -1

    for alive, i in w.mobs.alive {
        if alive && w.mobs.values[i].hp > 0 && !w.catalog.mobs[w.mobs.values[i].kind].prop {
            delta := w.mobs.values[i].position - position
            distance := delta[0] * delta[0] + delta[1] * delta[1]

            if distance < best {
                best, target = distance, i
            }
        }
    }

    if target < 0 {
        return control
    }

    delta := w.mobs.values[target].position - position
    control.aim = unit(delta)
    control.move = best < 180 * 180 ? -control.aim : [2]f32{-control.aim[1], control.aim[0]}

    if _, blocked := arena.clip(&w.layout, position + control.aim * 24, delta); blocked {
        control.move = bot_path(&w.layout, position, w.mobs.values[target].position)
    }

    wanted := arena.move(&w.layout, position, control.move * game.RUNNER_SPEED, 1.0 / f32(game.HZ))

    if abs(wanted[0] - position[0]) + abs(wanted[1] - position[1]) < 0.5 {
        control.move = {-control.move[1], control.move[0]}
    }

    return control
}

combat_actions :: #force_no_inline proc(self: ^DedicatedRoomProbe, w: ^game.World, seat: u16, epoch: u64) {
    connected := 0

    for p in w.players {
        if p.connected {
            connected += 1
        }
    }

    if !self.profile_sent && !w.players[seat - 1].in_yard {
        profile := w.players[seat - 1].profile
        profile.iron = 1
        profile.abilities = {1, 2}
        _, e := rgd.room_issue(&self.room, game.Action{kind = .Profile, profile = profile})

        if e == .None {
            self.profile_sent = true
        }

        return
    }

    if !self.ready_sent && connected == 2 && w.players[seat - 1].profile.iron == 1 {
        _, e := rgd.room_issue(&self.room, game.Action{kind = .Ready, ready = true})

        if e == .None {
            self.ready_sent = true
        }
    }

    if !seen(self, "combat-start") || !w.players[seat - 1].in_yard || w.players[seat - 1].hp == 0 {
        return
    }

    now := gd.time_get_ticks_msec(gd.singleton_time())

    if now < self.cast_due {
        return
    }

    for slot in 0 ..< 2 {
        if w.players[seat - 1].ability_cd[slot].remaining == 0 {
            control := combat_input(self)
            _, e := rgd.room_issue(&self.room, game.Action{kind = .Cast, slot = u8(slot), aim = control.aim})

            if e == .None {
                self.cast_due = now + 250
                return
            }
        }
    }
}

combat_observe :: #force_no_inline proc(self: ^DedicatedRoomProbe, w: ^game.World, epoch: u64) {
    living := game.living_enemies(w)
    self.peak = max(self.peak, living)
    shots, casts, kills, cooldowns := combat_counts(w)

    if self.room.session.authority && w.spawn_index >= 40 && living >= 30 {
        mark(self, "combat-start")
    }

    if self.room.session.authority && w.clock >= self.combat_sample {
        self.combat_sample = w.clock + 60
        gd.print_str(
            fmt.tprintf(
                "DEDICATED_COMBAT_SAMPLE epoch=%d tick=%d living=%d peak=%d shots=%d casts=%d kills=%d projectiles=%d lobs=%d zones=%d cooldowns=%d hp=%d/%d",
                epoch,
                w.clock,
                living,
                self.peak,
                shots,
                casts,
                kills,
                w.shots.count,
                w.lobs.count,
                w.zones.count,
                cooldowns,
                w.players[0].hp,
                w.players[1].hp,
            ),
        )
    }

    if self.room.session.authority && epoch > 1 && self.checked_epoch == epoch && !self.continued {
        if w.run != 0 {
            fail(self, "new run before combat continuation")
            return
        }

        if shots >= self.restored_shots + 10 && casts >= self.restored_casts + 2 && kills > self.restored_kills {
            self.continued = true
            gd.print_str(
                fmt.tprintf(
                    "DEDICATED_COMBAT_CONTINUED epoch=%d shots=%d casts=%d kills=%d",
                    epoch,
                    shots,
                    casts,
                    kills,
                ),
            )
            mark(self, "combat-continued")
        }
    }
}

combat_checkpoint :: #force_no_inline proc(self: ^DedicatedRoomProbe, tick: u64) -> bool {
    frame, ok := r.read(&self.room.session.server.timeline, tick)
    return ok && combat_active(&frame.state)
}

bot_path :: proc(layout: ^arena.Layout, from, target: [2]f32) -> [2]f32 {
    COLS :: 60
    ROWS :: 34
    CELLS :: COLS * ROWS

    if d := target - from; d[0] * d[0] + d[1] * d[1] < 35 * 35 {
        return {}
    }

    start := clamp(int(from[1] / 32), 0, ROWS - 1) * COLS + clamp(int(from[0] / 32), 0, COLS - 1)
    previous: [CELLS]int

    for &value in previous {
        value = -2
    }

    queue: [CELLS]int
    queue[0] = start
    previous[start] = -1
    head, tail, goal := 0, 1, -1

    for head < tail {
        at := queue[head]
        head += 1
        position := [2]f32{f32(at % COLS) * 32 + 16, f32(at / COLS) * 32 + 16}
        d := target - position

        if d[0] * d[0] + d[1] * d[1] < 40 * 40 {
            goal = at
            break
        }

        neighbors := [4]int{at - 1, at + 1, at - COLS, at + COLS}

        for next in neighbors {
            if next < 0 ||
               next >= CELLS ||
               previous[next] != -2 ||
               abs(next % COLS - at % COLS) + abs(next / COLS - at / COLS) != 1 {
                continue
            }

            point := [2]f32{f32(next % COLS) * 32 + 16, f32(next / COLS) * 32 + 16}
            blocked :=
                point[0] < arena.MARGIN ||
                point[0] > arena.WIDTH - arena.MARGIN ||
                point[1] < arena.MARGIN ||
                point[1] > arena.HEIGHT - arena.MARGIN

            for c in layout.covers {
                if point[0] > f32(c.x) - 16 &&
                   point[0] < f32(c.x + u16(c.w)) + 16 &&
                   point[1] > f32(c.y) - 16 &&
                   point[1] < f32(c.y + u16(c.h)) + 16 {
                    blocked = true
                    break
                }
            }

            if blocked {
                continue
            }

            previous[next] = at
            queue[tail] = next
            tail += 1
        }
    }

    if goal < 0 {
        return unit(target - from)
    }

    if goal == start {
        return unit(target - from)
    }

    for previous[goal] != start {
        goal = previous[goal]
    }

    return unit([2]f32{f32(goal % COLS) * 32 + 16, f32(goal / COLS) * 32 + 16} - from)
}
