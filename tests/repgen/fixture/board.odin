//gd:extends Node2D
//gd:class Board
package repgen_fixture

// The GAME-ROOT side of the entity-table contract: an exported PackedScene
// field whose `entity=Name:id` tag declares what the scene bodies and its
// stable wire id. scriptgen emits PAWN_TYPE, the kboot.Entity_Kind row, and
// the typed dispatch for the name-paired census hooks below.

import gd "godot:godot"
import knet "godot:kit/net"

Board :: struct {
	owner:      gd.Node2d,
	pawn_scene: ^gd.Resource `gd:"export,resource=PackedScene,entity=Pawn:7"`,
}

// The census hooks — typed, fired by the kboot driver (spawn-time fields are
// not set yet; presentation waits for Ev_Spawned).
pawn_spawned :: proc(game: ^Board, self: ^Pawn, id: knet.Net_Id, owner: knet.Player_Id) {
}

pawn_freed :: proc(game: ^Board, self: ^Pawn, id: knet.Net_Id) {
}

board_ready :: proc(self: ^Board) {
}
