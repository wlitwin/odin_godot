# kit/netgd — the Godot transport binding

[kit/net](net.md) is the pure wire core and [kit/session](session.md) is the pure session
model; **kit/netgd is the only place either touches Godot.** It rides the engine's
SceneMultiplayer raw-bytes path (`send_bytes` out, the `peer_packet` signal in) on top of
whatever `MultiplayerPeer` the game installed. The existing ergonomic wrappers already handle
peer creation — `gd.host` / `gd.join` for ENet, `gd.webrtc_host` / `gd.webrtc_join` for
browser room codes — so the toolkit works over every transport those support, and
[Steam](steamgd.md) slots in the same way. Riding SceneMultiplayer (rather than owning the
peer and polling it) keeps `@(gd_rpc)` and the engine's spawner/synchronizer interop working
alongside the toolkit.

State ownership rule (same as the events package): **no package globals** — a session's
transport state lives in the owning script's struct. The procs here are stateless sugar.

## The channel plan

- **channel 0** — untouched: the engine's own RPC/replication traffic.
- **`CHANNEL_RELIABLE` (1)** — commands, results, transitions, chat, join snapshots. Sent
  `RELIABLE`: discrete + rare, so the loss story is "none needed".
- **`CHANNEL_STREAM` (2)** — owner-authoritative state snapshots. Sent
  `UNRELIABLE_ORDERED`: last-value semantics — a drop is superseded by the next tick's
  snapshot.

The transfer-mode aliases (`RELIABLE`, `UNRELIABLE_ORDERED`) and the raw send procs
(`send_to`, `send_reliable`, `send_stream`) exist so call sites read as intent, but with a
`Session_Wire` attached you rarely call them yourself — the session's `Send_Proc` does.

## Session_Wire: the four one-line forwards

`Session_Wire` is the session's transport binding — the ~50 lines every game used to write
by hand (the `Send_Proc` adapter with its kind byte + channel pick, the packet route, the
engine's connection signals, the client's join handshake). It lives as a field on the game's
script struct.

Godot signals **must land on `@(gd_method)`s of a script** — scriptgen only processes game
scripts, so the kit cannot own the receiving methods. The contract: the game keeps four
one-line methods, and the wire owns everything behind them. From cavecrawl's
`examples/cavecrawl/scripts/net.odin`, verbatim:

```odin
@(gd_method)
cave_lobby_on_packet :: proc(self: ^CaveLobby, id: gd.Int, packet: gd.Packed_Byte_Array) {
	netgd.wire_receive(&self.wire, id, packet)
}

@(gd_method)
cave_lobby_on_peer_left :: proc(self: ^CaveLobby, id: gd.Int) {
	ksess.session_peer_disconnected(&self.ses, ksess.Peer_Id(id))
}

@(gd_method)
cave_lobby_on_net_up :: proc(self: ^CaveLobby) {
	ksess.session_client_join(&self.ses)
}

@(gd_method)
cave_lobby_on_net_down :: proc(self: ^CaveLobby) {
	ksess.session_peer_disconnected(&self.ses, ksess.HOST_PEER)
}
```

Wiring, in `ready()` (from cavecrawl's `cavecrawl.odin`) and `process()`:

```odin
netgd.wire_attach(&self.wire, self.owner, &self.ses, MSG_SESSION)
netgd.wire_listen(&self.wire, "on_packet", "on_peer_left", "on_net_up", "on_net_down")

// process():
netgd.wire_pump(&self.wire, now_s())
```

`wire_attach` installs the session's `Send_Proc` (kind byte + reliable/stream channel pick);
it survives `session_host_start` / `session_client_start` / `session_host_resume`, so call it
once. `wire_listen` connects `peer_packet` → `on_packet`, `peer_disconnected` →
`on_peer_left`, `connected_to_server` → `on_net_up`, and **both** `connection_failed` and
`server_disconnected` → `on_net_down`. Call it after the node is in the tree (`ready()`
qualifies). Empty method names skip that signal — but see the next section before you skip
any.

## The disconnect signals are NOT optional plumbing

- Unwired `peer_disconnected`: an alt-F4'd client haunts the roster forever, and the host
  keeps sending to a ghost.
- Unwired `connection_failed`: a failed join hangs on "Joining..." with no way out. The same
  forward handles `server_disconnected` — treating a vanished server as host loss.

## wire_receive and the kind byte

Every wire packet leads with the game's one message byte (the `kind` passed to
`wire_attach`). `wire_receive` checks `view[0] != wire.kind` and returns early — other kinds
are not the wire's; the game routes those itself *before* calling `wire_receive`. This is how
session traffic shares `peer_packet` with any other raw-bytes protocol the game runs.

## wire_set_latency — the acid-test shim

```odin
wire_set_latency :: proc(wire: ^Session_Wire, ms: int)
```

Injects one-way **receive** latency (0 disables): every packet this peer receives is held
that long before the session sees it — buffered in the wire, delivered by `wire_pump`. The
delay is app-side, above the transport, so ENet's acks and retransmits still flow at protocol
level; what you are testing is your *game's* feel under real round trips, not the socket's.
The toolkit's own acid tests run at 120ms so predictions are proven to bite instantly while
confirms measurably ride the slow wire. Test your game the same way — cavecrawl exposes it as
an env knob:

```odin
netgd.wire_set_latency(&self.wire, env_int("CAVE_LATENCY", 0)) // the acid rig, now a kit shim
```

## Kicks: wire_drop is deferred on purpose

A kick is two calls: `ksess.session_kick` unseats the player (and tells them why); the wire
severs their socket. But an **immediate** ENet disconnect races its own outgoing queue — the
`SES_KICKED` the session just sent gets discarded, and the kicked player sees a mystery
host-crash instead of the truth. So:

```odin
wire_drop :: proc(wire: ^Session_Wire, peer: ksess.Peer_Id, after := 0.75)
```

schedules the close; `wire_pump` performs it after the reliable queue has flushed and acked.
The session already ignores the unseated peer, so nothing it sends in the gap matters. From
cavecrawl:

```odin
was, ok := ksess.session_kick(&self.ses, target, ban = true)
if !ok {return}
netgd.wire_drop(&self.wire, was) // deferred: the KICKED message flushes first
```

The actual close is `drop_peer(node, peer)` — usable directly when you don't need the delay.
It calls `multiplayer_peer_disconnect_peer` with `force=false`, graceful on purpose for the
same flush reason.

## pba_view

```odin
pba_view :: proc "contextless" (pba: ^gd.Packed_Byte_Array) -> []u8
```

Zero-copy view of a `Packed_Byte_Array`'s contents — valid only while the array is alive,
i.e. inside the receiving method call. Feed it to `knet.reader_make`; clone anything you
keep. For raw-bytes listening without a `Session_Wire`, `listen_packets(node, method)`
connects `peer_packet` to a single `@(gd_method)` on the same node's script.

## Swapping transports

Nothing on this page mentions ENet specifics because the wire never sees the transport:
SceneMultiplayer's signals fire identically over any `MultiplayerPeer`. Hosting over Steam
instead of ENet is covered in [steamgd.md](steamgd.md) — the `Session_Wire` and the four
forwards are byte-for-byte the same.
