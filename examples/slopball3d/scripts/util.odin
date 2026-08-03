package slopball3d

// ----------------------------------------------------------------------------
// util — shared, owner-less helpers for slopball3d (no //gd:class, so scriptgen
// skips this file; plain package Odin compiled into the one scripts dll).
//
// The pitch lies in the XZ plane, Y up, floor at y=0: x runs goal-to-goal
// [0..PITCH_W], z runs sideline-to-sideline [0..PITCH_D]. Meters everywhere —
// the whole world is the 2D slopball's pixel geometry divided by 40.
// (The per-seat tint moved into the library: gd.peer_color.)
// ----------------------------------------------------------------------------

import gd "godot:godot"

PITCH_W :: f32(16) // goal line to goal line (x)
PITCH_D :: f32(9) // sideline to sideline (z)
BALL_REST_Y :: f32(0.2) // the ball's radius: where gravity parks it

// Normalize in the GROUND plane — steering is 2D even when the ball flies.
// Drops y, then leans on the library's value-form normalize.
normalized_xz :: proc "contextless" (v: [3]f32) -> [3]f32 {
	return gd.normalized3({v.x, 0, v.z})
}
