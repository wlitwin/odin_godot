package schema_game

import knet "godot:kit/net"
import data "packets"
import routes "tags"

@(gd_message = "routes.PING")
game_ping :: proc(self: ^Game, from: knet.Player_Id, msg: data.Payload) { self.received += i64(msg.value) }
