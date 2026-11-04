package claimball_pitch

import r "godot:replay"
import p "godot:replay/play"
import net "godot:replay/net"
import h "godot:replay/history"
import lb "godot:replay/lobby"

CONTENT :: u64(0x52434c41494d4233)
SEATS :: 4
HZ :: 60
RUN_SPEED :: f32(2.2)
RUN_ACCEL :: f32(0.35)
KICK_REACH :: f32(30)
KICK_POWER :: f32(6.5)
KICK_CD :: u16(20)
SPIKE_REACH :: f32(44)
SPIKE_POWER :: f32(5.5)
KICKOFF_HOLD :: u16(72)
CENTER :: [2]f32{320, 180}
PLAYER_BOUNDS :: p.Aabb2{{21, 21}, {619, 339}}
BALL_LAW :: p.Roll_Law2{0.985, 9, 0.55, {{20, 20}, {620, 340}}}
SPAWNS :: [4][2]f32{{200, 100}, {440, 260}, {200, 260}, {440, 100}}
KICK :: u8(1)

Player :: struct {
    initialized, connected, named: bool,
    motion:                        p.Motion2,
    kick_cd:                       u16,
    team:                          u8,
}

Ball :: struct {
    motion: p.Motion2,
    hold:   u16,
    reset:  u32,
}

Score :: struct {
    left, right, winner: u8,
}

World :: struct {
    group_seat:                         u16,
    outside:                            h.Boundary([SEATS]Player), // read-only sampled outsiders; no predicted contacts in this profile
    players:                            [SEATS]Player,
    names:                              [SEATS]lb.Name,
    manual_start:                       bool,
    ball:                               Ball,
    score:                              Score,
    clock:                              u64,
    round:                              u32,
    kicks, spikes, contacts:            u32,
    started:                            bool,
    min_players, goals_to, seat_offset: u8,
}

Controls :: struct {
    move:    [2]i8,
    buttons: u8,
}

Action :: struct {
    spike, start:  bool,
    name:          lb.Name,
    restart_round: u32,
}

Event_Kind :: enum u8 {
    Kick,
    Spike,
    Goal,
}

Event :: struct {
    round:              u32,
    kind:               Event_Kind,
    seat, team:         u8,
    position, velocity: [2]f32,
    score:              Score,
}

initial :: proc(dedicated := false, min_players: u8 = 1, goals_to: u8 = 3, manual_start: bool = false) -> World {
    w := World {
        round = 1,
        manual_start = manual_start,
        ball = {motion = {position = CENTER}, hold = KICKOFF_HOLD},
        min_players = min_players,
        goals_to = goals_to,
        seat_offset = dedicated ? 1 : 0,
    }

    for &name, i in w.names {
        name = lb.seat_name(u16(i + 1))
    }

    return w
}

model :: proc() -> net.Model(World, Controls, Action, Event, SEATS) {
    return {
        group = {id = 1, project = project, valid = group_valid},
        step = step,
        action = action,
        reset_player = reset_player,
        control_valid = control_valid,
        state_valid = state_valid,
        action_valid = action_valid,
        hold = proc(c: Controls) -> Controls {
            return c
        },
        event_owner = proc(e: Event) -> u16 {
            return u16(e.seat)
        },
    }
}

control_valid :: proc(c: Controls) -> bool {
    return c.move[0] >= -1 && c.move[0] <= 1 && c.move[1] >= -1 && c.move[1] <= 1 && c.buttons & ~KICK == 0
}

state_valid :: proc(w: World) -> bool {
    return w.group_seat == 0 && !w.outside.valid && rules_valid(w)
}

rules_valid :: proc(w: World) -> bool {
    if w.round == 0 {
        return false
    }

    for name in w.names {
        if !lb.name_valid(name, false) {
            return false
        }
    }

    if w.manual_start && w.seat_offset != 0 {
        return false
    }

    if w.min_players < 1 ||
       w.min_players > SEATS ||
       w.goals_to < 1 ||
       w.seat_offset > 1 ||
       w.ball.hold > KICKOFF_HOLD ||
       w.score.winner > 2 {
        return false
    }

    if w.score.left > w.goals_to || w.score.right > w.goals_to {
        return false
    }

    if (w.score.winner == 1) != (w.score.left == w.goals_to) ||
       (w.score.winner == 2) != (w.score.right == w.goals_to) {
        return false
    }

    if w.ball.reset != u32(w.score.left) + u32(w.score.right) {
        return false
    }

    for player, i in w.players {
        team := (i + 1 + int(w.seat_offset)) % 2 == 1 ? u8(1) : u8(2)

        if player.kick_cd > KICK_CD ||
           (player.connected && !player.initialized) ||
           (player.initialized && player.team != team) {
            return false
        }
    }

    return true
}

project :: proc(frame: r.Frame(World), seat: u16) -> World {
    w := frame.state
    w.group_seat = seat
    w.outside = {
        tick  = frame.tick,
        value = w.players,
        valid = true,
    }

    for &player, i in w.players {
        if i + 1 != int(seat) {
            player = {}
        } else {
            w.outside.value[i] = {}
        }
    }

    return w
}

group_valid :: proc(w: World, seat: u16) -> bool {
    if w.group_seat != seat || !w.outside.valid || w.outside.tick > w.clock || !rules_valid(w) {
        return false
    }

    for player, i in w.players {
        if i + 1 != int(seat) && player != (Player{}) {
            return false
        }

        if i + 1 == int(seat) && w.outside.value[i] != (Player{}) {
            return false
        }
    }

    return true
}

reset_player :: proc(w: ^World, seat: u16, ctx: ^r.Step(Event)) {
    w.names[seat - 1] = lb.seat_name(seat)
    pid := int(seat) + int(w.seat_offset)
    spots := SPAWNS
    w.players[seat - 1] = {
        initialized = true,
        connected = true,
        motion = {position = spots[pid % len(spots)]},
        team = pid % 2 == 1 ? 1 : 2,
    }
}

// Roster decisions may read boundary metadata without adding outsiders to the
// predicted simulation. Gameplay contacts still iterate only w.players.
member :: proc(w: ^World, index: int) -> Player {
    if w.group_seat != 0 && index + 1 != int(w.group_seat) {
        return w.outside.value[index]
    }

    return w.players[index]
}

leader :: proc(w: ^World) -> u16 {
    for i in 0 ..< SEATS {
        if member(w, i).connected {
            return u16(i + 1)
        }
    }

    return 0
}

action_valid :: proc(a: Action) -> bool {
    return(
        int(a.spike) + int(a.start) + int(a.name.length > 0) + int(a.restart_round > 0) == 1 &&
        lb.name_valid(a.name) \
    )
}

action :: proc(w: ^World, seat: u16, a: Action, ctx: ^r.Step(Event)) -> bool {
    if seat == 0 || seat > SEATS || !action_valid(a) || !w.players[seat - 1].connected {
        return false
    }

    if a.restart_round > 0 {
        return restart(w, seat, a.restart_round, ctx)
    }

    if a.spike {
        return spike(w, seat, a, ctx)
    }

    if a.name.length > 0 {
        w.names[seat - 1] = a.name
        w.players[seat - 1].named = true
        return true
    }

    if !w.manual_start || w.started || seat != leader(w) {
        return false
    }

    count := 0

    for i in 0 ..< SEATS {
        if member(w, i).connected {
            count += 1
        }
    }

    if count < int(w.min_players) {
        return false
    }

    w.started = true
    return true
}

// Restart within the same session. The command names its completed round, so
// delayed requests cannot reset a later match. Outside players remain immutable
// boundary samples during local prediction; only the authority resets everybody.
restart :: proc(w: ^World, seat: u16, round: u32, ctx: ^r.Step(Event)) -> bool {
    if w.score.winner == 0 || seat != leader(w) || round != w.round || round == max(u32) {
        return false
    }

    count := 0

    for i in 0 ..< SEATS {
        if member(w, i).connected {
            count += 1
        }
    }

    if count < int(w.min_players) {
        return false
    }

    before := w^
    next := initial(w.seat_offset == 1, w.min_players, w.goals_to, w.manual_start)
    next.clock, next.round, next.started = w.clock, w.round + 1, true
    next.group_seat, next.outside = w.group_seat, w.outside

    for player, i in before.players {
        if player.initialized {
            reset_player(&next, u16(i + 1), ctx)
            next.players[i].connected, next.players[i].named = player.connected, player.named
        }
    }

    next.names = before.names
    w^ = next
    return true
}
