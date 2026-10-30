package cave_owner_wasm
import r "godot:replay"
import net "godot:replay/net"
import game "../../../examples/replay_cavecrawl/shared/owner_cave"
@(require)
instantiate :: proc() {
 s:net.Server(game.World,game.Control,game.Action,game.Event,game.SEATS)
 cfg:=net.DEFAULT_CONFIG;cfg.content=game.CONTENT
 net.server_init(&s,r.Frame(game.World){state=game.initial()},game.model(),{},cfg,local_seat=1)
 net.server_step(&s);net.server_destroy(&s)
}
