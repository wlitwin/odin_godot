package duel_corpus

import r "godot:replay"
import sc "godot:replay/schema"
import game "../duel"

Result :: struct {
    hash:        u64,
    shots, hits: u32,
    kills:       [2]u32,
    ok:          bool,
}

run :: proc(seed: u64, ticks: u32) -> Result {
    w := game.initial(seed)
    state, event: sc.Schema
    defer sc.destroy(&state)
    defer sc.destroy(&event)

    if sc.init(&state, game.World).error != .None || sc.init(&event, r.Occurrence(game.Event)).error != .None {
        return {}
    }

    state_bytes := make([]u8, state.wire_size)
    event_bytes := make([]u8, event.wire_size)
    defer delete(state_bytes)
    defer delete(event_bytes)
    hash := u64(0xcbf29ce484222325)

    for tick in u64(1) ..= u64(ticks) {
        storage: [64]r.Occurrence(game.Event)
        ctx := r.Step(game.Event) {
            tick   = tick,
            epoch  = 1,
            events = storage[:],
        }
        input := [2]game.Input{game.corpus_input(tick, 0), game.corpus_input(tick, 1)}
        game.step(&w, input, &ctx)

        if ctx.error != .None || !game.state_valid(w) || sc.encode(&state, w, state_bytes).error != .None {
            return {}
        }

        hash = sc.digest(state_bytes, hash)
        count := [2]u8{u8(ctx.count), u8(ctx.count >> 8)}
        hash = sc.digest(count[:], hash)

        for e in storage[:ctx.count] {
            if sc.encode(&event, e, event_bytes).error != .None {
                return {}
            }

            hash = sc.digest(event_bytes, hash)
        }
    }

    return {hash, w.shots, w.hits, w.kills, true}
}
