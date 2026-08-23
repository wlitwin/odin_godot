# kit/boot

Every co-op (friendslop) project opens the same way: `ready()` builds a
lobby/chat/scoreboard/stage/world/wire stack, and `process()` runs a
pump-tick-drain preamble plus five stock event reactions, about a hundred
lines of setup before any game code. `kit/boot` provides exactly that shared
shell, and nothing game-shaped. Every widget and every reaction stays yours;
boot owns only the boilerplate between them.

Reach for boot when you want the standard friendslop lifecycle (menu →
lobby → play, host/join, chat, roster, host migration) without hand-writing
it. A game that prefers to drive `netgd`/`ksess` directly can still call
`boot_pump` for the loop and read `boot_phase` for the lifecycle, taking only
the pieces it uses.

## Wiring boot

`boot_attach` builds the stack in `ready()`; `boot_pump` runs the loop in
`process()`.

```odin
import kboot "godot:kit/boot"

// ready() — after installing your factory/hooks:
kboot.boot_attach(&self.boot, self.owner, &self.ses, &self.comms, kboot.Options{
	title       = "P U T T P U T T",
	status      = "Host a course, or join one at localhost",
	legend      = "click: putt · Tab scores · Enter chat", // "" = no legend
	msg_kind    = MSG_SESSION,
	latency_env = "GOLF_LATENCY", // the injected-latency shim's env knob
	methods     = {"on_host", "on_join", "on_start", "on_chat",
	               "on_packet", "on_peer_left", "on_net_up", "on_net_down"},
})

// process(): the whole loop, role-free — both procs are generated
events, marks, ticks := kboot.boot_pump(&self.boot, delta, now_s())
my_game_step(self, ticks)     // @(gd_step="authority") pass: host gate + edge pass inside (sim.md)
my_game_events(self, events)  // session-event dispatch over the declared halves (session.md)
```

`boot_pump` returns three values: `events` (every session event this frame)
and `marks` (the comms markers), both temp-allocated, plus `ticks` (how many
fixed net ticks fired this frame). `my_game_step` and `my_game_events` are
generated; the sections below cover each.

## The eight signal methods

The `methods` list names eight `@(gd_method)` procs declared in *your* script,
because Godot signals must land on the game's class. Their bodies are
one-liners; see either example game's `net.odin`. scriptgen validates every
name in `methods` against the class's registered methods at build time, so a
typo'd forward is a build error. An empty string `""` skips a signal.

You write four of the eight: `on_host`, `on_join`, `on_start`, and `on_chat`.
The other four, `on_packet`, `on_peer_left`, `on_net_up`, and `on_net_down`,
are the transport forwards, and boot generates their bodies (see [Transport
forwards](#transport-forwards)); `methods` still names them.

## Count time in net ticks, not frames

Boot unthrottles desktop windows (see [Desktop unthrottle](#desktop-unthrottle)),
so frame rate is 120 on one machine and whatever vsync reports on another. A
"3-second" countdown counted in frames halves or doubles per screen. Count in
net ticks instead: `boot_pump` returns `ticks`, the number of fixed net ticks
that fired this frame, and that is the clock the host's simulation and every
timer should use.

Declare the authority pass and hand it those ticks; the generated proc holds
the role gate and the loop:

```odin
@(gd_step = "authority")
my_game_tick :: proc(self: ^MyGame) { /* timers decrement HERE */ }

// process():
events, _, ticks := kboot.boot_pump(&self.boot, delta, now_s())
my_game_step(self, ticks) // generated: host-only fixed steps + the same-frame edge pass
```

## Widgets and containers

Every widget is a public field on `Boot`: `boot.ui`, `boot.chat`, `boot.score`,
`boot.legend`, `boot.wire`, `boot.stage`, and `boot.world`. Reposition,
restyle, or ignore any of them. `stage` and `world` are `Node2D` containers, so
screen shake ([kfx.Shake](fx.md)) can nudge them both as one. A 3D game sets
`Options.spatial = true` to get `Node3D` containers instead (see
`examples/slopball3d`).

### Adopting your own scenes

Set `Options.lobby_scene` / `chat_scene` / `score_scene` to hand boot a
game-authored scene to adopt (`nil` builds the stock widget). Boot resolves the
nodes it drives by name and pours the stock behavior into them; everything else
in the scene is your own chrome. The node names each widget requires are listed
in [ui.md's adopt contract](ui.md#adopting-your-own-scenes).

## The event loop

`boot_pump` runs `wire_pump` and `session_tick`, walks every drained session
event through the kit's forwarding table (`kit/boot/forward.odin`), and returns
every session event plus the comms markers (temp-allocated). Your own reactions
are your [declared event
halves](session.md#event-halves-game_event): hand the
stream to the generated `<snake>_events` and each half runs *after* boot's stock
reaction, so a game-specific status line overwrites the stock one.

### The forwarding table

`forward.odin` holds one switch over `ksess.Event`. It is not `#partial`: every
variant is named, and the ones with no kit-side consequence carry an empty case
labeled with the reason (`FACTORY`, `SIM WIRE`, `GAME-FACING`…). Adding a
session event is therefore a compile error in `kit/boot` until you decide what
the kit owes it.

The table handles: roster and score repaints; the host's Start gating at
`min_players`; `lane_set_owner` and `lane_drop_player`; the five arms of the
host-migration handoff; the phase's world latch; and the status line plus
restored Host/Join doors on every way a seat can end (failed, denied with the
host's reason, kicked).

## Lifecycle: boot_phase

`boot_phase(b)` returns the coarse lifecycle as a `Boot_Phase`, the
`running`/`started` latch pair answered once:

- `.Menu`: no seat is held and none is coming; the Host/Join doors are showing.
- `.Connecting`: a join is in flight (a code at the phonebook, or a survivor's
  host-migration chase).
- `.Lobby`: a seat is held; hosting counts as this phase too.
- `.Playing`: the world reached this screen (first spawn, state, or resync).

The phase is derived, not tracked. Each answer is read off the session (`ran` /
`joined` / `join_waited`) plus boot's own rendezvous, so a game that ran the raw
way (`netgd`/`ksess` by hand, `boot_pump` for everything after) still gets a
truthful phase without touching a door.

The one fact nothing below boot knows (the world reached this screen) is the
single latch boot keeps, and `boot_pump` is its only writer: raised in the drain
on the first spawn/state/resync, dropped at the top of any frame that finds no
seat. (`boot_open_host` drops it too, for the one re-seat with no unseated
frame: menu → Host again in a live process.) The consequences: a failed or
denied join and a kick fall back to `.Menu`, because the session disarms its own
join clock; a bare host loss stays put, because the seat outlives the socket and
migration may re-seat it; a survivor's chase reads `.Connecting`, because the
dial restarts the session as a client.

`boot_phase` is a level. A swap that must happen exactly once (hide the lobby,
print a receipt) wants the rising edge, and no bool is needed: `boot_pump` is
the only place the phase rises, so read the phase before the pump and compare
after. See `examples/hello_net`'s `process`.

## Teardown: boot_detach

`boot_attach` builds a boot-owned stack; `boot_detach(b)` frees exactly what
`boot_attach` and the doors allocated and zeroes the `Boot` back to its
pre-attach state, so a fresh `boot_attach` rebuilds everything.

Call `boot_detach` on one flow: **back to menu, then re-host or re-join in the
same live process.** It is the game's explicit verb, wired to no scene-exit
hook: a game returning to its menu calls it. Skip it before a re-host in the
same process and the previous run's tracking arrays, wire containers, and entity
ledgers leak, and a second `ui_layer`/`stage`/`world` stacks onto the first. When
the engine tears the whole node down it frees the same nodes anyway (boot lives
as long as its node) and the Odin memory dies with the process, so there is
nothing to hook.
`boot_detach` is idempotent: it is safe to call on an already-detached
(zeroed) `Boot`.

**The ownership rule**, one line per layer: boot lives as long as its node;
below boot, X destroys what X inits; node trees belong to the scene. Boot
created the container nodes (`ui_layer` / `stage` / `world`), so `boot_detach`
queue-frees those, and the widgets, the legend, and the world's entities
parented under them ride the subtree down with one free each. The [kui
`*_destroy`](ui.md) calls free only their Odin-side tracking arrays (the nodes
belong to the container, i.e. boot); `netgd.wire_detach` frees the wire's own
gauge and shim containers. Nothing is freed twice.

## Desktop unthrottle

On desktop, boot turns vsync off and caps at 120fps. Friendslop games get
playtested as two windows on one laptop, and with vsync on, the OS pacing an
occluded window's present makes the background instance *simulate* slow, not
just draw slow. The whole main loop blocks on the compositor, and every
timeline-synced screen stutters for it.

The unthrottle is dev-builds-only, keyed on the build flag `-disable-assert`
(the release line every kit guardrail keys on). Headless and web runs are left
untouched, and so is every release build: a shipped game never tears by default
nor caps a 240 Hz display at 120. Set `Options.keep_vsync = true` for the
dev-side opt-out, or set your own vsync/fps policy after `boot_attach`.

## Connecting: the doors

`boot_host(b, port, name)` and `boot_join(b, addr, port, token, name)` do
transport-up, session-start, and the menu/status/chat ritual (via
`netgd.begin_host` / `netgd.begin_join`, which exist separately if you want the
ritual your way).

Under both is one door per direction, parameterized by transport:

```odin
boot_open_host(b, t: ^netgd.Transport, at: netgd.Endpoint, name, token = 0, dedicated = false) -> bool
boot_open_join(b, t: ^netgd.Transport, at: netgd.Endpoint, name, token, spectate = false, status = "Joining...") -> bool
```

Every named door on this page is those two plus a status line. The ritual,
reconnect identity, [host-migration](netgd.md#swapping-transports) config (its
flavor comes from the transport's own record, so a door is never told twice),
phase, menu, chat, and roster, is written once, and a new transport inherits
all of it by filling a `netgd.Transport`. Steam gets both doors for the price
of one record (`ksteam.TRANSPORT`, documented in [steamgd.md](steamgd.md)).

### Dedicated server

`boot_serve(b, port, name)` is the dedicated-server door: same transport, but
the authority holds an infrastructure seat: no avatar, no roster row,
uncounted by player gates, and host migration never arms (see
[session.md](session.md)). Nobody presses Start on a server, so auto-start your
world once `session_count(players_only = true)` reaches your threshold
(`examples/slopball`'s `serve` role is the model).

### Spectator

`boot_spectate(b, addr, port, token, name)` is the watching door, the
dedicated pattern pointed the other way: a seat that sees everything and is
nobody. It bypasses a full room, counts toward nothing, and is receive-only past
the join ([session.md's spectator paragraph](session.md) has the contract). Give
it the same `!p.spectator` skip your spawn loops give `dedicated`.

## Transport forwards

The four transport forwards, `on_packet`, `on_peer_left`, `on_net_up`, and
`on_net_down`, are generated from the `boot: kboot.Boot` field on your script
struct. They route through the boot's own wire and session pointers, dispatch by
name (so they survive hot reload), and can be overridden by hand-writing a
same-named `@(gd_method)`. The `Options.methods` list still names them (the
method-name lint holds), but their bodies are not yours to write.

## Identity from an env prefix

Set `Options.env = "MY"` and `boot_port(b, def)` / `boot_name(b, def)` /
`boot_token(b)` read `MY_PORT` / `MY_NAME` / `MY_TOKEN` (the token is persisted
in `user://my_token`). The whole [bad-link
shim](netgd.md#wire_set_latency--link-simulation) then answers `MY_LATENCY` /
`MY_JITTER` / `MY_LOSS` without a separate `latency_env`, putting the whole
per-game env family under one prefix.

## Identity and tokens

Identity pairs with [`ksave.token`](save.md): the
env-or-file-or-per-instance ladder in one call. The same-machine seat-stealing
behavior is a documented option.

## Chat and net stats

`boot_chat(b, text, &sent)` is the whole `text_submitted` handler, focus release
included ([kui.chat_submit](ui.md)). `boot_net_stats(b)` returns the shared co-op
[`kui.Net_Stats`](ui.md#netgraph) fill (rtt, link
jitter/loss, malformed drops, bytes-by-kind); a sim-lane game lays its `sim` /
lead / resim rows on the result before `netgraph_refresh`.

## The entity factory

Tag each exported entity scene with what it embodies and its stable wire id,
then install the generated factory with the generated `<game>_entities`. The
make/free switches, the `TYPE` consts, the `spawn_scene` helper, and the
id→node map are all generated, so none of them exist in your code:

```odin
// on the game struct — ordinary drag-drop exports, plus the declaration:
mob_scene: ^gd.Resource `gd:"entity=Mob:3"`,

// ready(), after boot_attach (the factory parents under boot.world):
scrapyard_entities(self, &self.boot)

// the game-shaped half stays yours, as typed name-paired hooks (optional):
@(gd_half)
mob_spawned :: proc(game: ^Scrapyard, self: ^Mob, id: knet.Net_Id, owner: knet.Player_Id) {
	game.mobs[id] = self   // bookkeeping — fields NOT set yet; dress on Ev_Spawned
}
@(gd_half)
mob_freed :: proc(game: ^Scrapyard, self: ^Mob, id: knet.Net_Id) {
	delete_key(&game.mobs, id) // node + fields still alive — death fx go here
}
```

The id (`Mob:3`) is explicit and stable: it rides saves, rejoins, and migration
backups, so entities are never auto-numbered across builds. scriptgen errors on
duplicates, unknown structs, and mis-shaped hooks at build time.

**The kind's knobs ride the tag too**, as trailing entity tokens (export specs
may still follow them):

```odin
mob_scene:    ^gd.Resource `gd:"entity=Mob:3,stream_hz=30"`, // AI the eye reads through interp
runner_scene: ^gd.Resource `gd:"entity=Runner:2,avatar"`,    // a SEAT'S body, not an NPC
```

* `stream_hz=N` — the kind's owner-stream rate. It lands on the session as a
  per-TYPE declaration (`session_set_type_stream_hz`), so every spawn of the
  kind carries it on every peer — the host's own, a client's wire spawn, and
  the heir's takeover rebuild. The per-id `session_set_stream_hz` it replaces
  was a send-side hint each spawn site re-applied by hand and a takeover
  silently lost (the heir streamed mobs at full rate). The per-id call still
  exists for a one-off and wins by being later.
* `avatar` — this kind is a player's BODY. The one place the session reads it
  is a host takeover's orphan sweep: the dead host's NPCs are adopted by the
  heir (so they keep living), but its avatar is PARKED with its seat —
  owner unchanged, reclaimable by the token holder who dials back in — instead
  of becoming the heir's. (Before the tag every orphan was adopted and each
  game re-owned avatars back by hand from a spawn-time owner map.)

**Born at the send.** `<game>_entities` hands boot the kind table AND the
class's generated event dispatcher, and the dispatcher is what makes the
AUTHORITY's own spawns *born at the send*: `<game>_entity_spawned` runs inside
`kboot.boot_spawn_send`, before it returns — the symmetric guarantee to a
client's (whose make → fields → `Ev_Spawned` is one synchronous flow). So no
render, physics step, or later `_process` can ever see the host's node parented
but undressed, and the host's own `Ev_Spawned` is NOT in that frame's
`boot_pump` batch. Two consequences worth knowing: `boot_phase` still rises
only in `boot_pump` (the host's `entity_spawned` runs with the phase not yet
risen — the latch is promoted at the next pump, so the `was`/`phase` edge
idiom across the pump keeps working); and the raw door,
`kboot.boot_entities(&self.boot, self, <table>[:], events)`, takes the
dispatcher as an optional last argument — `nil` keeps the queue path for a
hand-rolled game that drains the batch itself (nothing is ever lost silently).

**Where the first placement goes — and why `_process` alone is not it.** Godot
runs no `_process` on a node added to the tree DURING the `_process` pass (the
engine iterates a copy of the process list; a node added in `_physics_process`
skips that physics step but does get `_process` the same render frame). Every
host-step spawn is added during `_process`, so an entity that positions itself
only in its own `_process` renders its spawn frame at the scene's default pose
on the spawner's screen — no matter when `Ev_Spawned` fires. The contract is:
`<game>_entity_spawned` is the initial-dress home (place the node from its
fields there — it is same-frame on every role now), the entity's `_process`
maintains from then on; or ship the scene hidden and reveal in the dress, as
homestead does. The same first-frame gap exists for a client's PREDICTED spawn
(`boot_spawn_predicted`, which has no `Ev_Spawned` until the authority's
rekeys it) — dress at the fire site, or hide until first present.

`boot_node(b, id)` looks up an entity's node (the `nodes[id]` map).
`boot_entities_wipe(b)` is the back-to-lobby / takeover wipe, and it is
census-driven: it fires the `_freed` hooks per live entity (the by-type maps
empty through the same code that fills them) before freeing the nodes. The scene
is read through the field at spawn time, so editor wiring and hot reload keep
working, and `session_set_factory` remains the escape hatch for exotic creation.

## Entity queries

Every `entity=` tag also generates the typed queries that stand in for a
hand-kept `map[Net_Id]^T` plus owner and `avatar_of` mirrors; they read the
kit's own ledgers instead (the registry's entity and owner, the boot's type
table):

```odin
mob, ok := mob_of(&self.boot, id)          // the entity behind an id
mine, ok := my_mob(&self.boot)             // this player's avatar
theirs, ok := mob_owned_by(&self.boot, pid)
for id in mob_ids(&self.boot) { ... }      // every live Mob (temp-alloc)
owner := kboot.boot_entity_owner(&self.boot, id) // the owner_pid map
```

With these, the spawn/free hooks above shrink to the genuinely game-shaped lines
(a hot `me_*` pointer, death fx), or vanish. The owned/ids scans walk the type
ledger, which is friendslop-sized; keep your own map in the rare game that makes
them hot.

## Host migration

Declare up to four name-paired halves and wire the generated table in `ready()`:

```odin
kboot.boot_migration(&self.boot, self, <snake>_succ_hooks)
```

The halves are `<game>_backup(self, w)`, `<game>_took_over(self, r)`,
`<game>_wiped(self)`, and `<game>_migrating(self, step, target, try)`. The kit
owns the handoff, the takeover/chase fork (run off the generated events tail, so
word halves see the old world), the census-driven wipe, the retry caps, and the
window latches. `boot_take_over` and `boot_chase` stay public for a manual
Resume button, and a game that raises its own transports calls `boot_succ_config`
once. The arm-by-arm word contract is in
[session.md](session.md#backup-hosting-and-resume).

Host migration is co-op-lane only: a sim lane's authority restarts, it does not
migrate (asserted with a teaching message).
