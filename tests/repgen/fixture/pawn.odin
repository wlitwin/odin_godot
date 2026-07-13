//gd:extends Node2D
//gd:class Pawn
package repgen_fixture

// repgen fixture: exercises every gd:"replicate" shape scriptgen must handle —
// bare, with options, multi-name fields, mixing with export/plain fields — plus
// the @(gd_command) surface: predicted and host-only commands, wire-typed args
// (including knet ids), and the required `net_id` identity field.

import gd "godot:godot"
import knet "godot:kit/net"

Pawn :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id, // command wire identity (assigned by the session layer)
	hp:     i32 `gd:"replicate"`,
	x, y:   f32 `gd:"replicate,interp,owner"`, // multi-name: one desc entry per name
	rot:    gd.Quaternion `gd:"replicate,interp,owner"`, // classified to hemisphere-safe nlerp
	aim:    f32 `gd:"replicate,interp=pawn_blend_aim,owner"`, // custom blend math
	heat:   f32 `gd:"replicate,wire=f16"`, // stock half-float wire encoding
	charge: i32 `gd:"replicate,wire=pawn_charge_codec"`, // custom fixed-size codec
	state:  u8 `gd:"replicate"`,
	speed:  f64 `gd:"export,range=0:10"`, // exports and replicates coexist
	local:  int, // untagged: never replicated
}

// The custom blend `aim` names — a knet.Blend_Proc; the generated descriptor
// references it verbatim, so this consumer compile IS the signature check.
pawn_blend_aim :: proc(dst, a, b: rawptr, alpha: f32) {
	(^f32)(dst)^ = (^f32)(a)^ + ((^f32)(b)^ - (^f32)(a)^) * alpha
}

// The custom codec `charge` names — a knet.Wire_Codec: i32 charge (0..255)
// ships as one byte. Same verbatim-splice contract as the blend proc.
pawn_charge_codec :: knet.Wire_Codec {
	size   = 1,
	encode = proc(wire, field: rawptr) {(^u8)(wire)^ = u8(clamp((^i32)(field)^, 0, 255))},
	decode = proc(field, wire: rawptr) {(^i32)(field)^ = i32((^u8)(wire)^)},
}

pawn_ready :: proc(self: ^Pawn) {
	if self.hp == 0 {self.hp = 10}
}

// Predicted command: single-player-looking mutation, runs on the host AND
// optimistically on the issuing client (same proc, byte-identical args).
@(gd_command = "predict")
pawn_hit :: proc(self: ^Pawn, amount: i32) -> bool {
	if self.hp <= 0 {return false}
	self.hp -= amount
	return true
}

// Host-only command (no predict): string + id args exercise the wider wire types.
@(gd_command)
pawn_mark :: proc(self: ^Pawn, label: string, who: knet.Player_Id) -> bool {
	self.state = 1
	return true
}

// Payload verb + name-paired consequence: results after the applied bool are
// in-process facts threaded into `pawn_loot_then` — fired on the AUTHORITY
// only, with the issuer and the verb's own wire args. Entity-local shape
// (no leading game param); the game-threaded shape is proven by the examples.
@(gd_command = "predict")
pawn_loot :: proc(self: ^Pawn, slot: i32) -> (ok: bool, got: u8) {
	if self.state != 0 {return false, 0}
	self.state = 1
	return true, u8(slot)
}

pawn_loot_then :: proc(self: ^Pawn, by: knet.Player_Id, slot: i32, got: u8) {
	self.hp += i32(got) // host-side consequence — an ordinary delta carries it
}
