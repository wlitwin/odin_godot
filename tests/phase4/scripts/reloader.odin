//gd:extends Node
//gd:class Reloader
package phase4_scripts

// ----------------------------------------------------------------------------
// Reloader — the Phase 4 hot-reload subject. A Node-based script with:
//   - one @export (`position`) used as the PRESERVED state across a dll swap, and
//   - behavior (`STEP`) that differs between build v1 and v2, selected by the
//     `RELOAD_V` compile define so the SAME source can stand in for an "edit-save".
//
// v1 (default): STEP == 10 — `process` advances `position` by 10/frame, get_step()==10.
// v2 (-define:RELOAD_V=2): STEP == 100 — process advances by 100/frame, get_step()==100.
//
// The struct LAYOUT is identical across versions (only proc bodies / a constant
// change), so reload takes the same-layout fast path: struct bytes kept in place,
// desc/proc ptrs re-pointed — full state preserved.
// ----------------------------------------------------------------------------

import "core:time"
import gd "godot:godot"

RELOAD_V :: #config(RELOAD_V, 1)

when RELOAD_V == 2 {
	STEP :: 100
} else {
	STEP :: 10
}

// First field MUST be the owner Object pointer (core writes it at offset 0).
Reloader :: struct {
	owner:    gd.Node,
	position: gd.Int `gd:"export"`,
}

// Lifecycle: bumps the exported position by STEP each frame (codegen wraps this as
// the `proc "c"` process slot).
reloader_process :: proc(self: ^Reloader, delta: f64) {
	self.position += STEP
}

// Custom method: returns the compile-time STEP so GDScript can observe which build
// (v1 vs v2) is currently live after a reload.
@(gd_method)
reloader_get_step :: proc(self: ^Reloader) -> int {
	return STEP
}

// Concurrency probe: the Phase 4 harness invokes this method on a Godot Thread, then
// reloads synchronously on the main thread. The core must wait for this old-generation
// trampoline to return before it mutates descriptors or instance state.
@(gd_method)
reloader_hold_reload_reader :: proc(self: ^Reloader, milliseconds: int) {
	time.sleep(time.Duration(milliseconds) * time.Millisecond)
}

// Hot-reload hook: runs on each live instance AFTER the dll swap, with the NEW code. A real
// script rebuilds cached proc pointers here; this one just emits a marker so the harness can
// prove the `<class>_reload` lifecycle fired on the swap. (A proc, not a field — no layout
// change, so the reload still takes the same-layout fast path the rest of this test asserts.)
reloader_reload :: proc(self: ^Reloader) {
	gd.print("RELOAD_HOOK_FIRED")
}
