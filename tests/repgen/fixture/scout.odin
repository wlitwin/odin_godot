//gd:extends Node2D
//gd:class Scout
package repgen_fixture

// repgen fixture: the EVERY-SCREEN presentation half — an `_fx` declaring
// `mine: bool` after `self`. The generated thunk must gate on the bool facts
// (the event trigger), broadcast the tuple from the authority (lane_fact),
// fire the half inline where this screen's live pass simulated it, and emit
// the decode thunk + `fx =` Sim_Set wiring for watchers (fired by the lane
// when the watch clock reaches the fact's tick).

import gd "godot:godot"

Scout :: struct {
	owner: gd.Node2d,
	x:     f32 `gd:"predict,interp"`,
	beep:  u16 `gd:"predict"`,
}

@(gd_tick)
scout_tick :: proc(self: ^Scout) -> (pinged: bool, dist: f32) {
	self.x += 1
	if self.beep > 0 {
		self.beep -= 1
	} else {
		self.beep = 60
		pinged = true
		dist = self.x
	}
	return
}

// The every-screen shape: `mine` right after `self` (by NAME — a bool fact
// can never silently shift into the slot). Facts are wire primitives here by
// contract: they cross to watching screens.
@(gd_half)
scout_tick_fx :: proc(self: ^Scout, mine: bool, pinged: bool, dist: f32) {
	_ = mine
	_ = pinged
	_ = dist
}
