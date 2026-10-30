package replay_quickdraw_wasm
import r "godot:replay"
import net "godot:replay/net"
import game "../../../examples/replay_quickdraw/shared/duel"
@(require)
instantiate :: proc() {
	s: net.Server(game.World, game.Controls, game.Action, game.Event, game.SEATS)
	net.server_init(&s, r.Frame(game.World){state = game.initial()}, game.model(), {}, local_seat = 1)
	net.server_step(&s)
	net.server_destroy(&s)
}
