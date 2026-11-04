package replay_scrapyard_test

import "core:testing"
import r "godot:replay"
import game "../../examples/replay_scrapyard/shared/game"

@(test)
lobby_departure_transfers_start_permission_without_returned_host_preemption :: proc(t: ^testing.T) {
    w := game.initial()
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 1,
        epoch  = 1,
        events = storage[:],
    }
    game.step(&w, [game.SEATS]game.Control{}, 7, 0, &ctx)

    for seat in u16(1) ..= 3 {
        game.action(&w, seat, game.Action{kind = .Ready, ready = true}, &ctx)
    }

    ctx.tick = 2
    game.step(&w, [game.SEATS]game.Control{}, 0, 1, &ctx)
    testing.expect_value(t, w.host, u16(2))
    testing.expect(t, !w.players[0].profile.ready)
    ctx.tick = 3
    game.step(&w, [game.SEATS]game.Control{}, 1, 0, &ctx)
    testing.expect_value(t, w.host, u16(2))
    game.action(&w, 1, game.Action{kind = .Ready, ready = true}, &ctx)
    testing.expect(t, !game.action(&w, 1, game.Action{kind = .Start}, &ctx))
    testing.expect(t, !game.action(&w, 3, game.Action{kind = .Start}, &ctx))
    testing.expect(t, game.action(&w, 2, game.Action{kind = .Start}, &ctx))
    testing.expect(t, game.state_valid(w))
}

@(test)
empty_lobby_keeps_manual_policy_and_dedicated_lobby_keeps_automatic_policy :: proc(t: ^testing.T) {
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 1,
        epoch  = 1,
        events = storage[:],
    }
    w := game.initial()
    game.step(&w, [game.SEATS]game.Control{}, 0, 7, &ctx)
    testing.expect_value(t, w.host, u16(1))
    ctx.tick = 2
    game.step(&w, [game.SEATS]game.Control{}, 4, 0, &ctx)
    testing.expect_value(t, w.host, u16(3))
    game.action(&w, 3, game.Action{kind = .Ready, ready = true}, &ctx)
    ctx.tick = 3
    game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    testing.expect_value(t, w.stage, game.Stage.Staging)
    w = game.initial(dedicated = true)
    game.step(&w, [game.SEATS]game.Control{}, 4, 0, &ctx)
    game.action(&w, 3, game.Action{kind = .Ready, ready = true}, &ctx)
    ctx.tick = 4
    game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    testing.expect_value(t, w.host, u16(0))
    testing.expect_value(t, w.stage, game.Stage.Yard)
    testing.expect(t, game.state_valid(w))
}
