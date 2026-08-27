//gd:extends Node
//gd:class LifecycleToggle
package phase4_scripts

// v2 keeps the same struct layout but removes `_physics_process` and adds `_process`.

import gd "godot:godot"

LifecycleToggle :: struct {
	owner:         gd.Node,
	process_ticks: gd.Int `gd:"export"`,
	physics_ticks: gd.Int `gd:"export"`,
}

lifecycle_toggle_process :: proc(self: ^LifecycleToggle, delta: f64) {
	self.process_ticks += 1
}

@(gd_method)
lifecycle_toggle_get_mode :: proc(self: ^LifecycleToggle) -> int {
	return 2 // v2: process only
}
