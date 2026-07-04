package kit_interact

// kit/interact — "what can I use right now?" (toolkit phase 3). The first
// real test of the DIMENSION-AGNOSTIC rule: positions are [3]f32 everywhere,
// 2D games leave z at zero, and there is no engine type in sight.
//
// The abstraction is deliberately thin, because interaction is two questions:
//
//   DISCOVERY (client, every frame): which nearby interactable should the
//     prompt point at? -> `pick` over candidates the game collects from its
//     registry walk.
//   GATING (host, inside the command): is this player actually allowed to
//     use that entity from where they stand? -> the command proc calls
//     `in_range`/`facing_ok` with the SAME numbers.
//
// Same procs, same constants, zero role branches — the prompt the client
// shows and the validation the host runs cannot disagree about geometry
// (the host's positions stay the truth when they differ in time).
//
// The USE itself is just a command on the target entity (open the door, loot
// slot 2) — kit/interact never dispatches anything.

import "core:math"

Candidate :: struct {
	id:     u32, // knet.Net_Id-sized; kept engine- and package-free
	pos:    [3]f32,
	radius: f32, // per-target extra reach (a chest is easier to touch than a lever)
}

@(private = "file")
dist_sq :: proc "contextless" (a, b: [3]f32) -> f32 {
	d := b - a
	return d.x * d.x + d.y * d.y + d.z * d.z
}

// Within `reach` of the target (plus the target's own radius)? Squared math,
// no sqrt — call it in commands as freely as in frame code.
in_range :: proc "contextless" (origin, target: [3]f32, reach: f32, radius: f32 = 0) -> bool {
	r := reach + radius
	return dist_sq(origin, target) <= r * r
}

// Is the target inside the facing cone? `min_dot` is the cone half-angle as a
// dot-product threshold (0 = 180° cone, 0.5 = 120°, 0.7071 = 90°). A zero
// `facing` vector means omnidirectional; standing ON the target always passes
// (there is no direction to disagree about).
facing_ok :: proc "contextless" (origin, target, facing: [3]f32, min_dot: f32) -> bool {
	if facing == {} {
		return true
	}
	to := target - origin
	d := math.sqrt(dist_sq(origin, target))
	if d == 0 {
		return true
	}
	f := math.sqrt(dist_sq({}, facing))
	dot := (to.x * facing.x + to.y * facing.y + to.z * facing.z) / (d * f)
	return dot >= min_dot
}

// The nearest candidate within reach and facing — what the prompt points at.
// The game collects candidates from its own entity walk (id, position, and
// per-target radius); `facing` zero means omnidirectional.
pick :: proc(cands: []Candidate, origin: [3]f32, reach: f32, facing := [3]f32{}, min_dot: f32 = 0) -> (best: Candidate, ok: bool) {
	best_d := max(f32)
	for c in cands {
		if !in_range(origin, c.pos, reach, c.radius) {
			continue
		}
		if !facing_ok(origin, c.pos, facing, min_dot) {
			continue
		}
		if d := dist_sq(origin, c.pos); d < best_d {
			best_d = d
			best = c
			ok = true
		}
	}
	return
}
