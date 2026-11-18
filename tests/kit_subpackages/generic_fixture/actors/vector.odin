//gd:extends Node
package generic_actors

import gd "godot:godot"
import knet "godot:kit/net"
import values "../values"

VectorActor :: struct {
    owner: gd.Node,
    net_id: knet.Net_Id,
    value: [2]f32 `gd:"predict"`,
}

@(gd_tick)
vector_actor_tick :: proc(self: ^VectorActor, input: values.Vector_Input) { self.value = input.move }
