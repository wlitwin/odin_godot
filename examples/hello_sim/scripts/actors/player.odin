//gd:extends Node2D
//gd:class Player
package hello_sim_entities

// hello_net's Player, PROMOTED to the server-authority sim lane. The diff
// from the coop file is the promotion checklist (sim.md) in miniature:
//   step 2 — the retag: `owner` (auto-interpolated) became `predict,interp`
//            (the field's writer is now the server's simulation, predicted
//            locally — that one word is the whole wire migration);
//   step 3 — the writes moved out of the frame loop into @(gd_tick): a pure
//            fixed-rate step (predicted fields, input) -> predicted fields;
//   step 4 — what the frame loop used to read off the devices became the
//            Player_Input struct (sampled and validated in hello.odin's
//            @(gd_sample)).
// Everything else — typed birth, the paint, the scene — carries over from
// hello_net unchanged in shape.

import gd "godot:godot"
import knet "godot:kit/net"

@(gd_input)

Player_Input :: struct {
    move: [2]i8 `gd:"range=-1:1"`,
}

Player :: struct {
    owner:  gd.Node2d,
    skin:   gd.Polygon2d `gd:"onready=Skin"`,
    net_id: knet.Net_Id,
    x, y:   f32 `gd:"predict,interp"`,
    pid:    u8 `gd:"replicate"`, // delta lane, untouched by the promotion
}

STEP :: f32(160.0 / 60.0) // px per tick at the lane's 60 Hz

// The simulation — runs on the authority for truth, on the owner as
// prediction, and inside every resim. Pure by contract: fields + input in,
// fields out. Mispredictions reconcile and glide without a line here.
@(gd_tick)
player_tick :: proc(self: ^Player, input: Player_Input) {
    self.x = clamp(self.x + f32(input.move[0]) * STEP, 8, 632)
    self.y = clamp(self.y + f32(input.move[1]) * STEP, 8, 352)
}

player_process :: proc(self: ^Player, delta: f64) {
    _ = delta

    // Fields are presentation truth here (the lane smooths corrections and
    // renders watched squares on the delayed clock) — the node just shows them.
    gd.node2d_set_position(cast(gd.Node2d)self.owner, {self.x, self.y})
}
