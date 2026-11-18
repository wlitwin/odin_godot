//gd:extends Node
package callback_actors

import gd "godot:godot"
import knet "godot:kit/net"

@(private)
@(gd_input)
Private_Input :: struct { move: i32 `gd:"range=-1:1"` }

Walker :: struct {
    owner: gd.Node,
    net_id: knet.Net_Id,
    value: i32 `gd:"predict"`,
    score: i32 `gd:"replicate"`,
}

@(private)
@(gd_tick)
walker_tick :: proc(self: ^Walker, input: Private_Input) -> (bool, i32) {
    self.value += input.move
    return true, self.value
}

@(private)
@(gd_command)
walker_push :: proc(self: ^Walker, amount: i32) -> (bool, i32) {
    self.score += amount
    return amount >= 0, amount
}

@(private)
@(gd_half)
walker_push_apply :: proc(self: ^Walker, amount: i32) { self.value += amount }
