package scrapyard_audio

import game "../game"
import content "../content"
import r "godot:replay"

Cue :: struct {
    kind: Sfx,
    position: [2]f32,
    spatial: bool,
    jolt: f32,
}

Player_Track :: struct {
    generation, warp, spent, purchases: u32,
    hp: u8,
    mode: u8,
    casts: [content.MAX_ABILITIES]u32,
}

Mob_Track :: struct {
    generation, shots: u32,
    hp, left: u16,
    alive: bool,
}

Observer :: struct {
    ready: bool,
    epoch, tick: u64,
    run: u32,
    clears, descents, wipes: u32,
    depart_seconds: u8,
    players: [game.SEATS]Player_Track,
    mobs: [game.MAX_MOBS]Mob_Track,
    dropped: u64,
}

gameplay :: proc(event: game.Event) -> (Cue, bool) {
    kind: Sfx

    #partial switch event.kind {
    case .Shot:
        switch event.detail {
        case 0, 3:
            kind = .Bolter
        case 1:
            kind = .Riveter
        case 2:
            kind = .Slime
        case 4:
            kind = .Ping
        case:
            return {}, false
        }
    case .Dash:
        kind = .Dash
    case .Hit, .Wall:
        kind = .Hit
    case .Killed:
        kind = .Kill
    case .Hurt:
        kind = .Ouch
    case .Pickup:
        kind = .Pickup
    case .Blast:
        kind = .Explode
    case:
        return {}, false
    }

    return {kind, event.position, true, 0}, true
}

track :: proc(w: ^game.World, epoch, tick: u64) -> Observer {
    o := Observer {
        ready = true,
        epoch = epoch,
        tick = tick,
        run = w.run,
        clears = w.clears,
        descents = w.descents,
        wipes = w.wipes,
    }

    if w.stage == .Clear && w.depart.left > 0 {
        o.depart_seconds = u8((u32(w.depart.left) + game.HZ - 1) / game.HZ)
    }

    for p, i in w.players {
        o.players[i] = {p.generation, p.warp, p.gun.spent, p.purchases, p.hp, u8(p.gun.mode), p.casts_by_ability}
    }

    for alive, i in w.mobs.alive {
        if alive {
            m := w.mobs.values[i]
            o.mobs[i] = {w.mobs.generations[i], m.shots, m.hp, m.tele.left, true}
        }
    }

    return o
}

// Only forward authoritative observations produce state-transition cues. A first
// observation, epoch/run change, or rewind establishes a silent baseline.
observe :: proc(o: ^Observer, epoch: u64, frame: ^r.Frame(game.World), out: []Cue) -> int {
    if epoch == 0 || o.ready && (epoch < o.epoch || epoch == o.epoch && frame.tick <= o.tick) {
        return 0
    }

    w := &frame.state
    next := track(w, epoch, frame.tick)
    next.dropped = o.dropped

    if !o.ready || epoch != o.epoch || w.run != o.run {
        o^ = next
        return 0
    }

    count := 0

    put :: proc(out: []Cue, count: ^int, dropped: ^u64, cue: Cue) {
        if count^ == len(out) {
            dropped^ += 1
            return
        }

        out[count^] = cue
        count^ += 1
    }

    if w.clears > o.clears {
        put(out, &count, &next.dropped, {kind = .Clear})
    }

    if w.descents > o.descents {
        put(out, &count, &next.dropped, {kind = .Descend})
    }

    if w.wipes > o.wipes {
        put(out, &count, &next.dropped, {kind = .Wipe})
    }

    if next.depart_seconds > 0 && next.depart_seconds != o.depart_seconds {
        put(out, &count, &next.dropped, {kind = .Buy, jolt = 1.2})
    }

    for p, i in w.players {
        old := o.players[i]

        if !p.connected || !p.in_yard || p.generation != old.generation || p.warp != old.warp {
            continue
        }

        if p.hp == 0 && old.hp > 0 {
            put(out, &count, &next.dropped, {kind = .Downed})
        }

        if p.hp > 0 && old.hp == 0 {
            put(out, &count, &next.dropped, {.Revive, p.position, true, 0})
        }

        if u8(p.gun.mode) != old.mode {
            if p.gun.mode == .Jammed {
                put(out, &count, &next.dropped, {.Jam, p.position, true, 0})
            }

            if p.gun.mode == .Ready && old.mode == 1 {
                put(out, &count, &next.dropped, {.Reload, p.position, true, 0})
            }

            if p.gun.mode == .Ready && old.mode == 2 {
                put(out, &count, &next.dropped, {.Unjam, p.position, true, 0})
            }
        }

        if p.purchases > old.purchases {
            put(out, &count, &next.dropped, {kind = .Buy})
        }

        for casts, id in p.casts_by_ability {
            if casts > old.casts[id] && content.ability_present(&w.catalog, u8(id)) {
                kind: Sfx = .Slime

                #partial switch w.catalog.abilities[id].family {
                case .Cone:
                    kind = .Ignite
                case .Buff:
                    kind = .Ping
                case:
                }

                put(out, &count, &next.dropped, {kind, p.position, true, 0})
            }
        }
    }

    for alive, i in w.mobs.alive {
        if alive {
            old := o.mobs[i]
            m := w.mobs.values[i]

            if !old.alive || w.mobs.generations[i] != old.generation {
                continue
            }

            if m.kind == 2 && m.shots > old.shots {
                put(out, &count, &next.dropped, {.Spit, m.position, true, 0})
            }

            if m.kind == 4 && m.tele.left > 0 && old.left == 0 {
                put(out, &count, &next.dropped, {.Slam, m.position, true, 0})
            }

            if m.kind == 3 && old.hp > 0 && m.hp == 0 {
                put(out, &count, &next.dropped, {.Pop, m.position, true, 0})
            }
        }
    }

    o^ = next
    return count
}

music_track :: proc(w: ^game.World) -> int {
    if w == nil || w.stage == .Staging || w.stage == .Over {
        return 0
    }

    if w.stage == .Clear {
        return 4
    }

    h := w.seed ~ (u32(w.floor) * 0x9E3779B9) ~ (w.run * 0x85EBCA6B)
    h = (h ~ (h >> 16)) * 0x45D9F3BB
    h = (h ~ (h >> 16)) * 0x45D9F3BB
    h ~= h >> 16
    return 1 + int(h % 3)
}
