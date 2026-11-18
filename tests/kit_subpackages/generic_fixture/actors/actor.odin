//gd:extends Node
package generic_actors

import gd "godot:godot"
import knet "godot:kit/net"
import c "../containers"
import v "../values"

Local_Type :: v.Local_Type
Local_Event :: union { v.Local_Type, i32 }

Actor :: struct {
    owner: gd.Node,
    net_id: knet.Net_Id,
    value: i32 `gd:"predict"`,
    block: c.Wrap(Local_Type),
    signals: c.Signals(i32),
    events: c.Event_Queue(Local_Event),
}

@(gd_tick)
actor_tick :: proc(self: ^Actor, input: c.Envelope(Local_Type, 2)) {
    self.value = input.body.items[0].axis
}
