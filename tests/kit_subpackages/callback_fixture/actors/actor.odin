//gd:extends Node
package callback_actors

import gd "godot:godot"
import knet "godot:kit/net"

Actor :: struct {
    owner: gd.Node,
    net_id: knet.Net_Id,
    value: i32 `gd:"replicate"`,
    counter: Counter(i32),
    local_calls: i32,
}

@(private)
@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
actor_add :: proc(self: ^Actor, amount: i32) -> (bool, i32) {
    self.value += amount
    return amount >= 0, amount * 2
}

@(gd_half)
actor_add_then :: proc(self: ^Actor, by: knet.Player_Id, amount, payload: i32) { self.local_calls += 1 }
