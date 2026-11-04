package replay_claimball_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import lb "godot:replay/lobby"
import v "godot:replay/view"
import game "../../examples/replay_claimball/shared/pitch"

won_pitch :: proc() -> game.World {
    w := game.initial(min_players = 2, goals_to = 1, manual_start = true)
    events: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 20,
        epoch  = 1,
        events = events[:],
    }
    game.step(&w, {}, 7, 0, &ctx)

    for &player, i in w.players {
        if player.initialized {
            player.named = true
            player.motion.position = {f32(80 + i * 100), 200}
            player.motion.velocity = {2, 1}
            player.kick_cd = 12
            w.names[i], _ = lb.name(i == 0 ? "Captain" : i == 1 ? "Striker" : "Departed")
        }
    }

    w.players[2].connected = false
    w.started = true
    w.score = {
        left   = 1,
        winner = 1,
    }
    w.ball.reset = 1
    w.kicks, w.spikes, w.contacts = 5, 2, 19
    return w
}

@(test)
restart_resets_match_values_and_preserves_identity_and_read_only_boundary :: proc(t: ^testing.T) {
    original := won_pitch()
    testing.expect(t, game.state_valid(original))

    for grouped in ([2]bool{false, true}) {
        w := grouped ? game.project(r.Frame(game.World){20, original}, 1) : original
        before := w
        events: [32]r.Occurrence(game.Event)
        ctx := r.Step(game.Event) {
            tick   = 21,
            epoch  = 1,
            events = events[:],
        }
        testing.expect(t, game.action(&w, 1, {restart_round = 1}, &ctx))
        testing.expect_value(t, w.round, u32(2))
        testing.expect(t, w.started && w.manual_start)
        testing.expect(t, w.names == before.names && w.clock == before.clock && w.min_players == 2 && w.goals_to == 1)
        testing.expect_value(t, w.score, game.Score{})
        testing.expect(t, w.kicks == 0 && w.spikes == 0 && w.contacts == 0)
        testing.expect_value(t, w.ball.motion.position, game.CENTER)
        testing.expect(t, w.ball.motion.velocity == [2]f32{} && w.ball.hold == game.KICKOFF_HOLD && w.ball.reset == 0)

        for player, i in w.players {
            if before.players[i].initialized {
                testing.expect(
                    t,
                    player.named &&
                    player.connected == before.players[i].connected &&
                    player.team == before.players[i].team,
                )
                testing.expect(t, player.motion.velocity == [2]f32{} && player.kick_cd == 0)
            }
        }

        if grouped {
            testing.expect(t, game.group_valid(w, 1) && reflect.equal(w.outside, before.outside))

            for player, i in w.players {
                if i != 0 {
                    testing.expect_value(t, player, game.Player{})
                }
            }
        } else {
            testing.expect(t, game.state_valid(w) && w.players[2].initialized && !w.players[2].connected)
        }
    }
}

@(test)
restart_rejects_wrong_leader_stale_round_mixed_commands_and_exhaustion :: proc(t: ^testing.T) {
    events: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 21,
        epoch  = 1,
        events = events[:],
    }

    for kind in 0 ..< 7 {
        w := won_pitch()
        seat: u16 = 1
        command := game.Action {
            restart_round = 1,
        }

        switch kind {
        case 0:
            seat = 2
        case 1:
            seat = 0
        case 2:
            w.players[1].connected = false
        case 3:
            w.score = {}
            w.ball.reset = 0
        case 4:
            w.round = 2 // Delayed round-one request after another completed match.
        case 5:
            w.round = max(u32)
            command.restart_round = max(u32)
        case 6:
            command.spike = true
        }

        before := w
        testing.expect(t, !game.action(&w, seat, command, &ctx))
        testing.expect(t, reflect.equal(w, before))
    }

    w := won_pitch()
    w.players[0].connected = false
    w.players[2].connected = true
    projected := game.project(r.Frame(game.World){20, w}, 2)
    boundary := projected.outside
    testing.expect_value(t, game.leader(&projected), u16(2))
    testing.expect(t, game.action(&projected, 2, {restart_round = 1}, &ctx))
    testing.expect(t, game.group_valid(projected, 2) && reflect.equal(projected.outside, boundary))
    testing.expect_value(t, projected.players[0], game.Player{})
}

@(test)
corrected_restart_replays_to_fresh_complete_and_projected_execution :: proc(t: ^testing.T) {
    for grouped in ([2]bool{false, true}) {
        w := won_pitch()

        if grouped {
            w = game.project(r.Frame(game.World){20, w}, 1)
        }

        step := proc(w: ^game.World, a: game.Action, ctx: ^r.Step(game.Event)) {
            game.step(w, {}, 0, 0, ctx)

            if game.action_valid(a) {
                game.action(w, 1, a, ctx)
            }
        }

        a, b: r.Timeline(game.World, game.Action, game.Event)
        testing.expect_value(t, r.init(&a, r.Frame(game.World){20, w}, step, cfg = {128, 32}), r.Error.None)
        testing.expect_value(t, r.init(&b, r.Frame(game.World){20, w}, step, cfg = {128, 32}), r.Error.None)
        defer r.destroy(&a)
        defer r.destroy(&b)

        for tick in 21 ..< 110 {
            testing.expect_value(t, r.advance(&a, game.Action{}).error, r.Error.None)
            testing.expect_value(
                t,
                r.advance(&b, tick == 21 ? game.Action{restart_round = 1} : game.Action{}).error,
                r.Error.None,
            )
        }

        testing.expect_value(t, r.revise_input(&a, 21, game.Action{restart_round = 1}).error, r.Error.None)
        actual, _ := r.current(&a)
        expected, _ := r.current(&b)
        testing.expect(t, reflect.equal(actual, expected) && actual.state.round == 2)
        testing.expect(t, grouped ? game.group_valid(actual.state, 1) : game.state_valid(actual.state))
    }
}

@(test)
correcting_a_kick_into_another_round_replaces_its_presentation_lifetime :: proc(t: ^testing.T) {
    occurrences: [2]r.Occurrence(game.Event)

    for round in 1 ..= 2 {
        w := game.initial()
        events: [32]r.Occurrence(game.Event)
        ctx := r.Step(game.Event) {
            tick   = 100,
            epoch  = 1,
            events = events[:],
        }
        game.reset_player(&w, 1, &ctx)
        w.round = u32(round)
        w.started = true
        w.ball.hold = 0
        w.players[0].motion.position = game.CENTER - [2]f32{20, 0}
        controls: [game.SEATS]game.Controls
        controls[0].buttons = game.KICK
        game.step(&w, controls, 0, 0, &ctx)
        testing.expect_value(t, ctx.count, 1)

        if ctx.count != 1 {
            return
        }

        occurrences[round - 1] = events[0]
    }

    testing.expect(t, occurrences[0].id != occurrences[1].id)
    j: v.Journal(game.Event)
    testing.expect_value(t, v.journal_init(&j, baseline = 99), v.Error.None)
    defer v.journal_destroy(&j)
    testing.expect_value(t, v.sync_tick(&j, 100, occurrences[:1]), v.Error.None)
    changes: [4]v.Change(game.Event)
    testing.expect_value(t, v.drain(&j, changes[:]), 1)
    testing.expect_value(t, changes[0].kind, v.Change_Kind.Begin)
    testing.expect_value(t, v.sync_tick(&j, 100, occurrences[1:]), v.Error.None)
    n := v.drain(&j, changes[:])
    testing.expect_value(t, n, 2)

    if n == 2 {
        testing.expect_value(t, changes[0].kind, v.Change_Kind.Cancel)
        testing.expect_value(t, changes[0].occurrence.value.round, u32(1))
        testing.expect_value(t, changes[1].kind, v.Change_Kind.Begin)
        testing.expect_value(t, changes[1].occurrence.value.round, u32(2))
    }
}
