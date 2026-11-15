<a id="6--the-shape-of-a-shippable-game"></a>

# 6 · Identity, recovery, and transport testing

This post covers persistent identity, saves, cooperative host migration,
Steam and web transports, and integration tests under latency. Each feature
needs session configuration and game-specific recovery or deployment work.

## Persistent identity

`ksave.token` supplies a persistent reconnect token from an environment
variable for tests or a file under `user://` for ordinary play. An opt-in
per-instance salt distinguishes clients in same-machine tests. Seats are keyed
by token, so replacing a connection does not create a new player identity:

- **Crash and rejoin** reclaims the retained seat, stats, and entities. For
  example, a returning player keeps seat 2 rather than receiving seat 5.
- **Kick and ban** apply to the token identity across connections
  (`session_kick(player, ban)`).
- **A locked session** (`session_set_locked`) still admits returning
  identities to their retained seats.

Tokens are hashed on the host and never relayed to other peers.

## Saves

`ksave.save_write` writes the authority's complete session snapshot together
with save metadata and a game blob. That snapshot includes the roster, stats,
and registered entities. It is distinct from a recipient's network snapshot,
which may be filtered and need not contain enough state to resume authority.

```odin
ksave.save_write(&self.ses, &w, GAME_VERSION, my_campaign_blob)  // save
blob, err := ksave.resume(&self.ses, name, path, GAME_VERSION)   // load and resume
```

The session snapshot carries identity, stats, entities, and replicated fields.
Use the game blob for other authority state, such as AI clocks and the wave
director. Restore that state when resuming. Friends then rejoin the resumed
run with their tokens, as they would after a dropped connection.

## Host migration

Backup snapshots stream to a designated client every few seconds. On host
loss, that client rebinds as the server and resumes the session from the
backup. Other peers reconnect with their tokens during the run. The
integration test exercises this path by sending `kill -9`
to the host process.

Wire `Ev_Backup_Target` and `Ev_Succession`, provide the successor's address,
and include game-specific authority state in backups. Recovery uses the last
backup and retained identities so players can continue without creating a new
lobby. Live migration supports the cooperative lane; it requires no installed
simulation lane. Post 7 describes that limit.

## Transports: Steam and web

The native session can use ENet on localhost, a LAN, or a VPS. Godot's
MultiplayerPeer abstraction lets the session use other transports. For Steam,
create or join a lobby, install its peer, and invite players through the
overlay. Replication and command code continue to use the session APIs.
Browser exports use WebRTC and require the corresponding connection setup.

## Testing under latency

Multi-process integration tests exercise packet timing, latency, and
differences between host and client behavior. Kit's game examples test these
conditions by running the game and driving its exposed methods:

- launch **two or three real game processes** headless, over real sockets,
  with **120ms injected latency**;
- a driver script plays each role through the game's own `@(gd_method)`
  surface (host, join, act, kill the host mid-run);
- each process prints one-line facts (`GOLF_CLAIM kind=1`,
  `GOLF_GEM_GONE kind=1`), and the harness greps that every peer saw what it
  should, including that the *observer's* screen presented the effect, not
  just the actor's.

The addon ships the harness template (`build/template/test/` +
[kit/testing](../kit/testing.md)); adapting it to a new game is a
project-specific task. A passing latency test checks this scenario; also
verify the export target, deployment, and failure cases your game supports.

<a id="where-to-go-next"></a>

## Further guides

1. **[Getting Started](../getting-started.md)** covers the toolchain through
   moving a node, if you haven't already.
2. **[Build a game in a day](../kit/build-a-game-in-a-day.md)** is the
   step-by-step recipe: lobby → entity → movement → verbs → combat → levels
   → save → migration → Steam.
3. **Read a finished game against it**, such as `examples/cavecrawl`, and keep [kit/](../kit/index.md) open
   as the per-package reference.
4. **Build and test each addition** before adding the next feature.

These features use the tagged fields, validating commands, and presentation
procedures from the earlier posts. Keep their ownership and timing rules
explicit as you add identity, recovery, and transports to the game.
