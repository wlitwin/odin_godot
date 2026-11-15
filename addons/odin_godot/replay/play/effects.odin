package replay_play

// Stack counts and durations are values; the game owns definitions, credit and
// what a pulse does. Zero is the canonical empty slot.
Effect :: struct {
    kind, power: u8,
    left:        u16,
}

effect_stack :: proc(effects: []Effect, kind, cap: u8, ticks: u16) -> (index: int, ok: bool) {
    if kind == 0 || cap == 0 || ticks == 0 {
        return -1, false
    }

    for &effect, i in effects {
        if effect.kind == kind {
            if effect.power < cap {
                effect.power += 1
            }

            effect.left = max(effect.left, ticks)
            return i, true
        }
    }

    for &effect, i in effects {
        if effect.kind == 0 {
            effect = {kind, 1, ticks}
            return i, true
        }
    }

    return -1, false
}

effects_tick :: proc(effects: []Effect) {
    for &effect in effects {
        if effect.kind == 0 {
            continue
        }

        if effect.left <= 1 {
            effect = {}
        } else {
            effect.left -= 1
        }
    }
}

Telegraph :: struct {
    left, wind: u16,
}

telegraph_start :: proc(t: ^Telegraph, wind: u16) {
    t^ = {wind, wind}
}

telegraph_tick :: proc(t: ^Telegraph) -> bool {
    if t.left == 0 {
        return false
    }

    t.left -= 1
    return t.left == 0
}

telegraph_cancel :: proc(t: ^Telegraph) {
    t^ = {}
}

telegraph_fraction :: proc(t: Telegraph) -> f32 {
    return t.wind > 0 ? 1 - f32(t.left) / f32(t.wind) : 0
}
