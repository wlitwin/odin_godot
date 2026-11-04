package cave

import r "godot:replay"
import p "godot:replay/play"
import net "godot:replay/net"
import lb "godot:replay/lobby"

CONTENT :: u64(0x4341564552504c39)
OWNER_MOTION :: false
SEATS :: 4
MAX_WAVES :: 8
HZ :: 20
REACH :: f32(40)
WALK_SPEED :: f32(120)
MAX_HP :: i32(100)
MAX_STAMINA :: i32(10)
ROCK_DAMAGE :: i32(35)
ROCK_SPEED :: f32(12)
ROCK_TTL :: u16(24)
BODY_RADIUS :: f32(14)
GEM :: p.Item_Id(1)
TORCH :: p.Item_Id(2)

Player :: struct {
    connected, initialized:       bool,
    position:                     [2]f32,
    bag:                          [6]p.Stack,
    hp, stamina:                  i32,
    rock_cd, heal_cd, chill:      u16,
    respawn_at:                   u64,
    kills, deaths, damage, slain: u32,
}

Dweller :: struct {
    position, home: [2]f32,
    hp:             i32,
    bite_cd:        u16,
    mood:           u8,
}

Rock :: struct {
    position, velocity: [2]f32,
    left:               u16,
    shooter:            u16,
}

Pickup :: struct {
    position: [2]f32,
    stack:    p.Stack,
}

Relic :: struct {
    position: [2]f32,
    carrier:  u16,
    version:  u32,
}

Director :: struct {
    wave:                   u8,
    remaining:              u16,
    next_spawn, rest_until: u64,
    done:                   bool,
}

World :: struct {
    authority_known: bool,
    authority_seat:  u16,
    players:         [SEATS]Player,
    chest:           [8]p.Stack,
    door_open:       bool,
    relic:           Relic,
    dwellers:        r.Pool(Dweller, 16),
    rocks:           r.Pool(Rock, 64),
    pickups:         r.Pool(Pickup, 48),
    director:        Director,
    depth:           u8,
    won:             bool,
    dens_used:       u32,
    seed:            u32,
    clock:           u64,
    floors:          [2]Floor,
    lobby:           lb.Lobby(SEATS),
}

Control :: struct {
    move: [2]i8,
}

Verb :: enum u8 {
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
    Lobby,
}

Action :: struct {
    verb:       Verb,
    index:      u16,
    generation: u32,
    aim:        [2]f32,
    lobby:      lb.Command,
}

Event_Kind :: enum u8 {
    None,
    Loot,
    Door,
    Thrown,
    Hit,
    Died,
    Revived,
    Respawned,
    Slain,
    Floor,
    Victory,
    Carry,
}

Event :: struct {
    kind:     Event_Kind,
    position: [2]f32,
    seat:     u16,
    amount:   i32,
}

Floor :: struct {
    chest, door:   [2]f32,
    dens:          [2][2]f32,
    rift:          p.Aabb2,
    gems, torches: u16,
    waves, rests:  [MAX_WAVES]u16,
    wave_count:    u8,
}

FLOORS :: [2]Floor {
    {
        chest = {300, 180},
        door = {560, 180},
        dens = {{320, 40}, {320, 320}},
        rift = {min = {380, 60}, max = {430, 300}},
        gems = 3,
        torches = 2,
        waves = {0 = 2, 1 = 3},
        rests = {0 = 40, 1 = 40},
        wave_count = 2,
    },
    {
        chest = {200, 260},
        door = {90, 300},
        dens = {{500, 100}, {500, 300}},
        rift = {min = {280, 60}, max = {330, 300}},
        gems = 5,
        torches = 1,
        waves = {0 = 3, 1 = 4},
        rests = {0 = 100, 1 = 60},
        wave_count = 2,
    },
}

floor :: proc(depth: u8) -> Floor {
    floors := FLOORS
    return floors[clamp(int(depth) - 1, 0, 1)]
}

stack_limit :: proc(item: p.Item_Id) -> u16 {
    return item == GEM ? 99 : item == TORCH ? 5 : 0
}

world_floor :: proc(w: ^World) -> Floor {
    return w.floors[clamp(int(w.depth) - 1, 0, 1)]
}

initial :: proc(seed: u32 = 1337, floors: [2]Floor = FLOORS, staging: bool = false, dedicated: bool = false) -> World {
    w := World {
        depth  = 1,
        seed   = seed,
        floors = floors,
        lobby  = lb.initial(SEATS, automatic = dedicated, playing = !staging),
    }
    enter_floor(&w, .Initial)
    return w
}

model :: proc() -> net.Model(World, Control, Action, Event, SEATS) {
    return {
        authority = {id = 1, apply = observe_authority},
        step = step,
        action = act,
        control_valid = control_valid,
        action_valid = action_valid,
        state_valid = state_valid,
        hold = hold,
        reset_player = reset_player,
    }
}

control_valid :: proc(c: Control) -> bool {
    return c.move[0] >= -1 && c.move[0] <= 1 && c.move[1] >= -1 && c.move[1] <= 1
}

hold :: proc(c: Control) -> Control {
    return c
}

action_valid :: proc(a: Action) -> bool {
    if a.verb == .Lobby {
        return a.index == 0 && a.generation == 0 && a.aim == ([2]f32{}) && lb.command_valid(a.lobby)
    }

    if a.lobby != (lb.Command{}) {
        return false
    }

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

reset_player :: proc(w: ^World, seat: u16, ctx: ^r.Step(Event)) {
    lb.reset_member(&w.lobby, seat)
    player := &w.players[seat - 1]
    spill(w, player)

    for stack in player.bag {
        if stack.item != 0 {
            r.abort(ctx)
            return
        }
    }

    // A fresh occupant is a different identity, unlike a reserved-seat rejoin.
    if w.relic.carrier == seat {
        w.relic.carrier = 0
        w.relic.version += 1
    }

    player^ = {
        initialized = true,
        position    = {80 + f32(seat - 1) * 22, 120},
        hp          = MAX_HP,
        stamina     = MAX_STAMINA,
    }
}

state_valid :: proc(w: World) -> bool {
    if !lb.valid(w.lobby) || w.authority_seat > SEATS || (!w.authority_known && w.authority_seat != 0) {
        return false
    }

    if w.depth < 1 || w.depth > 2 || w.relic.carrier > SEATS {
        return false
    }

    for def in w.floors {
        if !floor_valid(def) {
            return false
        }
    }

    def := w.floors[w.depth - 1]

    if w.director.wave > def.wave_count {
        return false
    }

    if w.director.wave == 0 {
        if w.director != (Director{}) || w.dwellers.count != 0 {
            return false
        }
    } else if w.director.remaining > def.waves[w.director.wave - 1] {
        return false
    }

    for player in w.players {
        if player.hp < 0 || player.hp > MAX_HP || player.stamina < 0 || player.stamina > MAX_STAMINA {
            return false
        }

        for stack in player.bag {
            if !p.stack_valid(stack, stack_limit(stack.item)) {
                return false
            }
        }
    }

    for stack in w.chest {
        if stack.item != 0 && stack.item != GEM && stack.item != TORCH || !p.stack_valid(stack, 99) {
            return false
        }
    }

    count := u32(0)

    for dweller, i in w.dwellers.values {
        if !w.dwellers.alive[i] {
            continue
        }

        count += 1

        if dweller.hp <= 0 || dweller.hp > 70 || w.dwellers.generations[i] == 0 {
            return false
        }
    }

    if count != w.dwellers.count {
        return false
    }

    count = 0

    for rock, i in w.rocks.values {
        if !w.rocks.alive[i] {
            continue
        }

        count += 1

        if rock.shooter < 1 || rock.shooter > SEATS || rock.left == 0 || rock.left > ROCK_TTL {
            return false
        }
    }

    if count != w.rocks.count {
        return false
    }

    count = 0

    for pickup, i in w.pickups.values {
        if !w.pickups.alive[i] {
            continue
        }

        count += 1

        if !p.stack_valid(pickup.stack, stack_limit(pickup.stack.item)) {
            return false
        }
    }

    return count == w.pickups.count
}

// Definition values are captured with the world. Authored resources are decoded
// once before play; simulation never reads mutable Godot resources.
floor_valid :: proc(def: Floor) -> bool {
    if def.wave_count < 1 || def.wave_count > MAX_WAVES || def.gems > 99 || def.torches > 99 {
        return false
    }

    points := [4][2]f32{def.chest, def.door, def.dens[0], def.dens[1]}

    for point in points {
        if !definition_point_valid(point) {
            return false
        }
    }

    if !definition_point_valid(def.rift.min) ||
       !definition_point_valid(def.rift.max) ||
       def.rift.min[0] >= def.rift.max[0] ||
       def.rift.min[1] >= def.rift.max[1] {
        return false
    }

    for count, i in def.waves {
        if i >= int(def.wave_count) {
            if count != 0 || def.rests[i] != 0 {
                return false
            }
        } else if count > 255 {
            return false
        }
    }

    return true
}

definition_point_valid :: proc(point: [2]f32) -> bool {
    return(
        point[0] == point[0] &&
        point[1] == point[1] &&
        point[0] >= 0 &&
        point[0] <= 640 &&
        point[1] >= 0 &&
        point[1] <= 370 \
    )
}
