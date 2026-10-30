package replay_cave_wasm

import r "godot:replay"
import game "../../../examples/replay_cavecrawl/shared/cave"
import gd "godot:replay/godot"

@(require)
instantiate :: proc() {
	s: gd.Session(game.World, game.Control, game.Action, game.Event, game.SEATS)
	options := gd.SESSION_OPTIONS
	options.network.hz = game.HZ
	gd.session_open(&s, r.Frame(game.World){state = game.initial()}, game.model(), options)
	gd.session_frame(&s, 0.05, game.Control{})
	gd.session_issue(&s, game.Action{verb = .Take})
	gd.session_close(&s)
}
