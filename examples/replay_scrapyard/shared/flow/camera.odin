package scrapyard_flow

import game "../game"

Camera_Target :: struct {
    seat: u16,
    generation: u32,
}

// Keep a living connected teammate until it becomes ineligible. Identity
// includes generation, so a reused seat never silently retains an old body.
camera_target :: proc(w: ^game.World, me: u16, previous: Camera_Target) -> Camera_Target {
    if me == 0 || me > game.SEATS || !w.players[me - 1].in_yard {
        return {}
    }

    local := w.players[me - 1]
    home := Camera_Target{me, local.generation}

    if local.hp > 0 {
        return home
    }

    if previous.seat > 0 && previous.seat <= game.SEATS && previous.seat != me {
        p := w.players[previous.seat - 1]

        if p.generation == previous.generation && p.connected && p.in_yard && p.hp > 0 {
            return previous
        }
    }

    for p, i in w.players {
        if u16(i + 1) != me && p.connected && p.in_yard && p.hp > 0 {
            return {u16(i + 1), p.generation}
        }
    }

    return home
}
