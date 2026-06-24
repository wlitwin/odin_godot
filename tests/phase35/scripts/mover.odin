//gd:extends Node2D
//gd:class Mover
package phase35_scripts

// Mover — a Node2D-based script exercising the `process` lifecycle wrapper codegen
// (plain `proc(self, delta)` -> the `proc "c"` slot) plus a Node2D base. Each frame
// it bumps an exported tick counter, proving compiled per-frame dispatch.

import gd "godot:godot"

Mover :: struct {
	owner: gd.Node2d,
	ticks: gd.Int `gd:"export"`,
}

mover_process :: proc(self: ^Mover, delta: f64) {
	self.ticks += 1
}
