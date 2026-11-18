package hello_net

import gd "godot:godot"
import knet "godot:kit/net"
import actors "actors"

// The fields are initialized on every peer at BORN. _ready and _spawned
// happen earlier, while the node still has its scene defaults. Place and
// color it here so its first rendered frame already shows the right player.
@(gd_half)
player_born :: proc(game: ^HelloNet, self: ^actors.Player, id: knet.Net_Id, owner: knet.Player_Id) {
    _ = id
    _ = owner
    hues := [4]gd.Color{{0.9, 0.5, 0.2, 1}, {0.3, 0.7, 0.9, 1}, {0.5, 0.9, 0.4, 1}, {0.9, 0.4, 0.7, 1}}
    gd.polygon2d_set_color(self.skin, hues[int(self.pid) % 4])
    gd.node2d_set_position(cast(gd.Node2d)self.owner, {self.x, self.y})
    gd.set_bool(cast(gd.Object)game.boot.ui.root, "visible", false)
}
