package dockyard_duo

import b "godot:box3d"
import r "godot:replay"
import ph "godot:replay/physics"

ROUND_TICKS :: u32(150 * 60)
DEPARTURE_TICKS :: u16(180)

Round_Phase :: enum u8 {
    Working,
    Departing,
    Results,
}

Action_Kind :: enum u8 {
    Boost,
    Retry,
    Next_Job,
}

JOB_NAMES :: [3]string{"First Shift", "Cross Dock", "Long Haul"}
CARGO_VALUES :: [3]u32{250, 350, 600}
CARGO_PADS :: [3]b.Vec3{{4.4, 0, 1.9}, {7.2, 0, 1.9}, {6, 0, .3}}
CARGO_LAYOUTS :: [3][3]b.Vec3 {
    {{-4, .46, 0}, {-6, .46, 3}, {-5, .41, -3.5}},
    {{-5, .46, -2.5}, {-3, .46, 2.8}, {-6.5, .41, 0}},
    {{-3.8, .46, 2.3}, {-6.5, .46, -1.5}, {-4.8, .41, -3.5}},
}

prepare_initial_round :: proc(world: b.World, game: ^Game, layout: u8) -> bool {
    if layout >= 3 {
        return false
    }

    game.layout = layout
    game.round = 1
    layouts := CARGO_LAYOUTS

    for i in 0 ..< 3 {
        definition := game.cargo_defs[i]
        definition.pose.position = layouts[layout][i]
        body, status := b.body_resolve(world, game.bodies[i + 3])

        if status != .Ok {
            return false
        }

        if b.body_set_pose(body, definition.pose) != .Ok || b.body_set_velocity(body, {}, {}) != .Ok {
            return false
        }

        game.previous[i] = definition.pose.position
    }

    return true
}

reset_round :: proc(game: ^Game, layout: u8, ctx: ^r.Step(Event)) -> bool {
    if layout >= 3 || game.round == max(u32) {
        return false
    }

    layouts := CARGO_LAYOUTS

    for seat in 0 ..< 2 {
        if ph.body_pose_set(ctx.execution, game.bodies[seat + 1], game.home[seat + 1]) != .None ||
           ph.body_velocity(ctx.execution, game.bodies[seat + 1], {}, {}) != .None {
            r.abort(ctx)
            return false
        }

        if game.lives[seat + 1] == max(u32) {
            r.abort(ctx)
            return false
        }

        game.lives[seat + 1] += 1
    }

    for i in 0 ..< 3 {
        definition := game.cargo_defs[i]
        definition.pose.position = layouts[layout][i]

        if game.lost[i] {
            body, shape, error := ph.spawn_with_shape(ctx.execution, game.assets[i + 3], definition)

            if error != .None {
                r.abort(ctx)
                return false
            }

            game.bodies[i + 3] = body
            game.shapes[i + 3] = shape
        } else {
            if ph.body_type(ctx.execution, game.bodies[i + 3], .Dynamic) != .None ||
               ph.body_pose_set(ctx.execution, game.bodies[i + 3], definition.pose) != .None ||
               ph.body_velocity(ctx.execution, game.bodies[i + 3], {}, {}) != .None {
                r.abort(ctx)
                return false
            }
        }

        if game.lives[i + 3] == max(u32) {
            r.abort(ctx)
            return false
        }

        game.lives[i + 3] += 1
        game.previous[i] = definition.pose.position
    }

    for index in ([9]int{8, 11, 12, 13, 14, 15, 16, 17, 18}) {
        if ph.body_pose_set(ctx.execution, game.bodies[index], game.home[index]) != .None ||
           ph.body_velocity(ctx.execution, game.bodies[index], {}, {}) != .None {
            r.abort(ctx)
            return false
        }
    }

    game.layout = layout
    game.round += 1
    game.phase = .Working
    game.round_ticks = 0
    game.departure_ticks = 0
    game.score = 0
    game.payout = 0
    game.inside = {}
    game.delivered = {}
    game.lost = {}
    game.dwell = {}
    game.magnet = {}
    game.cooldown = {}
    game.recovered = {}
    r.emit(ctx, 5, u64(game.round), Event{0, 5, game.round})
    return true
}

round_before :: proc(game: ^Game, ctx: ^r.Step(Event)) {
    if game.tick % 180 == 0 {
        if ph.hinge_motor(ctx.execution, game.joint, true, (game.tick / 180) % 2 == 0 ? f32(.5) : f32(-.5), 3) !=
           .None {
            r.abort(ctx)
            return
        }
    }

    for seat in 0 ..< 2 {
        pose, error := ph.body_pose(ctx.execution, game.bodies[seat + 1])

        if error != .None {
            r.abort(ctx)
            return
        }

        if pose.position.y < -3 {
            if game.lives[seat + 1] == max(u32) || game.recovered[seat] == max(u16) {
                r.abort(ctx)
                return
            }

            if ph.body_pose_set(ctx.execution, game.bodies[seat + 1], game.home[seat + 1]) != .None ||
               ph.body_velocity(ctx.execution, game.bodies[seat + 1], {}, {}) != .None {
                r.abort(ctx)
                return
            }

            game.lives[seat + 1] += 1
            game.recovered[seat] += 1
            game.cooldown[seat] = 30
            r.emit(ctx, 3, u64(seat + 1), Event{u16(seat + 1), 3, u32(game.recovered[seat])})
        }
    }
}

round_after :: proc(game: ^Game, ctx: ^r.Step(Event)) {
    if game.phase == .Working {
        game.round_ticks += 1

        for key, i in game.bodies[3:6] {
            if game.lost[i] {
                continue
            }

            pose, error := ph.body_pose(ctx.execution, key)

            if error != .None {
                r.abort(ctx)
                return
            }

            if pose.position.y < -4 {
                if ph.body_destroy(ctx.execution, key) != .None {
                    r.abort(ctx)
                    return
                }

                if game.delivered[i] {
                    game.delivered[i] = false
                    game.score -= 1
                }

                game.bodies[i + 3] = 0
                game.shapes[i + 3] = 0
                game.lost[i] = true
                game.inside[i] = false
                game.dwell[i] = 0
                r.emit(ctx, 6, u64(i + 1), Event{0, 6, u32(i + 1)})
            }
        }

        remaining := false

        for i in 0 ..< 3 {
            remaining = remaining || (!game.delivered[i] && !game.lost[i])
        }

        if game.round_ticks >= ROUND_TICKS || !remaining {
            game.phase = .Departing
            game.departure_ticks = 0

            for index in ([9]int{8, 11, 12, 13, 14, 15, 16, 17, 18}) {
                if ph.body_velocity(ctx.execution, game.bodies[index], {0, 0, .9}, {}) != .None {
                    r.abort(ctx)
                    return
                }
            }

            for delivered, i in game.delivered {
                if delivered {
                    if ph.body_velocity(ctx.execution, game.bodies[i + 3], {0, 0, .9}, {}) != .None {
                        r.abort(ctx)
                        return
                    }
                }
            }

            values := CARGO_VALUES
            game.payout = 0

            for delivered, i in game.delivered {
                if delivered {
                    game.payout += values[i]
                }
            }

            if game.score == 3 {
                game.payout += u32((ROUND_TICKS - game.round_ticks) / 60) * 2
            }

            r.emit(ctx, 4, u64(game.round), Event{0, 4, game.payout})
        }
    } else if game.phase == .Departing {
        game.departure_ticks += 1

        if game.departure_ticks >= DEPARTURE_TICKS {
            game.phase = .Results

            for index in ([9]int{8, 11, 12, 13, 14, 15, 16, 17, 18}) {
                if ph.body_velocity(ctx.execution, game.bodies[index], {}, {}) != .None {
                    r.abort(ctx)
                    return
                }
            }

            for delivered, i in game.delivered {
                if delivered {
                    if ph.body_velocity(ctx.execution, game.bodies[i + 3], {}, {}) != .None {
                        r.abort(ctx)
                        return
                    }
                }
            }

            r.emit(ctx, 7, u64(game.round), Event{0, 7, game.payout})
        }
    }
}

game_action :: proc(game: ^Game, seat: u16, value: Action, ctx: ^r.Step(Event)) -> bool {
    if !action_valid(value) || seat < 1 || seat > 2 {
        return false
    }

    if value.kind == .Boost {
        return game.phase == .Working && boost(game, seat, value, ctx)
    }

    if seat != 1 || game.phase != .Results {
        return false
    }

    return reset_round(game, value.kind == .Next_Job ? (game.layout + 1) % 3 : game.layout, ctx)
}

action_valid :: proc(value: Action) -> bool {
    if value.kind == .Boost {
        return boost_valid(value)
    }

    return value.x == 0 && value.z == 0
}
