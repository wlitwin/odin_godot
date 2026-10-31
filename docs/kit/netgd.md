# kit/netgd — the Godot transport binding

`kit/netgd` connects the engine-independent [replication core](net.md) and
[session](session.md) to Godot’s SceneMultiplayer. It sends packets with
`send_bytes` and receives them through `peer_packet`, using the installed
`MultiplayerPeer`. `gd.host` / `gd.join` create native ENet peers;
`gd.webrtc_host` / `gd.webrtc_join` handle browser room-code setup. The
[Steam adapter](steamgd.md) supplies another transport implementation.

Using SceneMultiplayer lets Kit share the engine’s multiplayer peer with
`@(gd_rpc)`, MultiplayerSpawner, and MultiplayerSynchronizer. Keep each session’s
transport state in its owning script struct; the procedures receive that state
explicitly.

<a id="the-channel-plan"></a>

## Transport channels

- **channel 0** remains available for Godot RPC and scene-replication traffic.
- **`CHANNEL_RELIABLE` (1)** carries commands, results, transitions, chat, and
  join snapshots using `RELIABLE` delivery.
- **`CHANNEL_STREAM` (2)** carries owner-state snapshots using
  `UNRELIABLE_ORDERED`. A later snapshot supersedes a lost sample.

With a `Session_Wire` attached, the session’s `Send_Proc` selects the channel and
calls `send_to`, `send_reliable`, or `send_stream`. A custom `Send_Proc` must
translate peer IDs through `wire_engine_peer(to_peer) -> (engine_peer, ok)`.
Do not cast `ksess.Peer_Id` directly to an engine integer: Kit’s
`BROADCAST_PEER` is `Peer_Id(-1)`, while Godot interprets raw -1 as “all except
peer 1.” The adapter maps broadcast to engine 0 and returns `ok = false` for
`NO_PEER`; discard a send with no connected destination.

## Session_Wire and the four forwarding methods

`Session_Wire` binds the session’s send procedure, packet routing, Godot
connection signals, and client join handshake. The stock [Boot](boot.md)
contains it as `boot.wire` and attaches it during `boot_attach`. A game managing
the components directly can keep its own wire field.

Godot signal receivers must be registered `@(gd_method)` procedures on a game
script. For a script that directly owns `ses` and `wire`, the forwarding methods
look like this:

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

Attach them after the node enters the tree, normally in `_ready`, and pump the
wire from `_process`:

```odin
netgd.wire_attach(&self.wire, self.owner, &self.ses, MSG_SESSION)
netgd.wire_listen(&self.wire, "on_packet", "on_peer_left", "on_net_up", "on_net_down")

// process():
netgd.wire_pump(&self.wire, now_s())
```

`wire_attach` installs the session’s send adapter. It survives
`session_host_start`, `session_client_start`, and `session_host_resume`, so it
need not be repeated for those transitions. `wire_listen` connects:

- `peer_packet` to `on_packet`;
- `peer_disconnected` to `on_peer_left`;
- `connected_to_server` to `on_net_up`; and
- both `connection_failed` and `server_disconnected` to `on_net_down`.

An empty method name skips that signal. Check the
[disconnect requirements](#the-disconnect-signals-are-required) before skipping one.

## Hosting and joining

The `begin_*` helpers open the selected transport and start its session:

```odin
// native (ENet) — the address is known before dialing
netgd.begin_host(&wire, port, name, max_peers = 32, token = 0) -> bool  // false = port taken
netgd.begin_join(&wire, addr, port, token, name) -> bool

// Browser WebRTC: the relay assigns the room code after connection.
netgd.begin_host_web(&wire, url, name, token = 0, room = "") -> bool  // false = relay socket refused
netgd.begin_join_web(&wire, url, room, token, name) -> bool
netgd.web_poll(&wire)   // every frame: pumps the signaling handshake
netgd.web_close(&wire)  // full teardown — retry a failed join, or an heir raising a new room
```

`token` identifies the local participant for reconnects. Hosting helpers pass
the host’s token; joining helpers pass the joining player’s token. The
[session](session.md) uses it to reclaim that participant’s identity after a
handoff. For WebRTC, `room` requests a reserved
room code. An empty value requests a new code. The hosting helper returns before
the signaling relay assigns that code, so call `web_poll` each frame and read
`gd.webrtc_room_code(node)` when available. Use `gd.webrtc_session_state` and
`gd.webrtc_error_reason` to display progress or failure in the lobby.

Web host migration reserves a successor’s code before the handoff. The successor
opens that reservation while other clients reconnect to it. Session logic,
commands, and replication use the same interfaces after either transport is
installed.

[Boot](boot.md) provides the corresponding lobby operations: `boot_host`,
`boot_join`, `boot_host_web`, and `boot_join_web`. The four `begin_*` helpers
select a transport and call `transport_host` or `transport_join`. Use those
generic procedures when a setting or retry policy chooses the provider at runtime;
see [Swapping transports](#swapping-transports).

### Native ENet join codes

Native join codes use the signaling relay as an endpoint directory. The host
registers its bound port under a generated code. A joiner resolves the code to
the host’s observed endpoint, then follows the normal `begin_join` flow.
`tests/webrtc/signal_server.mjs` implements the reference native-room protocol;
the production relay exposes it at `/rtc`.

A Boot-based game uses these operations, with `<game>_net_frame` driving the
rendezvous state. The hosted code appears in lobby status and `boot_room_code`;
a resolved join starts `boot_join`, and an invalid code returns to the menu
with its reason:

```odin
// Host with a join code (kui.lobby_show_code reveals the stock
// lobby's code field, and kui.lobby_code reads what the human typed):
kboot.boot_host_coded(&self.boot, RELAY_URL, port, name)
// Join by code rather than supplying an address and port:
kboot.boot_join_code(&self.boot, RELAY_URL, "KWXP", token, name)
```

A custom lobby can drive `code.odin` directly:

```odin
// Host: call after begin_host(port) succeeds.
netgd.code_host_open(&rdv, RELAY_URL, port)
// Joiner: resolve a code to an address.
netgd.code_join_open(&rdv, RELAY_URL, "KWXP")

// both, every frame, until it resolves:
switch netgd.code_poll(&rdv, &wire) {
case .Ready:
    if rdv.is_host {show(netgd.code_room(&rdv))} // the code to share
    else {ip, port := netgd.code_endpoint(&rdv); begin_join(&wire, ip, port, token, name)}
case .Failed: // Show rdv.err: .No_Room, .Full, or .Closed.
              // Offer another configured transport if appropriate.
}
```

`examples/hello_net` exercises the Boot helpers against a local relay. Setting
`HELLO_RELAY` enables its code-entry field. The supported cases include a
same-LAN pair, a public or port-forwarded host, and common port-preserving NAT.
The relay supplies each joiner’s observed endpoint and `wire_punch` sends UDP
packets to establish the mapping.

Raw ENet has no TURN relay for symmetric NAT. Report connection failure and
offer another configured transport, such as WebRTC with TURN or Steam; verify
reachability for the deployment rather than assuming the alternative succeeds.

<a id="the-disconnect-signals-are-required"></a>

## Disconnect handling

Forward `peer_disconnected` so the session removes a disconnected client from its
roster. Forward `connection_failed` so a refused join can leave the “Joining...”
state. `server_disconnected` uses the same failure callback to report host loss.

Scriptgen checks literal method names passed to `wire_listen`, `listen_packets`,
and Boot’s `methods` against registered `@(gd_method)` procedures. A misspelling
is a build error; an empty string deliberately omits a connection.

## Host migration

The cooperative session selects a successor; `netgd.Succession` provides the
connection information that lets survivors find it. Boot controls retry timing,
timeouts, and reconnect orchestration. `boot_migration` installs the callbacks;
live simulation-lane migration is not supported by this path. See
[session recovery](session.md#backup-hosting-and-resume).

A handoff record is `[kind u8][payload]`, encoded and decoded by this package
through `succession_decode`:

- **`.Native_Addr`** carries `[addr][port]`: the successor’s address as observed
  by the host and a port derived from its seat. It requires an ENet peer-address
  lookup. A provider lacking that lookup cannot supply this handoff.
- **`.Web_Room`** carries `[code]`: the pre-reserved relay room opened by the
  successor. Boot schedules reconnect attempts while that room becomes available.

Steam handoff is not implemented by these kinds. It needs a verified peer-ID
lookup and a corresponding rendezvous encoding; a Steam lobby’s owner is not
necessarily the successor chosen by the Kit session.

Configure `Succession{kind, signal_url, base_port, token, name}` once, normally
through `boot_succ_config`. On `Ev_Backup_Target`, the host’s `succession_torch`
publishes the handoff. The successor calls `succession_raise`; a survivor calls
`succession_dial` for one connection attempt. Boot owns the retries.
`succession_named` checks whether a successor is present. The game supplies its
campaign backup, entity cleanup, and recovery UI through `boot_migration` callbacks.

## wire_receive and the kind byte

The low seven bits of the packet’s leading byte identify the game protocol
installed with `wire_attach`. The high bit, `0x80`, marks stream-channel traffic.
`wire_receive` masks that bit before comparing the protocol ID with `wire.kind`.
Custom routing must use the same mask so it recognizes both reliable and stream
packets for the protocol. Route another raw-byte protocol before calling it.
This lets several protocols share the same `peer_packet` signal without decoding
each other’s packets.

## Link simulation

```odin
wire_set_latency :: proc(wire: ^Session_Wire, ms: int, jitter_ms := 0, loss_pct := 0, burst := 1, bandwidth_bps := 0)
```

`wire_set_latency` delays each packet on this peer’s receive path by the given
one-way latency; 0 disables the delay. `wire_pump` later delivers buffered
packets to the session. This happens above the transport, so it does not delay
ENet’s own acknowledgements and retransmissions. The integration tests use
120 ms to check local prediction and delayed authority confirmation.

`jitter_ms` adds uniform extra delay in `[0, jitter)` while preserving FIFO order
per sender. `loss_pct` drops selected stream batches, which later samples can
supersede. For reliable traffic it instead adds retransmission delay, preserving
the channel’s reliable-delivery requirement.

`burst` controls mean lost-run length in packets. At 1, losses are independent;
larger values use a Gilbert-Elliott-style model that groups roughly `~burst`
losses between clean intervals at the same average rate. This tests whether an
input-redundancy window survives a cluster of drops and how stacked reliable
retransmission delays affect the game.

`bandwidth_bps` limits modeled receive throughput in bytes/s, shared by all
senders. Excess packets queue and increase delay. Configure each endpoint’s
receive model separately to test asymmetric links. The model cannot assign
different conditions to individual senders on the same receiver.

Boot reads these settings from environment variables:

```sh
QD_LATENCY=120 QD_JITTER=30 QD_LOSS=3 ./run_two_windows.sh        # receive latency, jitter, and loss
QD_LOSS=3 QD_BURST=4 QD_BANDWIDTH=16000 ./run_two_windows.sh      # bursty loss with a 16KB/s receive budget
```

## Traffic and link stats

The wire counts framed bytes sent and received by session message kind: state,
stream, command, spawn, and app. App traffic is also split by its tag byte, so
simulation traffic can be identified separately. Read the completed one-second
window with:

```odin
netgd.wire_traffic(&wire) -> string
// "rx 3.2k state 2.1 stream 0.8 app16 0.2 · tx 0.4k cmd 0.3"
netgd.wire_rates(&wire) -> Wire_Rates // packets/s and bytes/s, in/out
netgd.wire_link_quality(&wire, peer) -> (rtt_ms, jitter_ms, loss_pct, ok)
```

`wire_traffic` formats the [netgraph](ui.md) traffic row; `wire_rates` returns
aggregate packet and byte rates. Boot populates both. Compare these measurements
when changing `wire=f16`, stream rates, or interest filtering.

`wire_link_quality` reads ENet’s per-peer smoothed RTT, RTT variance, and loss
scaled by `PACKET_LOSS_SCALE`. A client asks about `ksess.HOST_PEER`; a host asks
about a specific client. Quickdraw’s netgraph shows this integration.

## Kicks: wire_drop

A low-level kick first calls `ksess.session_kick` to remove the player and send
`SES_KICKED`, then closes its transport connection. Closing immediately can
discard the queued reason packet, causing the client to report host loss instead.

```odin
wire_drop :: proc(wire: ^Session_Wire, peer: ksess.Peer_Id, after := 0.75)
```

`wire_drop` schedules a deadline. `wire_pump` requests the disconnect after that
deadline; it does not inspect acknowledgements before doing so. The delay gives
the notification time to leave the reliable queue. The session has already
removed the player from its connected roster. For a game managing the wire directly:

```odin
was, ok := ksess.session_kick(&self.ses, target, ban = true)
if !ok {return}
netgd.wire_drop(&self.wire, was) // deferred: the KICKED message flushes first
```

`drop_peer(node, peer)` requests the actual graceful disconnect through
`multiplayer_peer_disconnect_peer` with `force=false`. Use `boot_kick` in a
Boot-based game to perform both the session removal and the delayed wire close.

## pba_view

```odin
pba_view :: proc "contextless" (pba: ^gd.Packed_Byte_Array) -> []u8
```

`pba_view` borrows the `Packed_Byte_Array` contents without copying. Use that view
only while the array remains alive, normally within the receiving method.
Pass it to `knet.reader_make` and copy bytes retained after the callback.
`gd.packed_byte_array_view` is the underlying engine helper; `netgd.pba_view`
is its networking alias.

Without a `Session_Wire`, `listen_packets(node, method)` connects `peer_packet`
to one registered `@(gd_method)` on the node’s script.

## Swapping transports

`Transport` describes provider-specific connection setup, pumping, teardown,
statistics, and peer addressing. Session packets continue to use
SceneMultiplayer’s raw-byte interface:

```odin
Transport :: struct {
    name:       string,           // "enet" / "webrtc" / "steam"
    rendezvous: Rendezvous_Kind,  // Handoff format supplied by address (.None = no migration)
    open_host:  proc(wire, at: Endpoint, name: string, token: u64, dedicated: bool) -> bool,
    open_join:  proc(wire, at: Endpoint, name: string, token: u64, spectate: bool) -> bool,
    pump:       proc(wire),       // nil = the engine polls it
    close:      proc(wire),       // nil = no extra resources to close
    link:       proc(wire, peer) -> (rtt_ms, jitter_ms, loss_pct: f64, ok: bool),
    address:    proc(wire, peer, allocator) -> (string, bool),
}

Endpoint :: struct {   // Connection details interpreted by the selected transport
    addr: cstring,     // native: the host's address (join) · web: the relay url
    port: int,         // native: the port to bind or dial
    room: cstring,     // web: the room code to reserve or join
    peer_id: u64,      // steam: the host's steam id (join)
    max_peers: int,    // host: seat cap (0 = the transport's default)
}
```

`open_host` and `open_join` are required. Optional callbacks have these effects:

| slot | nil means | what the user sees |
|---|---|---|
| `pump` | the engine polls it (ENet, Steam) | no separate transport pump |
| `close` | no extra resources outlive the peer | no provider-specific teardown |
| `link` | per-peer statistics are unavailable | the netgraph leaves link values blank |
| `address` | no peer rendezvous address is available | `.Native_Addr` migration cannot name the successor; `.Web_Room` uses reserved room codes without this callback |

`transport_host` and `transport_join` remember the chosen provider in the wire.
`transport_service`, `transport_close`, `wire_link_quality`, and succession then
use that provider’s callbacks. Generated `<game>_net_frame` calls the service
pump through Boot. A peer installed directly with `gd.host` and `wire_attach`
uses the ENet fallback; ENet-specific operations check the peer’s class and
return `ok = false` for another type.

The supplied records are `netgd.ENET`, `netgd.WEBRTC`, and `ksteam.TRANSPORT`
([Steam](steamgd.md)). Another provider fills the same record, with any
rendezvous encoding required for migration. The session wire and signal-forwarding
methods can keep the same interface.

A session uses one `MultiplayerPeer` provider for every seat. Select ENet,
WebRTC, or Steam for the run; individual participants cannot mix providers
within that session. A Steam user can host an ENet or WebRTC session for peers
using that provider.

Related features have separate requirements:

- **LAN discovery** is not supplied. A game can implement UDP discovery, or use
  the join-code relay for a same-LAN pair.
- **Server browsing** is not supplied. It needs a directory service with
  registration, listing, and liveness; join codes only resolve a known room.
- **Splitscreen** has one session identity per process. Local controller and
  camera handling belong to the game; Kit does not allocate independent local seats.
- **Consoles** and platform-specific console transports are untested here.
