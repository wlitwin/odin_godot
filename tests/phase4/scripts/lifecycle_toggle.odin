//gd:extends Node
//gd:class LifecycleToggle
package phase4_scripts

// v1 of the lifecycle transition fixture. rebuild_v2.sh temporarily replaces this
// source with fixtures/lifecycle_toggle_v2.odin while the Godot process is live.

import gd "godot:godot"

LifecycleToggle :: struct {
	owner:         gd.Node,
	process_ticks: gd.Int `gd:"export"`,
	physics_ticks: gd.Int `gd:"export"`,
}

lifecycle_toggle_physics_process :: proc(self: ^LifecycleToggle, delta: f64) {
	self.physics_ticks += 1
}

@(gd_method)
lifecycle_toggle_get_mode :: proc(self: ^LifecycleToggle) -> int {
	return 1 // v1: physics only
}
