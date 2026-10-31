<a id="co-op-arena--the-engine-native-multiplayer-path-end-to-end"></a>

# Co-op Arena — Godot engine multiplayer

> For the [Kit multiplayer toolkit](../../docs/kit/index.md), start with
> `examples/cavecrawl` or `examples/slopball`. Co-op Arena demonstrates direct
> use of Godot's `MultiplayerSynchronizer` and `@(gd_rpc)` APIs in ~1,100 lines
> of networking code. Kit supplies corresponding integration for its examples.

This pure-Odin / Polygon2D survivors game runs in three modes: single-player,
native ENet co-op, and browser WebRTC co-op. Each player simulates their own pawn
and projectiles locally, so movement and firing do not wait for a host round-trip.
Peers trust the firing player's damage reports.

`examples/survivors` remains the single-player gameplay reference; its co-op layer is
retained as the host-authoritative engine-native variant and as regression
coverage for engine replication interop; see its README.

```
nix develop --command bash -c 'bash examples/coop_arena/run.sh'              # single-player  -> ARENA_SINGLE_OK
nix develop --command bash -c 'bash examples/coop_arena/coop_native_run.sh'  # co-op ENet      -> ARENA_NATIVE_OK
nix develop --command bash -c 'bash examples/coop_arena/coop_web_run.sh'     # co-op WebRTC    -> ARENA_WEB_OK
```

To play windowed: open the project in Godot and press **Single Player**, **Host**, or **Join**
on the start screen (WASD to move; weapons auto-fire at the nearest enemy).

## One codebase, three modes

The same `arena_player.odin`,
`arena_bullet.odin`, `arena_enemy.odin` and the `ArenaGame` orchestrator (`arena.odin`) run in
all three modes:

- **Single-player uses the host simulation.** It opens no transport, and
  broadcasts have no remote recipients.
- **Transport is chosen at compile time by platform**: native builds use ENet (`gd.host` /
  `gd.join`); the web build uses WebRTC (`gd.webrtc_host` / `gd.webrtc_join` / `gd.webrtc_poll`).
  The same `@(gd_rpc)` methods and `gd.rpc` calls work over either, once connected.
- A scripted session, selected by native `COOP_ROLE` or the web `?role=` query,
  drives the headless test scenario. With no role, the game shows its start screen.

<a id="the-authority-model-the-whole-point"></a>

## Authority and damage rules

Each player's pawn has its multiplayer authority assigned to the owning peer,
including its child `MultiplayerSynchronizer`. The owner simulates movement and
auto-fire locally each frame; other peers display its synchronized transform.
Local input therefore does not wait for a host round-trip. The check in
`arena_player.odin` is `if !node_is_multiplayer_authority(owner) { return }`.

When a peer fires, it creates its bullet locally and broadcasts
`fired(origin, dir)`. Other peers create visual ghost bullets with the same path.
Only the firing peer's bullet resolves hits. It applies and broadcasts damage
through the `damage` RPC with `call_local`, and peers trust those reports.
The host does not validate hits; this cooperative policy provides no anti-cheat
protection against a dishonest firing peer.

The host creates enemies through `MultiplayerSpawner` and moves them toward the
nearest pawn. Each client's spawner instantiates the matching scene, and
`MultiplayerSynchronizer` sends the host's `position` and spawn-once `id`.
Enemies have no player input awaiting a local response, so their movement can
follow the host.

Damage remains peer-authoritative. Each peer stores enemy `hp` locally and
subtracts the broadcast damage from the firing player. The host owns the enemy's
multiplayer authority and frees dead enemies; the spawner replicates despawn.
`hp` is deliberately excluded from the synchronizer configuration because damage
RPCs update it.

> A possible scaling change for hundreds of enemies is to broadcast spawn seeds
> and simulate the horde locally on each peer, sending only deaths afterward.
> That would require deterministic enemy simulation. This example instead
> streams host positions; it does not benchmark the alternative's capacity.

<a id="replication-gotchas-honored-from-testsrepl_spike"></a>

## Scene replication requirements from `tests/repl_spike`

- `SceneReplicationConfig` is configured **in the `.tscn`** (a `SubResource` referenced by the
  `MultiplayerSynchronizer`), never built in `_ready`. See `arena_player.tscn` / `arena_enemy.tscn`.
- The `MultiplayerSpawner` is built on **every** peer in `_ready` (the client's spawner is what
  instantiates the host's spawns).
- The host's `queue_free` of an enemy is **not** paired with an explicit despawn RPC — the
  spawner replicates the despawn; an explicit RPC would double-free (`ERR_UNAUTHORIZED`).

<a id="what-the-headless-tests-prove"></a>

## Headless test coverage

| mode | sentinel | proves |
|------|----------|--------|
| single | `ARENA_SINGLE_OK` | unified codebase solo: move, auto-fire kills, XP/level, contact death |
| native (ENet) | `ARENA_NATIVE_OK` | Connection, both owner-authoritative pawns visible on both peers, owner movement replication, enemy spawn/position sync, local bullet on the firing tick (`BULLET_LOCAL`) followed by the remote bullet (`BULLET_REMOTE`), matching peer-authoritative kill/credit, despawn replication, and firing player's XP |
| web (WebRTC) | `ARENA_WEB_OK` | The same owner-authoritative cases in two browsers over WebRTC; `ARENA_WEB_BUNDLED` records a skip when Chrome/puppeteer is unavailable |

The "OWNER-LOCAL IMMEDIACY" check uses a firing client. It logs `BULLET_LOCAL`
on the frame its auto-fire timer fires; the host logs `BULLET_REMOTE` after the
broadcast arrives. This checks that the local bullet appears before a round-trip
to the host could complete.

## Deploying internet co-op (room-code lobby)

The web build pairs two players through a **room-code lobby**. To use it across
networks, provide a signaling server reachable by both players:

1. Run a signaling relay reachable by both players at `wss://HOST/rtc` and
   implementing the JSON protocol below. A Node reference is provided at
   `tests/webrtc/signal_server.mjs`; the original deployment notes also report
   an Elixir implementation of the same protocol in production.
2. The host opens the page, sets the signaling URL, presses **Host**, and shares
   the displayed room code, such as `WATR`.
3. The other player opens the page, enters the code, and presses **Join**.
   Both enter the arena when the WebRTC data channel connects.

The signaling URL is configurable: the lobby's URL field, or on web the `?url=` query
(`?url=wss://HOST/rtc`); the join code is the room field or `?room=CODE`. Single-player is
unchanged (no transport, no lobby).

### Signaling wire protocol (raw WebSocket, JSON text frames; server path `/rtc`)

```
client -> server                                  server -> client
  {"type":"create"}                                 {"type":"created","room":"<CODE>","id":1}
  {"type":"join","room":"<CODE>"}                   {"type":"joined","room":"<CODE>","id":<n>}
  {"type":"signal","to":<peerId>,"data":<opaque>}   {"type":"peer","id":<peerId>}
  {"type":"leave"}                                  {"type":"signal","from":<peerId>,"data":<opaque>}
                                                    {"type":"peer_left","id":<peerId>}
                                                    {"type":"error","reason":"no_room"|"full"|"bad_msg"}
```

The server relays `data` (the SDP offer/answer + trickled ICE) **verbatim** — it never parses it.
The host (id 1) creates the offer; the joiner answers. Implemented client-side in
`godot/Ergonomics_WebRtc.odin` (mirrored in `bindgen/upstream/godot/`) via Godot's `WebSocketPeer`
+ JSON; the same `@(gd_rpc)` layer then runs over the resulting `WebRTCMultiplayerPeer`.

### STUN / TURN

`Ergonomics_WebRtc.odin` configures the `WebRTCPeerConnection` with a public **STUN** server
(`stun:stun.l.google.com:19302`) so peers behind ordinary NATs gather server-reflexive candidates.
For **symmetric-NAT** pairs that STUN can't punch, add a **TURN** relay (with credentials) to the
`_ICE_CONFIG_JSON` `iceServers` array — there's a documented slot. Localhost (host candidates)
needs neither, which is why the headless tests don't require STUN.

<a id="what-still-needs-a-human"></a>

## Deployment and playtesting limits

Headless tests cover local bullet response, replication, and peer-authoritative
kills in all three modes. The browser tests exercise host `create`, code sharing,
`join`, and WebRTC RPC across two local browsers (`WEBRTC_OK` / `ARENA_WEB_OK`).
They do not establish internet NAT traversal or play quality under real latency.

Those checks require two machines on different networks, a public
`wss://HOST/rtc` relay, and a TURN server for symmetric NAT. Localhost tests do
not exercise those paths. Playtesting must also assess response and presentation
on the deployed connection.


## Files

- `scripts/arena.odin` — the `ArenaGame` orchestrator (transport, start screen, pawn spawn, host
  enemy spawner, the headless scripted session, and the `fired` / `damage` / `spawn_pawn` RPCs).
- `scripts/arena_player.odin` — the owner-authoritative pawn (local movement + auto-fire).
- `scripts/arena_bullet.odin` — the owner-simulated / deterministic-local projectile.
- `scripts/arena_enemy.odin` — the shared-horde enemy (host position, peer-auth `hp`).
- `scripts/util.odin`, `scripts/boot.odin` — shared helpers + the verbatim cross-DLL init.
- `arena.tscn`, `arena_player.tscn`, `arena_enemy.tscn`, `arena_bullet.tscn` — scenes (the
  replication config lives in the pawn/enemy `.tscn`).
- `run.sh`, `coop_native_run.sh`, `coop_web_run.sh`, `coop_drive.mjs` — the three test harnesses.
