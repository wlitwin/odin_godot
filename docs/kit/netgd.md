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

If you DO hand-roll a `Send_Proc` (the raw-layer path), translate the peer through
`wire_engine_peer(to_peer) -> (engine_peer, ok)` — never cast a `ksess.Peer_Id` to an
engine int. The sentinels don't line up: kit's `BROADCAST_PEER` is `Peer_Id(-1)` (it used
to alias `NO_PEER`'s 0, so a disconnected seat's peer handed to send became an accidental
broadcast), and the engine reads a raw -1 as "all except peer 1" — the server silently
misses every broadcast. `wire_engine_peer` maps broadcast to the engine's 0 and returns
`ok = false` for `NO_PEER`: a disconnected seat's peer reached the transport — drop the
send.

## Session_Wire: the four one-line forwards

`Session_Wire` is the session's transport binding — the ~50 lines every game used to write
by hand (the `Send_Proc` adapter with its kind byte + channel pick, the packet route, the
engine's connection signals, the client's join handshake). In a stock game it lives inside
[kit/boot](boot.md)'s `Boot` (`boot.wire` — `boot_attach` runs the `wire_attach`/
`wire_listen` calls below for you); games that skip boot keep it as a field on the script
struct and wire it directly.

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

## The two buttons — ENet and WebRTC flavors of the one door

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
netgd.web_close(&wire)  // full teardown — retry a failed join, or a successor raising a new room
```

`token` is the host's own reconnect identity (see [session](session.md) — it makes a dead
host reclaimable after a migration). `room` asks the relay to honor a RESERVED code
instead of minting a fresh one — succession rides it: the dying run's host mints
tomorrow's code today, and the heir raises the promised room under it while the crew
knocks on exactly that code (empty = mint, the ordinary host). The web pair differs from
ENet in one structural way: the room code **does not exist yet** when `begin_host_web`
returns — the relay assigns it async. Pump `web_poll` each frame and read it back with
`gd.webrtc_room_code(node)` when it lands; `gd.webrtc_session_state` /
`gd.webrtc_error_reason` narrate the handshake for your lobby. Everything ABOVE these calls — session, muster, commands, replication — is the same
code path on both transports; the branch ends the moment the multiplayer peer installs.

[kit/boot](boot.md) wraps both flavors with the stock lobby ceremony: `boot_host` /
`boot_join` and their `boot_host_web` / `boot_join_web` twins.

### Join codes for NATIVE ENet (code.odin)

"Send your friend a four-letter code" without Steam and without reading out
an IP: the same relay the browser build already talks to (native room mode —
`tests/webrtc/signal_server.mjs` is the reference; the production relay
speaks it at `/rtc`) becomes a phonebook for plain ENet. The host registers
its bound port under a minted code; a joiner trades the code for the host's
observed endpoint; the join proceeds exactly as `begin_join` always did.

**A kit game uses the boot doors** — same shape as every other door, and
`boot_pump` runs the whole rendezvous (the host's minted code lands in the
lobby status and `boot_room_code`; a joiner's resolved endpoint walks through
`boot_join` on its own; a bad code restores the menu with the reason):

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

`examples/hello_net` is the worked consumer of the boot doors (its `run.sh`
join-by-code act proves the full loop against a local relay; with
`HELLO_RELAY` set, its lobby grows the code field). **NAT honesty:** this covers
the same-LAN pair, the port-forwarded or public host, and the common
port-preserving home NAT (the relay hands the host each joiner's observed
endpoint and `wire_punch` warms the mapping with a few UDP packets).
Symmetric NATs it does NOT cover — there is no TURN for raw ENet; when the
connect times out, say so and offer the browser build (WebRTC + TURN) and
Steam, which always work. That trade — a copyable code for most, two spare
doors for the rest — is the stance.

## The disconnect signals are NOT optional plumbing

- Unwired `peer_disconnected`: an alt-F4'd client haunts the roster forever, and the host
  keeps sending to a ghost.
- Unwired `connection_failed`: a failed join hangs on "Joining..." with no way out. The same
  forward handles `server_disconnected` — treating a vanished server as host loss.

A MISSPELLED forward is the same bug wearing a compile-clean coat, so scriptgen validates
every literal method name passed to `wire_listen` / `listen_packets` (and `boot_attach`'s
`methods`) against the script's registered `@(gd_method)`s — a typo is a build error; an
empty string stays a deliberate skip.

## Succession: the rendezvous ceremony, written once

The session names WHO carries the torch ([session](session.md#backup-hosting-and-resume));
`netgd.Succession` owns HOW the survivors find them — extracted from the game
that shipped it (most of scrapyard's 400-line succession file was this):

- **native** — the torch carries "addr:port": the bearer's address as the host
  saw it, plus the seat-derived port the bearer will bind.
- **web** — the relay honors reservations on create, so the host MINTS
  tomorrow's room code today ("web:CODE" in the torch); the heir hosts UNDER
  it and survivors knock on a timer (a browser cannot block, and the heir
  needs a breath to open the room).

Configure once (`Succession{web, signal_url, base_port, token, name}`), then:
`succession_torch` on `Ev_Backup_Target` (host), `succession_raise` /
`succession_chase` from `Ev_Succession` (the heir / everyone else — wipe your
census first; `succession_named` peeks so a no-successor torch leaves the
world standing), `succession_pulse` every frame (the web knock pump — word
its `.Knocking`/`.Gave_Up` steps), and `succession_done` on `Ev_Welcomed`.
The game keeps its campaign blob, its census wipe, and its words — see
scrapyard's `succession.odin` for the worked consumer.

## wire_receive and the kind byte

Every wire packet leads with the game's one message byte (the `kind` passed to
`wire_attach`). `wire_receive` checks `view[0] != wire.kind` and returns early — other kinds
are not the wire's; the game routes those itself *before* calling `wire_receive`. This is how
session traffic shares `peer_packet` with any other raw-bytes protocol the game runs.

## wire_set_latency — the bad-link shim

```odin
wire_set_latency :: proc(wire: ^Session_Wire, ms: int, jitter_ms := 0, loss_pct := 0)
```

Injects one-way **receive** latency (0 disables): every packet this peer receives is held
that long before the session sees it — buffered in the wire, delivered by `wire_pump`. The
delay is app-side, above the transport, so ENet's acks and retransmits still flow at protocol
level; what you are testing is your *game's* feel under real round trips, not the socket's.
The toolkit's own acid tests run at 120ms so predictions are proven to bite instantly while
confirms measurably ride the slow wire.

A slow link is only half the truth — a BAD link wobbles and drops. `jitter_ms` adds a
uniform extra `[0, jitter)` per packet, with one honest constraint: delivery stays FIFO per
sender (the shim sits above ENet's already-ordered channels, and handing packets over
shuffled would break the ordered-reliable contract no real network can break at this
layer). `loss_pct` is channel-honest the same way: a **stream** batch rolls the dice and
vanishes (last-value semantics — the next batch supersedes it, which is the real behavior
of the unreliable channel), while **reliable** traffic must arrive, so its "loss" costs
what loss really costs a reliable channel: a retransmit's worth of extra delay. kit/boot
wires all three off env for you:

```sh
QD_LATENCY=120 QD_JITTER=30 QD_LOSS=3 ./run_two_windows.sh   # <ENV>_LATENCY/_JITTER/_LOSS
```

## The wire gauge — bytes by kind, and the link's own truth

Every framed byte the wire sends or receives is tallied by session message kind
(state, stream, cmd, spawn, app — with app split by its tag byte, so the sim
lane's traffic is named, not lumped), windowed per second. Two reads:

```odin
netgd.wire_traffic(&wire) -> string
// "rx 3.2k state 2.1 stream 0.8 app16 0.2 · tx 0.4k cmd 0.3"
netgd.wire_link_quality(&wire, peer) -> (rtt_ms, jitter_ms, loss_pct, ok)
```

`wire_traffic` is the [netgraph](ui.md)'s traffic row — fill `Net_Stats.traffic`
with it and you can watch a chatty field's bytes move as you tune `wire=f16`,
stream rates, or interest. `wire_link_quality` reads ENet's own per-peer
statistics (smoothed rtt, rtt variance, packet loss ×`PACKET_LOSS_SCALE`) — the
transport's view, meaningful on clients about the host (`ksess.HOST_PEER`); a
host asks per client peer. quickdraw's netgraph fill is the worked example.

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
SceneMultiplayer's signals fire identically over any `MultiplayerPeer`. The WebRTC doors
above are the browser story; hosting over Steam instead is covered in
[steamgd.md](steamgd.md) — the `Session_Wire` and the four forwards are byte-for-byte the
same in every case.

**Cross-play.** A session never MIXES transports: every peer of one session rides the
same `MultiplayerPeer` flavor — ENet, WebRTC, or Steam — because there is one multiplayer
peer under the SceneMultiplayer and every seat is a peer on it. "Swappable" means the
host picks the door for the whole run, not that peers pick doors per seat: a Steam owner
hosting for a non-Steam friend hosts on ENet or WebRTC, and the Steam friends walk
through that door like everyone else. The honest stance on the neighbors:

- **LAN discovery** — not shipped. A broadcast ping is easy to hand-roll (UDP broadcast
  the port, `begin_join` what answers); the join-code door already covers the same-LAN
  pair without it.
- **Server browser** — not shipped, and not a weekend: a browser needs a directory
  service — the join-code relay grown up into registration, listing, and liveness. The
  code door is the friendslop-sized piece of that.
- **Splitscreen** — one process, one seat. The session has one identity per process;
  two players on one couch sharing a screen is a game-side input/camera problem the
  toolkit doesn't model.
- **Consoles** — untested, and no platform transports exist here. The engine-free core
  would port; the door glue (a platform's session/invite API as a `MultiplayerPeer`)
  is the real work, and nobody has done it.
