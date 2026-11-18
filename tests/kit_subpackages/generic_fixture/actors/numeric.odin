//gd:extends Node
package generic_actors

import gd "godot:godot"
import knet "godot:kit/net"
import values "../values"

Numeric :: struct {
    owner: gd.Node,
    net_id: knet.Net_Id,
    value: i16 `gd:"predict"`,
}

@(gd_tick)
numeric_tick :: proc(self: ^Numeric, input: values.Sample_Input) {
    self.value = input.move[0]
}
