package scrapyard_flow

import "core:math"
import h "godot:replay/history"
import game "../game"

Wound_View :: struct {
	victim, marker, direction: [2]f32,
	directional: bool,
}

// The event already carries the origin. The saved proxy history supplies the
// victim's position at that tick, including a now-downed victim. Never borrow
// a newer occupant or infer a direction from today's positions.
wound_view :: proc(world: ^game.World, event: game.Event, tick: u64) -> (view: Wound_View, ok: bool) {
	if event.kind != .Hurt || event.seat == 0 || event.seat > game.SEATS {
		return
	}
	if world.players[event.seat - 1].generation != event.generation {
		return
	}
	proxies, found := h.read(&world.hit_history, tick)
	if !found {
		return
	}
	proxy := proxies[event.seat - 1]
	if proxy.generation != event.generation {
		return
	}
	view.victim = proxy.position
	delta := event.position - proxy.position
	length := math.sqrt(delta[0] * delta[0] + delta[1] * delta[1])
	if length > 0.001 {
		view.direction = delta / length
		view.marker = view.victim + view.direction * 30
		view.directional = true
	}
	return view, true
}
