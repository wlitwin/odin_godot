# Co-op Arena — the peer-authoritative "friendslop done right" reference

A pure-Odin / Polygon2D co-op survivors example where **ONE gameplay codebase runs in THREE
modes** — single-player, co-op over native ENet, and co-op in the browser over WebRTC — and the
netcode is **owner / peer-authoritative** so your own actions are instant (no host round-trip).

This is the **canonical co-op reference**. `examples/survivors` remains the single-player
gameplay reference; its co-op layer is retained as the *host-authoritative* variant + the
regression tests for the replication machinery (see its README).

```
nix develop --command bash -c 'bash examples/coop_arena/run.sh'              # single-player  -> ARENA_SINGLE_OK
nix develop --command bash -c 'bash examples/coop_arena/coop_native_run.sh'  # co-op ENet      -> ARENA_NATIVE_OK
nix develop --command bash -c 'bash examples/coop_arena/coop_web_run.sh'     # co-op WebRTC    -> ARENA_WEB_OK
```

To play windowed: open the project in Godot and press **Single Player**, **Host**, or **Join**
on the start screen (WASD to move; weapons auto-fire at the nearest enemy).

## One codebase, three modes

There is no separate "single-player game" and "co-op game". The SAME `arena_player.odin`,
`arena_bullet.odin`, `arena_enemy.odin` and the `ArenaGame` orchestrator (`arena.odin`) run in
all three modes:

- **Single-player == host-with-no-peers.** Single mode opens no transport at all; the
  authoritative simulation runs exactly as the host's does, the broadcasts simply reach nobody.
- **Transport is chosen at compile time by platform**: native builds use ENet (`gd.host` /
  `gd.join`); the web build uses WebRTC (`gd.webrtc_host` / `gd.webrtc_join` / `gd.webrtc_poll`).
  The same `@(gd_rpc)` methods and `gd.rpc` calls work over either, once connected.
- A headless **scripted session** (`COOP_ROLE` env on native, `?role=` query on web) drives the
  deterministic proofs the tests assert; with no role it shows the windowed start screen.

## The authority model (the whole point)

**Pawns are OWNER-authoritative.** Each player's pawn has its multiplayer authority set to the
owning peer (recursively, so the child `MultiplayerSynchronizer` streams *from* the owner). The
owner simulates its OWN pawn locally every frame — movement (with momentum) and auto-fire — with
**zero round-trip**. Non-owners run none of that; they just render the synchronized transform.
So your pawn answers your input the same frame you press a key, while still appearing, smoothly
synced, on the other screen. (See the gate in `arena_player.odin`:
`if !node_is_multiplayer_authority(owner) { return }`.)

**Projectiles are OWNER-authoritative + deterministic-local.** When a peer auto-fires, it spawns
its bullet **locally, immediately** (it sees its own shot with no network delay) and *then*
broadcasts `fired(origin, dir)`; every other peer spawns a matching **ghost** bullet that flies
the same path. Only the firing peer's own bullet resolves hits — when it overlaps an enemy it
authoritatively applies + **broadcasts** the damage/kill (`damage`, `call_local`), and peers
**trust it** (no anti-cheat — by design). This is the opposite of the host-authoritative
anti-pattern (client RPCs the host to spawn its bullet, then waits for it to come back).

**Enemies are a shared horde: HOST-authoritative spawn + movement, PEER-authoritative damage.**
The host spawns enemies through a `MultiplayerSpawner` (auto-instantiated on every client) and
moves them toward the nearest pawn; a `MultiplayerSynchronizer` streams the host's `position` +
the spawn-once `id`. Because a horde isn't something a player *inputs*, host authority there is
not perceived as input lag. **Damage/death is peer-authoritative**: `hp` is tracked locally on
every peer and decremented by the broadcast `damage` RPC (whoever's bullet hit), so both peers
agree on every death; the host (the node owner) frees the node and the spawner replicates the
despawn. `hp` is therefore deliberately *not* in the synchronizer config.

> Scaling note: for hundreds of enemies you'd switch to *deterministic-local* enemies (host
> broadcasts spawn seeds; every peer simulates the horde identically, only deaths are broadcast)
> to remove per-enemy position streaming. Host-authoritative positions are fine at this scale and
> keep the example simple.

## Replication gotchas honored (from `tests/repl_spike`)

- `SceneReplicationConfig` is configured **in the `.tscn`** (a `SubResource` referenced by the
  `MultiplayerSynchronizer`), never built in `_ready`. See `arena_player.tscn` / `arena_enemy.tscn`.
- The `MultiplayerSpawner` is built on **every** peer in `_ready` (the client's spawner is what
  instantiates the host's spawns).
- The host's `queue_free` of an enemy is **not** paired with an explicit despawn RPC — the
  spawner replicates the despawn; an explicit RPC would double-free (`ERR_UNAUTHORIZED`).

## What the headless tests prove

| mode | sentinel | proves |
|------|----------|--------|
| single | `ARENA_SINGLE_OK` | unified codebase solo: move, auto-fire kills, XP/level, contact death |
| native (ENet) | `ARENA_NATIVE_OK` | connection; both owner-auth pawns on both peers; **owner-local move replication**; spawner enemy + position sync; **OWNER-LOCAL bullet immediacy** (`BULLET_LOCAL` on the firer the same tick + `BULLET_REMOTE` on the other peer — local-first, no host round-trip); **peer-authoritative kill agreed by BOTH peers**, credited to the firer; despawn replication; XP to the firer |
| web (WebRTC) | `ARENA_WEB_OK` | the same owner-auth guarantees, in two real browsers over a browser-native WebRTC data channel (gated: `ARENA_WEB_BUNDLED` skip when no Chrome/puppeteer) |

The "OWNER-LOCAL IMMEDIACY" proof is the crux: the firer (the **client**, to make the strongest
case) logs `BULLET_LOCAL` the same frame its local auto-fire timer fires — a direct local spawn,
not a request sent to the host — and the host only later logs `BULLET_REMOTE` when the broadcast
arrives. No round-trip gates the owner seeing its own shot.

## Deploying internet co-op (room-code lobby)

The web build pairs two friends through a **room-code lobby** over a real signaling server — the
deployable path, not a localhost-only demo:

1. **Stand up a signaling relay** reachable by both players at a public `wss://HOST/rtc`. ANY
   server speaking the small JSON wire protocol below works; a Node reference implementation
   ships at `tests/webrtc/signal_server.mjs` (the maintainer runs an Elixir implementation of
   the same protocol in production).
2. **Host** opens the page, sets the signaling URL, presses **Host**, and gets a short **ROOM
   CODE** (e.g. `WATR`) displayed to share (text it to your friend).
3. **Friend** opens the page, types that code into the room field, presses **Join**. Both jump
   straight into the arena once the WebRTC data channel comes up.

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

## What still needs a human

The architecture + the room-code signaling are proven headless (local-first immediacy +
replication + owner-auth kills, all three modes; host `create`→code→`join`→WebRTC RPC across two
real browsers — `WEBRTC_OK` / `ARENA_WEB_OK`). What still needs a **real deploy + a person**:
**play-feel under real latency, and cross-NAT traversal** — two machines on different networks, a
public `wss://HOST/rtc` relay, and (for symmetric NAT) a TURN server. Localhost needs none of that,
so the tests prove the PROTOCOL + lobby but not internet NAT punching.

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
