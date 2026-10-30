package scrapyard_flow

import "core:math"

// The original igniter uses a fixed 150px, 10px/tick visual, independent of
// custom cone damage/range. Its owner fans five; remote announces carry one.
flame_position :: proc(origin, end: [2]f32, clock, until: u64, tongue: int) -> ([2]f32, bool) {
	if until < 17 || clock < until - 17 || clock - (until - 17) >= 15 || tongue < -2 || tongue > 2 {
		return {}, false
	}
	delta := end - origin
	length := math.sqrt(delta[0] * delta[0] + delta[1] * delta[1])
	if length < 0.001 {
		return {}, false
	}
	direction := delta / length
	angle := f32(tongue) * 0.25
	c, s := math.cos(angle), math.sin(angle)
	ray := [2]f32{direction[0] * c - direction[1] * s, direction[0] * s + direction[1] * c}
	return origin + ray * (18 + 10 * f32(clock - (until - 17))), true
}

// Same four-point kink and two-pixel half-width as the original spread bolt.
arc_polygon :: proc(origin, end: [2]f32) -> ([8][2]f32, bool) {
	delta := end - origin
	length := math.sqrt(delta[0] * delta[0] + delta[1] * delta[1])
	if length < 1 {
		return {}, false
	}
	normal := [2]f32{-delta[1] / length, delta[0] / length}
	path := [4][2]f32{{}, delta / 3 + normal * 7, delta * 2 / 3 - normal * 7, delta}
	points: [8][2]f32
	for point, i in path {
		points[i] = point + normal * 2
		points[7 - i] = point - normal * 2
	}
	return points, true
}

// The arc's eight vertices are an affine transform of arc_polygon({}, {1,0}).
// Cache that unit polygon once; changing the basis avoids rebuilding indices.
arc_axes :: proc(origin, end: [2]f32) -> (x, y: [2]f32, valid: bool) {
	delta := end - origin
	length := math.sqrt(delta[0] * delta[0] + delta[1] * delta[1])
	if length < 1 {
		return
	}
	return delta, {-delta[1] / length, delta[0] / length}, true
}

Flame_Key :: struct {
	epoch, until, source: u64,
	pool_generation, serial: u32,
	origin, end: [2]f32,
}

Flame_Track :: struct {
	key: Flame_Key,
	tick: u64,
	seeded: bool,
	stopped: [5]bool,
	previous: [5][2]f32,
}

// Reconciliation may replace a cast/path without decreasing the displayed tick
// or changing the pool generation. A stopped old tongue must not stop that path.
flame_reconcile :: proc(track: ^Flame_Track, key: Flame_Key, tick: u64, active: bool) -> bool {
	reset := !active || !track.seeded || track.key != key || tick < track.tick
	if reset {
		track.stopped = {}
		track.previous = {}
	}
	track.key, track.tick, track.seeded = key, tick, active
	return reset
}
