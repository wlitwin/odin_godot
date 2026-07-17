//gd:extends Node2D
//gd:class Player
package hello_net

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
	x, y:   f32 `gd:"replicate,interp,owner,wire=f16"`,
	pid:    u8 `gd:"replicate"`, // the seat this square belongs to (its color)
	mine:   bool, // set by the census hook: this peer drives this body
	tinted: bool, // one-shot: skin color applied once pid lands
}

player_process :: proc(self: ^Player, delta: f64) {
	_ = delta
	if !self.tinted && self.pid != 0 {
		self.tinted = true
		hues := [4]gd.Color{{0.9, 0.5, 0.2, 1}, {0.3, 0.7, 0.9, 1}, {0.5, 0.9, 0.4, 1}, {0.9, 0.4, 0.7, 1}}
		gd.polygon2d_set_color(self.skin, hues[int(self.pid) % 4])
	}
	// Mine or not, the node shows the fields: my writes land instantly, a
	// remote square's fields are the interpolated stream.
	gd.node2d_set_position(cast(gd.Node2d)self.owner, {self.x, self.y})
}

// The census hooks — the only bookkeeping the game keeps.
player_spawned :: proc(game: ^HelloNet, self: ^Player, id: knet.Net_Id, owner: knet.Player_Id) {
	_ = id
	if owner == game.ses.me {
		self.mine = true
		game.me = self
	}
}

player_freed :: proc(game: ^HelloNet, self: ^Player, id: knet.Net_Id) {
	_ = id
	if self == game.me {
		game.me = nil
	}
}
