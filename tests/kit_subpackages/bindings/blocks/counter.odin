package local_counter

import gd "godot:godot"
import knet "godot:kit/net"

Counter :: struct {
    score: i32 `gd:"replicate"`,
}

@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
counter_add :: proc(self: ^Counter, amount: i32) -> bool {
    self.score += amount
    return true
}

@(gd_method)
counter_read :: proc(self: ^Counter) -> gd.Int {
    return gd.Int(self.score)
}
