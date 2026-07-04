//gd:extends Node
//gd:class Orb
package kitacid_scripts

// ----------------------------------------------------------------------------
// THE ACID-TEST ENTITY — this file is the ENTIRE author surface for a new
// multiplayer entity. No role branches, no wire code, no spawn or prediction
// bookkeeping: tag the replicated fields, declare a net_id, and write commands
// as single-player-looking mutations. Prediction, revert, reject-truth, delta
// batching, and the observer's view all come from generated code + the session
// node (session.odin) — the acid test proves THIS is all a game needs to write.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import knet "godot:kit/net"

Orb :: struct {
	owner:   gd.Node,
	net_id:  knet.Net_Id, // wire identity (the session assigns it at spawn)
	hp:      i32 `gd:"replicate"`,
	stamina: i32 `gd:"replicate"`,
}

// Spend stamina to strike: authoritative on the host, predicted on the issuing
// client, replicated to everyone else — the SAME proc everywhere.
@(gd_command = "predict")
orb_strike :: proc(self: ^Orb, cost: i32) -> bool {
	if self.stamina < cost {return false}
	self.stamina -= cost
	self.hp -= cost * 2
	return true
}
