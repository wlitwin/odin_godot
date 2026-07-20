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
import "core:fmt"

Orb :: struct {
	owner:   gd.Node,
	net_id:  knet.Net_Id, // wire identity (the session assigns it at spawn)
	hp:      i32 `gd:"replicate"`,
	stamina: i32 `gd:"replicate"`,
	x, y:    f32 `gd:"owner,interp"`, // owner-streamed: write them, they replicate
}

// Spend stamina to strike: authoritative on the host, predicted on the issuing
// client, replicated to everyone else — the SAME proc everywhere. Results after
// the applied bool are the verb's PAYLOAD: in-process facts handed to the
// consequence below, never wire bytes.
@(gd_command = "predict")
orb_strike :: proc(self: ^Orb, cost: i32) -> (ok: bool, dealt: i32) {
	if self.stamina < cost {return false, 0}
	self.stamina -= cost
	self.hp -= cost * 2
	return true, cost * 2
}

// The strike's consequence — the name-paired, typed "and then…": fires ONCE,
// on the AUTHORITY, after the verb applies, with the issuer + wire args +
// payload. Predictions, replays, rejections, and retransmits never reach it —
// the acid greps exactly two ACID_THEN lines on the server and ZERO on the
// clients, under injected latency.
orb_strike_then :: proc(self: ^Orb, by: knet.Player_Id, cost: i32, dealt: i32) {
	gd.print_str(fmt.tprintf("ACID_THEN cost=%d dealt=%d hp=%d by_ok=%v", cost, dealt, self.hp, by != knet.PLAYER_ID_INVALID))
}
