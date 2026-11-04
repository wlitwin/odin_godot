package scrapyard_flow

import game "../game"
import content "../content"
import profile "../profile"

// Start is a host UI shortcut for its own Ready followed by Start. Other peers
// must already be ready; the simulation still validates every action normally.
muster_can_start :: proc(w: ^game.World, seat: u16) -> bool {
    if w.stage != .Staging || seat == 0 || seat > game.SEATS || w.host != seat || !w.players[seat - 1].connected {
        return false
    }

    for player, i in w.players {
        if i != int(seat - 1) && player.connected && !player.profile.ready {
            return false
        }
    }

    return true
}

muster_pick :: proc(
    catalog: ^content.Catalog,
    value: game.Profile,
    field, direction: int,
    automatic: u8 = 0,
) -> (
    game.Profile,
    u8,
) {
    return profile.cycle(catalog, value, automatic, field, direction)
}
