//gd:extends Node2D
//gd:class Player
package hello_net_entities

// ONE PLAYER'S SQUARE. The struct is the whole netcode: x/y are
// owner-streamed (this peer writes its own; every other screen interpolates
// them), pid rides the host's reliable delta lane. The proc just paints —
// there is nothing else to write.

import gd "godot:godot"
import knet "godot:kit/net"

Player :: struct {
    owner:  gd.Node2d,
    skin:   gd.Polygon2d `gd:"onready=Skin"`,
    net_id: knet.Net_Id,
    x, y:   f32 `gd:"owner,wire=f16"`,
    pid:    u8 `gd:"replicate"`, // the seat this square belongs to (its color)
}

player_process :: proc(self: ^Player, delta: f64) {
    _ = delta

    // Mine or not, the node shows the fields: my writes land instantly, a
    // remote square's fields are the interpolated stream.
    gd.node2d_set_position(cast(gd.Node2d)self.owner, {self.x, self.y})
}
