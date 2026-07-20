//gd:extends Node2D
//gd:class Pawn
package repgen_fixture

// repgen fixture: exercises every gd:"replicate" shape scriptgen must handle —
// bare, with options, multi-name fields, mixing with export/plain fields — plus
// the @(gd_command) surface: predicted and host-only commands, wire-typed args
// (including knet ids), and the required `net_id` identity field.

import gd "godot:godot"
import knet "godot:kit/net"
import ksim "godot:kit/sim"
import psim "godot:play/sim"

Pawn :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id, // command wire identity (assigned by the session layer)
	hp:     i32 `gd:"replicate"`,
	x, y:   f32 `gd:"owner,interp"`, // multi-name: one desc entry per name
	rot:    gd.Quaternion `gd:"owner,interp"`, // classified to hemisphere-safe nlerp
	aim:    f32 `gd:"owner,interp=pawn_blend_aim"`, // custom blend math
	heat:   f32 `gd:"replicate,wire=f16"`, // stock half-float wire encoding
	charge: i32 `gd:"replicate,wire=pawn_charge_codec"`, // custom fixed-size codec
	px, py: f32 `gd:"predict,interp,slack=0.5,glide=0.1,cut=32"`, // kit/sim: per-field reconcile slack + render-error glide/cut
	fuel:   u16 `gd:"predict"`, // predicted without interp: steps, never lerps
	pace:   Pace, // TICK-COMPOSITION: the block's step hoists, runs after pawn_tick
	chill:  psim.Cool, // IMPORTED-shelf tick block: the hoist crosses packages
	warm:   psim.Cool `gd:"manual"`, // MANUAL: predict field still flattens, but the tick is NOT hoisted (the wielder drives it)
	state:  u8 `gd:"replicate"`,
	speed:  f64 `gd:"export,range=0:10"`, // exports and replicates coexist
	local:  int, // untagged: never replicated
	// gd:"backup" — host-local migration/save state, all three kinds; the nested
	// one (pace.beat) proves the walk rides `using`/embeds like replicate does.
	save_seed: u32 `gd:"backup"`, // Pod: write_pod whole
	save_seen: map[knet.Net_Id]u16 `gd:"backup"`, // Map[POD]POD: length + key/value loop
	save_log:  [dynamic]u8 `gd:"backup"`, // [dynamic]POD: length + element loop
}

// The custom blend `aim` names — a knet.Blend_Proc; the generated descriptor
// references it verbatim, so this consumer compile IS the signature check.
pawn_blend_aim :: proc(dst, a, b: rawptr, alpha: f32) {
	(^f32)(dst)^ = (^f32)(a)^ + ((^f32)(b)^ - (^f32)(a)^) * alpha
}

// The sim-lane surface: a POD input struct (discovered from the tick proc's
// signature — no tag) and the @(gd_tick) step, full shape (input + lane).
Pawn_Input :: struct {
	move:    [2]i8,
	buttons: u8,
}

@(gd_tick)
pawn_tick :: proc(self: ^Pawn, input: Pawn_Input, lane: ^ksim.Lane) -> (dashed: bool) {
	self.px += f32(input.move[0])
	self.py += f32(input.move[1])
	if input.buttons != 0 && self.fuel > 0 {
		self.fuel -= 1
		dashed = true
	}
	_ = lane
	return
}

// A tick BLOCK: inputless by contract (intent flows through fields the
// wielder's tick writes), hoisted to run after the entity's own step.
Pace :: struct {
	heat: u16 `gd:"predict"`,
	beat: u32 `gd:"backup"`, // NESTED gd:"backup": collected onto Pawn as self.pace.beat
}

@(gd_tick)
pace_tick :: proc(p: ^Pace) {
	if p.heat > 0 {
		p.heat -= 1
	}
}

// The tick's name-paired halves (self-first shapes; quickdraw exercises the
// game-first ones): the consequence on the authority, the fx on the owning
// peer's live pass — the generated thunk holds the role gates.
pawn_tick_then :: proc(self: ^Pawn, by: knet.Player_Id, dashed: bool) {
	if dashed && self.hp > 1 {
		self.hp -= 1
	}
	_ = by
}

pawn_tick_fx :: proc(self: ^Pawn, dashed: bool) {
	_ = dashed
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

// The verb's PREDICTED-EFFECT half (sim-lane verbs only): resims re-run it
// with the ledgered wire args — relative effects stay exact. The verb above
// keeps the predicate and the delta-lane write, execute-once.
pawn_hit_apply :: proc(self: ^Pawn, amount: i32) {
	self.px += f32(amount) // knockback: relative, the patch can't express it
}

// Host-only command (no predict): string + id args exercise the wider wire types.
// `who` is a player the verb TARGETS — ordinary wire data, legal under any name
// but the reserved `by`.
@(gd_command)
pawn_mark :: proc(self: ^Pawn, label: string, who: knet.Player_Id) -> bool {
	self.state = 1
	return true
}

// The ISSUER param on a SIM-lane verb: `by` is the seat the lane resolved (me
// speculating, the ledgered seat on the host), spliced before the wire args.
@(gd_command)
pawn_salute :: proc(self: ^Pawn, by: knet.Player_Id, style: u8) -> bool {
	if style == 0 {return false}
	self.state = style
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

// The hp EDGE half — delta-lane change presentation, proc-as-subscription:
// the name pairs it to the field, the session's per-frame pass fires it with
// the net (old, new) — no seen_* mirror, no resync re-seed to forget.
pawn_hp_edge :: proc(self: ^Pawn, old, new: i32) {
	_ = old
	_ = new
}
