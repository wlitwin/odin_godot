# Raw WebSocket transport

`websocket_host` owns a native TCP listener and bounded WebSocketPeer connections.
`websocket_join` works natively and in browser exports. The adapter uses no
MultiplayerAPI or Godot scene RPCs. Keep the owner at a stable address; close its
public transport or call `websocket_close` to release it.

The Transport view accepts **Reliable** messages only and preserves the 64 KiB
logical packet limit. `Unreliable` returns `Invalid`; this adapter does not provide
an unordered channel. Accepted sends copy bytes. Small destination buffers retain
the next packet. Connection IDs are assigned by the native listener and are never
reused during its lifetime; a client addresses its server as peer 1.

Defaults allow 16 connections, 64 queued engine packets, 256 KiB input/output
buffers per connection, and a ten-second handshake deadline. The listener accepts
at most eight sockets per poll. Full connection tables reject incoming sockets;
full outgoing buffers return backpressure. Incomplete handshakes and disconnected
peers release their references. The ordinary Transport receive path discards text
messages with a bounded loop.

Services that multiplex JSON signaling and binary control messages can use
`websocket_receive` (including its `text` flag) and `websocket_send_text` directly.
Packet identities come from the socket, never a field in received JSON. This is
transport plumbing, not authentication: authority traffic still uses its MAC,
request correlation, identity checks and durable coordinator decisions.

`Room_Options.control_backend = .Websocket` interprets `coordinator` as a WebSocket
URL. Its default remains Enet. Control reconnection preserves the RPC client and
request frontier. Gameplay may use ENet or the [authenticated RTC path](../rendezvous.md);
selecting WebSocket control alone does not configure the gameplay destination.

The native listener currently accepts plain WebSocket connections. Browser clients
can use `wss://` with a deployment's TLS endpoint/reverse proxy. Public TLS/origin
configuration is not established by the loopback acceptance fixture.
