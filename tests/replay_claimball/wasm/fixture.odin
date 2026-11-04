package replay_claimball_wasm
import net "godot:replay/net"
import game "../../../examples/replay_claimball/shared/pitch"

@(require) instantiate :: proc() {
    c: net.Client(game.World, game.Controls, game.Action, game.Event, game.SEATS)
    net.client_init(&c, game.model(), {}, net.Token{0 = 1})
    net.client_step(&c, game.Controls{})
    net.client_prediction(&c)
    net.client_destroy(&c)
}
