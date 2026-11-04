package scrapyard_wasm

import r "godot:replay"
import net "godot:replay/net"
import game "../../../examples/replay_scrapyard/shared/game"
import upgrade "../../../examples/replay_scrapyard/shared/upgrade"

@(require) instantiate :: proc() {
    converted, _ := upgrade.root_42(nil)
    delete(converted)
    previous, _ := upgrade.root_48(nil)
    delete(previous)
    s: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
    net.server_init(&s, r.Frame(game.World){state = game.initial()}, game.model(), {}, local_seat = 1)
    net.server_step(&s)
    net.server_issue(&s, game.Action{kind = .Ready, ready = true})
    net.server_step(&s)
    net.server_issue(&s, game.Action{kind = .Start})
    net.server_step(&s)
    net.server_local(&s, game.Control{move = {1, 0}, dash = true})
    net.server_step(&s)
    net.server_destroy(&s)
}
