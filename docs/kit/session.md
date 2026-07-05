# kit/session — identity, roster, and the driven world

`kit/session` is player identity and the shared roster: who is in this run, under which
stable `Player_Id`, connected or not — plus the machinery that drives [kit/net](net.md)'s
replication walks for you (spawns, deltas, streams, commands, pings, stats, backup
snapshots). This is the package games actually talk to: a game wires a transport, a
factory, and a command hook, then spawns entities and drains events. Like kit/net it is
engine-free — the game script owns the sockets and framing, usually via
[kit/netgd](netgd.md)'s `Session_Wire`.

## The mental model

**A player IS a reconnect token.** The client generates a random u64 secret once and
persists it (`kit/save`'s `persistent_token` does the disk part). The host maps
token → `Player_Id` forever: reconnecting with the same token — from a new transport peer,
after a crash, mid-game — reclaims the same id, and with it name, stats, and owned
entities. `Peer_Id` (a transport seat, reassigned on reconnect, meaningless across runs)
and `knet.Player_Id` (an identity) are distinct types on purpose, so the two can't
silently cross at API boundaries. Departed players stay in the roster as disconnected for
exactly this reason. Tokens are stored hashed, so a backup snapshot can carry the identity
table to a would-be new host without handing anyone the secrets.

**Events, not callbacks.** Everything the game needs to react to comes out of one queue,
drained per frame with `session_poll` — no callbacks into half-initialized script state.
The one synchronous exception is the entity factory's `make` (the registry needs the
pointer before a snapshot can apply); react to the spawn itself via `Ev_Spawned`, which
fires right after.

**Three hookups**, and the session is transport-agnostic:

- **send** — the session hands complete message bytes + a target peer to the game, which
  prefixes *its* session kind byte and ships them (`session_set_transport`).
- **handle_packet** — the game routes its session kind byte back
  (`session_handle_packet`).
- **peer up/down** — the game forwards the transport's connect/disconnect signals
  (`session_peer_disconnected`; session join is a JOIN *message*, not a socket event — a
  connected-but-never-joined peer is nobody).

**Zero role branches.** The same game code runs on host and clients. Commands are issued
through the same generated wrapper everywhere; the host receives `Ev_State_Applied` for
its own ticks and `Ev_Spawned` from its own factory spawns, so event-driven repaint code
never needs an `is_host` check (a host inventory once went stale for six phases because it
didn't get this). The command hook fires for the host's own local issues too.

**Factory symmetry.** `session_spawn_make` routes the *host's* entity creation through the
same `Make_Entity_Proc` clients run, so every entity type's creation is written exactly
once; `session_despawn` runs the installed free proc on the host too. Drop-in mid-game
join is the same code path as being early: a joiner's WELCOME is followed by `SES_WORLD`
(every entity as a spawn tuple) on the same ordered channel, so the joiner materializes
everything before any delta can name an unknown id.

## Wire it up (before *_start)

All pre-start wiring survives re-init — call these once in `ready()`:

```odin
session_configure :: proc(s: ^Session, cfg: Session_Config)
session_set_transport :: proc(s: ^Session, user: rawptr, send: Send_Proc)
session_set_factory :: proc(s: ^Session, user: rawptr, make_entity: Make_Entity_Proc, free_entity: Free_Entity_Proc)
session_set_command_hook :: proc(s: ^Session, user: rawptr, hook: Command_Hook)
session_app_route :: proc(s: ^Session, tag: u8, user: rawptr, handler: App_Handler)
```

`Session_Config` holds every tunable; zero-valued fields mean the defaults (a zero config
is the out-of-the-box session). All durations are **seconds** — the session bakes them to
tick counts itself, so changing `tick_hz` never silently rescales your timeouts:

```odin
Session_Config :: struct {
	tick_hz:         int, // net ticks per second (0 = knet.DEFAULT_TICK_HZ, 20)
	interp_delay:    f64, // how far in the past remote entities render
	command_timeout: f64, // prediction auto-revert horizon
	join_timeout:    f64, // client_start -> Ev_Join_Failed horizon
	backup_interval: f64, // backup-host snapshot refresh cadence
	max_players:     int, // NEW joins refused past this many connected (0 = unlimited; rejoins always reclaim their seat)
}
```

The **command hook** is the sanctioned spot for the cross-entity half of a command: a
command proc may only mutate its target (that's what the predict/revert/reject-truth
machinery protects), so "loot chest → items appear in MY bag" is a chest-only proc that
records what it took in a non-replicated scratch field, plus the hook crediting the
issuer's entity on the host — a mutation that reaches everyone as an ordinary delta. The
loser of a race gets a rejected chest command and no credit: phantom items are impossible.

In practice the transport hookup is one line — from cavecrawl's `ready`:

```odin
ksess.session_set_factory(&self.ses, self, cave_make_entity, cave_free_entity)
ksess.session_set_command_hook(&self.ses, self, cave_command_hook)
netgd.wire_attach(&self.wire, self.owner, &self.ses, MSG_SESSION)
netgd.wire_listen(&self.wire, "on_packet", "on_peer_left", "on_net_up", "on_net_down")
```

## Start, drive, drain

```odin
session_host_start :: proc(s: ^Session, name: string)
session_client_start :: proc(s: ^Session, token: u64, name: string)
session_client_join :: proc(s: ^Session)     // transport is connected: ask for a seat
session_client_leave :: proc(s: ^Session)    // graceful goodbye
session_tick :: proc(s: ^Session, dt: f64, now: f64) -> (ticks: int, sampled: int)
session_poll :: proc(s: ^Session) -> (ev: Event, ok: bool)
session_handle_packet :: proc(s: ^Session, from_peer: Peer_Id, r: ^knet.Reader)
session_peer_disconnected :: proc(s: ^Session, peer: Peer_Id)
```

The host is a full player too (name, id, stats) — it just never JOINs over the wire.
Clients call `session_client_start` when they begin connecting and `session_client_join`
once the transport handshake completes; no WELCOME within `join_timeout` produces
`Ev_Join_Failed` instead of hanging on "Joining…" forever.

Call `session_tick(s, delta, knet.now_s())` once per frame: it advances the net ticker
(delta walk, streams, pings, stats, backup refresh, prediction expiry) and stream-samples
remote entities. Then drain:

```odin
for {
	ev, ok := ksess.session_poll(&self.ses)
	if !ok {break}
	#partial switch e in ev {
	case ksess.Ev_Welcomed:  // (client) the host accepted us; the roster is seeded
	case ksess.Ev_Spawned:   // the factory made it and the snapshot applied
	// ...
	}
}
```

The event union: `Ev_Welcomed`, `Ev_Player_Joined` (with `rejoin`), `Ev_Player_Left`,
`Ev_Host_Left` (v1 has no migration — the run is over), `Ev_Join_Failed`,
`Ev_Join_Denied` (`.Full` / `.Locked` / `.Banned` — each a different sentence to the
player), `Ev_Kicked`, `Ev_Spawned`, `Ev_Despawned`, `Ev_Owner_Changed`, `Ev_Blob_Changed`,
`Ev_Stats_Updated`, `Ev_Backup_Received`, `Ev_State_Applied`,
`Ev_Entity_Changed` (opt-in), `Ev_Command_Executed` (host),
`Ev_Command_Confirmed` / `Ev_Command_Rejected` (client; timeouts surface as rejections
with the real seq/entity).

## The replicated world

```odin
session_spawn_make :: proc(s: ^Session, type: Entity_Type, owner := knet.PLAYER_ID_INVALID) -> (entity: rawptr, id: knet.Net_Id)
session_spawn_send :: proc(s: ^Session, id: knet.Net_Id)
session_spawn :: proc(s: ^Session, type: Entity_Type, entity: rawptr, set: ^knet.Command_Set, owner := knet.PLAYER_ID_INVALID) -> knet.Net_Id
session_despawn :: proc(s: ^Session, id: knet.Net_Id)
session_start_replicating :: proc(s: ^Session)
session_teleport :: proc(s: ^Session, id: knet.Net_Id)
session_owner_of :: proc(s: ^Session, id: knet.Net_Id) -> knet.Player_Id
```

Prefer the `session_spawn_make` / `session_spawn_send` pair — two-phase because the spawn
announcement carries a field snapshot: make, set your per-spawn fields, then send.
`session_spawn` remains for games that build entities by hand. From cavecrawl:

```odin
sep, sid := ksess.session_spawn_make(&self.ses, SPEL_TYPE, owner = p.id)
sp := cast(^Spelunker)sep
sp.x = SPAWN_X + f32(i) * 60
sp.y = SPAWN_Y
sp.hp = MAX_HP
ksess.session_spawn_send(&self.ses, sid)
```

`session_start_replicating` is the host's "the world is set up — go live": it commits
shadows, ships the full world to every already-seated client, and from then on the
per-tick delta walk broadcasts and every later joiner gets the world behind its welcome.
`session_teleport` is for the *owner* of a streamed entity declaring a jump (respawn,
level change) so remote screens snap instead of sliding the avatar across the map.

The client-side factory:

```odin
Make_Entity_Proc :: proc(user: rawptr, type: Entity_Type, id: knet.Net_Id, owner: knet.Player_Id) -> (entity: rawptr, set: ^knet.Command_Set)
Free_Entity_Proc :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr)
```

Returning nil from `make` skips the entity safely — the wire carries its length, so
unknown types are stepped over whole.

### Entity blobs

```odin
session_set_blob :: proc(s: ^Session, id: knet.Net_Id, data: []u8)
session_blob :: proc(s: ^Session, id: knet.Net_Id) -> []u8
```

The variable-length escape hatch: one opaque, **author-dirtied** payload per
entity. Deliberately not a field — no diffing (you say when it changed, which
deletes the "how do you memcmp a pointer-bearing value" problem), no
interpolation, no prediction interplay. The host sets it; it ships reliably to
every peer, `Ev_Blob_Changed` fires everywhere (the host included), and — the
real reason it exists — it rides every full snapshot, so late joiners, backup
hosts, and saves carry it with **zero catch-up code**. Cavecrawl carves a
per-floor inscription into the level entity this way; a rejoiner reads it off
the same event as everyone else.

Use per-tick replicated fields for simulation state, app messages for
event-shaped things, and a blob for variable-length state a *new observer*
must be able to see. `session_blob` returns a view (copy it if you keep it),
and re-received duplicates — a rejoin re-delivers the world — are dropped by
version, so the event never double-fires.

## Roster, moderation, stats

```odin
session_player :: proc(s: ^Session, id: knet.Player_Id) -> (Player, bool)
session_roster :: proc(s: ^Session, allocator := context.temp_allocator) -> []Player
session_host :: proc(s: ^Session) -> knet.Player_Id
session_count :: proc(s: ^Session, connected_only := false) -> int
session_set_locked :: proc(s: ^Session, locked: bool)
session_kick :: proc(s: ^Session, player: knet.Player_Id, ban := false) -> (was: Peer_Id, ok: bool)
```

`session_set_locked` is the standard move once a run starts, if drop-in isn't wanted: new
joins are refused with `.Locked`, players already in the roster still reconnect freely.
`session_kick` tells the target it was deliberate (`Ev_Kicked`, not a mystery host-crash);
with `ban` the token bounces off future joins with `.Banned` for the rest of the run (bans
are run-scoped; persist them yourself if forever matters).

Stats are generic named i64 counters on the *player* record — host-accumulated, replicated
to everyone as a full snapshot at ~2 Hz when dirty, and they survive disconnects like
everything else identity-shaped. Column 0 is always "ping", fed by the session itself:

```odin
session_stat_column :: proc(s: ^Session, name: string) -> Stat_Col  // host; idempotent by name
session_stat_find :: proc(s: ^Session, name: string) -> (Stat_Col, bool)
session_stat_set :: proc(s: ^Session, player: knet.Player_Id, col: Stat_Col, value: i64)
session_stat_add :: proc(s: ^Session, player: knet.Player_Id, col: Stat_Col, delta: i64)
session_stat :: proc(s: ^Session, player: knet.Player_Id, col: Stat_Col) -> i64
```

## App messages

`SES_APP` lets packages built on top of the session ([kit/comms](comms.md) is the first)
ride its transport hookup instead of asking the game for another kind byte: register a
handler under a small tag, ship bytes with begin/flush. The session applies its seat gates
before routing — on the host `from` is the resolved sender (unseated peers are nobody and
get dropped); on a client `from` is `PLAYER_ID_INVALID` and the handler checks
`from_peer == HOST_PEER` when authority matters.

```odin
session_app_begin :: proc(s: ^Session, tag: u8) -> ^knet.Writer
session_app_flush :: proc(s: ^Session, to_peer: Peer_Id)
session_app_send :: proc(s: ^Session, to_peer: Peer_Id, tag: u8, bytes: []u8)
session_app_send_to :: proc(s: ^Session, player: knet.Player_Id, tag: u8, bytes: []u8)
```

## Backup hosting and resume

The host periodically ships a complete re-hostable snapshot — identity table (hashed
tokens), roster, allocation cursors, stats, every entity as a spawn tuple — to the eldest
connected client (`Ev_Backup_Received`). Saving a run and surviving a dead host are the
same contract: [kit/save](save.md) wraps `session_snapshot` in a versioned file envelope.

```odin
session_snapshot :: proc(s: ^Session, w: ^knet.Writer)
session_host_resume :: proc(s: ^Session, me: knet.Player_Id, name: string, backup: []u8) -> bool
```

`session_host_resume` is called on a fresh session with the factory already installed;
every other player comes back disconnected and rejoins with their tokens, reclaiming ids,
stats, and owned entities exactly like any reconnect. The dead run's host has no token
(hosts never JOIN), so it returns as a new player. Returns false on a corrupt blob.

Backups also carry the GAME'S campaign bytes — wave directors, AI clocks, whatever the
session can't know — via the same blob split kit/save's envelope makes:

```odin
Backup_Blob_Proc :: proc(user: rawptr, w: ^knet.Writer)
session_set_backup_blob :: proc(s: ^Session, user: rawptr, write: Backup_Blob_Proc)
session_backup_parts :: proc(s: ^Session, allocator := context.temp_allocator) -> (game_blob: []u8, snapshot: []u8, ok: bool)
```

**The takeover recipe** (live in cavecrawl's `cave_lobby_on_takeover`): on `Ev_Host_Left`,
the peer holding a backup splits it with `session_backup_parts` (it returns copies — the
resume's re-init frees the stored payload), wipes its LOCAL world copies (nodes and game
maps — the factory is about to rebuild them), rebinds its transport as a server, calls
`session_host_resume` with its own id, and parses the game blob back. Friends rejoin the
same address with their tokens and reclaim themselves.

**Live migration** makes that hands-free — the missing piece is that everyone must know
WHO carries the torch and WHERE to find them *before* the host dies:

```odin
Ev_Backup_Target :: struct { player: knet.Player_Id } // (host) holder changed — name them
session_set_successor_info :: proc(s: ^Session, info: []u8)
session_successor :: proc(s: ^Session) -> (knet.Player_Id, []u8)
Ev_Succession :: struct { successor: knet.Player_Id } // (client) host gone, torch named
```

The session names WHO (the backup holder); the TRANSPORT knows where — the info blob is
opaque to the session (address:port for ENet via `netgd.peer_address`, a lobby id for
Steam, a room code for WebRTC). It broadcasts immediately and to every later joiner. On
host loss, `Ev_Succession` fires beside `Ev_Host_Left` on every client: the bearer runs
the takeover recipe, everyone else rejoins the info — and because the event RE-FIRES on
every failed reconnect, chasing a successor that hasn't bound yet retries for free (cap
your attempts). Cavecrawl's acid act 4 kills the host with `kill -9` and the run survives
with nobody pressing anything.

## Ownership transfer

Ownership is *which peer's writes stream out* of an entity's owner-stream fields —
carrying, mounting, possession, and dragging a downed friend are all one call, usually
from a command hook:

```odin
session_set_owner :: proc(s: ^Session, id: knet.Net_Id, owner: knet.Player_Id)
```

`PLAYER_ID_INVALID` hands it back to nobody: the entity rests where its last owner left
it (host-authoritative deltas still flow). Every peer gets `Ev_Owner_Changed{id, owner,
prev}` — the new carrier starts gluing the entity to itself off that event, role-free.
Remote screens SNAP across the handoff (the transfer resets the stream ring and bumps the
warp), and the old owner stops streaming by construction — `registry_write_streams` only
walks entities owned by me. In-flight packets from the old owner may land for ~a round
trip; they carry the pre-bump warp, so the first new-warp sample supersedes them with a
snap, never a blend.

## Recipes over existing pieces

Genre staples that need NO new machinery — write them down so nobody builds them twice:

**Character-portable saves** (the Valheim model: your character travels between servers,
worlds stay with their hosts). The character is a client-side blob — bag, appearance,
whatever follows the PLAYER rather than the world. Persist it with [kit/save's](save.md)
file helpers; on `Ev_Welcomed`, ship it to the host on an app tag
(`session_app_send(HOST_PEER, TAG_CHARACTER, blob)`); the host validates and applies it to
your avatar (an ordinary host-authoritative mutation — deltas carry it to everyone). Save
it back on quit and on the host's periodic beat if you're paranoid. The host stays
authoritative: a hacked blob is just input to validate, not truth to obey.

**Private per-player state** (roles, a saboteur, secret objectives). Secrets are
player-addressed app messages — `session_app_send_to(player, tag, bytes)` — not replicated
fields: the delta walk broadcasts by design, and per-recipient field filtering is
complexity this toolkit deliberately refuses (every laptop in the room can already run
Wireshark; a friendslop saboteur's secret survives friends, not forensics). Keep the
secret host-side, tell exactly who needs to know, and let CONSEQUENCES be public state
like everything else.

**Owner-detected events** (a ball drops in the cup, a cart reaches the checkpoint —
anything derived from state some PLAYER's machine simulates). The rule: **position-derived
events belong to the position authority.** If the host adjudicates them off its
stream-sampled copy, the deciding eye runs ~a fifth of a second behind the owner's screen
and everyone watches the ball roll past the hole (puttputt learned this live). Two shapes,
both already primitives — the split is whether the event leaves a *signature in owner state*:

- *State signature* (the common one): the owner's sim applies the event to its OWNED
  fields — snap the ball into the cup and stop — and that rest state streams out like any
  movement. The host runs its own predicate against its copy and fires the authoritative
  CONSEQUENCE (advance the hole, credit the stat) when the signature arrives; convergence
  is guaranteed because the signature is durable, and the wait happens off-screen.
- *No natural signature* (or the consequence needs arguments): the owner issues a
  **predicted command** — instant locally, validated by the host, consequences in the
  command hook. This is the same machinery as every other verb.

This is a recipe, not tooling, on purpose: the predicates and signatures are game logic —
a generic "owner event" message would just be an unvalidated command, strictly worse than
the command loop that already exists.

## Gotchas

- **`Session_Config` durations are seconds, resolved at `*_start`.** `session_init` bakes
  them to tick counts against the configured rate — so configure *before* starting, and
  mid-run read the resolved fields (`session_tick_hz(s)`, `s.pending_max_age`), not `cfg`.
- **`session_init` is re-entrant, deliberately.** `host_start` / `client_start` /
  `host_resume` on a session that already ran tears down the previous *run's* state
  (registry, command ctx, roster, tokens, stats, backup blob) but preserves everything
  wired before start: transport, factory, hooks, app routes, config. Back-to-lobby →
  rehost needs no rewiring; equally, nothing from the old run survives.
- **Rejoins pass the lock and capacity gates by design.** A returning token's seat is its
  own — that is the whole reconnect promise; only a ban shuts a known token out. Don't
  count on `session_set_locked` or `max_players` to keep a specific player out: kick with
  `ban = true`.
- **`session_kick` doesn't sever the socket.** It returns the seat the player held so the
  game can also drop the transport connection (`netgd.wire_drop`) — without that the
  kicked client still holds a socket it can talk on, even though the session ignores
  unseated peers.
- **Deltas carry state, not events** (see [kit/net's gotchas](net.md#gotchas)): a
  replicated byte the host pulses within one net tick never ships. Cavecrawl's match flow
  keeps `level.won` at 1 for the whole end screen and every peer reacts to the edge
  locally.
- **The factory's `make` is the one synchronous call into the game** — keep it to
  instantiate-and-return; game reactions belong on `Ev_Spawned`, which fires right after
  (on the host too, via `session_spawn_make`).
- **Hosts don't get client events.** There is no `Ev_Welcomed`/`Ev_Command_Confirmed` on
  the authority (its commands run directly) — but it *does* get `Ev_State_Applied`,
  `Ev_Spawned`/`Ev_Despawned`, and `Ev_Command_Executed`, which is what repaint code
  should key on.

See also: [kit/net](net.md) (the core underneath), [kit/netgd](netgd.md) (the transport
binding), [kit/comms](comms.md), [kit/combat](combat.md), [kit/items](items.md),
[kit/ui](ui.md), [kit/save](save.md), [kit/steamgd](steamgd.md).
