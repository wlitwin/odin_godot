//gd:extends Node2D
//gd:class Pawn
package repgen_fixture

// repgen fixture: exercises every gd:"replicate" shape scriptgen must handle —
// bare, with options, multi-name fields, and mixing with export/plain fields.

import gd "godot:godot"

Pawn :: struct {
	owner: gd.Node2d,
	hp:    i32 `gd:"replicate"`,
	x, y:  f32 `gd:"replicate,interp,owner"`, // multi-name: one desc entry per name
	state: u8 `gd:"replicate"`,
	speed: f64 `gd:"export,range=0:10"`, // exports and replicates coexist
	local: int, // untagged: never replicated
}

pawn_ready :: proc(self: ^Pawn) {
	if self.hp == 0 {self.hp = 10}
}
