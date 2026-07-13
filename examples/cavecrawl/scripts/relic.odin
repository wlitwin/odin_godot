//gd:extends Node2D
//gd:class Relic
package cavecrawl_scripts

// The CARRYABLE — the ownership-transfer pattern in its smallest form. The
// relic's position is OWNER-STREAMED: whoever holds it, their writes are
// what everyone else's screen follows, with the same interpolation that
// smooths the players themselves. Grab and drop are ordinary predicted
// commands whose cross-entity half (the actual handoff) is one
// session_set_owner call in each verb's `_then` consequence below; every
// peer hears Ev_Owner_Changed and the new carrier starts gluing it to their
// avatar — role-free, like everything else. Carrying, mounts, possession,
// dragging a downed friend: all this pattern with different glue.
// The body is entities/relic.tscn.

import gd "godot:godot"
import kinter "godot:kit/interact"
import knet "godot:kit/net"
import ksess "godot:kit/session"

Relic :: struct {
	owner:  gd.Node2d,
	glyph:  gd.Label `gd:"onready=Glyph"`,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"replicate,interp,owner,wire=f16"`,
}

// Take it (only meaningful while it rests — the consequence checks the
// current owner; racing grabbers both predict, the host's arrival order
// decides).
@(gd_command = "predict")
relic_grab :: proc(self: ^Relic, px: f32, py: f32) -> bool {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false}
	return true
}

// THE HANDOFF ITSELF, host only: first-come — a later grab finds it carried
// and does nothing (the verb mutates nothing replicated, so the loser's
// accepted grab is a harmless no-op).
relic_grab_then :: proc(game: ^CaveLobby, self: ^Relic, by: knet.Player_Id, px: f32, py: f32) {
	if ksess.session_owner_of(&game.ses, self.net_id) == knet.PLAYER_ID_INVALID {
		ksess.session_set_owner(&game.ses, self.net_id, by)
	}
}

// Set it down where the carrier stands. Only the carrier may — the
// consequence compares issuer to owner; the proc itself mutates nothing
// replicated.
@(gd_command)
relic_drop :: proc(self: ^Relic) -> bool {
	return true
}

relic_drop_then :: proc(game: ^CaveLobby, self: ^Relic, by: knet.Player_Id) {
	if ksess.session_owner_of(&game.ses, self.net_id) == by {
		ksess.session_set_owner(&game.ses, self.net_id, knet.PLAYER_ID_INVALID)
	}
}

relic_process :: proc(self: ^Relic, delta: f64) {
	gd.node2d_set_position(self.owner, {self.x, self.y})
}
