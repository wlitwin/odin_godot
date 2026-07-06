# 6 · The shape of a shippable game

Five posts of mental-model work deserve a payoff ledger. This post is that:
the distance between "my friends can connect" and "I'd hand this to
strangers," and how much of it the model from posts 3–5 already crossed for
you. Almost everything here is one call plus a concept you already have.

## Identity survives everything

Post 3 introduced the token in one sentence; here's what it's quietly
carrying. `ksave.token` gives each player a persistent identity (an env var
for tests, a file under `user://` for real, an opt-in per-instance salt for
same-machine testing). Because seats key on tokens, not connections:

- **Crash and rejoin** → same seat, same stats, same entities. No lobby
  re-negotiation, no "player 2 is now player 5."
- **Kick and ban** stick to the *person*, not the socket
  (`session_kick(player, ban)`).
- **A locked session** (`session_set_locked`) still admits returning
  identities — their seat is theirs.

Tokens are hashed on the host and never relayed to other peers. Moderation
is three calls and it's real.

## Saves are the snapshot you already ship

The state model means the session can serialize the whole world at any
moment — it already does, continuously, for late joiners. A save file is
that machinery pointed at disk:

```odin
ksave.save_write(&self.ses, &w, GAME_VERSION, my_campaign_blob)  // save
blob, err := ksave.resume(&self.ses, name, path, GAME_VERSION)   // the whole Resume button
```

Identity, stats, every entity, every replicated field — carried. Your blob
holds only what the session can't know (AI clocks, wave director). Friends
rejoin a resumed run with their tokens like any reconnect, because a
resumed save *is* a reconnect. You did not write a save system; you
structured state so one was implied.

## The host's cat unplugs the router

The nightmare scenario of friend-hosted games, and the toolkit's flagship
party trick: backup snapshots stream to a designated client every few
seconds, and on host loss that client **rebinds as the server, resumes the
session from the backup, and everyone else auto-rejoins with their
tokens** — hands-free, mid-run, proven in the test suite by `kill -9`-ing
the host process. Your part is wiring two events and providing an address
(`Ev_Backup_Target` / `Ev_Succession`). The party keeps playing; nobody
re-lobbies.

If you've shipped a friend-hosted game before, you know this feature
alone justifies a framework. It is only *possible* because state-is-the-
protocol — there is no list of in-flight RPCs to lose.

## Steam is a transport, not a rewrite

Everything above runs over plain ENet — localhost, LAN, a VPS. Shipping to
friends-of-friends means Steam, and because the session sits behind Godot's
MultiplayerPeer abstraction, the swap is the lobby ritual and nothing else:
create/join a Steam lobby, hand the peer to the same wire, invite through
the overlay. Gameplay code, replication, prediction, migration: untouched.
The browser export runs the same session over WebRTC. Transport is a detail,
which is exactly what your netcode never let it be before.

## The habit that keeps it all true

Every claim in this series is pinned by the same testing pattern, and it's
the one habit to steal even if you steal nothing else. Multiplayer bugs live
in timing, latency, and role asymmetry — places a unit test can't reach and
a quick playtest samples once. The kit games test themselves like this
instead:

- launch **two or three real game processes** headless, real sockets,
  **120ms injected latency**;
- a driver script plays each role through the game's own `@(gd_method)`
  surface (host, join, act, kill the host mid-run);
- each process prints one-line facts (`GOLF_CLAIM kind=1`,
  `GOLF_GEM_GONE kind=1`); the harness greps that every peer saw what it
  should — including that the *observer's* screen presented the post-5
  showings, not just the actor's.

The addon ships the harness template (`build/template/test/` +
[kit/testing](../kit/testing.md)); adapting it to a new game is an
afternoon. Every subtle bug in this series' war stories — the early gem,
the missing particles, a host-migration edge — was caught or pinned by a
grep, not a playtest. When your acid is green under injected latency, you
ship with a confidence GDScript-plus-RPCs never gave you.

## How to actually start

The mental model is the hard part, and you now have it. The build order that
worked for the games this toolkit was proven on:

1. **[Getting Started](../getting-started.md)** — toolchain to moving node,
   if you haven't already.
2. **[Build a game in a day](../kit/build-a-game-in-a-day.md)** — the
   step-by-step recipe: lobby → entity → movement → verbs → combat → levels
   → save → migration → Steam, each brick under an hour. It's terse where
   this series is conceptual; that's now a feature.
3. **Read a finished game against it** — `examples/cavecrawl` (every
   toolkit system in one project) — and keep [kit/](../kit/index.md) open
   as the per-package reference.
4. **Then build yours**, one brick per session, acid test green before the
   next brick. Boring, incremental, and it works.

The pitch, one last time: none of this asked you to be a network
programmer. You wrote structs with tagged fields, verbs that return bool,
and presentation procs — single-player-shaped code under a discipline. The
discipline is the price. Reconnects, drop-in joins, saves, host migration,
and honest-feeling latency are what it buys, and you get to keep the
editor, the scene tree, and the engine you already know.

*— end of the series. Go make something your friends can break.*
