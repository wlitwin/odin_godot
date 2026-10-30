package scrap_recording

import d "godot:replay/diagnostic"
import net "godot:replay/net"
import game "../game"

// Manual replay revision for game rules plus the network batch adapter. Mutable
// catalogs, rules, RNG and authority hit history are already in the full world.
CONTEXT :: d.Recording_Context {
	content = game.CONTENT,
	build = 1,
	tick_hz = game.HZ,
}

Recording :: d.Recording(game.World, net.Batch(game.Control, game.Action, game.SEATS), net.Net_Event(game.Event))
