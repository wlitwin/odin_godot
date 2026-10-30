package scrapyard_flow

import r "godot:replay"
import v "godot:replay/view"

Actor_Cue :: struct {
	id: r.Event_Id,
	generation: u32,
	left: f32,
}

// One currently displayed cue per actor/kind. Confirm/update never replay it;
// cancellation affects only that identity, not a newer effect in the same slot.
actor_cue :: proc(cue: ^Actor_Cue, kind: v.Change_Kind, id: r.Event_Id, generation: u32, duration: f32) {
	if kind == .Cancel && cue.id == id {
		cue.left = 0
	}
	if kind == .Begin &&
	   (id.epoch > cue.id.epoch ||
			   id.epoch == cue.id.epoch &&
				   (id.tick > cue.id.tick || id.tick == cue.id.tick && generation > cue.generation)) {
		cue^ = {id, generation, duration}
	}
}
