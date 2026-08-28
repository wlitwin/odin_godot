# kit/netgd — the Godot transport binding

[kit/net](net.md) is the pure wire core and [kit/session](session.md) is the pure session
model. **kit/netgd is the only place either touches Godot.** It rides the engine's
SceneMultiplayer raw-bytes path (`send_bytes` out, the `peer_packet` signal in) on top of
whatever `MultiplayerPeer` the game installed. The ergonomic wrappers handle peer creation:
`gd.host` / `gd.join` for ENet, `gd.webrtc_host` / `gd.webrtc_join` for browser room codes.
This lets the toolkit work over every transport those support, and [Steam](steamgd.md) slots
in the same way. Riding SceneMultiplayer, rather than owning the peer and polling it, keeps
`@(gd_rpc)` and the engine's spawner/synchronizer interop working alongside the toolkit.

State ownership rule (same as the events package): **no package globals**. A session's
transport state lives in the owning script's struct. The procs here are stateless sugar.

## The channel plan

- **channel 0** is untouched: the engine's own RPC/replication traffic.
- **`CHANNEL_RELIABLE` (1)** carries commands, results, transitions, chat, and join
  snapshots. It is sent `RELIABLE` because this traffic is discrete and rare, so no loss
  handling is needed.
- **`CHANNEL_STREAM` (2)** carries owner-authoritative state snapshots. It is sent
  `UNRELIABLE_ORDERED` with last-value semantics: a drop is superseded by the next tick's
  snapshot.

The transfer-mode aliases (`RELIABLE`, `UNRELIABLE_ORDERED`) and the raw send procs
(`send_to`, `send_reliable`, `send_stream`) let call sites read as intent, but with a
`Session_Wire` attached you rarely call them yourself: the session's `Send_Proc` does.

If you hand-roll a `Send_Proc` (the raw-layer path), translate the peer through
`wire_engine_peer(to_peer) -> (engine_peer, ok)`. Never cast a `ksess.Peer_Id` to an engine
int directly. The sentinels don't line up: kit's `BROADCAST_PEER` is `Peer_Id(-1)`, but the
engine reads a raw -1 as "all except peer 1", so a raw cast makes the server silently miss
every broadcast. `wire_engine_peer` maps broadcast to the engine's 0 and returns `ok = false`
for `NO_PEER`: a disconnected seat's peer reached the transport, so drop the send.

## Session_Wire and the four forwarding methods

`Session_Wire` is the session's transport binding: the `Send_Proc` adapter (kind byte +
reliable/stream channel pick), the packet route, the engine's connection signals, and the
client's join handshake, roughly 50 lines a game would otherwise write by hand. In a stock
game it lives inside [kit/boot](boot.md)'s `Boot` (`boot.wire`; `boot_attach` runs the
`wire_attach`/`wire_listen` calls below for you). Games that skip boot keep it as a field on
the script struct and wire it directly.

Godot signals **must land on `@(gd_method)`s of a script**. Scriptgen only processes game
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
qualifies). Empty method names skip that signal, but see [the disconnect
signals](#the-disconnect-signals-are-required) before you skip any.

## Hosting and joining

Every game's Host/Join handlers repeat the same two-step: bring the transport up, then start
the session over it. The wire owns both flavors:

```odin
// native (ENet) — the address is known before dialing
netgd.begin_host(&wire, port, name, max_peers = 32, token = 0) -> bool  // false = port taken
netgd.begin_join(&wire, addr, port, token, name) -> bool

// browser (WebRTC room codes) — the relay ASSIGNS the code after the host connects
netgd.begin_host_web(&wire, url, name, token = 0, room = "") -> bool  // false = relay socket refused
netgd.begin_join_web(&wire, url, room, token, name) -> bool
netgd.web_poll(&wire)   // every frame: pumps the signaling handshake
netgd.web_close(&wire)  // full teardown — retry a failed join, or an heir raising a new room
```

`token` is the host's own reconnect token (see [session](session.md)); it makes a dead host
reclaimable after a host-migration handoff. `room` asks the relay to honor a RESERVED code
instead of minting a fresh one. Host migration uses it: the current host reserves the next
room code in advance, and the heir hosts under that reserved code while clients reconnect on
exactly that code (empty = mint a fresh code, the ordinary host case). The web pair differs
from ENet in one structural way: the room code **does not exist yet** when `begin_host_web`
returns. The relay assigns it async. Pump `web_poll` each frame and read it back with
`gd.webrtc_room_code(node)` when it lands; `gd.webrtc_session_state` /
`gd.webrtc_error_reason` narrate the handshake for your lobby. Everything above these calls
(session, muster, commands, replication) is the same code path on both transports; the branch
ends the moment the multiplayer peer installs.

[kit/boot](boot.md) wraps both flavors with the stock lobby ceremony: `boot_host` /
`boot_join` and their `boot_host_web` / `boot_join_web` twins.

All four `begin_*` calls are **sugar** over one mechanism: `transport_host` /
`transport_join` with the flavor picked for you. They are the shortest way to spell the common
case and the names games already say; reach for the generic pair when the transport is a
*variable* (a settings menu, a fallback chain, kit/boot's doors). See [Swapping
transports](#swapping-transports).

### Native ENet join codes

"Send your friend a four-letter code" without Steam and without reading out an IP: the same
relay the browser build already talks to (native room mode: `tests/webrtc/signal_server.mjs`
is the reference; the production relay speaks it at `/rtc`) becomes a phonebook for plain
ENet. The host registers its bound port under a minted code; a joiner trades the code for the
host's observed endpoint; the join proceeds exactly as `begin_join` does.

**A kit game uses the boot doors**, the same shape as every other door, and `boot_pump` runs
the whole rendezvous (the host's minted code lands in the lobby status and `boot_room_code`; a
joiner's resolved endpoint walks through `boot_join` on its own; a bad code restores the menu
with the reason):

```odin
// host — instead of boot_host (also: kui.lobby_show_code reveals the stock
// lobby's code field, and kui.lobby_code reads what the human typed):
kboot.boot_host_coded(&self.boot, RELAY_URL, port, name)
// joiner — a CODE instead of an address; no port, no IP:
kboot.boot_join_code(&self.boot, RELAY_URL, "KWXP", token, name)
```

Games below the boot (or with their own lobby flow) drive `code.odin` raw:

```odin
// host, AFTER begin_host(port) succeeded:
netgd.code_host_open(&rdv, RELAY_URL, port)
// joiner, INSTEAD of an address:
netgd.code_join_open(&rdv, RELAY_URL, "KWXP")

// both, every frame, until it resolves:
switch netgd.code_poll(&rdv, &wire) {
case .Ready:
    if rdv.is_host {show(netgd.code_room(&rdv))} // the code to share
    else {ip, port := netgd.code_endpoint(&rdv); begin_join(&wire, ip, port, token, name)}
case .Failed: // rdv.err: .No_Room (typo / host gone), .Full, .Closed — say WHY,
              // then point at the doors that always work (browser, Steam)
}
```

`examples/hello_net` is the worked consumer of the boot doors (its `run.sh` join-by-code act
proves the full loop against a local relay; with `HELLO_RELAY` set, its lobby grows the code
field). **NAT coverage:** this covers the same-LAN pair, the port-forwarded or public host,
and the common port-preserving home NAT (the relay hands the host each joiner's observed
endpoint and `wire_punch` warms the mapping with a few UDP packets). Symmetric NATs it does
NOT cover: there is no TURN for raw ENet. When the connect times out, say so and offer the
browser build (WebRTC + TURN) and Steam, which always work. A copyable code serves most
players; the two spare doors serve the rest.

## The disconnect signals are required

- Unwired `peer_disconnected`: an alt-F4'd client haunts the roster forever, and the host
  keeps sending to a ghost.
- Unwired `connection_failed`: a failed join hangs on "Joining..." with no way out. The same
  forward handles `server_disconnected`, treating a vanished server as host loss.

A misspelled forward compiles clean but fails at runtime, so scriptgen validates every literal
method name passed to `wire_listen` / `listen_packets` (and `boot_attach`'s `methods`) against
the script's registered `@(gd_method)`s: a typo is a build error; an empty string is a skip.

## Host migration

The session decides which peer becomes the new host, the heir
([session](session.md#backup-hosting-and-resume)). `netgd.Succession` owns HOW the survivors
find that heir. `kboot`'s state machine owns WHEN: the window, the retry policy, and the
deferred mechanics (`boot_migration` wires the whole flow, and most games never touch this
layer directly). The handoff record is typed as `[kind u8][payload]`, encoded and decoded
only here (`succession_decode`), so a new transport adds a `Rendezvous_Kind` and two switch
arms, never a string-format negotiation:

- **`.Native_Addr`** is `[addr][port]`: the heir's address as the host saw it, plus the
  seat-derived port the heir will bind. ENet-only: a transport with no peer-address story
  cannot provide this handoff, and warns once rather than silently shipping no migration.
- **`.Web_Room`** is `[code]`: the relay honors reservations on create, so the host reserves
  the next room code in advance; the heir hosts under it and survivors reconnect on boot's
  timer (a browser cannot block, and the heir needs a moment to open the room). A Steam lobby
  id is the reserved next kind.

Configure once (`Succession{kind, signal_url, base_port, token, name}`; `boot_succ_config`
does it for door games), then the verbs are stateless: `succession_torch` on
`Ev_Backup_Target` (host) publishes the handoff, `succession_raise` (heir), `succession_dial`
(one attempt at a decoded rendezvous: `kboot`'s machine owns tries, gaps, and give-up;
`succession_named` peeks so a handoff with no named successor leaves the world standing). The
game keeps its campaign blob, its census wipe, and its words, as `boot_migration` halves.

## wire_receive and the kind byte

Every wire packet leads with the game's one message byte (the `kind` passed to `wire_attach`).
`wire_receive` checks `view[0] != wire.kind` and returns early: other kinds are not the
wire's, and the game routes those itself *before* calling `wire_receive`. This is how session
traffic shares `peer_packet` with any other raw-bytes protocol the game runs.

## Link simulation

```odin
wire_set_latency :: proc(wire: ^Session_Wire, ms: int, jitter_ms := 0, loss_pct := 0, burst := 1, bandwidth_bps := 0)
```

Injects one-way **receive** latency (0 disables): every packet this peer receives is held
that long before the session sees it, buffered in the wire and delivered by `wire_pump`. The
delay is app-side, above the transport, so ENet's acks and retransmits still flow at protocol
level; what you are testing is your *game's* feel under real round trips, not the socket's.
The toolkit's integration tests run at 120 ms to verify that prediction responds immediately
while confirms measurably ride the slow wire.

`jitter_ms` adds a uniform extra `[0, jitter)` per packet, with one constraint: delivery stays
FIFO per sender (the shim sits above ENet's already-ordered channels, and reordering here
would break the ordered-reliable contract). `loss_pct` is channel-honest the same way: a
**stream** batch rolls the dice and vanishes (last-value semantics: the next batch supersedes
it, which is the real behavior of the unreliable channel), while **reliable** traffic must
arrive, so its "loss" costs what loss really costs a reliable channel: a retransmit's worth of
extra delay.

Two more knobs model links that are cruel, not just bad. `burst` is the mean lost-run length
in packets: at 1 (the default) losses are independent coin flips; past it they arrive
Gilbert-Elliott style, with long clean stretches, then a burst that eats `~burst` consecutive
packets, at the *same average rate*. Bursts matter because a redundant input window shrugs off
scattered drops but can be wiped out whole inside one burst, and reliable-channel losses in a
burst stack their retransmit delays, which is the pattern real WiFi and cellular produce.
`bandwidth_bps` caps the modeled downlink (bytes/s, one pipe shared by every sender):
sustained overflow doesn't drop, it QUEUES, and the delay grows. This is bufferbloat, the
failure narrow links have long before loss shows up. Up/down asymmetry needs no knob: each end
shims its own *receive*, so a bad uplink is the OTHER window's numbers (the integration tests
run each process with its own env). Not modeled: per-peer mixing on one receiver. One flaky
friend among good ones shares your whole shimmed downlink.

kit/boot wires all five off env for you:

```sh
QD_LATENCY=120 QD_JITTER=30 QD_LOSS=3 ./run_two_windows.sh        # the classic trio
QD_LOSS=3 QD_BURST=4 QD_BANDWIDTH=16000 ./run_two_windows.sh      # cruel: bursty loss on a 16KB/s pipe
```

## Traffic and link stats

Every framed byte the wire sends or receives is tallied by session message kind (state,
stream, cmd, spawn, app; app is split by its tag byte, so the sim lane's traffic is named,
not lumped), windowed per second. Two reads:

```odin
netgd.wire_traffic(&wire) -> string
// "rx 3.2k state 2.1 stream 0.8 app16 0.2 · tx 0.4k cmd 0.3"
netgd.wire_link_quality(&wire, peer) -> (rtt_ms, jitter_ms, loss_pct, ok)
```

`wire_traffic` is the [netgraph](ui.md)'s traffic row. Fill `Net_Stats.traffic` with it and
you can watch a chatty field's bytes move as you tune `wire=f16`, stream rates, or interest.
`wire_link_quality` reads ENet's own per-peer statistics (smoothed rtt, rtt variance, packet
loss ×`PACKET_LOSS_SCALE`), the transport's view, meaningful on clients about the host
(`ksess.HOST_PEER`); a host asks per client peer. quickdraw's netgraph fill is the worked
example.

## Kicks: wire_drop

A kick is two calls: `ksess.session_kick` unseats the player (and tells them why); the wire
severs their socket. An **immediate** ENet disconnect races its own outgoing queue: the
`SES_KICKED` the session just sent would be discarded, and the kicked player would see a
host-crash instead of the reason. So:

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

The actual close is `drop_peer(node, peer)`, usable directly when you don't need the delay.
It calls `multiplayer_peer_disconnect_peer` with `force=false`, graceful for the same flush
reason.

## pba_view

```odin
pba_view :: proc "contextless" (pba: ^gd.Packed_Byte_Array) -> []u8
```

`pba_view` returns a zero-copy view of a `Packed_Byte_Array`'s contents. It is valid only
while the array is alive, i.e. inside the receiving method call. Feed it to
`knet.reader_make`; clone anything you keep. For raw-bytes listening without a
`Session_Wire`, `listen_packets(node, method)` connects `peer_packet` to a single
`@(gd_method)` on the same node's script.

`gd.packed_byte_array_view` is the underlying helper (engine-type ergonomics, not
networking). `netgd.pba_view` is an alias for it; every packet handler in the tree opens with
it, so the short spelling stays.

## Swapping transports

The data plane is transport-agnostic: SceneMultiplayer's signals fire identically over any
`MultiplayerPeer`, which is why nothing on this page mentions ENet specifics: the wire never
sees the transport. The control plane (open, pump, close, who-is-that-peer) is captured in
one record (`transport.odin`):

```odin
Transport :: struct {
    name:       string,           // "enet" / "webrtc" / "steam"
    rendezvous: Rendezvous_Kind,  // the handoff flavor `address` feeds (.None = cannot migrate)
    open_host:  proc(wire, at: Endpoint, name: string, token: u64, dedicated: bool) -> bool,
    open_join:  proc(wire, at: Endpoint, name: string, token: u64, spectate: bool) -> bool,
    pump:       proc(wire),       // nil = the engine polls it
    close:      proc(wire),       // nil = nothing outlives the peer
    link:       proc(wire, peer) -> (rtt_ms, jitter_ms, loss_pct: f64, ok: bool),
    address:    proc(wire, peer, allocator) -> (string, bool),
}

Endpoint :: struct {   // WHERE a run lives, in the flavor its transport understands
    addr: cstring,     // native: the host's address (join) · web: the relay url
    port: int,         // native: the port to bind or dial
    room: cstring,     // web: the room code — reserved on host, knocked on join
    peer_id: u64,      // steam: the host's steam id (join)
    max_peers: int,    // host: seat cap (0 = the transport's default)
}
```

`open_host` / `open_join` are **required**; the rest are optional. A nil slot is a documented
degradation with a stated consequence:

| slot | nil means | what the user sees |
|---|---|---|
| `pump` | the engine polls it (ENet, Steam) | nothing, one nil check per frame |
| `close` | nothing outlives the peer | a re-host binds clean anyway |
| `link` | no per-peer statistics story | the netgraph blanks its link row instead of showing a confident zero |
| `address` | no rendezvous handle for a peer | **host migration is off**, and `succession_torch` says so once, naming the transport |

`transport_host` / `transport_join` open a wire and the wire remembers its transport;
`transport_service` (the per-frame pump, driven for you by `boot_pump`), `transport_close`,
`wire_link_quality`, and the succession handoff all dispatch through that remembered
transport. A wire opened the RAW way (`gd.host` by hand, then `wire_attach`) never named one
and reads as ENet. This is safe because every ENet verb class-checks the installed peer and
answers `ok = false` when it is something else.

Shipped records: `netgd.ENET`, `netgd.WEBRTC`, and `ksteam.TRANSPORT`
([steamgd.md](steamgd.md)). A fourth transport fills one record and inherits every door,
the lobby ceremony, the control-plane pump, and the succession config: `Session_Wire` and
the four forwards are byte-for-byte the same in every case.

**Cross-play.** A session never MIXES transports: every peer of one session rides the
same `MultiplayerPeer` flavor (ENet, WebRTC, or Steam), because there is one multiplayer
peer under the SceneMultiplayer and every seat is a peer on it. "Swappable" means the
host picks the door for the whole run, not that peers pick doors per seat: a Steam owner
hosting for a non-Steam friend hosts on ENet or WebRTC, and the Steam friends walk
through that door like everyone else. The neighboring features and their status:

- **LAN discovery** is not shipped. A broadcast ping is easy to hand-roll (UDP broadcast
  the port, `begin_join` what answers); the join-code door already covers the same-LAN
  pair without it.
- **Server browser** is not shipped, and it is not a weekend project: a browser needs a
  directory service, the join-code relay grown up into registration, listing, and
  liveness. The join-code helper covers only the rendezvous step.
- **Splitscreen** means one process, one seat. The session has one identity per process;
  two players on one couch sharing a screen is a game-side input/camera problem the
  toolkit doesn't model.
- **Consoles** are untested, and no platform transports exist here. The engine-free core
  would port; the door glue (a platform's session/invite API as a `MultiplayerPeer`)
  is the real work, and nobody has done it.
