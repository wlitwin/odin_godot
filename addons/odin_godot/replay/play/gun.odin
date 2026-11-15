package replay_play

// Pure magazine/reload/jam mechanism. Cadence and the shot's world effect belong
// to the caller; every persistent field is a value that can be replayed/saved.
Gun_Mode :: enum u8 {
    Ready,
    Reloading,
    Jammed,
}

Gun_Pull :: enum u8 {
    Held,
    Fired,
    Jammed,
    Empty,
    Clear_Tap,
    Cleared,
}

Gun_Error :: enum {
    None,
    Invalid,
    Exhausted,
}

Gun_Def :: struct {
    mag, reload_ticks, jam_per_mille: u16,
    jam_taps:                         u8,
}

Gun_State :: struct {
    ammo:        u16,
    mode:        Gun_Mode,
    reload_left: u16,
    taps:        u8,
    salt, spent: u32,
}

Gun_Result :: struct {
    pull:  Gun_Pull,
    error: Gun_Error,
}

gun_def_valid :: proc(d: Gun_Def) -> bool {
    return d.mag > 0 && d.reload_ticks > 0 && d.jam_per_mille <= 1000 && d.jam_taps > 0
}

gun_valid :: proc(g: Gun_State, d: Gun_Def) -> bool {
    if !gun_def_valid(d) ||
       g.ammo > d.mag ||
       g.mode > .Jammed ||
       g.reload_left > d.reload_ticks ||
       g.taps > d.jam_taps {
        return false
    }

    if (g.mode == .Reloading) != (g.reload_left > 0) || (g.mode == .Jammed) != (g.taps > 0) {
        return false
    }

    return true
}

gun_equip :: proc(g: ^Gun_State, d: Gun_Def, salt: u32 = 0) -> Gun_Error {
    if !gun_def_valid(d) {
        return .Invalid
    }

    g^ = {
        ammo = d.mag,
        salt = salt,
    }
    return .None
}

gun_jams :: proc(g: Gun_State, d: Gun_Def) -> bool {
    if d.jam_per_mille == 0 {
        return false
    }

    h := g.salt * 2654435761 + g.spent * 40503 + 668265263
    h ~= h >> 15
    h *= 2246822519
    h ~= h >> 13
    return u16(h % 1000) < d.jam_per_mille
}

gun_tick :: proc(g: ^Gun_State, d: Gun_Def) -> Gun_Error {
    if !gun_valid(g^, d) {
        return .Invalid
    }

    if g.mode == .Reloading {
        g.reload_left -= 1

        if g.reload_left == 0 {
            g.ammo, g.mode = d.mag, .Ready
        }
    }

    return .None
}

gun_pull :: proc(g: ^Gun_State, d: Gun_Def) -> Gun_Result {
    if !gun_valid(g^, d) {
        return {error = .Invalid}
    }

    switch g.mode {
    case .Reloading:
        return {pull = .Held}
    case .Jammed:
        g.taps -= 1

        if g.taps == 0 {
            g.mode = .Ready
            return {pull = .Cleared}
        }

        return {pull = .Clear_Tap}
    case .Ready:
        if g.ammo == 0 {
            g.mode, g.reload_left = .Reloading, d.reload_ticks
            return {pull = .Empty}
        }

        if g.spent == max(u32) {
            return {error = .Exhausted}
        }

        jam := gun_jams(g^, d)
        g.ammo -= 1
        g.spent += 1

        if jam {
            g.mode, g.taps = .Jammed, d.jam_taps
            return {pull = .Jammed}
        }

        if g.ammo == 0 {
            g.mode, g.reload_left = .Reloading, d.reload_ticks
        }

        return {pull = .Fired}
    }

    return {error = .Invalid}
}
