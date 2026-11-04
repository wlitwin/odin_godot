package scrap_presentation

import "core:math"
import game "../game"
import flow "../flow"

// The adapter supplies the victim from the exact retained event tick. This is
// cosmetic placement only; gameplay hit judgment still uses authority history.
wound :: proc(player: game.Player, event: game.Event) -> (view: flow.Wound_View, ok: bool) {
    if event.kind != .Hurt || player.generation != event.generation {
        return
    }

    view.victim = player.position
    delta := event.position - player.position
    length := math.sqrt(delta[0] * delta[0] + delta[1] * delta[1])

    if length > .001 {
        view.direction = delta / length
        view.marker = view.victim + view.direction * 30
        view.directional = true
    }

    return view, true
}
