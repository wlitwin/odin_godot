//gd:extends Node
//gd:class BadMessageWire
package bad_message_wire

import gd "godot:godot"
import knet "godot:kit/net"

TAG_BAD_MESSAGE :: u8(4)

Bad_Message :: struct {
	text: string,
}

BadMessageWire :: struct {
	owner: gd.Node,
}

@(gd_message = "TAG_BAD_MESSAGE")
bad_message_wire_receive :: proc(self: ^BadMessageWire, from: knet.Player_Id, msg: Bad_Message) {
	_ = self
	_ = from
	_ = msg
}
