package quickdraw

// ----------------------------------------------------------------------------
// util — the arena's shared math (no //gd:class, scriptgen skips this file).
//
// EVERYTHING here is pure: walls, crates, and the hitscan ray are plain
// arithmetic, not PhysicsServer calls — which is precisely what makes the
// movement resimmable (a replay re-runs the identical collision) and the
// lag-comp probe re-testable against rewound positions. This is the
// query-based-kinematics rule from docs/kit/sim.md, practiced.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import "core:math"

ARENA_W :: f32(640)
ARENA_H :: f32(360)
ARENA_WALL :: f32(12) // visual border thickness; movement clamps inside it
GUN_R :: f32(9) // a gunner's body circle

// Per-tick movement at 60 Hz (the sim tick IS the unit of time).
RUN_SPEED :: f32(2.2) // ~132 px/s
DASH_SPEED :: f32(7.0)
DASH_LEN :: u16(8) // dash burst, in ticks
DASH_CD :: u16(45) // full cooldown, burst included (~0.75s)

FIRE_CD :: u16(18) // ~0.3s between shots
FIRE_RANGE :: f32(800) // arena-wide; walls and crates are the real limit

// The LOB — the slow predicted-spawn projectile (bullet.odin). Slow enough to
// read and dodge, which is the whole reason its splash lands on server truth,
// not a rewind.
LOB_SPEED :: f32(2.6) // ~156 px/s — a touch faster than a running gunner
LOB_LIFE :: u16(70) // ~1.2s of flight before it lands (~180 px reach)
LOB_RADIUS :: f32(26) // splash reach at the landing point
LOB_CD :: u16(48) // ~0.8s between lobs

// The DRONE — the companion each duelist steers ALONGSIDE the gunner, from its
// OWN input class (drone.odin). Its speed is deliberately unlike a gunner's, so
// its motion can never be mistaken for the avatar's stick.
DRONE_SPEED :: f32(1.6) // ~96 px/s

MAX_HP :: i32(3)
RESPAWN_TICKS :: u64(120) // ~2s on the floor

Crate :: struct {
	x0, y0, x1, y1: f32,
}

// Two cover crates in the TOP band — the reason a duel has footwork, and the
// bottom half stays a clear firing lane (the acid duels across it). The
// scene's visual rectangles copy these numbers; the MATH is the collision.
CRATES :: [2]Crate{{180, 70, 230, 150}, {410, 70, 460, 150}}

// Seats 2 and 3 (the first two joiners) share the clear bottom lane — the
// duel acid's strafer and deadeye see each other past the crates. A var:
// constants can't take runtime indices.
SPAWNS := [4][2]f32{{60, 60}, {580, 60}, {60, 300}, {580, 300}}

normalized :: proc "contextless" (v: gd.Vector2) -> gd.Vector2 {
	length := math.sqrt(v.x * v.x + v.y * v.y)
	if length <= 0.00001 {return gd.Vector2{0, 0}}
	return gd.Vector2{v.x / length, v.y / length}
}

peer_color :: proc "contextless" (player_id: int) -> gd.Color {
	switch player_id % 4 {
	case 1:  return gd.Color{0.35, 0.65, 1.0, 1}     // host — blue
	case 2:  return gd.Color{1.0, 0.62, 0.2, 1}      // orange
	case 3:  return gd.Color{0.5, 0.9, 0.4, 1}       // green
	case:    return gd.Color{0.9, 0.45, 0.9, 1}      // magenta
	}
}

// The aim angle rides the input struct as a u16 turn fraction — 2π/65536
// resolution (~0.005°), byte-identical on every peer that decodes it.
angle_to_wire :: proc "contextless" (a: f32) -> u16 {
	t := a / (2 * math.PI)
	t -= math.floor(t)
	return u16(t * 65536)
}

angle_of :: proc "contextless" (q: u16) -> f32 {
	return f32(q) * (2 * math.PI / 65536)
}

// Push a body circle out of a crate along the shallow axis — the whole
// collision response, deterministic by construction.
crate_pushout :: proc "contextless" (x: ^f32, y: ^f32, c: Crate) {
	if x^ <= c.x0 - GUN_R || x^ >= c.x1 + GUN_R || y^ <= c.y0 - GUN_R || y^ >= c.y1 + GUN_R {
		return
	}
	left := x^ - (c.x0 - GUN_R)
	right := (c.x1 + GUN_R) - x^
	top := y^ - (c.y0 - GUN_R)
	bot := (c.y1 + GUN_R) - y^
	m := min(left, right, top, bot)
	switch m {
	case left:
		x^ = c.x0 - GUN_R
	case right:
		x^ = c.x1 + GUN_R
	case top:
		y^ = c.y0 - GUN_R
	case:
		y^ = c.y1 + GUN_R
	}
}

// Ray vs crate (slab test). Returns the entry distance along the ray, or
// `limit` when it never enters within limit.
ray_crate :: proc "contextless" (sx, sy, dx, dy: f32, c: Crate, limit: f32) -> f32 {
	tmin := f32(0)
	tmax := limit
	// X slabs.
	if math.abs(dx) < 1e-6 {
		if sx < c.x0 || sx > c.x1 {return limit}
	} else {
		t1 := (c.x0 - sx) / dx
		t2 := (c.x1 - sx) / dx
		if t1 > t2 {t1, t2 = t2, t1}
		tmin = max(tmin, t1)
		tmax = min(tmax, t2)
	}
	// Y slabs.
	if math.abs(dy) < 1e-6 {
		if sy < c.y0 || sy > c.y1 {return limit}
	} else {
		t1 := (c.y0 - sy) / dy
		t2 := (c.y1 - sy) / dy
		if t1 > t2 {t1, t2 = t2, t1}
		tmin = max(tmin, t1)
		tmax = min(tmax, t2)
	}
	if tmax < tmin {return limit}
	return tmin
}

// Ray vs body circle. Returns the hit distance, or `limit` for a miss.
ray_body :: proc "contextless" (sx, sy, dx, dy, cx, cy: f32, limit: f32) -> f32 {
	ox := cx - sx
	oy := cy - sy
	proj := ox * dx + oy * dy // distance along the ray to the closest approach
	if proj < 0 || proj > limit + GUN_R {return limit}
	perp2 := ox * ox + oy * oy - proj * proj
	if perp2 > GUN_R * GUN_R {return limit}
	t := proj - math.sqrt(GUN_R * GUN_R - perp2)
	if t < 0 || t > limit {return limit}
	return t
}

// Where a shot from (sx,sy) along `a` stops against the WALLS + CRATES only —
// the tracer length every screen can compute locally.
shot_wall_limit :: proc "contextless" (sx, sy, a: f32) -> f32 {
	dx := math.cos(a)
	dy := math.sin(a)
	limit := FIRE_RANGE
	// Arena border.
	if dx > 1e-6 {limit = min(limit, (ARENA_W - ARENA_WALL - sx) / dx)}
	if dx < -1e-6 {limit = min(limit, (ARENA_WALL - sx) / dx)}
	if dy > 1e-6 {limit = min(limit, (ARENA_H - ARENA_WALL - sy) / dy)}
	if dy < -1e-6 {limit = min(limit, (ARENA_WALL - sy) / dy)}
	for c in CRATES {
		limit = min(limit, ray_crate(sx, sy, dx, dy, c, limit))
	}
	return max(limit, 0)
}
