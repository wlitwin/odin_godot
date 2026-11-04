package replay_slopball_test
import "core:testing"
import "core:reflect"
import r "godot:replay"
import own "godot:replay/owned"
import lb "godot:replay/lobby"
import game "../../examples/replay_slopball/shared/pitch"

completed_match :: proc() -> game.World {
    w := game.initial(minimum = 2, goals_to = 1)
    events: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 1,
        epoch  = 1,
        events = events[:],
    }
    game.step(&w, {}, 7, 0, &ctx)
    w.tick = 2
    w.left, w.won = 1, 1
    w.players[2].connected = false
    w.names[0], _ = lb.name("Captain")
    w.players[0].named = true
    assert(own.offer(&w.ball, 2, 2, 60) == .None)
    return w
}

@(test)
restart_preserves_roster_and_revokes_all_previous_solver_scopes :: proc(t: ^testing.T) {
    w := completed_match()
    before := w
    events: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 3,
        epoch  = 1,
        events = events[:],
    }
    testing.expect(t, game.state_valid(w))
    testing.expect(t, game.action(&w, 1, {restart_round = 1}, &ctx))
    testing.expect(
        t,
        w.round == 2 &&
        w.started &&
        w.left == 0 &&
        w.right == 0 &&
        w.won == 0 &&
        w.kickoff_until == 3 + game.KICKOFF_TICKS,
    )
    testing.expect(t, w.names == before.names && w.minimum == before.minimum && w.goals_to == before.goals_to)

    for player, i in w.players {
        testing.expect(
            t,
            player.connected == before.players[i].connected &&
            player.named == before.players[i].named &&
            player.initialized == before.players[i].initialized,
        )
        testing.expect(
            t,
            player.body.key == before.players[i].body.key && player.body.revision > before.players[i].body.revision,
        )
        testing.expect(t, reflect.equal(player.body.value, game.spawn(u16(i + 1))))
        testing.expect_value(t, player.body.sequence, u64(0))
    }

    testing.expect(
        t,
        w.ball.revision > before.ball.pending.revision &&
        w.ball.pending.revision == 0 &&
        w.ball.owner == 1 &&
        w.ball.sequence == 0,
    )
    controls: [game.SEATS]game.Control
    controls[0].player = {own.scope(before.players[0].body), 100, 100, before.players[0].body.value}
    controls[0].player.value.position[0] += 10
    controls[1].ball = {own.offer_scope(before.ball), 100, 100, before.ball.value}
    controls[1].ball.value.position[0] += 10
    ball, player := w.ball.value, w.players[0].body.value
    ctx = {
        tick   = 4,
        epoch  = 1,
        events = events[:],
    }
    game.step(&w, controls, 0, 0, &ctx)
    testing.expect(t, reflect.equal(w.ball.value, ball) && reflect.equal(w.players[0].body.value, player))
    testing.expect_value(t, w.rejected, u32(2))
    testing.expect(t, game.state_valid(w))
}

@(test)
restart_is_atomic_and_rejects_stale_or_unqualified_requests :: proc(t: ^testing.T) {
    for kind in 0 ..< 7 {
        w := completed_match()
        seat: u16 = 1
        a := game.Action {
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
            w.round = 2
        case 4:
            w.ball.revision_counter = max(u64)
        case 5:
            w.round = max(u32)
            a.restart_round = max(u32)
        case 6:
            a.start = true
        }

        before := w
        events: [32]r.Occurrence(game.Event)
        ctx := r.Step(game.Event) {
            tick   = 3,
            epoch  = 1,
            events = events[:],
        }
        testing.expect(t, !game.action(&w, seat, a, &ctx))
        testing.expect(t, reflect.equal(w, before))
        testing.expect_value(t, ctx.count, 0)
    }
}

@(test)
restart_correction_replays_to_fresh_execution_with_round_scoped_events :: proc(t: ^testing.T) {
    w := completed_match()

    step := proc(w: ^game.World, a: game.Action, ctx: ^r.Step(game.Event)) {
        game.step(w, {}, 0, 0, ctx)

        if game.action_valid(a) {
            game.action(w, 1, a, ctx)
        }
    }

    a, b: r.Timeline(game.World, game.Action, game.Event)
    testing.expect_value(t, r.init(&a, r.Frame(game.World){2, w}, step), r.Error.None)
    defer r.destroy(&a)
    testing.expect_value(t, r.init(&b, r.Frame(game.World){2, w}, step), r.Error.None)
    defer r.destroy(&b)

    for tick in 3 ..< 20 {
        testing.expect_value(t, r.advance(&a, game.Action{}).error, r.Error.None)
        testing.expect_value(
            t,
            r.advance(&b, tick == 3 ? game.Action{restart_round = 1} : game.Action{}).error,
            r.Error.None,
        )
    }

    testing.expect_value(t, r.revise_input(&a, 3, game.Action{restart_round = 1}).error, r.Error.None)
    actual, _ := r.current(&a)
    expected, _ := r.current(&b)
    testing.expect(t, reflect.equal(actual, expected) && actual.state.round == 2)
    occurrences: [8]r.Occurrence(game.Event)
    n, err := r.copy_events(&a, 3, occurrences[:])
    testing.expect_value(t, err, r.Error.None)
    testing.expect(t, n > 0)

    for event in occurrences[:n] {
        if event.value.kind == .Started {
            testing.expect_value(t, event.value.round, u32(2))
            testing.expect_value(t, event.id.source, u64(2) << 32 | 100)
        }
    }
}
