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
entities. The one gate: a reclaim only takes a seat that is no longer CONNECTED. A known
token walking in while its seat is live is a second instance sharing the identity file
(a couch test, extra browser tabs — same-origin storage hands every tab the same token)
and is seated as a NEW player; the transport reaps genuinely dead sockets within seconds,
after which the reclaim proceeds as ever. `Peer_Id` (a transport seat, reassigned on reconnect, meaningless across runs)
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
	fingerprint:     u64, // wire-contract hash override (0 = the generated default) — see below
}
```

**The version door — on by default.** Two builds whose replicated
declarations disagree don't get an error — they get GARBAGE: the descriptors
are positional, so a skewed peer misparses every delta into the wrong fields,
the least debuggable failure a playtest can produce. scriptgen closes that
door without any wiring: it hashes the package's whole wire contract
(replicated field order/types/lanes, verbs, entity ids, input structs
field-by-field, fact tuples, rpcs) into the generated `NET_FINGERPRINT`, and
the guard file registers it as the session default at load. The join carries
it: a mismatch is refused as `Ev_Join_Denied{.Version}` ("your build and the
host's disagree"), and a checked host also refuses fingerprint-less clients
(pre-check builds). Comment edits and formatting never move the hash; a
renamed field does (over-refusal — rebuild both ends — is harmless; a type
change slipping through would be the disaster). The session folds its own
`PROTOCOL_REV` in, so a kit upgrade that changes the wire refuses skewed
peers even when the game's declarations didn't move.

`Session_Config.fingerprint` is the override: leave it 0 (the default) to use
the generated value, set it for a hand-rolled multi-module contract, or set
`ksess.FINGERPRINT_NONE` to disable the gate on purpose (hand-built
descriptors, tests — a session with no generated fingerprint at all is simply
unchecked, as before).

The cross-entity half of a command — a command proc may only mutate its target
(that's what the predict/revert/reject-truth machinery protects) — lives in the verb's
name-paired **[`<verb>_then` consequence](net.md#consequences-verb_then)**: "loot chest
→ items appear in MY bag" is a chest-only proc that *returns* what it took, plus a
`chest_take_then` crediting the issuer on the host — a mutation that reaches everyone
as an ordinary delta. The loser of a race gets a rejected chest command and no credit:
phantom items are impossible. The consequence's `game` param is the factory's `user` —
the session's one game pointer. (The untyped command hook underneath remains for
*generic* reactions; see [hooks](#command-hooks-the-generic-layer-under-_then).)

In practice the transport hookup is one line — from cavecrawl's `ready`:

```odin
ksess.session_set_factory(&self.ses, self, cave_make_entity, cave_free_entity)
netgd.wire_attach(&self.wire, self.owner, &self.ses, MSG_SESSION)
netgd.wire_listen(&self.wire, "on_packet", "on_peer_left", "on_net_up", "on_net_down")
```

## Start, drive, drain

([kit/boot](boot.md) drives this whole section for you — `boot_host`/
`boot_join` call the starts, `boot_pump` ticks and drains. What follows is
the layer underneath, which stays public for games that want the ritual
their own way.)

```odin
session_host_start :: proc(s: ^Session, name: string, token: u64 = 0, dedicated := false)
session_client_start :: proc(s: ^Session, token: u64, name: string)
session_client_join :: proc(s: ^Session)     // transport is connected: ask for a seat
session_client_leave :: proc(s: ^Session)    // graceful goodbye
session_tick :: proc(s: ^Session, dt: f64, now: f64) -> (ticks: int, sampled: int)
session_poll :: proc(s: ^Session) -> (ev: Event, ok: bool)
session_handle_packet :: proc(s: ^Session, from_peer: Peer_Id, r: ^knet.Reader)
session_peer_disconnected :: proc(s: ^Session, peer: Peer_Id)
```

The host is a full player too (name, id, stats) — it just never JOINs over the wire.

**Dedicated servers**: `session_host_start(…, dedicated = true)` makes the
authority a SERVER, not a player. Its seat is flagged `Player.dedicated` on
every roster (the welcome carries it, so clients know too): games skip it when
spawning avatars (`if p.dedicated {continue}`), the kit lobby/scoreboard hide
it, `session_count(players_only = true)` doesn't count it, `max_players` caps
humans only — and **succession never arms** (a dead server restarts; migration
is the peer model's answer to a *player*-host leaving). The friendslop
friends-host-for-friends model is untouched; this is the always-on/public
escape hatch. One call door: [`kboot.boot_serve`](boot.md); proof:
`examples/slopball/server_run.sh`.
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
	case ksess.Ev_Spawned:   // BORN, on every peer: entity exists AND its spawn-time fields are set
	                         // (host hears its own at spawn_send/session_spawn — dress/reveal here)
	// ...
	}
}
```

### Event halves (`<game>_<event>`) — the switch, generated

A [kit/boot](boot.md) game never writes that switch. Each event pairs by
name with a plain proc on the game shell (the class with the `kboot.Boot`
field), and scriptgen generates `<snake>_events(self, events)` — the
dispatch — from whatever you declared. Undeclared events are skipped; that
IS the `#partial`:

```odin
cave_lobby_player_joined :: proc(self: ^CaveLobby, id: knet.Player_Id, rejoin: bool) {
	// every peer: repaint, log
}

// The AUTHORITY consequence — comms lines, fielding a late joiner. The
// generated dispatch holds the is_host gate; the half never checks a role.
cave_lobby_player_joined_then :: proc(self: ^CaveLobby, id: knet.Player_Id, rejoin: bool) { ... }

// in process(): the two generated calls, role-free at the call site
events, marks, ticks := kboot.boot_pump(&self.boot, delta, now_s())
cave_lobby_step(self, ticks)      // the coop authority step, if declared (sim.md)
cave_lobby_events(self, events)
```

The half names are the event names (`_welcomed`, `_player_joined`,
`_player_left`, `_host_left`, `_join_failed`, `_join_denied`, `_kicked`,
`_backup_target`, `_succession`, `_backup_received`, `_owner_changed`,
`_blob_changed`, `_stats_updated`, `_state_applied`, `_command_executed`,
`_command_confirmed`, `_command_rejected`) — except the entity cluster,
which wears an `entity_` prefix (`_entity_spawned`, `_entity_resynced`,
`_entity_despawned`, `_entity_changed`) so it can never be mistaken for the
[census hooks](boot.md): the census `<entity>_spawned` fires BEFORE the
spawn tuple's fields apply (wiring), `<game>_entity_spawned` fires after
(the initial-dress home). Each half's params are the event's fields,
positionally; a mispaired shape or a one-edit-typo'd name is a build error
with the fix spelled out, never a proc that silently doesn't fire.

**Role gates are generated, both kinds.** A two-role event (`player_joined`,
`player_left`, `entity_spawned`, `owner_changed`, `blob_changed`) may
declare a `_then` half — authority only, the event's consequence. A
single-role event gets its annotation ENFORCED at dispatch: a `(client)`
event queued just before a mid-batch takeover flipped `is_host` dies at the
generated gate instead of re-running takeover code (a host death often
lands as TWO transport signals, so `Ev_Succession` can queue twice in one
batch — the gate is why the game's succession half needs no `is_host` and
cavecrawl's carries none). A `_then` on a client-only event ("the authority
never hears Ev_Kicked") or a host-only one ("Ev_Backup_Target is already
authority-only") is a build error.

The event union: `Ev_Welcomed`, `Ev_Player_Joined` (with `rejoin`), `Ev_Player_Left`,
`Ev_Host_Left` (alone it ends the run; with [succession](#backup-hosting-and-resume)
armed, `Ev_Succession` fires beside it and the run survives), `Ev_Join_Failed`,
`Ev_Join_Denied` (`.Full` / `.Locked` / `.Banned` / `.Version` — each a different
sentence to the player), `Ev_Kicked`, `Ev_Spawned`, `Ev_Resynced` (a KNOWN entity's fields caught up
wholesale — interest re-entry, a snapshot over live state; generated
[`<field>_edge` halves](net.md#edges-class_field_edge--presenting-delta-lane-changes)
re-seed themselves silently, so this event is only for hand-rolled edge
scratch, which re-seeds here or presents the missed changes as fresh events),
`Ev_Despawned`, `Ev_Owner_Changed`,
`Ev_Blob_Changed`, `Ev_Stats_Updated`, `Ev_Backup_Received`, `Ev_State_Applied`,
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

Spawning is two-phase because the announcement carries a field snapshot:
make, set your per-spawn fields, then send. A [kit/boot](boot.md) game
spawns TYPED — every `entity=Name:id` tag generates a `<entity>_spawn`
helper (the tag already knows the struct, so the `TYPE` const and the
rawptr cast stop existing at spawn sites), paired with the one role-safe
announce `kboot.boot_spawn_send`. From cavecrawl:

```odin
sp, sid := spelunker_spawn(&self.boot, owner = p.id)
sp.x = SPAWN_X + f32(i) * 60
sp.y = SPAWN_Y
sp.hp = MAX_HP
kboot.boot_spawn_send(&self.boot, sid)
```

(For a TICKING entity the same helper routes through `boot_fire_spawn`: the
host mints the real entity, a client a predicted one — sim.md's fired
projectile.) The raw `session_spawn_make`/`session_spawn_send` pair stays
public underneath, and `session_spawn` remains for games that build
entities by hand.

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

Games rarely write one anymore: tag each exported entity scene with
`entity=Name:id` and [kboot.boot_entities](boot.md) installs the GENERATED
factory (scene under `boot.world`, node ledger, typed `*_spawned`/`*_freed`
census hooks). `session_set_factory` remains the escape hatch for exotic
creation, and returning nil from `make` skips the entity safely — the wire
carries its length, so unknown types are stepped over whole.

### Entity blobs

```odin
session_set_blob :: proc(s: ^Session, id: knet.Net_Id, data: []u8)
session_blob :: proc(s: ^Session, id: knet.Net_Id) -> []u8
```

The variable-length escape hatch — the RARE-CHANGE arm of
[net.md's collections stance](net.md#collections--the-dynamic-stance)
(bounded state takes a fixed array; a live collection of things takes
entities): one opaque, **author-dirtied** payload per
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

**The client-column trap, defused**: `session_stat_column` registers and runs on
the HOST (typically in your Start handler) — a `Stat_Col` you stored there is
zero-value on every client. Handles are 1-BASED so that zero value is
`STAT_COL_INVALID`, and every read/write **asserts on it with the fix in the
message** instead of silently returning column 0 (the auto-fed ping — homestead's
acid once caught a resource gate passing on 254 milliseconds of latency). On any
peer that didn't register the column, resolve BY NAME with `session_stat_find`
(cheap — do it per read).

## Command hooks (the generic layer under _then)

Per-verb consequences belong in [`<verb>_then` procs](net.md#consequences-verb_then) —
typed, name-paired, next to the verb. The untyped hooks remain underneath for
*generic* reactions that cut across verbs: metrics, acid-test receipts, replay
logs — anything keyed on "a command ran" rather than on one verb's meaning.
Route by type to avoid classifying entities by hand (command ids collide
across types — every type's first command is 0):

```odin
ksess.session_set_type_hook(&self.ses, CHEST_TYPE, self, chest_hook)  // wins
ksess.session_set_command_hook(&self.ses, self, game_hook)            // catch-all for the rest
```

A routed type's hook receives exactly that type's commands. The host's own
local issues and clients' commands land in the same dispatcher, which runs
AFTER the verb's `_then`. Survives session starts, like everything wired in
`ready()`.

## Interest management (area of interest)

**Existence global, freshness local.** Every peer still knows every entity —
spawns, despawns, joins, saves, and migration backups are never filtered, so
everything those give you for free stays free. What interest filters is the
per-tick STATE traffic: a peer only receives deltas and owner-stream samples
for entities near its **focus**. Off by default.

```odin
// host, once — the locator lends the session eyes (it can't read your fields):
ksess.session_set_interest(&self.ses, 800, 120, self, my_locator)
my_locator :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) -> (x, y: f32, always: bool) {
	// return each entity's position; `always = true` for placeless entities
	// (the world/level entity, global timers) — relevant to everyone, forever.
}
// host, every frame: where each player is looking from (their avatar):
ksess.session_set_focus(&self.ses, pid, avatar.x, avatar.y)
```

Mechanics worth knowing:

- **Re-entry resync.** A filtered delta is gone forever, so when an entity
  ENTERS a peer's interest the host sends that peer one full spawn tuple (the
  same reconcile path a rejoin uses): fields and blob catch up at once. The
  catch-up announces itself as `Ev_Resynced` (not a second `Ev_Spawned` — the
  entity was never gone on this peer). The jump is history, not gameplay:
  generated `<field>_edge` halves re-seed silently by construction; any
  hand-rolled `seen_*` scratch re-seeds off the event, or wounds taken while
  out of interest present as fresh hits on re-entry. `hysteresis` widens the
  exit edge (enter at `radius`, leave at `radius + hysteresis`) so
  border-dancers don't thrash this.
- **Streams route via the host.** Owners send their batches to the host
  instead of the transport's blind relay (the packets passed through that
  machine anyway — no extra hop), and the host forwards per-recipient at
  entity granularity. Streams need no resync: samples are absolute.
- **Stale ghosts are yours to present.** An entity out of interest keeps its
  last-known state on that peer's screen — frozen, not gone. Dim it, fog it,
  or leave it; that's a game choice, deliberately.
- **A peer with no focus yet receives everything** — filtering starts when
  you start saying where they are. Commands, stats, chat, and everything
  reliable-and-rare stay unfiltered.

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
stats, and owned entities exactly like any reconnect. The dead run's host reclaims its
own seat the same way when it passed a token to `session_host_start` (with none, it
returns as a new player). Returns false on a corrupt blob.

Backups also carry the GAME'S campaign bytes — wave directors, AI clocks, whatever the
session can't know — via the same blob split kit/save's envelope makes:

```odin
Backup_Blob_Proc :: proc(user: rawptr, w: ^knet.Writer)
session_set_backup_blob :: proc(s: ^Session, user: rawptr, write: Backup_Blob_Proc)
session_backup_parts :: proc(s: ^Session, allocator := context.temp_allocator) -> (game_blob: []u8, snapshot: []u8, ok: bool)
```

Don't hand-serialize those bytes: tag the host-local fields `gd:"backup"` and scriptgen
generates the version-hashed write/read pair (POD, `map[POD]POD`, `[dynamic]POD`) — see
[save](save.md#declaring-the-game-blob--gdbackup). The proc above is what you wire the
generated writer into.

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
Steam, a room code for WebRTC). For ENet and WebRTC the whole rendezvous ceremony —
minting the reserved room, wording the torch, raising the heir, the knock-on-a-timer
chase — is [`netgd.Succession`](netgd.md#succession-the-rendezvous-ceremony-written-once),
written once. It broadcasts immediately and to every later joiner. On
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

**Player-to-player trade** (the mediating entity — every true multi-party
transaction). A trade mutates TWO players' bags atomically, and a command may
only mutate its target — so make the TRANSACTION the target. The trade window
is an ordinary entity the host spawns when two players shake hands: its
replicated fields are the offer slots (item + count, a *reference* — the bags
stay untouched until commit) and one confirm byte per side. Every edit is a
single-target predicted command on the Trade, which means every trade race is
already solved by machinery you have: two edits to the same slot serialize in
host arrival order, the loser reverts through reject-truth like any contended
chest.

```odin
Trade :: struct {
	owner:      gd.Node2d,
	net_id:     knet.Net_Id,
	a, b:       u64 `gd:"replicate"`, // the two Player_Ids at the table
	offer_a:    [4]kitems.Slot `gd:"replicate"`,
	offer_b:    [4]kitems.Slot `gd:"replicate"`,
	confirm_a:  bool `gd:"replicate"`,
	confirm_b:  bool `gd:"replicate"`,
	state:      u8 `gd:"replicate"`, // OPEN / DONE / FAILED — an edge every screen words
}

// WHICH seat is acting is never an argument — it's derived from the ISSUER.
// The verbs below declare `by: knet.Player_Id` right after the receiver, so
// the framework fills it with the true issuer (it never rides the wire): a
// hostile peer cannot edit or confirm the OTHER side of the table, and a
// spectator's command finds no seat and rejects.
trade_seat :: proc(self: ^Trade, by: knet.Player_Id) -> (side: u8, seated: bool) {
	if u64(by) == self.a {return 0, true}
	if u64(by) == self.b {return 1, true}
	return 0, false
}

// THE DUPE-GUARD, single-target and therefore race-proof: ANY offer edit
// clears BOTH confirms in the same verb, so the switch-the-item-at-the-last-
// second scam is structurally dead — a confirm racing an edit lands on
// cleared state and the commit below refuses.
@(gd_command = "predict")
trade_offer :: proc(self: ^Trade, by: knet.Player_Id, slot: u8, item: u16, count: u16) -> bool {
	if self.state != TRADE_OPEN {return false}
	side, seated := trade_seat(self, by)
	if !seated {return false}
	(side == 0 ? &self.offer_a[slot] : &self.offer_b[slot])^ = {kitems.Item_Id(item), count}
	self.confirm_a = false
	self.confirm_b = false
	return true
}

@(gd_command = "predict")
trade_confirm :: proc(self: ^Trade, by: knet.Player_Id) -> (ok: bool, sealed: bool) {
	if self.state != TRADE_OPEN {return false, false}
	side, seated := trade_seat(self, by)
	if !seated {return false, false}
	if side == 0 {self.confirm_a = true} else {self.confirm_b = true}
	return true, self.confirm_a && self.confirm_b // the second confirm seals it
}

// The NOTARY: the confirm's consequence, host only. The verb could only see
// the table; the consequence sees the world — it re-validates that both
// offers still sit in their bags (someone may have dropped a promised item
// mid-trade) and either moves everything or fails the whole table. Both
// outcomes are ordinary host mutations: deltas carry the verdict and the
// items to every screen at once, and phantom items are impossible — nothing
// was predicted into anyone's bag.
trade_confirm_then :: proc(game: ^MyGame, self: ^Trade, by: knet.Player_Id, sealed: bool) {
	if !sealed {return}
	if game_move_offers(game, self) { // validate both bags, then swap
		self.state = TRADE_DONE
	} else {
		self.state = TRADE_FAILED // the run words it; the goods never moved
	}
}
```

What falls out free is the point: the trade is an entity, so a mid-trade
host migration resumes with the window intact, a reconnecting player finds
their table where they left it, and a late joiner spectating the market sees
it — zero catch-up code. `Ev_Player_Left` is the one edge you own: the host
despawns any table naming the departed (their seat may reclaim it later, but
an open offer must not outlive its owner's presence). Escrow is the variant
when a promised item must not be double-promised to two windows — the offer's
`_then` moves the item bag→table on the host instead of referencing it, and
the failed-commit path hands it back; start with references and reach for
escrow only when your economy needs the exclusivity. And note what is
deliberately NOT here: predicting the bags themselves. Items landing one beat
after the seal reads as a handshake; items vanishing from your bag on a
rejected prediction reads as theft.

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
binding), [kit/sim](sim.md) (the server-authority resim lane — everything on this page,
identity through moderation, works unchanged beside it), [kit/comms](comms.md),
[kit/combat](combat.md), [kit/items](items.md), [kit/ui](ui.md), [kit/save](save.md),
[kit/steamgd](steamgd.md).
