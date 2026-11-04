package replay_history

import r "godot:replay"

// A bounded value-owned history suitable for collision proxies and other
// simulation dependencies. Place it in World to include it in rollback/save/
// migration. Queries copy values and never move live game entities temporarily.
Entry :: struct($T: typeid) {
    tick:  u64,
    value: T,
    valid: bool,
}

History :: struct($T: typeid, $N: int) {
    entries: [N]Entry(T),
}

record :: proc(h: ^History($T, $N), tick: u64, value: T) {
    #assert(N > 1)
    assert(r.value_supported(T))
    h.entries[tick % u64(N)] = {tick, value, true}
}

read :: proc(h: ^History($T, $N), tick: u64) -> (T, bool) {
    entry := &h.entries[tick % u64(N)]
    return entry.value, entry.valid && entry.tick == tick
}

bracket :: proc(h: ^History($T, $N), from, to: u64) -> (a, b: T, ok: bool) {
    if to < from || to - from >= u64(N) {
        return
    }

    x, found_a := read(h, from)
    y, found_b := read(h, to)
    return x, y, found_a && found_b
}
