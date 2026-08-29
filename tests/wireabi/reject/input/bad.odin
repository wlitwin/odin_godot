//gd:extends Node
//gd:class BadInputWire
package bad_input_wire

import gd "godot:godot"
import knet "godot:kit/net"

Bad_Input :: struct {
	count: int,
}

BadInputWire :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	x:      f32 `gd:"predict"`,
}

@(gd_tick)
bad_input_wire_tick :: proc(self: ^BadInputWire, input: Bad_Input) {
	_ = self
	_ = input
}
