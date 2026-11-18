package starter_game

import r "godot:replay"
import net "godot:replay/net"
import schema "godot:replay/schema"

SEATS :: 2
CONTENT :: u64(0x52504c5354415254)

Pickup_Rules :: struct {reach: i32}
DEFAULT_PICKUP :: Pickup_Rules{reach = 24}

pickup_valid :: proc(rules: Pickup_Rules) -> bool {return rules.reach >= 1 && rules.reach <= 96}

content :: proc(rules: Pickup_Rules) -> u64 {
    value := u32(rules.reach)
    bytes := [4]u8{u8(value), u8(value >> 8), u8(value >> 16), u8(value >> 24)}
    return schema.digest(bytes[:], CONTENT)
}

World :: struct {
    positions: [SEATS]i32,
    connected: u8,
    coins:     u8,
    bags:      [SEATS]u8,
    pickup:    Pickup_Rules,
}

Control :: struct {
    move: i8,
}

Action :: struct {
    take: bool,
}

Event :: struct {
    seat: u16,
}

initial :: proc(pickup := DEFAULT_PICKUP) -> World {
    return {positions = {220, 420}, coins = 1, pickup = pickup}
}

model :: proc() -> net.Model(World, Control, Action, Event, SEATS) {
    return {
        step = step,
        action = action,
        state_valid = state_valid,
        control_valid = control_valid,
        action_valid = action_valid,
        hold = hold,
    }
}

step :: proc(w: ^World, inputs: [SEATS]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
    w.connected = (w.connected | u8(joins)) & ~u8(leaves)

    for input, i in inputs {
        if w.connected & (u8(1) << uint(i)) != 0 {
            w.positions[i] = clamp(w.positions[i] + i32(input.move) * 3, 40, 600)
        }
    }
}

action :: proc(w: ^World, seat: u16, value: Action, ctx: ^r.Step(Event)) -> bool {
    if !value.take ||
       seat == 0 ||
       seat > SEATS ||
       w.connected & (u8(1) << uint(seat - 1)) == 0 ||
       w.coins == 0 ||
       abs(w.positions[seat - 1] - 320) > w.pickup.reach {
        return false
    }

    w.coins -= 1
    w.bags[seat - 1] += 1
    r.emit(ctx, u64(seat), 1, Event{seat})
    return true
}

control_valid :: proc(c: Control) -> bool {
    return c.move >= -1 && c.move <= 1
}

action_valid :: proc(a: Action) -> bool {
    return a.take
}

hold :: proc(c: Control) -> Control {
    return c
}

state_valid :: proc(w: World) -> bool {
    if w.connected & ~u8(3) != 0 || w.coins > 1 || !pickup_valid(w.pickup) {
        return false
    }

    total := u32(w.coins)

    for p, i in w.positions {
        if p < 40 || p > 600 || w.bags[i] > 1 {
            return false
        }

        total += u32(w.bags[i])
    }

    return total == 1
}
