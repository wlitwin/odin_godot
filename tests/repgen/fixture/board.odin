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
	owner:      gd.Node2d,
	boot:       kboot.Boot, // declares the four standard transport forwards
	pawn_scene: ^gd.Resource `gd:"export,resource=PackedScene,entity=Pawn:7"`,
}

// Hand-written wins, name by name: this suppresses the generated on_net_down
// (the other three forwards still generate).
@(gd_method)
board_on_net_down :: proc(self: ^Board) {
}

// The census hooks — typed, fired by the kboot driver (spawn-time fields are
// not set yet; presentation waits for Ev_Spawned).
pawn_spawned :: proc(game: ^Board, self: ^Pawn, id: knet.Net_Id, owner: knet.Player_Id) {
}

pawn_freed :: proc(game: ^Board, self: ^Pawn, id: knet.Net_Id) {
}

// The lane's GAME half — typed device read + authority world pass; scriptgen
// emits the rawptr thunks and `board_lane_init` (input size from Pawn_Input,
// the step's role gate from the attribute token).
@(gd_sample)
board_sample :: proc(self: ^Board, tick: u64, input: ^Pawn_Input) {
}

@(gd_step = "authority")
board_step :: proc(self: ^Board, tick: u64) {
}

board_ready :: proc(self: ^Board) {
}
