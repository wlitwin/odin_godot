//gd:extends Node2D
//gd:class Board
package repgen_fixture

// The GAME-ROOT side of the entity-table contract: an exported PackedScene
// field whose `entity=Name:id` tag declares what the scene bodies and its
// stable wire id. scriptgen emits PAWN_TYPE, the kboot.Entity_Kind row, and
// the typed dispatch for the name-paired census hooks below.

import gd "godot:godot"
import kboot "godot:kit/boot"
import kcomms "godot:kit/comms"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import ksim "godot:kit/sim"

Board :: struct {
	owner:       gd.Node2d,
	boot:        kboot.Boot, // with the three fields below: generated net facade
	ses:         ksess.Session,
	comms:       kcomms.Comms,
	lane:        ksim.Lane,
	// The pawn is a SEAT'S BODY (`avatar`): a host takeover parks it with its
	// seat instead of adopting it — the knob rides the tag, onto the kinds row.
	pawn_scene:  ^gd.Resource `gd:"entity=Pawn:7,avatar"`,
	// A NON-ticking tagged entity beside the ticking pawn: its typed spawn
	// helper takes the host-asserted coop route (pawn's routes through
	// boot_fire_spawn — a client's call predicts). Its owner stream is
	// DECLARED at 20 Hz (`stream_hz=`), so every spawn of the kind — on every
	// peer, the heir's rebuild included — carries the rate; an export spec may
	// still trail behind the entity's own tokens.
	chest_scene: ^gd.Resource `gd:"entity=Chest:8,stream_hz=20,group=Loot"`
}

// Hand-written wins, name by name: this suppresses the generated on_net_down
// (the other three forwards still generate).
@(gd_method)
board_on_net_down :: proc(self: ^Board) {
}

// The census hooks — typed, fired by the kboot driver (spawn-time fields are
// not set yet; presentation waits for Ev_Spawned).
@(gd_half)
pawn_spawned :: proc(game: ^Board, self: ^Pawn, id: knet.Net_Id, owner: knet.Player_Id) {
}

@(gd_half)
pawn_freed :: proc(game: ^Board, self: ^Pawn, id: knet.Net_Id) {
}

// The BORN moment, typed: Ev_Spawned's arm in the generated board_events
// resolves the pawn through the census and calls this with the fields SET —
// the dress that used to be a type-switch in an untyped entity_spawned half.
@(gd_half)
pawn_born :: proc(game: ^Board, self: ^Pawn, id: knet.Net_Id, owner: knet.Player_Id) {
	_ = game; _ = self; _ = id; _ = owner
}

// MY avatar-kind entity (the pawn — `avatar` on its tag) was born: my spawn,
// my drop-in, my reconnect reclaiming its standing body.
@(gd_half)
board_embodied :: proc(self: ^Board, id: knet.Net_Id) {
	_ = self; _ = id
}


// The lane's GAME half — typed device read + up to TWO world passes; scriptgen
// emits the rawptr thunks and `board_lane_init` (input size from Pawn_Input,
// each pass wired to its slot from the attribute token). Both passes here:
// the everywhere contact pass and the host-only adjudication pass.
@(gd_sample = "validate")
board_sample :: proc(self: ^Board, tick: u64, input: ^Pawn_Input) {
}

// Generated field constraints run first. This optional hook remains for
// cross-field/game predicates; the bare `validate` token pairs the name.
board_sample_validate :: proc(self: ^Board, input: ^Pawn_Input) -> bool {
	_ = self
	return input.trigger == 0 || input.buttons != 0
}

// The SECOND input class's device read — one @(gd_sample) per input TYPE. This
// fills the turret's input; resolve_sim matches it to Turret's class by the
// struct it writes, and board_lane_init registers it with lane_add_input_class.
@(gd_sample)
board_sample_turret :: proc(self: ^Board, tick: u64, input: ^Turret_Input) {
}

// Everywhere: runs live and in every resim, on every peer (pure-sim contact).
@(gd_step)
board_contact :: proc(self: ^Board, tick: u64) {
}

// Authority: the host alone, once per real tick (adjudication, respawns).
@(gd_step = "authority")
board_step :: proc(self: ^Board, tick: u64) {
}

// Declared presentation cue: one entity parameter makes the anchor unambiguous,
// so the author does not name it in the attribute. The generated bare door
// holds every network/timeline gate.
@(gd_cue)
pawn_bumped_fx :: proc(g: ^Board, p: ^Pawn, mine: bool, force: f32) {
}

// With several entity parameters, the attribute names the PARAMETER that owns
// the presentation timeline. The other pointer crosses the wire as its Net_Id
// and is resolved before the cue is presented.
@(gd_cue = "anchor=scout")
pawn_spotted_fx :: proc(g: ^Board, p: ^Pawn, scout: ^Scout, mine: bool, strength: u8) {
}

// `anchor=none` deliberately chooses the authority/world clock even though a
// typed entity is part of the presentation. Its pointer is still sent safely
// as a stable Net_Id and resolved on each peer.
@(gd_cue = "anchor=none")
pawn_echoed_fx :: proc(g: ^Board, p: ^Pawn, mine: bool) {
}

// The old spelling remains source- and wire-compatible. No entity parameters
// means an anchorless world cue: the authority is the local causer.
@(gd_fact)
board_horn_fx :: proc(g: ^Board, mine: bool, side: u8) {
}

board_ready :: proc(self: ^Board) {
}

// Compile-time exercise for the generated census surface: both overloads
// resolve to the same typed pointer, and iteration promotes ref.id onto the
// row while carrying owner + entity without a second lookup.
census_typecheck :: proc(self: ^Board, id: knet.Net_Id) {
	ref := pawn_ref(id)
	if pawn, ok := pawn_of(&self.boot, ref); ok {
		_ = pawn
	}
	if pawn, ok := pawn_of(&self.boot, id); ok {
		_ = pawn
	}
	for tracked in pawn_all(&self.boot) {
		_ = tracked.id
		_ = tracked.owner
		_ = tracked.entity
	}
}
