package kit_ai_test

// Standalone tests for kit/ai — perception, steering, and the wave director
// (the verbs NPC brains are written with). No Godot runtime:
//
//   odin test tests/kitai -collection:godot=$PWD

import "core:testing"
import kai "godot:kit/ai"

@(test)
nearest_respects_range_and_walls :: proc(t: ^testing.T) {
	targets := []kai.Target {
		{id = 1, pos = {50, 0, 0}},
		{id = 2, pos = {20, 0, 0}},
		{id = 3, pos = {500, 0, 0}}, // out of range
	}
	best, ok := kai.nearest({0, 0, 0}, targets, 100)
	testing.expect(t, ok)
	testing.expect_value(t, best.id, u32(2))

	_, any := kai.nearest({0, 0, 0}, targets, 5)
	testing.expect(t, !any, "nothing that close")

	// A wall between us and the near one: the far one is seen instead.
	wall :: proc(user: rawptr, from, to: [3]f32) -> bool {
		return to.x < 30 // blocks anything near the origin
	}
	seen, sok := kai.nearest({0, 0, 0}, targets, 100, wall)
	testing.expect(t, sok)
	testing.expect_value(t, seen.id, u32(1))
}

@(test)
stepping_arrives_without_overshooting :: proc(t: ^testing.T) {
	pos := [3]f32{0, 0, 0}
	goal := [3]f32{10, 0, 0}
	arrived: bool
	steps := 0
	for !arrived && steps < 100 {
		pos, arrived = kai.step_toward(pos, goal, 3)
		steps += 1
	}
	testing.expect_value(t, pos, goal) // the last step LANDS, never oscillates
	testing.expect_value(t, steps, 4) // 3+3+3+1

	// Diagonals move at `speed`, not speed-per-axis.
	next, _ := kai.step_toward({0, 0, 0}, {30, 40, 0}, 5)
	testing.expect(t, abs(next.x - 3) < 0.001 && abs(next.y - 4) < 0.001)

	// Fleeing puts distance directly away from the threat.
	away := kai.step_away({10, 0, 0}, {0, 0, 0}, 5)
	testing.expect_value(t, away, [3]f32{15, 0, 0})
	panic_dir := kai.step_away({7, 7, 0}, {7, 7, 0}, 5) // standing ON it: still move
	testing.expect(t, panic_dir != [3]f32{7, 7, 0})
}

@(test)
patrols_advance_and_wrap :: proc(t: ^testing.T) {
	route := [][3]f32{{0, 0, 0}, {100, 0, 0}, {100, 100, 0}}
	testing.expect_value(t, kai.patrol_next(route, 0, {50, 0, 0}, 5), 0) // not there yet
	testing.expect_value(t, kai.patrol_next(route, 0, {2, 0, 0}, 5), 1) // reached: advance
	testing.expect_value(t, kai.patrol_next(route, 2, {100, 99, 0}, 5), 0) // wraps
	testing.expect_value(t, kai.patrol_next(nil, 3, {0, 0, 0}, 5), 0) // no route: harmless
}

@(test)
the_director_paces_waves :: proc(t: ^testing.T) {
	waves := []kai.Wave{{count = 2, rest = 10}, {count = 3, rest = 10}}
	d: kai.Director
	tick := u64(0)

	spawned := 0
	starts := 0 // wave_started: the "wave N rolls in" edge, no consumer-side shadow
	// Wave 1 arms on the first tick, spawns one per tick after.
	for _ in 0 ..< 4 {
		tick += 1
		n, ws := kai.director_tick(&d, tick, waves)
		spawned += n
		if ws {starts += 1}
	}
	testing.expect_value(t, spawned, 2)
	testing.expect_value(t, starts, 1) // announced exactly once, the tick it armed
	testing.expect_value(t, kai.director_wave(&d), 1)
	testing.expect_value(t, d.alive, 2)

	// Nothing more while the field is hostile.
	tick += 1
	{
		n, _ := kai.director_tick(&d, tick, waves)
		testing.expect_value(t, n, 0)
	}

	// The wave falls; the breather starts counting from the LAST death.
	kai.director_note_death(&d, tick, waves)
	kai.director_note_death(&d, tick, waves)
	for _ in 0 ..< 9 { // rest=10: still calm
		tick += 1
		{
		n, _ := kai.director_tick(&d, tick, waves)
		testing.expect_value(t, n, 0)
	}
	}
	spawned2 := 0
	for _ in 0 ..< 6 {
		tick += 1
		n2, _ := kai.director_tick(&d, tick, waves)
		spawned2 += n2
	}
	testing.expect_value(t, spawned2, 3)
	testing.expect_value(t, kai.director_wave(&d), 2)

	// Clearing the last wave finishes the director for good.
	for _ in 0 ..< 3 {
		kai.director_note_death(&d, tick, waves)
	}
	for _ in 0 ..< 15 {
		tick += 1
		{
		n, _ := kai.director_tick(&d, tick, waves)
		testing.expect_value(t, n, 0)
	}
	}
	testing.expect(t, d.done)
}
