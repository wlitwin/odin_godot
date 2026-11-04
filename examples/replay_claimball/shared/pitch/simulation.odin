package claimball_pitch

import r "godot:replay"
import p "godot:replay/play"

step :: proc(w: ^World, controls: [SEATS]Controls, joins, leaves: u64, ctx: ^r.Step(Event)) {
    w.clock = ctx.tick
    connected := 0

    for &player, i in w.players {
        bit := u64(1) << uint(i)

        if leaves & bit != 0 {
            player.connected = false
        }

        if joins & bit != 0 {
            if !player.initialized {
                reset_player(w, u16(i + 1), ctx)
            }

            player.connected = true
        }

        if player.connected {
            connected += 1
        }
    }

    if !w.started {
        if w.manual_start {
            return
        }

        if connected < int(w.min_players) {
            return
        }

        w.started = true
    }

    // Authored order: goal/freeze from the previous settled ball pose, ball
    // flight, player movement/cooldowns, then contact and kicks in seat order.
    ball_tick(w, ctx)
    p.roll_step(&w.ball.motion, BALL_LAW)

    for &player, i in w.players {
        if player.connected {
            c := controls[i]
            p.momentum_step(
                &player.motion,
                p.unit2({f32(c.move[0]), f32(c.move[1])}) * RUN_SPEED,
                RUN_ACCEL,
                PLAYER_BOUNDS,
            )

            if player.kick_cd > 0 {
                player.kick_cd -= 1
            }
        }
    }

    if w.score.winner != 0 || w.ball.hold > 0 {
        return
    }

    for &player, i in w.players {
        if player.connected {
            d := w.ball.motion.position - player.motion.position
            distance_sq := p.length_sq2(d)

            if p.soft_contact(&w.ball.motion, player.motion, 17, 1.1, 3.2) {
                w.contacts += 1
            }

            c := controls[i]

            if c.buttons & KICK != 0 && distance_sq < KICK_REACH * KICK_REACH && player.kick_cd == 0 {
                aim := p.unit2({f32(c.move[0]), f32(c.move[1])})

                if aim == ([2]f32{}) {
                    aim = p.unit2(d)
                }

                w.ball.motion.velocity += aim * KICK_POWER
                player.kick_cd = KICK_CD
                w.kicks += 1
                r.emit(
                    ctx,
                    event_source(w.round, u32(i + 1)),
                    1,
                    Event {
                        round = w.round,
                        kind = .Kick,
                        seat = u8(i + 1),
                        position = w.ball.motion.position,
                        velocity = w.ball.motion.velocity,
                    },
                )
            }
        }
    }
}

ball_tick :: proc(w: ^World, ctx: ^r.Step(Event)) {
    b := &w.ball

    if w.score.winner != 0 || b.hold > 0 {
        b.motion.velocity = {}

        if b.hold > 0 {
            b.hold -= 1
        }

        return
    }

    position := b.motion.position
    team := u8(0)

    if position[1] > 130 && position[1] < 230 {
        if position[0] <= 20 {
            team = 2
        }

        if position[0] >= 620 {
            team = 1
        }
    }

    if team == 0 {
        return
    }

    if b.reset == max(u32) {
        r.abort(ctx)
        return
    }

    if team == 1 {
        w.score.left += 1
    } else {
        w.score.right += 1
    }

    if w.score.left >= w.goals_to || w.score.right >= w.goals_to {
        w.score.winner = team
    }

    b.motion, b.hold = {
            position = CENTER,
        }, KICKOFF_HOLD
    b.reset += 1
    r.emit(
        ctx,
        event_source(w.round, 100),
        1,
        Event{round = w.round, kind = .Goal, team = team, position = position, score = w.score},
    )
}

// Intent-only command: the authority/prediction reads this seat's world position.
// Callers cannot substitute an arbitrary origin for the reach predicate.
spike :: proc(w: ^World, seat: u16, action: Action, ctx: ^r.Step(Event)) -> bool {
    if !action.spike || !w.started || w.score.winner != 0 || w.ball.hold > 0 {
        return false
    }

    player := w.players[seat - 1]

    if !player.connected {
        return false
    }

    d := w.ball.motion.position - player.motion.position

    if p.length_sq2(d) > SPIKE_REACH * SPIKE_REACH {
        return false
    }

    direction := p.unit2(d)

    if direction == ([2]f32{}) {
        direction = {1, 0}
    }

    w.ball.motion.velocity += direction * SPIKE_POWER
    w.spikes += 1
    r.emit(
        ctx,
        event_source(w.round, u32(seat)),
        2,
        Event {
            round = w.round,
            kind = .Spike,
            seat = u8(seat),
            position = w.ball.motion.position,
            velocity = w.ball.motion.velocity,
        },
    )
    return true
}

// A player/ball starts a new presentation lifetime in each match. A correction
// at the same tick must cancel the old-round occurrence and begin the new one.
event_source :: proc(round, actor: u32) -> u64 {
    return u64(round) << 32 | u64(actor)
}
