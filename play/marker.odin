package play

import gd "godot:godot"

// play/marker — lazy world-markers: a Godot node built ONCE, then followed / filled /
// shown each frame (a warning ring, a revive bar, a downed beacon).
//
// ENGINE-BOUND and PRESENTATION-ONLY. Unlike play/edge|pace|fsm|anim (pure, safe
// anywhere), these touch Godot nodes — call them from a render path only, never a
// command or host tick (which has no nodes). They exist to hide the gd API's cast +
// magic-string ceremony at the call site; the node's own BUILD stays inline, since
// that's game-specific (which polygon, which colour), and the build-once guard is
// just `cast(rawptr)node == nil` — terse enough to leave in the open.
//
// Handles are passed as gd.Node2d; a Polygon2d marker casts once at the call
// (cast(gd.Node2d)v.ring) — the same cast the raw gd calls already needed.

// show toggles a marker's visibility.
show :: proc(node: gd.Node2d, on: bool) {
	gd.set_bool(cast(gd.Object)node, "visible", on)
}

// follow moves a marker to a position (local to its parent, or world for a top-level
// holder) — its per-frame tracking.
follow :: proc(node: gd.Node2d, x, y: f32) {
	gd.node2d_set_position(node, {x, y})
}

// fill x-scales a bar's fill node to `pct` in [0,1], leaving height at 1 — the
// revive / health-bar shape.
fill :: proc(node: gd.Node2d, pct: f32) {
	gd.node2d_set_scale(node, {pct, 1})
}

// depth sets a marker's draw order (z-index), hiding the Canvas_Item cast. Set once,
// at build.
depth :: proc(node: gd.Node2d, z: int) {
	gd.canvas_item_set_z_index(cast(gd.Canvas_Item)node, gd.Int(z))
}
