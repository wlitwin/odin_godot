package replay_test

import "core:testing"
import r "godot:replay"
import h "godot:replay/history"

Boundary_World :: struct {x: i32, gate: h.Boundary(i32)}
boundary_step :: proc(w: ^Boundary_World, move: i32, ctx: ^r.Step(u8)) {
	gate, status := h.boundary_sample(w.gate, ctx.tick, 3, .Hold)
	if status != .Exact && status != .Held {r.abort(ctx); return}
	w.x = min(w.x + move, gate)
}

@(test)
historical_boundary_is_owned_bounded_and_replayed_from_the_checkpoint :: proc(t: ^testing.T) {
	timeline: r.Timeline(Boundary_World, i32, u8)
	defer r.destroy(&timeline)
	base := r.Frame(Boundary_World){tick = 10, state = {x = 4, gate = {10, 8, true}}}
	r.init(&timeline, base, boundary_step)
	for _ in 0 ..< 3 {testing.expect_value(t, r.advance(&timeline, i32(3)).error, r.Error.None)}
	f, _ := r.current(&timeline); testing.expect_value(t, f.state.x, i32(8))
	testing.expect_value(t, r.advance(&timeline, i32(3)).error, r.Error.Aborted)
	testing.expect_value(t, timeline.head, u64(13))
	// New authoritative boundary at tick 11 changes the replayed collision result.
	truth := r.Frame(Boundary_World){tick = 11, state = {x = 7, gate = {11, 12, true}}}
	testing.expect_value(t, r.correct(&timeline, truth, nil).error, r.Error.None)
	f, _ = r.current(&timeline); testing.expect_value(t, f.state.x, i32(12))
	testing.expect_value(t, r.audit(&timeline, 12).error, r.Error.None)
	copy := f.state.gate; copy.value = 999
	f, _ = r.current(&timeline); testing.expect_value(t, f.state.gate.value, i32(12))
	_, exact := h.boundary_sample(f.state.gate, 12, 3, .Exact); testing.expect_value(t, exact, h.Boundary_Status.Expired)
	_, future := h.boundary_sample(f.state.gate, 10, 3, .Hold); testing.expect_value(t, future, h.Boundary_Status.Future)
}
