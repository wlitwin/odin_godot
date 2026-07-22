# 6 · The shape of a shippable game

This post covers what takes a game from "my friends can connect" to
something you would hand to strangers: persistent identity, saves, host
migration, Steam and web transports, and the testing habit that keeps them
honest. Most of it is one call plus a concept the earlier posts already gave
you.

## Persistent identity

`ksave.token` gives each player a persistent identity: an env var for tests,
a file under `user://` for real, and an opt-in per-instance salt for
same-machine testing. Seats key on tokens, not connections, so:

- **Crash and rejoin** → same seat, same stats, same entities. There is no
  lobby re-negotiation, and no "player 2 is now player 5."
- **Kick and ban** apply to the *person*, not the socket
  (`session_kick(player, ban)`).
- **A locked session** (`session_set_locked`) still admits returning
  identities. Their seat is theirs.

Tokens are hashed on the host and never relayed to other peers.

## Saves

Because the session replicates state, it can serialize the whole world at any
moment, and it does so continuously, for late joiners. A save file is that
same serialization written to disk:

```odin
ksave.save_write(&self.ses, &w, GAME_VERSION, my_campaign_blob)  // save
blob, err := ksave.resume(&self.ses, name, path, GAME_VERSION)   // the whole Resume button
```

Identity, stats, every entity, and every replicated field are carried. Your
blob holds only what the session can't know (AI clocks, wave director). A
resumed save is a reconnect: friends rejoin a resumed run with their tokens
exactly as they would after any drop.

## Host migration

Backup snapshots stream to a designated client every few seconds. On host
loss, that client **rebinds as the server, resumes the session from the
backup, and everyone else auto-rejoins with their tokens**, all of it
hands-free, mid-run. The test suite proves it by `kill -9`-ing the host
process.

Your part is wiring two events and providing an address (`Ev_Backup_Target`
/ `Ev_Succession`). The party keeps playing; nobody re-lobbies. This works
because state, not a stream of in-flight messages, is what gets replicated;
there is no list of pending RPCs to lose.

## Transports: Steam and web

Everything above runs over plain ENet: localhost, LAN, a VPS. The session
sits behind Godot's MultiplayerPeer abstraction, so shipping over Steam is
the lobby ritual and nothing else: create or join a Steam lobby, hand the
peer to the same wire, and invite through the overlay. Gameplay code,
replication, prediction, and migration are untouched. The browser export
runs the same session over WebRTC.

## Testing under latency

Multiplayer bugs live in timing, latency, and role asymmetry: places a unit
test can't reach and a quick playtest samples only once. The kit games test
themselves against exactly those conditions:

- launch **two or three real game processes** headless, over real sockets,
  with **120ms injected latency**;
- a driver script plays each role through the game's own `@(gd_method)`
  surface (host, join, act, kill the host mid-run);
- each process prints one-line facts (`GOLF_CLAIM kind=1`,
  `GOLF_GEM_GONE kind=1`), and the harness greps that every peer saw what it
  should, including that the *observer's* screen presented the effect, not
  just the actor's.

The addon ships the harness template (`build/template/test/` +
[kit/testing](../kit/testing.md)); adapting it to a new game is an
afternoon. When your acceptance test is green under injected latency, you can
ship.

## Where to go next

1. **[Getting Started](../getting-started.md)** covers the toolchain through
   moving a node, if you haven't already.
2. **[Build a game in a day](../kit/build-a-game-in-a-day.md)** is the
   step-by-step recipe: lobby → entity → movement → verbs → combat → levels
   → save → migration → Steam, each brick under an hour.
3. **Read a finished game against it**, such as `examples/cavecrawl` (every
   toolkit system in one project), and keep [kit/](../kit/index.md) open
   as the per-package reference.
4. **Then build yours**, one brick per session, and keep the acceptance test
   green before the next brick.

None of this asked you to be a network programmer. You wrote structs with
tagged fields, verbs that return bool, and presentation procs: single-player-
shaped code under a discipline. What that discipline buys is reconnects,
drop-in joins, saves, host migration, and honest-feeling latency, and you
keep the editor, the scene tree, and the engine you already know.
