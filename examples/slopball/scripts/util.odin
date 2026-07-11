package slopball

// ----------------------------------------------------------------------------
// util — shared, owner-less helpers for slopball (no //gd:class, so scriptgen skips this
// file; plain package Odin compiled into the one scripts dll, shared by every script).
// ----------------------------------------------------------------------------

import gd "godot:godot"
import "core:math"

PITCH_W :: f32(640)
PITCH_H :: f32(360)

normalized :: proc "contextless" (v: gd.Vector2) -> gd.Vector2 {
	length := math.sqrt(v.x * v.x + v.y * v.y)
	if length <= 0.00001 {return gd.Vector2{0, 0}}
	return gd.Vector2{v.x / length, v.y / length}
}

// peer_color — a distinct colour per player id so the avatars read apart on every screen.
peer_color :: proc "contextless" (player_id: int) -> gd.Color {
	switch player_id % 4 {
	case 1:  return gd.Color{0.35, 0.65, 1.0, 1}     // host — blue
	case 2:  return gd.Color{1.0, 0.62, 0.2, 1}      // orange
	case 3:  return gd.Color{0.5, 0.9, 0.4, 1}       // green
	case:    return gd.Color{0.9, 0.45, 0.9, 1}      // magenta
	}
}
