//gd:extends Node2D
//gd:class Board
package repgen_fixture

// The GAME-ROOT side of the entity-table contract: an exported PackedScene
// field whose `entity=Name:id` tag declares what the scene bodies and its
// stable wire id. scriptgen emits PAWN_TYPE, the kboot.Entity_Kind row, and
// the typed dispatch for the name-paired census hooks below.

import gd "godot:godot"
import kboot "godot:kit/boot"
import knet "godot:kit/net"

Board :: struct {
	owner:       gd.Node2d,
	boot:        kboot.Boot, // declares the four standard transport forwards
	// The pawn is a SEAT'S BODY (`avatar`): a host takeover parks it with its
	// seat instead of adopting it — the knob rides the tag, onto the kinds row.
	pawn_scene:  ^gd.Resource `gd:"entity=Pawn:7,avatar"`,
	// A NON-ticking tagged entity beside the ticking pawn: its typed spawn
	// helper takes the host-asserted coop route (pawn's routes through
	// boot_fire_spawn — a client's call predicts). Its owner stream is
	// DECLARED at 20 Hz (`stream_hz=`), so every spawn of the kind — on every
	// peer, the heir's rebuild included — carries the rate; an export spec may
	// still trail behind the entity's own tokens.
	chest_scene: ^gd.Resource `gd:"entity=Chest:8,stream_hz=20,group=Loot"`,
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

// Frame-safe on both local sample scratch and received packet bytes: clamp is
// sanitization, false is admission refusal. The bare `validate` token pairs
// this `<sample>_validate` name automatically.
board_sample_validate :: proc(self: ^Board, input: ^Pawn_Input) -> bool {
	_ = self
	input.move[0] = clamp(input.move[0], -1, 1)
	input.move[1] = clamp(input.move[1], -1, 1)
	return input.buttons & 0xf0 == 0
}

// The SECOND input class's device read — one @(gd_sample) per input TYPE. This
// fills the turret's input; resolve_sim matches it to Turret's class by the
// struct it writes, and board_lane_init registers it with lane_add_input_class.
@(gd_sample = "validate=board_turret_input_validate")
board_sample_turret :: proc(self: ^Board, tick: u64, input: ^Turret_Input) {
}

board_turret_input_validate :: proc(self: ^Board, input: ^Turret_Input) -> bool {
	_ = self
	return input.aim[0] >= -1000 && input.aim[0] <= 1000 &&
	       input.aim[1] >= -1000 && input.aim[1] <= 1000
}

// Everywhere: runs live and in every resim, on every peer (pure-sim contact).
@(gd_step)
board_contact :: proc(self: ^Board, tick: u64) {
}

// Authority: the host alone, once per real tick (adjudication, respawns).
@(gd_step = "authority")
board_step :: proc(self: ^Board, tick: u64) {
}

// Declared WORLD-PASS facts (@(gd_fact)): the author writes the presentation
// half (`<event>_fx`, mine-form); scriptgen generates the announce door under
// the bare event name, holding every gate. ANCHORED on the pawn — its tracked
// owner derives `mine`, watchers fire on the watch clock, its despawn drops
// late facts:
@(gd_fact)
pawn_bumped_fx :: proc(g: ^Board, p: ^Pawn, mine: bool, force: f32) {
}

// ...and ANCHORLESS — a world fact: the authority's own simulation is the
// causer (mine=true on its screen alone); every client presents at the watch
// clock with no entity.
@(gd_fact)
board_horn_fx :: proc(g: ^Board, mine: bool, side: u8) {
}

board_ready :: proc(self: ^Board) {
}
