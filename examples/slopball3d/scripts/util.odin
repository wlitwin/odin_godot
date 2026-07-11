package slopball3d

// ----------------------------------------------------------------------------
// util — shared, owner-less helpers for slopball3d (no //gd:class, so scriptgen
// skips this file; plain package Odin compiled into the one scripts dll).
//
// The pitch lies in the XZ plane, Y up, floor at y=0: x runs goal-to-goal
// [0..PITCH_W], z runs sideline-to-sideline [0..PITCH_D]. Meters everywhere —
// the whole world is the 2D slopball's pixel geometry divided by 40.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import "godot:gdext"
import "core:math"

PITCH_W :: f32(16) // goal line to goal line (x)
PITCH_D :: f32(9) // sideline to sideline (z)
BALL_REST_Y :: f32(0.2) // the ball's radius: where gravity parks it

// Normalize in the GROUND plane — steering is 2D even when the ball flies.
normalized_xz :: proc "contextless" (v: [3]f32) -> [3]f32 {
	length := math.sqrt(v.x * v.x + v.z * v.z)
	if length <= 0.00001 {return {}}
	return {v.x / length, 0, v.z / length}
}

// True when this run has no real window (the acid path). The headless display
// server has no vsync to disable, and capping its fps would only slow the acids.
running_headless :: proc() -> bool {
	name := gd.display_server_get_name(gd.singleton_display_server())
	buf: [64]u8
	n := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&name, cast(cstring)&buf[0], len(buf) - 1)
	return n > 0 && string(buf[:n]) == "headless"
}

// LOCAL PLAYTEST UNTHROTTLE — two windows on one laptop. macOS paces an
// occluded window's present, and with vsync on the whole main loop blocks on
// it: the background instance SIMULATES slow, not just draws slow (the log
// receipt: two instances' session-tick counters drift ~90 ticks apart after a
// focus switch). Pace by timer instead: vsync off, fps capped so the loop
// never waits on the compositor and the laptop doesn't render at 1000fps.
unthrottle_for_local_play :: proc() {
	if running_headless() {return}
	gd.display_server_window_set_vsync_mode(gd.singleton_display_server(), .Vsync_Disabled, 0)
	gd.engine_set_max_fps(gd.singleton_engine(), 120)
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
