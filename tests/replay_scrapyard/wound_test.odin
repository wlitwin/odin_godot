package replay_scrapyard_test

import "core:testing"
import h "godot:replay/history"
import game "../../examples/replay_scrapyard/shared/game"
import flow "../../examples/replay_scrapyard/shared/flow"

@(test)
wound_bearing_uses_recorded_victim_and_rejects_missing_or_reused_history :: proc(t: ^testing.T) {
    w := yard()
    w.players[0].position = {100, 100}
    h.record(&w.hit_history, 10, game.proxies(&w))
    event := game.Event {
        kind       = .Hurt,
        seat       = 1,
        generation = 1,
        position   = {200, 100},
        serial     = 2,
    }
    w.players[0].position = {400, 600}
    w.players[0].hp = 0
    view, ok := flow.wound_view(&w, event, 10)
    testing.expect(t, ok && view.directional)
    testing.expect_value(t, view.victim, [2]f32{100, 100})
    testing.expect_value(t, view.marker, [2]f32{130, 100})
    testing.expect_value(t, view.direction, [2]f32{1, 0})
    h.record(&w.hit_history, 11, game.proxies(&w))
    event.position = {500, 600}
    view, ok = flow.wound_view(&w, event, 11)
    testing.expect(t, ok && view.directional && view.victim == [2]f32{400, 600})
    event.position = {100, 100}
    view, ok = flow.wound_view(&w, event, 10)
    testing.expect(t, ok && !view.directional)
    event.generation = 2
    _, ok = flow.wound_view(&w, event, 10)
    testing.expect(t, !ok)
    event.generation = 1
    _, ok = flow.wound_view(&w, event, 12)
    testing.expect(t, !ok)
    w.players[0].generation = 2
    _, ok = flow.wound_view(&w, event, 10)
    testing.expect(t, !ok)
    w.players[0].generation = 1
    h.record(&w.hit_history, 42, game.proxies(&w))
    _, ok = flow.wound_view(&w, event, 10)
    testing.expect(t, !ok)
}
