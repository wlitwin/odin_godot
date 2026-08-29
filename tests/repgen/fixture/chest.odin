//gd:extends Node
//gd:class Chest
package repgen_fixture

// A NON-ticking class with coop @(gd_command)s: their generated wrappers return a
// knet.Action_Outcome — state is .Applied (host accept), .Predicted (client
// in-flight), or .Rejected, while reason/seq make failures actionable without
// an is_host branch. Pawn/Turret tick and return the same shape; this pins the
// co-op path's predicting, non-predicted, and authority-only wrappers.

import gd "godot:godot"
import knet "godot:kit/net"

Chest :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	gold:   i32 `gd:"replicate"`,
	sealed: bool `gd:"replicate"`,
	claim:  u64 `gd:"replicate"`, // who claimed it — written from the ISSUER param below
	target: knet.Net_Ref(Pawn) `gd:"replicate"`, // typed entity relation stays a POD id on the wire
}

// PREDICT: the client applies optimistically, so its issue is .Predicted (held)
// or .Rejected (the local apply reverted).
@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
chest_open :: proc(self: ^Chest, amount: i32) -> bool {
	if self.gold < amount {return false}
	self.gold -= amount
	return true
}

// NON-PREDICTED + OPEN: the client never runs the predicate locally, so it
// cannot locally reject — a successful send is simply in flight (.Predicted).
@(gd_command = knet.ACTION_ANY_SEAT)
chest_seal :: proc(self: ^Chest) -> bool {
	self.sealed = true
	return true
}

// An authority-only maintenance verb remains callable through the same wrapper
// on every peer; non-authority callers receive .Rejected without sending.
@(gd_command = knet.ACTION_AUTHORITY)
chest_lockdown :: proc(self: ^Chest) -> bool {
	self.sealed = true
	return true
}

// THE ISSUER PARAM: `by: knet.Player_Id` right after the receiver is framework-
// filled — ctx.me on the issuing peer, the resolved sender on the host — and
// never rides the wire, so the predicate arbitrates on WHO without trusting a
// client-claimed argument (the spoofable-`side` wart, deleted).
@(gd_command = knet.Action_Policy {
	access = .Any_Seat,
	prediction = .Optimistic,
	max_args_bytes = 32,
})
chest_claim :: proc(self: ^Chest, by: knet.Player_Id) -> bool {
	if self.claim != 0 {return false} 	// first come — later claims reject
	self.claim = u64(by)
	return true
}

// Its consequence sees the SAME issuer, once, after `by` — no duplication.
@(gd_half)
chest_claim_then :: proc(self: ^Chest, by: knet.Player_Id) {
	_ = by
}

chest_ready :: proc(self: ^Chest) {}
