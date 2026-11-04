package union_game

import r "godot:replay"
import net "godot:replay/net"

Coins :: struct {
    amount: u32,
}

Pocket :: union {
    Coins,
}

Union_Player :: struct {
    active: bool,
    x:      i32,
    pocket: Pocket,
}

Union_World :: struct {
    players: [2]Union_Player,
    chest:   u32,
}

Move :: struct {
    dx: i8,
}

Union_Control :: union {
    Move,
}

Take :: struct {
    amount: u32,
}

Put :: struct {
    amount: u32,
}

Union_Action :: union {
    Take,
    Put,
}

Taken :: struct {
    seat:   u16,
    amount: u32,
}

Returned :: struct {
    seat:   u16,
    amount: u32,
}

Union_Event :: union {
    Taken,
    Returned,
}

union_model :: proc() -> net.Model(Union_World, Union_Control, Union_Action, Union_Event, 2) {
    return {step = proc(w: ^Union_World, controls: [2]Union_Control, joins, leaves: u64, ctx: ^r.Step(Union_Event)) {
            for &player, i in w.players {
                if joins & (u64(1) << uint(i)) != 0 {
                    player.active = true
                }

                if leaves & (u64(1) << uint(i)) != 0 {
                    player.active = false
                }

                if move, ok := controls[i].(Move); ok && player.active {
                    player.x += i32(move.dx)
                }
            }
        }, control_valid = proc(c: Union_Control) -> bool {
            move, ok := c.(Move)
            return !ok || move.dx >= -1 && move.dx <= 1
        }, hold = proc(c: Union_Control) -> Union_Control {
            return c
        }, action_valid = proc(a: Union_Action) -> bool {
            switch value in a {
            case Take:
                return value.amount > 0 && value.amount <= 5
            case Put:
                return value.amount > 0 && value.amount <= 5
            case:
                return false
            }
        }, state_valid = proc(w: Union_World) -> bool {
            total := w.chest

            for player in w.players {
                if coins, ok := player.pocket.(Coins); ok {
                    if coins.amount > 5 {
                        return false
                    }

                    total += coins.amount
                }
            }

            return total == 5
        }, action = proc(w: ^Union_World, seat: u16, a: Union_Action, ctx: ^r.Step(Union_Event)) -> bool {
            player := &w.players[seat - 1]
            coins, _ := player.pocket.(Coins)

            switch value in a {
            case Take:
                if w.chest < value.amount {
                    return false
                }

                w.chest -= value.amount
                coins.amount += value.amount
                player.pocket = coins
                r.emit(ctx, u64(seat), 1, Union_Event(Taken{seat, value.amount}))
            case Put:
                if coins.amount < value.amount {
                    return false
                }

                w.chest += value.amount
                coins.amount -= value.amount
                player.pocket = coins.amount == 0 ? Pocket(nil) : Pocket(coins)
                r.emit(ctx, u64(seat), 1, Union_Event(Returned{seat, value.amount}))
            case:
                return false
            }

            return true
        }}
}
