package kit_ai

// kit/ai — the verbs NPCs are written with (toolkit phase 5): perception,
// steering, and the wave director. PATTERNS, NOT A FRAMEWORK: kit/ai has no
// Brain type, no behavior tree, no update loop. The game writes an ordinary
// switch over a replicated `state: u8` in its HOST tick, built from these
// verbs — cavecrawl's dweller is the documented example.
//
// THE NPC MODEL rides what already exists: an NPC is an entity OWNED BY THE
// HOST PLAYER — the host's brain tick writes x/y like any owner writes
// streamed fields, and every client interpolates the motion for free. Its
// state byte and hp are plain replicated fields. No new machinery.
//
// Everything here is deterministic, allocation-free, dimension-agnostic
// ([3]f32; 2D leaves z zero) and engine-free.

import "core:math"

// ---- perception ----------------------------------------------------------------

Target :: struct {
	id:  u32,
	pos: [3]f32,
}

// Is the straight line from `from` to `to` blocked (a wall between)? The
// GAME owns geometry — kit/ai only asks. nil = open world, everything seen.
Blocker_Proc :: proc(user: rawptr, from, to: [3]f32) -> bool

@(private = "file")
dist_sq :: proc "contextless" (a, b: [3]f32) -> f32 {
	d := b - a
	return d.x * d.x + d.y * d.y + d.z * d.z
}

// The nearest target within `max_range` that line-of-sight reaches.
nearest :: proc(from: [3]f32, targets: []Target, max_range: f32, blocker: Blocker_Proc = nil, user: rawptr = nil) -> (best: Target, ok: bool) {
	best_d := max_range * max_range
	for t in targets {
		d := dist_sq(from, t.pos)
		if d > best_d {
			continue
		}
		if blocker != nil && blocker(user, from, t.pos) {
			continue
		}
		best_d = d
		best = t
		ok = true
	}
	return
}

in_reach :: proc "contextless" (from, to: [3]f32, reach: f32) -> bool {
	return dist_sq(from, to) <= reach * reach
}

// ---- steering (per tick; returns the new position) --------------------------------

// One tick of walking toward `goal`. `arrived` = we are ON it now (never
// overshoots — the last step lands exactly).
step_toward :: proc "contextless" (pos, goal: [3]f32, speed: f32) -> (next: [3]f32, arrived: bool) {
	d := goal - pos
	dist := math.sqrt(dist_sq(pos, goal))
	if dist <= speed {
		return goal, true
	}
	return pos + d * (speed / dist), false
}

// One tick of running AWAY from `threat` (flee). Standing exactly on the
// threat picks +x arbitrarily — any direction beats none.
step_away :: proc "contextless" (pos, threat: [3]f32, speed: f32) -> [3]f32 {
	d := pos - threat
	dist := math.sqrt(dist_sq(pos, threat))
	if dist == 0 {
		return pos + [3]f32{speed, 0, 0}
	}
	return pos + d * (speed / dist)
}

// Patrol bookkeeping: advance (and wrap) the waypoint index once the current
// one is within `reach`. The game steps toward `points[current]` as usual.
patrol_next :: proc "contextless" (points: [][3]f32, current: int, pos: [3]f32, reach: f32) -> int {
	if len(points) == 0 {
		return 0
	}
	idx := current % len(points)
	if in_reach(pos, points[idx], reach) {
		return (idx + 1) % len(points)
	}
	return idx
}

// ---- the wave director --------------------------------------------------------------
//
// Generalized from survivors: the director decides WHEN and HOW MANY; the
// game decides what and where (its spawn code runs per emitted spawn). One
// wave at a time, the next after the field is clear and a breather passes.

Wave :: struct {
	count: u16, // how many this wave
	rest:  u16, // ticks of calm AFTER this wave clears, before the next
}

Director :: struct {
	wave:       int, // waves fully started so far (1-based once running)
	pending:    u16, // still to spawn in the current wave
	alive:      int, // living spawns (the game reports deaths)
	rest_until: u64, // calm gate before the next wave starts
	done:       bool, // all waves started and cleared
}

// Once per host tick. Returns how many to spawn NOW (the director paces one
// per tick — spawn bursts read badly and spike the delta batch) and whether a
// NEW WAVE just rolled in — the "wave N!" banner/horn moment every consumer
// shadowed with a `wave_seen` compare of its own.
director_tick :: proc(d: ^Director, tick: u64, waves: []Wave) -> (spawn: int, wave_started: bool) {
	if d.done {
		return 0, false
	}
	if d.pending > 0 {
		d.pending -= 1
		d.alive += 1
		return 1, false
	}
	if d.alive > 0 || tick < d.rest_until {
		return 0, false
	}
	if d.wave >= len(waves) {
		d.done = true
		return 0, false
	}
	d.pending = waves[d.wave].count
	d.wave += 1
	return 0, true // spawning starts next tick; the wave is announced NOW
}

// The game reports each director-spawned NPC's death. When the wave clears,
// the calm before the next one starts counting.
director_note_death :: proc(d: ^Director, tick: u64, waves: []Wave) {
	if d.alive > 0 {
		d.alive -= 1
	}
	if d.alive == 0 && d.pending == 0 && d.wave > 0 && d.wave <= len(waves) {
		d.rest_until = tick + u64(waves[d.wave - 1].rest)
	}
}

// The current wave number for HUDs ("wave 2/3"); 0 before the first.
director_wave :: proc "contextless" (d: ^Director) -> int {
	return d.wave
}
