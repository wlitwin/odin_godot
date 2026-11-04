package replay_godot

import transportgd "godot:replay/godot/transport"
import tr "godot:replay/transport"

@(private)
rendezvous_connection_live :: proc(socket: ^transportgd.Websocket, peer: tr.Peer_Id) -> bool {
    wire := transportgd.websocket_transport(socket)
    return tr.peer_connected(&wire, peer)
}
