package callback_actors

import knet "godot:kit/net"

Counter :: struct($T: typeid) { value: T `gd:"replicate"` }
@(private)
Payload :: struct($T: typeid) { value: T }

@(private)
@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
counter_gain :: proc(self: ^Counter($T), amount: i32) -> (bool, Payload(T)) {
    self.value += T(amount)
    return true, {self.value}
}
