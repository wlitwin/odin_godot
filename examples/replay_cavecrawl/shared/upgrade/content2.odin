package cave_upgrade
import r "godot:replay"
import p "godot:replay/play"
import net "godot:replay/net"
import lb "godot:replay/lobby"
import game "../cave"
Floor :: game.Floor
CONTENT_2 :: u64(0x4341564552504c32)

World_2 :: struct {
    players:   [SEATS]Player,
    chest:     [8]p.Stack,
    door_open: bool,
    relic:     Relic,
    dwellers:  r.Pool(Dweller, 16),
    rocks:     r.Pool(Rock, 64),
    pickups:   r.Pool(Pickup, 48),
    director:  Director,
    depth:     u8,
    won:       bool,
    dens_used: u32,
    seed:      u32,
    clock:     u64,
    floors:    [2]Floor,
}

Legacy_Verb :: enum u8 {
    None,
    Take,
    Door,
    Drop,
    Grab,
    Throw,
    Heal,
    Revive,
    Carry,
    Set_Down,
}

Legacy_Action :: struct {
    verb:       Legacy_Verb,
    index:      u16,
    generation: u32,
    aim:        [2]f32,
}

legacy_action_valid :: proc(a: Legacy_Action) -> bool {
    return(
        a.verb >= .Take &&
        a.verb <= .Set_Down &&
        a.index < 64 &&
        a.aim[0] == a.aim[0] &&
        a.aim[1] == a.aim[1] &&
        abs(a.aim[0]) <= 1 &&
        abs(a.aim[1]) <= 1 \
    )
}

convert_action :: proc(old: Legacy_Action) -> (game.Action, bool) {
    // Refused old requests can have game-invalid values. Preserve their fields;
    // the checkpoint keeps the refusal reason and validates accepted work.
    return {verb = game.Verb(old.verb), index = old.index, generation = old.generation, aim = old.aim}, true
}

convert_world2 :: proc(old: World_2) -> (game.World, bool) {
    if old.director.wave == 0 {
        return {}, false
    }

    world := game.World {
        players   = old.players,
        chest     = old.chest,
        door_open = old.door_open,
        relic     = old.relic,
        dwellers  = old.dwellers,
        rocks     = old.rocks,
        pickups   = old.pickups,
        director  = old.director,
        depth     = old.depth,
        won       = old.won,
        dens_used = old.dens_used,
        seed      = old.seed,
        clock     = old.clock,
        floors    = old.floors,
        lobby     = lb.initial(SEATS, playing = true),
    }

    for player, i in old.players {
        if player.connected {
            world.lobby.present |= u64(1) << uint(i)
        }
    }

    world.lobby.ready = world.lobby.present
    lb.roster(&world.lobby, 0, 0)
    return world, game.state_valid(world)
}

model2 :: proc() -> net.Model(World_2, game.Control, Legacy_Action, game.Event, SEATS) {
    return {
        control_valid = game.control_valid,
        action_valid = legacy_action_valid,
        state_valid = proc(old: World_2) -> bool {
            _, ok := convert_world2(old)
            return ok
        },
        action = proc(_: ^World_2, _: u16, _: Legacy_Action, _: ^r.Step(game.Event)) -> bool {
            panic("archive-only model")
        },
    }
}
