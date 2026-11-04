package scrapyard_flow

import "core:fmt"
import co "godot:replay/comms"
import lb "godot:replay/lobby"
import game "../game"

News_Player :: struct {
    name: lb.Name,
    generation: u32,
    present, named: bool,
}

News_State :: struct {
    run: u32,
    floor: u8,
    stage: game.Stage,
    wave: u16,
    total: u8,
    depart, boss, horde: bool,
    players: [game.SEATS]News_Player,
}

NEWS_BATCH :: 16

// Legacy profiles allow some Unicode controls that communications forbids.
// Adapt the display name without changing saved profiles or gameplay schemas.
news_name :: proc(value: game.Name, seat: int) -> lb.Name {
    value := value
    name, ok := lb.name(game.name_string(&value))

    if !ok {
        name, _ = lb.name(fmt.tprintf("runner %d", seat))
    }

    return name
}

news_state :: proc(w: ^game.World) -> (state: News_State) {
    state.run, state.floor, state.stage = w.run, w.floor, w.stage
    state.wave, state.total, state.depart = w.director.wave, w.wave_count, w.depart.left > 0
    state.horde =
        w.rules.enabled &&
        w.rules.horde_every > 0 &&
        w.floor % w.rules.horde_every == 0 &&
        !(w.rules.boss_every > 0 && w.floor % w.rules.boss_every == 0)

    for p, i in w.players {
        state.players[i] = {
            news_name(p.profile.name, i + 1),
            p.generation,
            p.connected && p.profile.name.count > 0,
            p.profile.name.count > 0,
        }
    }

    for alive, i in w.mobs.alive {
        if alive && w.mobs.values[i].kind == 4 && w.mobs.values[i].hp > 0 {
            state.boss = true
            break
        }
    }

    return
}

// Called for every newly confirmed authority tick, not sampled client frames.
// A bounded batch can be retried atomically by the external communications feed.
news_lines :: proc(before, after: News_State) -> (lines: [NEWS_BATCH]co.Payload, count: int) {
    put :: proc(lines: ^[NEWS_BATCH]co.Payload, count: ^int, text: string) {
        value, ok := co.text_payload(text, true)
        assert(ok && count^ < NEWS_BATCH)
        lines[count^] = value
        count^ += 1
    }

    for p, i in after.players {
        old := before.players[i]

        if p.present && (!old.present || p.generation != old.generation) {
            name := p.name
            put(
                &lines,
                &count,
                fmt.tprintf(
                    "%s %s",
                    lb.text(&name),
                    old.generation == p.generation && old.named ? "climbs back over the fence" : "rolls up to the yard",
                ),
            )
        } else if old.present && !p.present {
            name := old.name
            put(&lines, &count, fmt.tprintf("%s is gone — their runner waits", lb.text(&name)))
        }
    }

    if after.run != before.run {
        put(&lines, &count, "dragged back to the surface — parts and cores stay with you")
    } else if after.floor != before.floor {
        put(&lines, &count, fmt.tprintf("floor %d — deeper into the heaps", after.floor))
    } else if before.stage == .Staging && after.stage == .Yard {
        put(&lines, &count, "the yard opens — something scuttles in the heaps")
    }

    if after.stage == .Over && before.stage != .Over {
        put(&lines, &count, "the yard goes quiet...")
    }

    if before.boss && !after.boss && after.stage != .Over && after.floor == before.floor && after.run == before.run {
        put(&lines, &count, "the TITAN falls — the floor is yours")
    }

    if after.stage == .Clear && before.stage != .Clear {
        put(&lines, &count, "floor clear — a core earned; shop's open, gate's lit")
    }

    if after.depart && !before.depart {
        put(&lines, &count, "the platform shudders — descending...")
    }

    if before.depart && !after.depart && after.stage == .Clear {
        put(&lines, &count, "the platform holds — regroup on the pad")
    }

    if after.boss && !before.boss {
        put(&lines, &count, "the heaps CONVULSE — the SCRAP TITAN rises")
    }

    if after.horde && (after.floor != before.floor || after.run != before.run || before.stage == .Staging) {
        put(&lines, &count, "the heaps EMPTY — a horde floor")
    }

    if after.wave > 1 && after.wave != before.wave {
        put(&lines, &count, fmt.tprintf("wave %d of %d rolls in", after.wave, after.total))
    }

    return
}
