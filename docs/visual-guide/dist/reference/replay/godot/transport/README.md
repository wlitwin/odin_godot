# Godot transport adapters

Import `transportgd "godot:replay/godot/transport"` when owning a raw Godot
transport. These adapters implement the engine-free
[`tr.Transport`](../../transport/README.md) contract and keep sockets, engine
references, packet buffers, and callbacks outside the gameplay world.

The normal [Session, Room, and Party owners](../README.md) open their own
backends. Use this package for a directly owned transport, a control-service
listener, or explicit backend configuration.

| Backend | Owner | Setup | Transport view |
| --- | --- | --- | --- |
| Native UDP | `Enet` | `enet_host` / `enet_join` | `enet_transport` |
| WebRTC data channels | `Rtc` | `rtc_open` with `Rtc_Config` | `rtc_transport` |
| WebSocket messages | `Websocket` | `websocket_host` / `websocket_join` | `websocket_transport` |
| GodotSteam | `Steam` | `steam_open` with `Steam_Config` and an initialized `Steam_Runtime` | `steam_transport` |
| An existing Godot peer | `Multiplayer_Transport` | `multiplayer_attach` | `multiplayer_transport` |

Keep the owner at a stable address until closed. A `tr.Transport` is a borrowed
view; copying the view does not transfer or duplicate ownership. Poll the view
once per frame, receive packets into caller storage, and close it before
discarding the owner:

```odin
import transportgd "godot:replay/godot/transport"
import tr "godot:replay/transport"

host_example :: proc() -> bool {
	peer: transportgd.Enet
	if !transportgd.enet_host(&peer, 4242) {return false}
	wire := transportgd.enet_transport(&peer)
	// Drive tr.poll, tr.send, and tr.receive while peer remains alive.
	tr.close(&wire)
	return true
}
```

The adapters own or retain the Godot references documented by their setup
procedures. They do not install a scene tree's `MultiplayerAPI`, so engine RPCs
and scene multiplayer remain a separate owner. WebSocket text messages use
`websocket_send_text` / `websocket_receive`; its generic transport view carries
binary reliable messages.

RTC setup, authorization, ICE settings, continuation data, and peer identities
stay together here. Steam setup and endpoint conversion likewise share this
package. The extraction changes package paths, not packet formats, identity
encoding, authority policies, or supported backends.
