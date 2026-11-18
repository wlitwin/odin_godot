//gd:extends Node
//gd:class BindingActor
package binding_test

import gd "godot:godot"
import knet "godot:kit/net"
import meter "blocks"

BindingActor :: struct {
    owner: gd.Node,
    net_id: knet.Net_Id,
    value: i32 `gd:"replicate"`,
    using counter: meter.Counter,
}

@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
binding_actor_add :: proc(self: ^BindingActor, amount: i32) -> bool {
    self.value += amount
    return amount >= 0
}

@(gd_half)
binding_actor_add_then :: proc(game: ^Binding_Game, self: ^BindingActor, by: knet.Player_Id, amount: i32) {
    game.defaults += 1
}
