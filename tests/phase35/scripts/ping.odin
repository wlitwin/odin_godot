//gd:extends Node
//gd:class Ping
//gd:signal pinged(value: int)
package phase35_scripts

// ----------------------------------------------------------------------------
// Ping — the Phase 3.5 CODEGEN-FORM showcase. This is the *nice* authoring form:
// a struct with tagged exports, plain typed lifecycle/method procs, and `//gd:`
// markers. scriptgen reads this and emits `ping.gen.odin` with the verbose Phase-3
// registration (trampolines + backing arrays + `@(init) rt.register(...)`).
//
// Compare against the HAND-WRITTEN showcase/ping.odin — the generated output
// registers an identical Class_Desc.
// ----------------------------------------------------------------------------

import gd "godot:godot"

// First field MUST be the owner Object pointer (core writes it at offset 0).
// Tagged fields become @export vars; untagged fields are private instance state.
Ping :: struct {
	owner: gd.Node,
	speed: f32   `gd:"export"`,
	count: gd.Int `gd:"export"`,
}

// Lifecycle by proc name (the `ping_` struct prefix is stripped -> `ready`), bound
// by the `^Ping` receiver. Plain proc; codegen wraps it as the `proc "c"` slot.
ping_ready :: proc(self: ^Ping) {
	if self.speed == 0 {self.speed = 1.5}
}

// Custom methods: `@(gd_method)`, callable from GDScript. The exposed name is the
// proc name minus the struct prefix (`ping_add` -> `add`). Codegen generates the
// Variant trampoline from this typed signature.
@(gd_method)
ping_add :: proc(self: ^Ping, a, b: int) -> int {
	return a + b
}

@(gd_method)
ping_addf :: proc(self: ^Ping, a, b: f64) -> f64 {
	return a + b
}

@(gd_method)
ping_get_speed :: proc(self: ^Ping) -> f64 {
	return f64(self.speed)
}

@(gd_method)
ping_emit_ping :: proc(self: ^Ping, value: int) {
	self.count += gd.Int(value)
	// `ping_emit_<signal>` is generated from the //gd:signal marker.
	ping_emit_pinged(self, i64(value))
}
