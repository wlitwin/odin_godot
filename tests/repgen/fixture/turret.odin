//gd:extends Node2D
//gd:class Turret
package repgen_fixture

// A SECOND input-driven entity KIND on the same lane — its own input struct,
// so its own wire class. board.odin samples both; a player driving a pawn AND
// a turret ships both windows each tick, and each entity's tick reads only its
// own. scriptgen sorts the input types (Pawn_Input < Turret_Input), so the
// pawn is the primary class 0 and the turret is class 1 (input_class = 1 in its
// Sim_Set, registered via lane_add_input_class).

import gd "godot:godot"

Turret :: struct {
	owner:      gd.Node2d,
	aimx, aimy: f32 `gd:"predict,interp"`
}

// Distinct from Pawn_Input (a different width, a different intent) — the whole
// point of a second class is that the two inputs never share a window.
@(gd_input)
Turret_Input :: struct {
	aim: [2]i16 `gd:"range=-1000:1000"`
}

@(gd_tick)
turret_tick :: proc(self: ^Turret, input: Turret_Input) {
	self.aimx += f32(input.aim[0])
	self.aimy += f32(input.aim[1])
}
