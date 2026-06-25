# Odin Co-op Survivors — 2-player ENet co-op

A networked, server-authoritative 2-player co-op spin on `examples/survivors`, written in pure
Odin with pure `Polygon2D` visuals. The **same** `scripts/game.odin` (`CoopGame`) runs on both
peers: it hosts/joins an ENet session, replicates players and (server-owned) enemies, and proves
the full networked loop across two real processes.

This is the "friendslop" artifact: two instances, one Hosts, one Joins, and they play together.

## Run it windowed (two instances)

```sh
# instance A — press "Host"
nix develop --command bash -c '$GODOT --path examples/coop_survivors'
# instance B — press "Join" (defaults to 127.0.0.1:7777)
nix develop --command bash -c '$GODOT --path examples/coop_survivors'
```

The host's player is blue, the client's is orange. The server streams a swarm of red enemies
that chase the nearest player; both players auto-fire at the nearest enemy in range, the server
applies the damage authoritatively, and the shared score (top-left) stays in sync on both.

> Windowed play-FEEL and true over-the-internet / NAT behavior need a human on a real network.
> The headless test below proves the LOOP (the six guarantees) deterministically.

## Prove the loop headless (two peers over ENet)

```sh
nix develop --command bash -c 'bash examples/coop_survivors/run.sh'   # prints COOP_OK
```

`run.sh` launches two headless Godot processes (a `COOP_ROLE=server` + a `COOP_ROLE=client`,
driven by env: `COOP_ROLE`, `COOP_PORT`, `COOP_ADDR`) on a randomized, bind-retried port with a
wall-clock connection timeout, then asserts — from BOTH processes' stdout — the six co-op
guarantees:

| # | Guarantee | Server sentinel | Client sentinel |
|---|-----------|-----------------|-----------------|
| 1 | connection establishes | `SERVER_SEES_CLIENT id=<cid>` | `CLIENT_SEES_SERVER` |
| 2 | both players on both peers | `PLAYERS_OK on=1 count=2` | `PLAYERS_OK on=<cid> count=2` |
| 3 | client moves, server observes | `SAW_REMOTE_MOVE on=1 peer=<cid>` | `MOVED on=<cid>` |
| 4 | enemy replication | `ENEMY_SPAWN on=1 id=9001` | `ENEMY_SEEN on=<cid> id=9001` |
| 5 | authoritative death | `ENEMY_DEAD on=1 id=9001` | `ENEMY_GONE on=<cid> id=9001` |
| 6 | shared score agrees | `SCORE_SET on=1 value=N` | `SCORE_SET on=<cid> value=N` (same N) |

It is gated into `tests/run_all.sh` (`coopsurvivors|COOP_OK`).

## Replication approach: explicit `@(gd_rpc)`, not Spawner/Synchronizer

The loop is replicated with explicit, server-authoritative `@(gd_rpc)` calls (mirroring the
proven `tests/rpc_net` remote path), NOT `MultiplayerSpawner` / `MultiplayerSynchronizer`.

**Why.** A headless test must be *reliable, not flaky* — that is the hard requirement here. The
high-level replication nodes had never been exercised with Odin scripts, and wiring them into a
deterministic two-process headless assertion is itself a second full implementation with an
unproven, timing-dependent surface (spawnable-scene paths, `SceneReplicationConfig` reading Odin
script `@export` props, visibility/auth filters). The binding *does* ship the classes
(`new_multiplayer_spawner`, `new_multiplayer_synchronizer`, `new_scene_replication_config` and
their methods are all present and instantiable), so they are a valid future milestone — but the
explicit-RPC path gives the same six guarantees today, deterministically (5/5 clean runs). The
project brief explicitly blesses this fallback.

The RPC surface (all on `CoopGame`):

- `spawn_player(peer_id)` — `authority,call_local`: create both avatars on both peers.
- `sync_player_pos(peer_id,x,y)` — `any_peer,unreliable`: each peer mirrors the *other* player.
- `spawn_enemy(id,x,y)` / `despawn_enemy(id)` — `authority,call_local`: server-owned enemy lifecycle.
- `sync_enemy_pos(id,x,y)` — `authority,unreliable`: server streams enemy positions.
- `request_damage(id,amount)` — `any_peer`: a client asks the server to damage an enemy; the
  server mutates the authoritative enemy and, on death, banks score + replicates despawn + score.
- `set_score(value)` — `authority,call_local`: server-authoritative shared score.

New `gd.*` helpers used (added to `godot/Ergonomics_Multiplayer.odin`, mirrored to
`bindgen/upstream/`): `gd.rpc(node, "method", ...variants)` and
`gd.rpc_id(node, peer, "method", ...variants)`.

## Web / WASM

Co-op is ENet/desktop-only. Godot's web export ships no `ENetMultiplayerPeer`, so `gd.host`/
`gd.join` return `false` on wasm32 (the script compiles clean for `freestanding_wasm32` — env
reading goes through Godot's `OS` singleton, not `core:os`). WebRTC/WebSocket web co-op is a
LATER milestone.

## Reused vs new

- **Reused from `examples/survivors`:** the Polygon2D arena/player/enemy visual style, the
  server-authoritative damage→death→score idea, the `//gd:` / `@(gd_method)` / `@(gd_rpc)`
  authoring form, and the two-headless-process orchestration shape from `tests/rpc_net/run.sh`.
- **New:** the whole networked orchestrator (`CoopGame`), the start screen, the explicit-RPC
  replication protocol, the `gd.rpc`/`gd.rpc_id` ergonomic helpers, and `run.sh`'s six-guarantee
  assertions. The single-player `examples/survivors` is untouched.
