# `kit/session`: players, entities, and replication scheduling

`kit/session` owns the live multiplayer session: stable player identities,
roster, entity lifetime, replication scheduling, commands, pings, stats,
moderation, interest management, and backup snapshots. It drives the lower-level
[kit/net](net.md) registry and replication walks.

The package does not import Godot or own sockets. A game provides a transport
send callback and forwards received packets and peer disconnects. Most Godot
projects use [kit/netgd](netgd.md) or [kit/boot](boot.md) for that integration.

<a id="the-mental-model"></a>

## Session roles and integration

### Player identity

A client presents a random `u64` reconnect token. The host maps that token to a
`Player_Id` for the run. Reconnecting with the same token after the old
connection has ended reclaims the player's ID, name, stats, and owned entities.
Disconnected players remain in the roster so their seats can be reclaimed.

A token cannot take over a seat whose previous connection is still live. In
that case, the new connection receives a new player ID; this matters when local
test instances or browser tabs accidentally share the same persisted token.

`Peer_Id` identifies a current transport connection. `Player_Id` identifies the
gameplay player across reconnects. They are distinct types and should not be
stored interchangeably. Backup snapshots store token hashes, allowing a
successor host to preserve reconnect identity without receiving the secrets.

Use [kit/save](save.md) to persist a token between application launches.

### Events and callbacks

Normal game reactions are queued and drained with `session_poll`. Synchronous
callbacks are reserved for work the session cannot defer: creating an entity,
locating it for interest management, serializing a backup blob, executing an
authority hook, or decoding bytes whose reader is temporary. See
[Three tiers of entry](#three-tiers-of-entry-into-your-code) for the complete
contract.

### Transport boundary

Three connections keep the session transport-independent:

- `session_set_transport` installs a callback that receives complete message
  bytes, destination peer, and channel.
- `session_handle_packet` accepts a session payload routed from the transport.
- `session_peer_disconnected` reports the end of a transport connection. A
  socket connection alone is not a player; the join handshake creates a seat.

### Shared and authority-specific code

Generated command wrappers, entity factories, and queued events provide common
call sites on hosts and clients. Presentation code can normally react to the
same spawn, state, and command events on every peer. Authority-specific work is
still explicit in `_then` halves, authority steps, host lifecycle methods, and
other places where only the authority can mutate shared gameplay state.

### Entity factory and late join

Boot normally provides generated, typed functions: `<type>_spawn`,
`boot_spawn_send`/`boot_spawn_cancel`, and `<type>_despawn`. At the advanced
session layer, `session_spawn_make` sends authority-side creation through the same
`Make_Entity_Proc` used on clients. `session_despawn` similarly calls the
installed free procedure on every role. A late joiner's welcome and complete
world snapshot use the same reliable ordered channel, so entities are created
before later deltas can refer to them.

<a id="wire-it-up-before-_start"></a>

## Configure callbacks before starting

Install these callbacks once in `ready()`, before starting the session. They
remain installed when the session is reinitialized:

```odin
session_configure :: proc(s: ^Session, cfg: Session_Config)
session_set_transport :: proc(s: ^Session, user: rawptr, send: Send_Proc)
session_set_factory :: proc(s: ^Session, user: rawptr, make_entity: Make_Entity_Proc, free_entity: Free_Entity_Proc)
session_set_command_hook :: proc(s: ^Session, user: rawptr, hook: Command_Hook)
session_app_route :: proc(s: ^Session, tag: u8, user: rawptr, handler: App_Handler)
```

`session_reset(s)` ends the live run and frees its roster, registry, queues,
profiles, and snapshots while retaining this pre-start wiring and configuration.
The generated game-network detach uses it when returning to the menu so the
game can attach again later. `session_destroy(s)` also releases the callbacks;
use it when the session value will no longer be used.

`Session_Config` holds the session settings. Zero-valued fields select the
defaults, so a zero-initialized config is valid. All durations are in seconds.
The session converts them to tick counts, preserving timeout durations when
`tick_hz` changes:

```odin
Session_Config :: struct {
	tick_hz:         int, // net ticks per second (0 = knet.DEFAULT_TICK_HZ, 20)
	interp_delay:    f64, // how far in the past remote entities render
	interp_adapt:    bool, // adapt interpolation delay (off by default; interp_delay is the floor)
	interp_delay_max: f64, // maximum adaptive delay in seconds (0 = the Kit default)
	command_timeout: f64, // prediction auto-revert horizon
	join_timeout:    f64, // client_start -> Ev_Join_Failed horizon
	backup_interval: f64, // backup-host snapshot refresh cadence
	max_players:     int, // cap for new seats (0 = DEFAULT_MAX_PLAYERS, 8); reconnects use their existing seat
	change_events:   bool, // emit Ev_Entity_Changed for each dirty entity per tick
	stream_budget:   int, // per-peer owner-stream bytes per tick (0 = unlimited; requires interest management)
	traffic:         Traffic_Config, // authority ingress: reliable, stream, and action token buckets
	fingerprint:     u64, // wire-contract hash override (0 = the generated default) — see below
}
```

`max_players` defaults to eight. Set it to a negative value only when an
unbounded lobby is intentional; reconnects may reclaim an existing seat even
when the room is otherwise full. `change_events` is off by default. Enable it
when the game should repaint only entities touched by a state batch.

`stream_budget` limits owner-stream bytes sent to each peer per network tick. It
requires interest management because per-peer routing is what makes individual
budgets possible. Updates are prioritized by staleness, with distance as a
tiebreaker.

`traffic` bounds what each seated client may send *to* the authority. Reliable
and stream limits are per transport peer; `actions` is a narrower per-player
budget shared by immediate co-op commands and tick-scheduled simulation verbs.
Each `Traffic_Limit` has `packets_per_second`, `bytes_per_second`, and
`burst_seconds` (zero burst means one second). A zero rate leaves that dimension
unlimited; the named profiles install complete bounded values. This is separate
from outbound `stream_budget`, which prioritizes what the authority sends to
each observer and therefore requires interest management.

For a new game, use a named network configuration instead of filling this
struct directly: `kboot.network_profile(.Friends_Coop)`,
`.Listen_Server_Action`, or `.Dedicated_Competitive`. The profiles materialize
and validate `Session_Config` together with the matching `ksim.Lane_Config`,
while still allowing ordinary field overrides. See
[Network profiles](profiles.md).

Schema compatibility checks are on by default. Descriptors are positional, so
peers built with different schemas could interpret valid bytes as different
fields. Before writing generated code, scriptgen recursively validates the
types sent as raw bytes and emits `NET_SCHEMA_CANONICAL`: field paths, wire
kinds and widths, enum storage,
fixed bounds, input classes and constraints, message tags, and action access, prediction,
argument limits, and scheduling. Platform-width integers, implicit-width enums,
pointers, unsupported containers, unresolved nested types, and structs with
hidden padding are build errors. Generated size/alignment assertions check that
the target compiler's layout agrees with scriptgen's schema.

`NET_ABI_FINGERPRINT` hashes that readable schema. The complete generated
`NET_FINGERPRINT` also covers entity ids, presentation events, RPC signatures, and the
session's `PROTOCOL_REV`; the guard registers it as the session default at load.
JOIN carries the fingerprint. Peers with matching fingerprints pass the
compatibility check; a mismatch is refused as `Ev_Join_Denied{.Version}`.
A checked host also refuses fingerprint-less clients
from pre-check builds. Comments and formatting do not change the hash; changing
a path, representation, bound, policy, or schedule does. Rebuild both peers
after a schema change.

Leave `Session_Config.fingerprint` at 0 to use the generated value. Set it to
a custom fingerprint when combining declarations from multiple modules, or
to `ksess.FINGERPRINT_NONE` to disable compatibility checks for hand-built
descriptors or tests. A session with no generated fingerprint is unchecked.

The generated hash cannot detect changes to a content table indexed by a wire
value. It records that a `Slot` is `{item: u16, count: u16}`, but it does not
record which item definition each ID selects. The same limitation applies to
name-to-ID tag tables and other indices into game content. If a build reorders
or renames entries, its fingerprint can still match even though a replicated
`item=1` selects a different definition on the receiving peer.

Use `ksess.session_mix_fingerprint(base, contract)` to include the table's
canonical text in the fingerprint. Pass `base = 0` to combine it with the
generated default; assigning a content hash directly would replace the schema
check. Peers then reject mismatched content tables during admission.
`kitems.items_contract(&table)` produces canonical text for item registries,
sorted so registration order does not matter. Cavecrawl includes its
`GEM`/`TORCH` table this way.

In cavecrawl's `ready`, the game installs its entity factory, attaches the
transport, and registers transport callbacks:

```odin
ksess.session_set_factory(&self.ses, self, cave_make_entity, cave_free_entity)
netgd.wire_attach(&self.wire, self.owner, &self.ses, MSG_SESSION)
netgd.wire_listen(&self.wire, "on_packet", "on_peer_left", "on_net_up", "on_net_down")
```

### The allocator tiers

Kit packages use three allocator conventions. The session stores an allocator
and restores it at each entry point, as described in the second convention.

**Explicit param**: kit/net's `*_make` procs (`writer_make`, `registry_make`, …)
take an `allocator` argument. The caller selects the allocator for each object.

**Stored and rebound**: kit/sim's `Lane` and this `Session` each store one
allocator. `Session.allocator` is adopted from `context.allocator` at the first
`*_start` and retained across reinitialization. The session restores it as
`context.allocator` at entry points that allocate or free memory: the starts, resume, destroy,
`session_tick`, the packet entry, `session_present`, the spawn/blob/owner/despawn
mutators, and the subsystem writers (`session_stat_column`,
`session_profile_mine`, `session_set_successor_info`). A roster name cloned in a
packet handler and freed in `run_destroy` therefore uses the same allocator for
both operations. So does a registry shadow allocated on spawn and freed on
despawn. This remains true when the game's ambient allocator differs between
calls, for example when it uses an arena or a tracking allocator. Set
`s.allocator` before `*_start` to select a custom allocator. If it is zero, the
session adopts the `context.allocator` in effect when it starts.

**Ambient**: comms, xfer, album, items, and the UI widgets allocate through
`context.allocator` without storing it. A game using a custom allocator must
keep `context.allocator` the same across each subsystem's initialization, use,
and destruction. Free operations use the ambient allocator in effect at
teardown.

An allocator-isolation test checks the stored-and-rebound allocator convention. `tests/kitsession`'s
`the_session_never_spends_the_ambient_allocator` runs a full lifecycle (start, join, both
spawn paths, blobs, interest, stats, profiles, ticks, kick, leave, disconnect, a re-init,
destroy) with a tracking allocator assigned to the session and a separate
allocator monitoring ambient allocations. The test asserts zero ambient
allocations. This detects entry points that fail to restore the session
allocator, a mistake that may otherwise go unnoticed while the session runs.

<a id="start-drive-drain"></a>

## Start the session and process events

[kit/boot](boot.md) manages this lifecycle: `boot_host`/`boot_join` start the
session, and generated `<game>_net_frame` advances it and drains events through
Boot. Use the lower-level API below when a game needs custom lifecycle ordering.
These signatures show the main lifecycle arguments; the source definitions also
include optional spectator and packet-channel settings.

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

The host normally has a player identity, name, and stats. It creates its seat
locally without sending JOIN over the transport.

**Dedicated servers.** `session_host_start(…, dedicated = true)` gives the
authority a server seat flagged `Player.dedicated`. The welcome includes this
flag in every client's roster. Games skip that seat when spawning avatars
(`if p.dedicated {continue}`); the Kit lobby and scoreboard hide it, and
`session_count()` excludes it. `max_players` therefore limits human players.
Host migration is disabled for this role: a dedicated server must restart if
it fails. Use this role when infrastructure runs the authority, through
[`kboot.boot_serve`](boot.md) in Boot. See `examples/slopball/server_run.sh`.

Clients call `session_client_start` when connecting begins and
`session_client_join` once the transport handshake completes. If WELCOME does
not arrive within `join_timeout`, the session emits `Ev_Join_Failed` so the
game can report the failed join.

Call `session_tick(s, delta, knet.now_s())` once per frame: it advances the net ticker
(delta walk, streams, pings, stats, backup refresh, prediction expiry) and stream-samples
remote entities. Then drain:

```odin
for {
	ev, ok := ksess.session_poll(&self.ses)
	if !ok {break}
	#partial switch e in ev {
	case ksess.Ev_Seated:    // this process now holds a player or server seat
	case ksess.Ev_Welcomed:  // (client) the host accepted us; the roster is seeded
	case ksess.Ev_Spawned:   // entity exists and spawn-time fields are available
	// ...
	}
}
```

`session_set_born` installs an optional authority-side hook for `Ev_Spawned`.
With it, `session_spawn` and `session_spawn_send` deliver the authority's event
synchronously after fields are set and announced. This lets presentation be
initialized before a newly created node renders. Client spawn events remain
queued so a welcome and its world snapshot retain their ordered batch behavior.
[kit/boot](boot.md) installs this hook through the generated entity table;
low-level integrations may install it before starting the session.

### Event halves and generated dispatch

A [kit/boot](boot.md) game can replace the manual event switch with generated
event halves. Each declared proc pairs by name with a session event. The
generated `<game>_net_frame` forwards them automatically and runs any declared
cooperative authority step. The lower-level `<game>_net_pump` and
`<game>_events(self, events)` remain available for custom frame ordering.
Undeclared events are ignored.

```odin
@(gd_half)
cave_lobby_player_joined :: proc(self: ^CaveLobby, id: knet.Player_Id, rejoin: bool) {
	// every peer: repaint, log
}

// Authority consequence: announce and spawn for a late joiner.
@(gd_half)
cave_lobby_player_joined_then :: proc(self: ^CaveLobby, id: knet.Player_Id, rejoin: bool) { ... }

// _process
_ = cave_lobby_net_frame(self, delta, now_s())
```

The half names are the event names (`_seated`, `_welcomed`, `_player_joined`,
`_player_left`, `_host_left`, `_join_failed`, `_join_denied`, `_kicked`,
`_backup_target`, `_succession`, `_backup_received`, `_owner_changed`,
`_blob_changed`, `_stats_updated`, `_profile_changed`, `_state_applied`, `_command_executed`,
`_command_confirmed`, `_command_rejected`), except the entity cluster,
which uses an `entity_` prefix (`_entity_spawned`, `_entity_resynced`,
`_entity_despawned`, `_entity_changed`) to distinguish it from the
[census hooks](boot.md): `<entity>_spawned` runs before spawn fields apply,
while `<game>_entity_spawned` and the typed `<entity>_born` hook run after the
fields are available. Use `_spawned` for bookkeeping and `_born` for initial
presentation. On the authority, `kboot.boot_spawn_send` dispatches the born
event before returning. Each half's parameters correspond positionally to the
event fields; invalid names or signatures are build errors.

An optional `<game>_embodied(self, id)` half runs when an entity type tagged
`avatar` is born with the local player's ownership. It covers initial spawn,
late join, and reconnect reclaim with one typed event.

Generated dispatch checks the role required by each event. An event delivered
to every role (`player_joined`, `player_left`, `entity_spawned`, `owner_changed`,
`blob_changed`) may declare a `_then` half for authority-only consequences.
An event restricted to one role is dispatched only while the process has that
role. For example, a host disconnect can produce two transport signals and
queue `Ev_Succession` twice in one batch. After the first event changes
`is_host`, generated dispatch skips the second client-only event. The
succession half therefore needs no `is_host` check. Declaring `_then` for a
client-only event such as `Ev_Kicked`, or a host-only event such as
`Ev_Backup_Target`, is a build error.

The event union covers session lifecycle (`Ev_Seated`, `Ev_Welcomed`,
`Ev_Player_Joined` with `rejoin`, `Ev_Player_Left`, `Ev_Host_Left`,
`Ev_Join_Failed`, `Ev_Join_Denied`, `Ev_Kicked`), entity changes (`Ev_Spawned`,
`Ev_Resynced`, `Ev_Despawned`, `Ev_Owner_Changed`, `Ev_Blob_Changed`,
`Ev_State_Applied`, opt-in `Ev_Entity_Changed`), and updates to stats, profiles,
and backups (`Ev_Stats_Updated`, `Ev_Profile_Changed`, `Ev_Backup_Received`).

`Ev_Seated` fires at `session_host_start` on the host and immediately before
`Ev_Welcomed` on a client. A takeover retains the successor's existing seat
and does not fire it again. `Ev_Host_Left` ends the run unless
[succession](#backup-hosting-and-resume) is armed; in that case,
`Ev_Succession` also fires so the run can continue. `Ev_Join_Denied` distinguishes
`.Full`, `.Locked`, `.Banned`, and `.Version`, allowing the game to explain the
refusal to the player.

`Ev_Resynced` reports that a known entity received a complete field update,
such as on interest re-entry or when a snapshot is applied over live state.
Generated [`<field>_edge` halves](net.md#field-change-edges) reset their stored
comparison values without emitting edges. Games with custom edge detection
can use this event to reset those values or present missed changes as new events.

Command events are `Ev_Command_Executed` on the host and
`Ev_Command_Confirmed` / `Ev_Command_Rejected` on the client. They cover both
immediate co-op and tick-scheduled actions:

- confirmed: `seq`, `entity`, `cmd`, `model`;
- rejected: those fields plus typed `reason`; and
- executed: `player`, the addressed fields, `reason`, `seq`, and `model`.

The generated `_command_confirmed`, `_command_rejected`, and
`_command_executed` halves receive those fields positionally. Reasons are
`Access`, `Rate`, `Malformed`, `Stale`, `Predicate`, or `Timeout`; timeout
callbacks retain the real sequence, entity, and command. `model` is
`.Immediate` or `.Scheduled`, identifying the action model directly for games
that use both.

## The replicated world

In a `Boot` game, use the generated typed helpers for gameplay:
`<type>_spawn`, `<type>_despawn`, `<type>_teleport`, and
`boot_spawn_send`/`boot_spawn_cancel`. They call the lower-level functions
below, which are available for custom factories and batches containing
multiple entity kinds.

```odin
session_spawn_make :: proc(s: ^Session, type: Entity_Type, owner := knet.PLAYER_ID_INVALID) -> (entity: rawptr, id: knet.Net_Id)
session_spawn_send :: proc(s: ^Session, id: knet.Net_Id)
session_spawn :: proc(s: ^Session, type: Entity_Type, entity: rawptr, set: ^knet.Command_Set, owner := knet.PLAYER_ID_INVALID) -> knet.Net_Id
session_despawn :: proc(s: ^Session, id: knet.Net_Id)
session_start_replicating :: proc(s: ^Session)
session_teleport :: proc(s: ^Session, id: knet.Net_Id)
session_owner_of :: proc(s: ^Session, id: knet.Net_Id) -> knet.Player_Id
```

Spawning has separate creation and announcement steps because the announcement
carries a field snapshot. Create the entity, set its per-spawn fields, then
send it. In a [kit/boot](boot.md) game, each `entity=Name:id` tag generates a
typed `<entity>_spawn` helper. It supplies the entity type and casts internally,
so the caller needs neither a `TYPE` constant nor a rawptr cast. Use
`kboot.boot_spawn_send` to announce the entity on the appropriate role. From
cavecrawl:

```odin
sp, sid := spelunker_spawn(&self.boot, owner = p.id)
sp.x = SPAWN_X + f32(i) * 60
sp.y = SPAWN_Y
sp.hp = MAX_HP
kboot.boot_spawn_send(&self.boot, sid) // authority born hooks run before this returns
```

If validation or configuration fails before announcement, call
`kboot.boot_spawn_cancel(&boot, id)`. It removes only an unsent authority draft
or a client-provisional predicted spawn; it cannot delete a committed entity.
This gives complex factories explicit rollback without forcing ordinary Odin
callers through a non-capturing callback API.

For a ticking entity, the helper calls `boot_fire_spawn`: the host creates the
accepted entity and a client creates a predicted entity, as in sim.md's fired
projectile example. The `session_spawn_make`/`session_spawn_send` pair remains
public, and games that build entities directly can use `session_spawn`.

Call `session_start_replicating` on the host after setting up the world. It
commits the registry's comparison copies and sends the full world to clients
already seated. Subsequent network ticks broadcast deltas, and later joiners
receive the world after their welcome. An entity owner calls
`session_teleport` to mark a discontinuous position change on a streamed entity,
such as a respawn or level change. Remote presentation then snaps to the new
position instead of interpolating across the map.

The client-side factory:

```odin
Make_Entity_Proc :: proc(user: rawptr, type: Entity_Type, id: knet.Net_Id, owner: knet.Player_Id) -> (entity: rawptr, set: ^knet.Command_Set)
Free_Entity_Proc :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr)
```

For most games, tag each exported entity scene with `entity=Name:id` and use
the generated `<game>_entities` wrapper around [kboot.boot_entities](boot.md).
It installs a factory that creates scenes under `boot.world`, records their
nodes, dispatches typed `*_spawned`/`*_freed` census hooks, and dispatches born
hooks for the host's own spawns when they are sent. Use `session_set_factory`
for custom creation. Returning nil from `make` skips an entity. Each entity's
wire record includes its length, allowing the receiver to skip unknown types.

### Entity blobs

```odin
session_set_blob :: proc(s: ^Session, id: knet.Net_Id, data: []u8)
session_blob :: proc(s: ^Session, id: knet.Net_Id) -> []u8
```

An entity blob holds one opaque, variable-length payload per entity. Use it
for state that changes infrequently, following
[net.md's collection guidance](net.md#dynamic-collections): fixed arrays for
bounded state, entities for live collections, and blobs for occasional
variable-length updates. The game marks changes explicitly by setting the
blob; the session does not diff, interpolate, or predict its contents.

The host sets the blob and sends it reliably to every peer.
`Ev_Blob_Changed` fires on clients and the host. Full snapshots also include
blobs, making them available to late joiners, backup hosts, and saves.
Cavecrawl stores a per-floor inscription on the level entity this way;
rejoining players read it through the same event handler as other players.

A blob is capped at 256 KiB and still has to fit the 1 MiB session packet that
carries its update or world snapshot. Larger one-shot data belongs in
`kit/xfer`, which chunks and paces it instead of blocking reliable state.

Use per-tick replicated fields for simulation state, app messages for transient
events, and blobs for variable-length state that new observers need to receive.
`session_blob` returns a view; copy it if you need to retain it. The session
discards duplicate versions, including those received when a rejoin delivers
the world again, so duplicates do not emit another change event.

## Roster, moderation, stats

```odin
session_player :: proc(s: ^Session, id: knet.Player_Id) -> (Player, bool)
session_roster :: proc(s: ^Session, allocator := context.temp_allocator) -> []Player
session_host :: proc(s: ^Session) -> knet.Player_Id
session_count :: proc(s: ^Session, connected_only := true, players_only := true) -> int
session_set_locked :: proc(s: ^Session, locked: bool)
session_kick :: proc(s: ^Session, player: knet.Player_Id, ban := false, reason := Disconnect_Reason.Kicked) -> (was: Peer_Id, ok: bool)
session_set_traffic_hook :: proc(s: ^Session, user: rawptr, hook: Traffic_Hook)
session_set_production_log_hook :: proc(s: ^Session, user: rawptr, hook: Production_Log_Hook)
```

By default, `session_count` counts connected players and excludes dedicated
server seats. Player limits and checks, including min-players, ready checks,
and `max_players`, use this count. Set `connected_only = false` to include
departed roster entries, as reported by save/resume receipts. Set
`players_only = false` to include a dedicated server seat in the count.

Call `session_set_locked` when a run should stop accepting new players. New
joins receive `.Locked`, while players already in the roster may reconnect.
`session_kick` delivers `Ev_Kicked` to explain the removal to the target. With
`ban`, it also rejects future joins using that token with `.Banned` for the
rest of the run. Bans are included in the
[backup snapshot](#backup-hosting-and-resume) and survive takeover. The game
must persist them separately if they should apply to later runs.

Traffic refusals are observable without writing packet plumbing. The hook gets
a typed `Traffic_Violation` containing player, transport peer, class
(`Reliable`, `Stream`, or `Action`), attempted bytes, and that class's strike
count. Return `.Drop` to report only, `.Kick` to revoke the seat, or `.Ban` to
also deny its reconnect token for this run:

```odin
traffic_policy :: proc(user: rawptr, v: ksess.Traffic_Violation) -> ksess.Traffic_Response {
	log_traffic(v)
	return v.strikes >= 3 ? .Kick : .Drop
}

ksess.session_set_traffic_hook(&self.ses, self, traffic_policy)
```

With the generated/netgd transport, Kick and Ban also schedule the socket close
after `Ev_Kicked` flushes. `session_traffic_stats` exposes admitted packets,
bytes, and drops per player and class; `session_traffic_dropped` is the one-line
netgraph total.

Disconnect events carry a fixed `Disconnect_Reason`: `Graceful`,
`Transport_Lost`, `Timeout`, `Kicked`, `Banned`, `Traffic_Policy`, or
`Protocol` (`Unknown` is the zero value). The reason crosses `SES_BYE`,
`SES_LEFT`, and `SES_KICKED`, so `Ev_Player_Left`, `Ev_Host_Left`,
`Ev_Join_Failed`, and `Ev_Kicked` report the same structured cause rather than
forcing games to infer it from timing.

For production diagnostics, install `session_set_production_log_hook`. It
receives `Production_Log_Record`, a fixed-size record of enums, player/peer ids,
byte counts, ingress stage, and running count for malformed packets, rejected
actions, traffic refusals, and disconnects. It contains no attacker-controlled
text. Kit delivers at most `PRODUCTION_LOG_EVENTS_PER_SECOND` (16) per session
second and increments `session_production_log_dropped` for the remainder, so a
hostile peer cannot turn the logger into unbounded allocation or output work.

```odin
net_log :: proc(user: rawptr, record: ksess.Production_Log_Record) {
	metrics_count(record.kind, record.action_reason, record.disconnect)
}

ksess.session_set_production_log_hook(&self.ses, self, net_log)
```

**Spectators.** `session_client_start(..., spectate = true)` creates a
receive-only seat. It receives world updates (spawns, deltas, streams, stats,
chat), but the host rejects its commands, streams, and simulation inputs.
Spectators bypass `max_players`, so they can watch a full room.
`session_count()` excludes them, as do player checks and host migration.
`Player.spectator` is available in every roster; the lobby marks these rows
"(watching)" and the scoreboard skips them. Game spawn loops should check
`!p.spectator` as well as excluding `dedicated` seats. To become a player, a
spectator must leave and rejoin, subject to the normal admission checks.

Stats are named i64 counters on each player record. The host updates them and
replicates a full stats snapshot to everyone at ~2 Hz when values have changed.
They survive disconnects with the player identity. Column 0 is always "ping",
updated by the session:

```odin
session_stat_column :: proc(s: ^Session, name: string) -> Stat_Col  // host; idempotent by name
session_stat_find :: proc(s: ^Session, name: string) -> (Stat_Col, bool)
session_stat_set :: proc(s: ^Session, player: knet.Player_Id, col: Stat_Col, value: i64)
session_stat_add :: proc(s: ^Session, player: knet.Player_Id, col: Stat_Col, delta: i64)
session_stat :: proc(s: ^Session, player: knet.Player_Id, col: Stat_Col) -> i64
```

`session_stat_column` registers columns on the host, typically in the Start
handler. A `Stat_Col` stored by that handler remains zero on clients. Handles
are 1-based, so zero is `STAT_COL_INVALID`; reads and writes assert on it with
a message explaining how to resolve the column. On peers that did not register
the column, look it up by name with `session_stat_find`. The lookup is cheap
enough to perform on each read.

<a id="player-profiles-the-lobbys-state-typed"></a>

### Typed player profiles

Each player writes a profile row containing declared choices such as a
character pick, loadout, ready status, or cosmetics. All seats use the same
fixed-layout struct, and the host relays each row to other peers. Unlike stats,
which the host accumulates, profile values are supplied by their players:

```odin
Pick :: struct { look, iron: u8, ready: bool }

// Tag the Session field. Script generation installs the profile at ready
// and includes Pick's recursive wire layout in the fingerprint. A changed
// layout rejects an incompatible join even when the type's size is unchanged.
ses: ksess.Session `gd:"profile=Pick"`

// Write and read the local profile row before or after joining.
// Before seating, the row remains pending. Seating assigns it to the player
// and starts replication without a second declaration.
ksess.session_profile_mine(&self.ses, Pick).look += 1

// anyone's row, in session_roster order (stable slots on every screen):
for p in ksess.session_roster(&self.ses) {
    pick, _ := ksess.session_profile_of(&self.ses, p.id, Pick)
    draw_row(p, pick)
}
```

The declaration installs the profile type through generated code. Each
network tick, the session compares the local row with its previous value and
sends changes. The host relays the table at the stats cadence and includes it
after the welcome for late joiners. Every peer therefore has the table if it
becomes host during takeover. Without scriptgen, install the type with
`ksess.session_profile_install(&ses, Pick)` in ready, before `*_start`.
Manual installation does not include the row's layout in the generated
fingerprint check.

`Ev_Profile_Changed{player}` fires when a peer's view of another player's row
changes; local writes do not emit it. The generated
`<game>_profile_changed(self, player)` half receives those changes, and
`<game>_profile_changed_then` handles their authority-only consequences. To
populate the local row from saved game data, use `<game>_seated(self, me)`,
which runs on every role once per seat taken. `_welcomed` runs only on clients
and would require separate host initialization.

For a ready-up flow, draw rows from `session_roster` and `session_profile_of`,
require every row's `ready` before the host can Start, and use
`_profile_changed_then` to spawn a newly ready player during a live run.
The host must validate client-declared profiles. Authority-awarded values
such as banked currency or inventory belong in replicated entity fields.

## Command hooks

A command proc may mutate only its target. Prediction, revert, and rejected
command correction depend on that restriction. Put cross-entity changes in
the verb's name-paired [`<verb>_then` consequence](net.md#command-consequences).
For example, taking loot uses a chest-only proc that returns the items taken.
On the host, `chest_take_then` credits those items to the issuer's bag; that
change reaches peers through an ordinary delta. If another player loses a
race for the same loot, their chest command is rejected and its consequence
does not credit their bag. The consequence's `game` parameter is the factory's
`user`, the session's game pointer.

Use the untyped hooks for reactions shared across verbs, such as metrics,
integration-test receipts, and replay logs. Route them by entity type to select
the matching command descriptor. Generated command IDs are stable hashes of
verb names, independent of declaration order.

```odin
ksess.session_set_type_hook(&self.ses, CHEST_TYPE, self, chest_hook)  // wins
ksess.session_set_command_hook(&self.ses, self, game_hook)            // catch-all for the rest
```

A routed type's hook receives exactly that type's commands. The host's own
commands and clients' commands use the same dispatcher, which runs after the
verb's `_then`. The installed hook survives session starts, like callbacks wired in
`ready()`.

## Interest management (area of interest)

Interest management limits per-tick deltas and owner-stream samples to entities
near a player's focus position. It is off by default. Every peer still knows
every entity: spawns, despawns, join snapshots, saves, and migration backups
are unfiltered and include the complete registry.

```odin
// Install the authority's position callback before start or during play.
ksess.session_set_interest(&self.ses, 800, 120, self, my_locator)
my_locator :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) -> (x, y, z: f32, always: bool) {
	// Return the entity position (z = 0 for 2D). Set always = true for
	// shared entities such as the level or timers that should bypass distance filtering.
}
// Update each player's observer position on the authority every frame.
// The optional z coordinate defaults for a 2D game.
ksess.session_set_focus(&self.ses, pid, avatar.x, avatar.y)
```

The session applies filtering as follows:

- **Re-entry resync.** The session does not retain filtered deltas for later
  delivery. When an entity enters a peer's interest, the host sends a full
  spawn tuple through the rejoin reconciliation path, updating its fields and
  blob together. This emits `Ev_Resynced`, since the entity already exists on
  that peer. Generated `<field>_edge` halves reset their comparison values
  without emitting edges. Custom `seen_*` values should also reset on this
  event; otherwise, earlier damage may appear as new hits on re-entry.
  `hysteresis` widens the exit boundary: entities enter at `radius` and leave
  at `radius + hysteresis`. This avoids repeated resyncs near the boundary.
- **Streams route via the host.** Owners send their batches to the host
  instead of relying on an unfiltered transport relay. Packets already pass
  through the host, so this adds no network hop. The host forwards individual
  entities to each eligible recipient. Stream samples contain absolute state
  and do not need resync.
- **The game presents stale entities.** An entity outside interest retains
  its last-known state on that peer. The game chooses whether to dim it,
  obscure it with fog, or leave it visible.
- **A peer without a focus receives everything.** Filtering starts when the
  game supplies its focus position. Commands, stats, chat, and infrequent
  reliable messages remain unfiltered.
- **Filtering can change during a run.** Joiners receive the host's filtering
  mode in their welcome. Later changes are announced to connected clients
  through `SES_AOI`. Client streams pass through the host's authority checks
  in either mode; AOI changes forwarding from whole batches to filtered
  per-recipient updates.

## App messages

`SES_APP` lets packages such as [kit/comms](comms.md) send messages through the
session's existing transport. Register a handler under a small tag, then write
and flush its payload. The session checks the sender's seat before routing.
On the host, `from` identifies the seated sender; packets from unseated peers
are dropped. On a client, `from` is `PLAYER_ID_INVALID`, and handlers must
check `from_peer == HOST_PEER` for messages that require authority.

```odin
session_app_begin :: proc(s: ^Session, tag: u8) -> ^knet.Writer
session_app_flush :: proc(s: ^Session, to_peer: Peer_Id, channel: Channel = .Reliable)
session_app_send :: proc(s: ^Session, to_peer: Peer_Id, tag: u8, bytes: []u8, channel: Channel = .Reliable)
session_app_send_to :: proc(s: ^Session, player: knet.Player_Id, tag: u8, bytes: []u8)
```

`channel` defaults to reliable. Use it for events or other messages that must
arrive. Use `.Stream` only for tick-stamped payloads that supersede earlier
ones, so a lost update can be replaced by the next send. [kit/sim](sim.md)
uses this channel for input and snapshot batches carried by `SES_APP`.
Receivers route both channels identically, but dropped `.Stream` messages are
not redelivered, and their ordering relative to reliable messages is undefined.

### Host relay

Several app-channel packages use a shared host relay. A client uploads a
payload to the host, which attaches the sender identity resolved by the
session and rebroadcasts it. Peers accept these identity-bearing messages only
from the host and drop them from any other source. The relay's echo policy
determines whether the author receives a copy.

```odin
Relay_Proc :: proc(user: rawptr, author: knet.Player_Id, r: ^knet.Reader)

relay_route    :: proc(hr: ^Host_Relay, s: ^Session, tag: u8, user: rawptr, deliver: Relay_Proc, echo := true)
relay_unroute  :: proc(hr: ^Host_Relay)
relay_begin    :: proc(hr: ^Host_Relay) -> ^knet.Writer                       // as ME, either role
relay_begin_as :: proc(hr: ^Host_Relay, author: knet.Player_Id) -> ^knet.Writer // HOST only
relay_flush    :: proc(hr: ^Host_Relay, to: Peer_Id = BROADCAST_PEER)
```

The envelope it owns, inside the `SES_APP` framing:

```
[tag][RELAY_UP][payload]                     client -> host   (no author: it can't be trusted)
[tag][RELAY_CAST][author u64][payload]       host -> all/one  (the author the session resolved)
```

The calling package writes its payload through the same API on hosts and
clients. The relay selects the upload or broadcast framing:

```odin
w := ksess.relay_begin(&c.relay)   // host: a stamped cast · client: an upload
knet.write_u8(w, CO_SAY)
knet.write_string(w, said)
ksess.relay_flush(&c.relay)        // host: broadcast (+ local echo) · client: to the host
```

- **`echo`** controls local delivery to the author. When true, the host delivers
  its own broadcast locally, and clients deliver returned messages with
  `author == me`. kit/comms enables it so the author's chat follows host order.
  kit/xfer disables it because the sender already holds the transferred bytes.
- **`relay_begin_as`** lets the host specify the author, for example when
  replaying chat history under the original speaker, sending a line with no
  speaker, or relaying an album payload under its publisher. Clients cannot
  submit an author through this API; author selection occurs only on the host.
- **An addressed cast never echoes.** `relay_flush(hr, peer)` sends only to
  that peer. `comms_catchup` uses it to replay a log to a joiner without adding
  the entries to the host's log again.
- **`deliver` must queue work and return.** It receives the payload and the
  resolved author. It must not write through the same relay while reading
  the payload, because that would reset the session's scratch writer and
  invalidate the bytes being read. Use the queued delivery described below.

Tags are one byte. `relay_route` asserts if another package already uses the
tag and names the existing assignment: comms 0, [combat](combat.md)'s fires 1,
xfer 2, [kit/sim](sim.md) 3. Some packages use `SES_APP` without the relay.
`fire_announce` broadcasts, while `fire_announce_to` sends a transient fire to
one peer. kit/sim sends directly on the stream channel with its own tick semantics.

<a id="the-riders-queue-appq"></a>

### App message queues (appq)

`App_Handler` and `Relay_Proc` run during packet dispatch. Each package queues
decoded work in its handler so the game can drain it after packet processing.
`App_Queue` provides the shared container:

```odin
App_Queue :: struct($T: typeid)

appq_push    :: proc(q: ^App_Queue($T), item: T)              // from the handler
appq_poll    :: proc(q: ^App_Queue($T)) -> (item: T, ok: bool) // from the game
appq_items   :: proc(q: ^App_Queue($T)) -> []T                 // what's still pending
appq_len     :: proc(q: ^App_Queue($T)) -> int
appq_destroy :: proc(q: ^App_Queue($T))
```

Packages expose their own public polling functions: `comms_poll`, `xfer_poll`,
`fire_poll`, and `album_poll` delegate storage to `App_Queue` without changing
their signatures. The container has no `Session` pointer, `Session_Run` entry,
or `run_destroy` registration. Its dynamic array retains its creation
allocator. The session and packages using ambient allocation can therefore
share the container while retaining their respective
[allocator rules](#the-allocator-tiers).

## Backup hosting and resume

The host periodically sends a complete recovery snapshot to the eldest
connected client, which receives `Ev_Backup_Received`. It includes the identity
table with hashed tokens, roster, allocation cursors, stats, and every entity
as a spawn tuple. It also includes `locked` and the `denied` ban list, so a
takeover preserves room locking and bans. Recovery resumes the last backup
received. `backup_interval` controls the send cadence, not a maximum rollback
window; network delay or loss can leave the available backup older than that interval.
[kit/save](save.md) uses the same `session_snapshot` representation inside a
versioned file envelope to save a run.

```odin
session_snapshot :: proc(s: ^Session, w: ^knet.Writer)
session_host_resume :: proc(s: ^Session, me: knet.Player_Id, name: string, backup: []u8) -> bool
```

The same `session_snapshot` bytes use two envelopes:
`[blob_len u32][game blob][snapshot]` for a live backup, and kit/save's
magic-and-`FORMAT` envelope on disk. A live backup is exchanged between peers
whose compatibility was checked at admission: `PROTOCOL_REV` is included in
the fingerprint. A save may be loaded by a later build without a join handshake,
so the file carries its own version. See
[save.md's versioning rule](save.md#versioning-what-crosses-time-what-crosses-the-wire) for
the statement and the third convention (the generated FNV field hash).

Call `session_host_resume` on a fresh session with the factory already
installed. Other players are initially disconnected and can rejoin with their
tokens to reclaim IDs, stats, and owned entities. The previous host can also
reclaim its seat if it supplied a token to `session_host_start`; otherwise it
returns as a new player. `session_host_resume` returns false on corrupt data.

Backups can also include game-owned campaign data, such as wave directors and
AI clocks. As in kit/save's file envelope, these bytes are stored separately
from the session snapshot:

```odin
Backup_Blob_Proc :: proc(user: rawptr, w: ^knet.Writer)
session_set_backup_blob :: proc(s: ^Session, user: rawptr, write: Backup_Blob_Proc)
session_backup_parts :: proc(s: ^Session, allocator := context.temp_allocator) -> (game_blob: []u8, snapshot: []u8, ok: bool)
```

Tag host-local fields `gd:"backup"` to generate version-hashed write/read
procedures for POD, `map[POD]POD`, and `[dynamic]POD` data. See
[save](save.md#declaring-the-game-blob). Install the generated writer through
the callback above.

`kboot.boot_migration` coordinates host migration. The game declares four
name-paired halves and installs them in `ready`; Kit schedules takeover,
clears the old world, and limits reconnect attempts:

```odin
// Declare each callback with @(gd_half); unmatched callbacks fail generation.
@(gd_half) my_game_backup    :: proc(self: ^G, w: ^knet.Writer)  // host: the campaign blob (wire
                                                                 // the generated gd:"backup" writer in)
@(gd_half) my_game_took_over :: proc(self: ^G, r: ^knet.Reader)  // successor: read the backup and restore game state
@(gd_half) my_game_wiped     :: proc(self: ^G)                   // every peer: clear pools not managed as entities
@(gd_half) my_game_migrating :: proc(self: ^G, step: kboot.Migrate_Step, target: string, try: int)

// The generated my_game_net_attach installs my_game_succ_hooks.
// A custom shell may call this after boot_attach:
kboot.boot_migration(&self.boot, self, my_game_succ_hooks)
```

On `Ev_Backup_Target`, Kit computes and broadcasts the successor's connection address
([`netgd.Succession`](netgd.md#host-migration):
`addr:port` on native, a reserved room code on web, allocated once per run).
On `Ev_Succession`, Kit schedules migration at the end of the generated
`<snake>_events` call, allowing ordinary event halves to finish against the old
world. The successor then clears that world: the entity table's `_freed` hooks
empty the per-type maps, and `_wiped` clears the remaining pools. It starts the
announced transport, calls `session_host_resume`, and passes the game blob to
`_took_over`.

Other clients reconnect within Kit's retry limits. A failed reconnect emits
the succession event again to trigger another attempt; web connection requests
are driven by `boot_pump`. `_migrating` reports each connection attempt and
failure, including a missing successor or exhausted retries. The successor's
`.Taking_Over` notification is deduplicated when `kill -9` produces two
disconnect signals. `kboot.boot_take_over`/`boot_chase` remain public for a
manual Resume button, but refuse to run while the process has a live seat.
Games managing their own transports, such as Steam, call
`kboot.boot_succ_config` once to supply the transport configuration.
Cavecrawl's acceptance-test act 4 kills the host with `kill -9` and verifies
that the run continues without manual intervention.

Custom transports can use the lower-level API:

```odin
Ev_Backup_Target :: struct { player: knet.Player_Id } // (host) holder changed — name them
session_set_successor_info :: proc(s: ^Session, info: []u8)
session_successor :: proc(s: ^Session) -> (knet.Player_Id, []u8)
Ev_Succession :: struct { successor: knet.Player_Id } // (client) host gone, successor named
session_backup_parts :: proc(...) -> (game_blob, snapshot: []u8, ok: bool) // copies
```

The session selects the successor player. It treats the connection info as
opaque bytes, allowing a Steam lobby ID or an `addr:port` address. Live
migration is supported only for the cooperative lane.
`boot_migration` requires that no simulation lane is installed; this precondition
is asserted in development builds. Simulation-lane recovery restarts the authority
with fresh lane history rather than migrating live rollback state.

## Ownership transfer

An entity's network owner is the player allowed to send its owner-stream
fields. Transfer that ownership with `session_set_owner`, usually from a
command hook, to implement carrying, mounting, possession, or dragging a
downed character:

```odin
session_set_owner :: proc(s: ^Session, id: knet.Net_Id, owner: knet.Player_Id)
```

`PLAYER_ID_INVALID` removes the stream owner. The entity retains its last
streamed state while host-authoritative deltas continue. Every peer receives
`Ev_Owner_Changed{id, owner, prev}`; a new carrier can begin attaching the
entity's position to its own from that event. Transfer resets stream history
and increments the warp marker, causing remote presentation to snap across
the handoff. The old owner stops sending because `registry_write_streams`
visits only locally owned entities. Its in-flight packets may arrive for
about a round trip with the previous warp marker. The first sample with the
new marker supersedes them without blending.

## Coop lag compensation (session_rewound)

A co-op shooter aims at the positions displayed on its screen. By the time a
shot reaches the host, those positions are about a round trip plus the
interpolation delay behind the host's live state. Testing hitscan against
live positions can therefore miss a moving target that appeared under the
crosshair. `session_rewound` temporarily restores streamed positions for the
time the shooter saw:

```odin
// In the authority fire consequence, trace against the shooter's historical view.
ksess.session_rewound(&self.ses, by, &sweep, proc(user: rawptr) {
    sw := cast(^Sweep)user
    for id, m in sw.game.mobs { /* m.x, m.y READ where the shooter saw them */ }
})
// The live world is restored here; apply damage to the targets found.
```

During the query, every streamed body except the shooter's own is rewound.
For other clients' bodies, the host uses inbound stream history. For its own
streamed bodies, such as mobs or its avatar, it uses the outbound history
retained by `registry_write_streams` with `keep_history`. Entities updated
through host-authoritative deltas with no owner have no stream history and
are tested at live positions. The host's own shots are also tested live.

The rewind duration is `RTT + interp_delay`: it includes both the stream's
trip to the shooter and the shot's return trip. Using half the RTT would omit
one transit; the derivation is documented in `session_rewound`'s comment.
`session_rewind_secs(s, shooter)` returns that duration for diagnostics or
custom hit queries. Until the shooter's first pong arrives, only the
interpolation delay is used, giving a shorter rewind.

## Three tiers of entry into your code

[Kit's event-delivery conventions](conventions.md#event-delivery) use poll
unions for multiple event types and tuple-poll functions for a single event
type. Callbacks run synchronously only when Kit needs a result or temporary
operation state. The session applies these conventions in three tiers.

Choose the tier by checking these requirements in order:

1. Use a **pull callback** when the session needs a pointer, position, or byte
   range before it can finish an operation.
2. Use an **atomic authority hook** when game code needs state available only
   during that operation, such as a command's pending result, a packet's byte
   view, or the authority's current simulation tick.
3. Use a **presentation event** for work that can be queued until the operation
   finishes without changing its meaning.

If next-frame delivery preserves the required information and behavior, queue
the work.

<a id="tier-1--pull-callbacks-the-session-is-asking-a-question"></a>

### Tier 1 — callbacks that return required data

These callbacks return information the session needs before it can continue.
Return a valid answer promptly, including for empty or unavailable input.
Do not perform additional world mutations, sends, spawns, or despawns inside
these callbacks; the session has not yet completed the calling operation.

| callback | asked | why it can't be an event |
| --- | --- | --- |
| `Make_Entity_Proc` | on every spawn, both roles | the registry needs the pointer before the spawn tuple's fields can apply |
| `Free_Entity_Proc` | on every despawn, both roles | the game must free the entity and node before the ID can be reused |
| `Locator_Proc` ([interest](#interest-management-area-of-interest)) | per entity, per tick, host | the session cannot read your position fields |
| `Backup_Blob_Proc` ([backups](#backup-hosting-and-resume)) | per backup refresh, host | the campaign bytes are the game's; the snapshot is written in one pass |
| kit/sim's `Sample_Proc` / `Step_Proc` / `Resim_Proc` | per tick / per resim | the lane cannot read or advance your simulation |

Put game reactions in the event emitted by the operation. For example,
`Ev_Spawned` follows entity creation on both clients and the host.

<a id="tier-2--atomic-authority-hooks-the-moment-does-not-survive-the-frame"></a>

### Tier 2 — hooks that use operation-local state

These hooks run synchronously while operation-specific state is available.
They may use ordinary world mutators, but must not re-enter the operation
that called them.

| hook | fires inside | the state that would be gone |
| --- | --- | --- |
| `<verb>_then` consequences ([net.md](net.md#command-consequences)) | the command's execution, host | the verb's return value and the issuer, before anything else runs |
| `Command_Hook` / `session_set_type_hook` | the same dispatch, after `_then` | *pre-result*: the generic layer sees the verdict as it is decided |
| `App_Handler` / `Relay_Proc` ([app messages](#app-messages)) | the packet switch | `^knet.Reader` views the receive buffer and is valid only during packet processing |

An app handler must copy any bytes it needs after returning. Retaining a
slice into the reader would leave it pointing at released transport memory
next frame. Kit handlers decode the payload and queue the result for later
delivery, as described in [App_Queue](#the-riders-queue-appq).

<a id="tier-3--presentation-runs-on-your-frame-world-consistent"></a>

### Tier 3 — queued and scheduled presentation

Presentation runs from `session_tick` or the game's pump after the state
updates it depends on have completed. The game may drain an event queue or
receive a scheduled callback:

- **Drained**: `session_poll`'s `Event` union and the generated [event halves](#event-halves-and-generated-dispatch); the SES_APP packages' polls (`comms_poll`, `xfer_poll`, `fire_poll`, `album_poll`), which use [`App_Queue`](#the-riders-queue-appq).
- **Kit-driven**: generated [`@(gd_event)` presentation](net.md#reliable-presentation-events), generated [`<field>_edge` halves](net.md#field-change-edges) (fired by the presentation pass inside `session_tick`), and `session_present`'s `Later_Proc` (drained on the same clock, interp-delayed).

Use tier 3 for new features unless they need a required callback result
(tier 1) or operation-local state (tier 2). Document the specific requirement
when adding a synchronous entry point.

<a id="gotchas"></a>

## Lifecycle and replication pitfalls

- **Configure durations before `*_start`.** `Session_Config` durations are in
  seconds. `session_init` converts them to tick counts at the configured rate.
  During a run, read the resolved fields (`session_tick_hz(s)`,
  `s.pending_max_age`) rather than `cfg`.
- **Starting again clears the previous run.** `host_start` / `client_start` /
  `host_resume` can reuse a session value. `session_init` tears down its
  registry, command context, roster, tokens, stats, and backup blob, while
  preserving the transport, factory, hooks, app routes, and configuration
  installed before start. Returning to the lobby and rehosting requires no
  rewiring.
- **Rejoins bypass locking and capacity checks.** A known token may reclaim
  its seat even when `session_set_locked` is set or `max_players` is reached.
  To exclude that player for the run, kick with `ban = true`.
- **Custom transports must close kicked connections.** `session_kick` returns
  the former transport peer so the game can drop it with `netgd.wire_drop` or
  an equivalent operation. Until then the socket remains open, though the
  session ignores packets from unseated peers. Boot's `boot_kick` performs
  both steps and schedules the close after `Ev_Kicked` is flushed.
- **Deltas contain sampled state** (see [kit/net's gotchas](net.md#gotchas)).
  A replicated byte set and reset within one network tick is not sent.
  Cavecrawl keeps `level.won` at 1 throughout the end screen so each peer can
  react to the field change locally.
- **The write guard counts violations in release builds.** A client that
  writes a host-lane replicated field can diverge from authority state until
  the next authority delta replaces it (see
  [kit/net's gotchas](net.md#gotchas)). Development builds assert with the
  class, field, and correction named. A `-disable-assert` build still checks
  fields, logs the first violation once, and increments
  `session_guard_hits(s)`. A nonzero count indicates a local client write to
  authority-owned state. Expose it alongside `session_malformed(s)`, the
  dropped-packet count shown by the netgraph.
- **Keep the factory's `make` limited to creation.** Instantiate the entity
  and return it; put game reactions in `Ev_Spawned`. The host receives that
  event too, through `session_spawn_make`. Before adding another synchronous
  callback, check its required timing against the
  [three tiers](#three-tiers-of-entry-into-your-code).
- **Use events delivered to the relevant role.** The authority executes its
  commands directly and receives neither `Ev_Welcomed` nor
  `Ev_Command_Confirmed`. It does receive `Ev_State_Applied`,
  `Ev_Spawned`/`Ev_Despawned`, and `Ev_Command_Executed`, which presentation
  code can handle on the host. Use `Ev_Seated` or its `_seated` half to
  initialize per-seat metadata on every role. `_welcomed` would initialize
  only clients and require a separate call when the host starts.

## Internals and design notes

### Trust and admission

ENet is plaintext UDP: anyone on the path can read the wire. WebRTC and Steam
provide encrypted transports and are the appropriate choices when traffic
privacy matters. Client owner streams always route
through the host authority gateway; it resolves the transport peer to a seated player,
preflights the complete batch, verifies every row against current entity ownership and wire
size, then relays it. Clients accept owner streams only from the host. `stream_budget`
can limit outbound per-peer owner-stream bytes when interest management is enabled.
`Session_Config.traffic` applies token-bucket rate and byte limits to every
seated peer's reliable and stream ingress. The shared action bucket covers
both command execution models.
Immediate and tick-scheduled client actions enter one
`session_authority_action_admit` pipeline after their model-specific header is
decoded: authenticated playing seat, model-qualified dedup window, structural
payload/target/descriptor, declared access, argument policy, tick plausibility,
shared byte/rate budget, and bounded model queue. `Authority_Ingress_Stats`
counts admissions and refusals by model, reason, and stage; execution callbacks
remain model-specific after admission.
Fingerprint checks detect incompatible builds. The write guard detects
application mistakes in the local process. Neither establishes that a remote
client is trustworthy.

The current defaults check decoding bounds, count parse failures through
`session_malformed`, and commit reliable entity updates transactionally.
Co-op and simulation commands use access checks and deduplication windows for
exactly-once execution. The host checks owner-stream senders against entity
ownership. Simulation inputs have structural checks and size limits; the game
can declare a validator to check their meaning. Four separate admission points
enforce receive-only spectator seats.

Named profiles bound traffic by rate and bytes, including structurally valid
traffic from a malicious peer. Packet, field, message, profile, event, command,
blob, and replication containers have semantic limits checked before
allocation. Schema mismatches are rejected during join.
These defenses cover malformed traffic, application mistakes, and version skew;
they are not a complete adversarial-server policy.

For public lobbies or other play with untrusted clients, use an encrypted
transport, tune profile budgets against measured legitimate peaks, and install
the traffic hook for moderation and the bounded production-log hook for
diagnostics. The state-hash probe helps investigate desynchronization. These
controls limit admitted work. They do not provide account identity or DDoS
protection before the transport, and the game must still validate the meaning
of structurally valid player requests.

<a id="recipes-over-existing-pieces"></a>

### Gameplay patterns using session APIs

The following patterns combine existing session APIs for common game features.

**Character-portable saves** let a character travel between servers while
worlds remain with their hosts. Store the character's bag, appearance, and
other portable data in a client-side blob using [kit/save's](save.md) file
helpers. On `Ev_Welcomed`, send it to the host under an app tag
(`session_app_send(HOST_PEER, TAG_CHARACTER, blob)`). The host validates and
applies it to the avatar, and authority deltas distribute the result to peers.
Save it on quit and at application-appropriate checkpoints. The host must
validate all submitted values before applying them, including data loaded from
a player's save.

**Player-addressed state.** Send private roles or objectives through
`session_app_send_to(player, tag, bytes)`, or through the typed
[`@(gd_message)`](net.md#typed-app-messages) form
(`role_send_to(&ses, player, msg)`) for POD payloads. Replicated fields are
broadcast to recipients without per-player field filtering, so they cannot
hold secrets from those recipients. Addressing does not provide end-to-end
secrecy: the host sees the message, and ENet is plaintext. Use an encrypted
transport and retain authoritative secret state on the host. Replicate only
its public consequences.

**Player-to-player trade.** A trade must update both players' bags together,
while a command may mutate only its target. Represent the pending transaction
as a `Trade` entity spawned by the host when two players begin trading. Its
replicated fields hold offer slots (item + count) and one confirmation value
per side. Offers reference items; the bags remain unchanged until commit.
Each edit is a single-target predicted command on the Trade. The host
processes conflicting edits in arrival order, and a rejected edit reverts
through command correction, as with a contested chest.

The excerpt shows transaction ordering. Before indexing either offer array,
validate that the submitted slot is within its bounds. The authority must also
validate item IDs, quantities, and bag contents before committing the trade.

```odin
Trade :: struct {
	owner:      gd.Node2d,
	net_id:     knet.Net_Id,
	a, b:       u64 `gd:"replicate"`, // the two Player_Ids at the table
	offer_a:    [4]kitems.Slot `gd:"replicate"`,
	offer_b:    [4]kitems.Slot `gd:"replicate"`,
	confirm_a:  bool `gd:"replicate"`,
	confirm_b:  bool `gd:"replicate"`,
	state:      u8 `gd:"replicate"`, // OPEN / DONE / FAILED; present changes through the field edge
}

// Declare by after the receiver so the framework supplies the issuer.
// The peer cannot submit a different player's ID as that argument. The
// predicates use it to restrict edits and confirmations to the matching side.
trade_seat :: proc(self: ^Trade, by: knet.Player_Id) -> (side: u8, seated: bool) {
	if u64(by) == self.a {return 0, true}
	if u64(by) == self.b {return 1, true}
	return 0, false
}

// Editing either offer clears both confirmations in the same target mutation.
// A later confirmation must accept the revised offers before commit.
@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
trade_offer :: proc(self: ^Trade, by: knet.Player_Id, slot: u8, item: u16, count: u16) -> bool {
	if self.state != TRADE_OPEN {return false}
	side, seated := trade_seat(self, by)
	if !seated {return false}
	(side == 0 ? &self.offer_a[slot] : &self.offer_b[slot])^ = {kitems.Item_Id(item), count}
	self.confirm_a = false
	self.confirm_b = false
	return true
}

@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
trade_confirm :: proc(self: ^Trade, by: knet.Player_Id) -> (ok: bool, sealed: bool) {
	if self.state != TRADE_OPEN {return false, false}
	side, seated := trade_seat(self, by)
	if !seated {return false, false}
	if side == 0 {self.confirm_a = true} else {self.confirm_b = true}
	return true, self.confirm_a && self.confirm_b // the second confirm seals it
}

// Authority-only consequence. Recheck both inventories before moving the
// offered items; an item may have left a bag since the offer was made.
// Record success or failure in authority state for normal replication.
// Client prediction changes the trade table, not either inventory.
@(gd_half)
trade_confirm_then :: proc(game: ^MyGame, self: ^Trade, by: knet.Player_Id, sealed: bool) {
	if !sealed {return}
	if game_move_offers(game, self) { // validate both bags, then swap
		self.state = TRADE_DONE
	} else {
		self.state = TRADE_FAILED // present failure; no offered items moved
	}
}
```

Snapshots include the Trade's fields, so host migration can restore an open
window and late joiners can see its current offers. The game must also handle
`Ev_Player_Left`: the host despawns any table naming the departed player, so
open offers do not outlive a participant's presence. A player may reclaim
their seat later, but must begin a new trade after that cleanup.

Use escrow when an item must not be offered in two windows at once. The
offer's `_then` moves it from the bag to the table on the host, and a failed
commit returns it. Reference-based offers are sufficient when this
exclusivity is unnecessary. In either design, predict changes to the trade
window while the authority commits changes to the bags. The player sees the
bag update after acceptance, avoiding inventory changes that must be undone
when a prediction is rejected.

**Owner-detected events.** When a player's machine simulates movement, it
should also detect events derived from that movement, such as a ball entering
a cup or a cart reaching a checkpoint. The host's stream-sampled copy can be
~a fifth of a second behind the owner's screen. If the host alone detects the
event, the ball may appear to pass the hole before the result arrives. The
owner can report the result through either persistent state or a command:

- *State signature*: the owner changes its owned fields to record the result,
  for example by stopping the ball inside the cup. That persistent state
  streams to the host, which checks its own predicate before applying
  consequences such as advancing the hole or crediting stats. Later samples
  still contain the result if an earlier sample is lost, while the owner's
  presentation already shows the ball at rest.
- *Command*: when no persistent state identifies the event, or its consequence
  needs arguments, issue a predicted command. The target changes locally
  immediately; the host validates the command and runs its consequence hook
  after acceptance.

The game implements the predicates and state signatures. Use the command
validation path for owner requests rather than adding a generic owner-event
message without validation.

### Adding a session subsystem (the touchpoint checklist)

The session's subsystems, interest (`interest.odin`), profiles (`profile.odin`), stats
(`stats.odin`), backup/succession (`backup.odin`), all integrate through the same ~8
touchpoints:

1. **Wire kind(s)**: claim the next `SES_*` id(s) in session.odin's table; netgd's
   netgraph name table follows it.
2. **Packet case(s)**: one `case` per kind in the packet switch. Role/seat gate first
   (rejections leave `r.err` clear because they are not malformed), then call
   `<sub>_recv`. A sticky `r.err` increments the malformed counter.
3. **A net_tick slot**: if you send on a cadence, add one call in `session_net_tick`'s
   sequence. Stats and profiles use the ~2 Hz lobby cadence; choose the
   appropriate cadence for the new subsystem.
4. **Late-join state**: `host_handle_join` sends the world, stats, profiles,
   and current succession info. Include any persistent subsystem state that
   a late joiner needs.
5. **State scoping**: put run state in `Session_Run`, which is cleared on each
   reinitialization, and pre-start wiring in `Session_Wiring`, which is
   retained. Add owned-container cleanup to `run_destroy`. State that must
   survive `host_resume` specifically needs a `keep_*` flag on `session_init`;
   profiles provide an example.
6. **Departure cleanup**: remove per-player state through `mark_left`, where
   deduplication windows and interest pairs are also pruned.
7. **Event union, or the tier above it.** New game-facing events join `Event`, and
   scriptgen's `SESSION_EVENTS` table if games should get generated halves. If your
   subsystem instead calls game code, determine which of the
   [three tiers](#three-tiers-of-entry-into-your-code) it belongs to before writing the
   proc type. For `SES_APP` messages, reuse the [relay](#host-relay)
   and the [queue](#the-riders-queue-appq).
   Adding a variant fails to compile in `kit/boot/forward.odin`, which holds the
   kit's own forwarding table as one exhaustive (non-`#partial`) switch. Give the new
   variant a case for its Kit consequence, such as lane forwarding, a widget
   repaint, or succession handling. If it needs no Kit reaction, add an empty
   case with a comment explaining why.
8. **Fingerprint**: if your wire shape depends on game declarations (profile rows do),
   include it in the build fingerprint so incompatible peers are rejected
   during admission.

See also: [kit/net](net.md) (the core underneath), [kit/netgd](netgd.md) (the transport
binding), [kit/sim](sim.md) (the server-authority simulation lane, which also
uses this page's identity, replication, and moderation APIs), [kit/comms](comms.md),
[kit/combat](combat.md), [kit/items](items.md), [kit/ui](ui.md), [kit/save](save.md),
[kit/steamgd](steamgd.md).
