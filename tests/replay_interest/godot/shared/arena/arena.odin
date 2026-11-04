package interest_arena

import r "godot:replay"
import net "godot:replay/net"

SEATS :: 2
OBJECTS :: 32
CONTENT :: u64(0x494e545245535431)
POLICY :: u64(0x5a4f4e455631)
SECRET :: u64(0xf0e1d2c3b4a59687)

Player :: struct {
    present: bool,
    x:       i32,
    score:   u32,
}

Object :: struct {
    x:     i32,
    pulse: u32,
    nonce: u64,
}

World :: struct {
    players:  [SEATS]Player,
    objects:  [OBJECTS]Object,
    visible:  u64,
    complete: bool,
    secret:   u64 `replay:"authority"`,
}

Control :: struct {
    move:         i8,
    private_hint: u32 `replay:"authority"`,
}

Action :: struct {
    claim: bool,
}

Event :: struct {
    object: u16,
    x:      i32,
    value:  u64,
}

initial :: proc() -> World {
    w := World {
        complete = true,
        visible  = (u64(1) << OBJECTS) - 1,
        secret   = SECRET,
    }

    for &object, i in w.objects {
        object.x = i32(i * 40)
        object.nonce = SECRET + u64(i + 1)
    }

    return w
}

state_valid :: proc(w: World) -> bool {
    return w.complete && w.visible == (u64(1) << OBJECTS) - 1 && w.secret == SECRET
}

step :: proc(w: ^World, controls: [SEATS]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
    for &player, i in w.players {
        bit := u64(1) << uint(i)

        if joins & bit != 0 {
            player.present = true

            if i == 1 && player.x == 0 {
                player.x = 1200
            }
        }

        if leaves & bit != 0 {
            player.present = false
        }

        if player.present {
            player.x = clamp(player.x + i32(controls[i].move) * 10, 0, 1240)
        }
    }

    if !w.complete {
        return
    } // the player's group contains no remote object simulation

    for &object, i in w.objects {
        object.pulse += 1
        object.nonce = SECRET + u64(i + 1) + ctx.tick * 7919
    }

    // One public candidate per tick. Delivery policy uses this tick's exact frame.
    index := int(ctx.tick % OBJECTS)
    r.emit(ctx, u64(index + 100), 1, Event{u16(index), w.objects[index].x, w.objects[index].nonce})
}

act :: proc(w: ^World, seat: u16, a: Action, ctx: ^r.Step(Event)) -> bool {
    if !a.claim || !w.players[seat - 1].present {
        return false
    }

    w.players[seat - 1].score += 1
    return true
}

center :: proc(w: World, who: net.Recipient) -> i32 {
    return who.spectator ? 600 : w.players[who.seat - 1].x
}

visible :: proc(w: World, who: net.Recipient, index: int) -> bool {
    return abs(w.objects[index].x - center(w, who)) <= 80
}

replica_valid :: proc(v: net.Replica(World, Control, SEATS), who: net.Recipient) -> bool {
    if v.state.complete || v.state.secret != 0 || v.state.visible >> OBJECTS != 0 {
        return false
    }

    for object, i in v.state.objects {
        expected := abs(i32(i * 40) - center(v.state, who)) <= 80

        if (v.state.visible & (u64(1) << uint(i)) != 0) != expected {
            return false
        }

        if !expected && object != (Object{}) {
            return false
        }

        if expected && object.x != i32(i * 40) {
            return false
        }
    }

    for control, i in v.held {
        if control.private_hint != 0 {
            return false
        }

        if i + 1 != int(who.seat) && control != (Control{}) {
            return false
        }
    }

    return true
}

model :: proc(filtered: bool = true) -> net.Model(World, Control, Action, Event, SEATS) {
    m := net.Model(World, Control, Action, Event, SEATS) {
        step = step,
        action = act,
        control_valid = proc(c: Control) -> bool {
            return c.move >= -1 && c.move <= 1
        },
        action_valid = proc(a: Action) -> bool {
            return a.claim
        },
        state_valid = state_valid,
        hold = proc(c: Control) -> Control {
            return c
        },
    }

    if filtered {
        m.replication = {
            id = POLICY,
            project = proc(
                frame: r.Frame(World),
                held: [SEATS]Control,
                who: net.Recipient,
            ) -> (
                net.Replica(World, Control, SEATS),
                bool,
            ) {
                w := frame.state
                w.complete = false
                w.visible = 0

                for &object, i in w.objects {
                    if visible(frame.state, who, i) {
                        w.visible |= u64(1) << uint(i)
                    } else {
                        object = {}
                    }
                }

                controls := held

                for &control, i in controls {
                    if i + 1 != int(who.seat) {
                        control = {}
                    }
                }

                return {w, controls}, true
            },
            valid = replica_valid,
            event = proc(frame: r.Frame(World), who: net.Recipient, e: r.Occurrence(Event)) -> (Event, bool) {
                if !visible(frame.state, who, int(e.value.object)) {
                    return {}, false
                }

                value := e.value
                value.value = 0 // reveal location/pulse occurrence, not authority nonce
                return value, true
            },
        }
    }

    return m
}

player_model :: proc() -> net.Model(World, Control, Action, Event, SEATS) {
    m := model()
    m.group = {
        id = 1,
        project = proc(frame: r.Frame(World), seat: u16) -> World {
            w := frame.state
            w.visible = 0
            w.objects = {}

            for &player, i in w.players {
                if i + 1 != int(seat) {
                    player = {}
                }
            }

            return w
        },
        valid = proc(w: World, seat: u16) -> bool {
            if w.complete || w.secret != 0 || w.visible != 0 {
                return false
            }

            for object in w.objects {
                if object != (Object{}) {
                    return false
                }
            }

            for player, i in w.players {
                if i + 1 != int(seat) && player != (Player{}) {
                    return false
                }
            }

            return true
        },
    }
    return m
}
