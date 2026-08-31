# kit/boot: standard game integration

`kit/boot` connects the common Godot-facing parts of a Kit game. It creates the
stock lobby, chat, scoreboard, stage and world containers; attaches the
transport, session, and comms packages; installs generated entity support; and
provides the per-frame pump.

Use `Boot` when the standard menu → lobby → game lifecycle fits your project.
Every component remains accessible as a public field, so a game can restyle,
replace, reposition, or ignore individual widgets. Games with a custom shell
can instead use `kit/netgd` and `kit/session` directly.

## The generated game-network facade

The normal game shell declares one direct `Boot`, `Session`, and `Comms` field.
A simulation game also declares one direct `Lane`. From that shape, scriptgen
generates `<game>_net_attach`, `<game>_net_pump`, `<game>_net_frame`, and
`<game>_net_detach`; no
additional annotation is required.

```odin
import gd "godot:godot"
import kboot "godot:kit/boot"
import kcomms "godot:kit/comms"
import knet "godot:kit/net"
import ksess "godot:kit/session"

My_Game :: struct {
	owner: gd.Node2d,
	boot:  kboot.Boot,
	ses:   ksess.Session,
	comms: kcomms.Comms,
	// lane: ksim.Lane, // add for a game with @(gd_tick)
}

// _ready
my_game_net_attach(
	self,
	kboot.Options{
		title = "P U T T P U T T",
		status = "Host a course, or join one at localhost",
		legend = "Click: putt · Tab: scores · Enter: chat",
		env = "GOLF",
	},
	kboot.network_profile(.Friends_Coop),
)

// _process
if kboot.boot_phase(&self.boot) != .Menu {
	frame := my_game_net_frame(self, delta, knet.now_s())
}
```

`my_game_net_attach` attaches Boot, installs the generated entity factory and
typed message routes, arms declared migration hooks, and initializes/attaches
the generated simulation lane when the class owns one. Its optional third
argument is a complete `kboot.Network_Config`; zero selects `.Friends_Coop`.
Start with `kboot.network_profile`, then override ordinary `session` or `lane`
fields. The whole pair is validated before either layer starts. See
[Network profiles](profiles.md).

`my_game_net_pump` advances the network stack and dispatches every declared
session-event half. It returns a `kboot.Net_Frame`: `marks` contains positional
comms markers and `ticks` is the number of co-op network ticks advanced this
frame. The marker slice is temporary and must be consumed this frame.

`my_game_net_frame` is the common complete operation: it calls the generated
pump/event dispatch and then the generated cooperative authority step plus
same-frame edge pass when one exists. Games that need visuals or authority work
on a different side of event dispatch keep using `_net_pump` and `_step`
separately; the convenience does not remove the explicit ordering path.

`my_game_step` exists when a co-op game declares an
`@(gd_step = "authority")` proc. A game with `kit/sim` attaches its lane with
the generated facade, and the pump advances that lane itself.

### Advanced: custom frame composition

The lower-level `boot_attach`, `<game>_entities`, `<game>_messages`,
`<game>_lane_init`, `boot_lane`, `boot_pump`, and `<game>_events` procedures
are primitives for a genuinely custom frame graph, not alternate spellings of
`<game>_net_frame`. Use them only when event dispatch or lane installation must
occur at a custom point. A shell with multiple direct sessions or lanes is left
on these explicit APIs because the generator cannot safely guess a graph.

## Standard signal methods

`Options.methods` identifies four UI methods (`on_host`, `on_join`, `on_start`,
and `on_chat`) and four transport-forwarding methods (`on_packet`,
`on_peer_left`, `on_net_up`, and `on_net_down`). Its zero value selects those
standard names.

The game implements the UI methods because hosting, joining, starting, and chat
policy are game-specific. Script generation supplies the four transport
forwarders from the `boot: kboot.Boot` field. A hand-written method with the
same name overrides a generated forward. Literal method names are checked at
build time; use an empty string only when intentionally skipping a signal.

## Count time in net ticks, not frames

Gameplay timers that must agree across peers should not count rendered frames.
For a co-op authority loop, use the fixed network ticks returned by the
generated network pump. Presentation animations can continue to use frame
`delta`.

Declare the authority pass and hand it those ticks; the generated proc holds
the role gate and the loop:

```odin
@(gd_step = "authority")
my_game_tick :: proc(self: ^MyGame) { /* decrement authority timers */ }

// process():
frame := my_game_net_frame(self, delta, now_s())
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

`<game>_net_pump` runs `boot_pump`, then passes its event slice to the generated
`<game>_events` dispatcher. Boot applies stock reactions first; the generated
dispatcher then calls the game's declared [event
halves](session.md#event-halves-and-generated-dispatch). The lower-level
`boot_pump` returns `(events, marks, ticks)` when a game needs to choose exactly
where that dispatch occurs.

### The forwarding table

The forwarding table refreshes roster and score widgets, controls the host's
Start button from `min_players`, forwards ownership changes to an attached
simulation lane, advances host succession, updates the world-seen latch, and
restores the menu after failed, denied, or ended sessions. The switch is
exhaustive, so adding a new `ksess.Event` requires an explicit Boot decision at
compile time.

## Lifecycle: boot_phase

`boot_phase(b)` reports the coarse lifecycle as a `Boot_Phase`:

- `.Menu`: no seat is held and none is coming; the Host/Join doors are showing.
- `.Connecting`: a join is in flight (a code at the phonebook, or a survivor's
  host-migration chase).
- `.Lobby`: a seat is held; hosting counts as this phase too.
- `.Playing`: the world reached this screen (first spawn, state, or resync).

The phase is derived from the session's run, join, and timeout state plus Boot's
join-code rendezvous. Boot stores only whether replicated world state has
reached this screen. A failed or denied join and a kick return to `.Menu`. A
host disconnect may remain in the current phase while succession attempts to
re-seat the player.

`boot_phase` is current state, not an event. To run work once when the world
arrives, read the phase before `<game>_net_pump` and compare it with the phase
after the pump. See `examples/hello_sim`.

## Teardown

Call the generated `<game>_net_detach(self)` when returning to a menu and later
re-attaching in the same process. It destroys the simulation lane and comms
routes first, releases Boot's wire/UI/entity state, then resets the session's
live run and registry. Pre-start session wiring and configuration survive, so a
fresh `<game>_net_attach` plus Host/Join starts from a clean run without losing
the game's settings. The operation is idempotent.

The generated detach is an explicit game verb, not a scene-exit callback. When
the engine tears the whole node down, it frees the node tree and the Odin
process memory ends with it. Use detach for the flow that keeps the process
alive across a complete network-stack reset.

At the lower level, `boot_net_detach(b)` performs the same full ordered
teardown using the session/comms/lane pointers retained by `Boot`.
`boot_detach(b)` releases only the state created by `boot_attach` and the Boot
doors; it deliberately leaves caller-owned lane, comms, and session values to
their matching destroy procedures. All three forms are idempotent.

**The ownership rule**, one line per layer: boot lives as long as its node;
below boot, X destroys what X inits; node trees belong to the scene. Boot
created the container nodes (`ui_layer` / `stage` / `world`), so `boot_detach`
queue-frees those, and the widgets, the legend, and the world's entities
parented under them ride the subtree down with one free each. The [kui
`*_destroy`](ui.md) calls free only their Odin-side tracking arrays (the nodes
belong to the container, i.e. boot); `netgd.wire_detach` frees the wire's own
gauge and shim containers. Nothing is freed twice.

## Desktop unthrottle

In development builds on desktop, Boot disables vsync and caps rendering at 120
fps. This prevents an occluded local test window from having its whole main loop
paced by the compositor while two peers run on one machine.

The unthrottle is dev-builds-only, keyed on the build flag `-disable-assert`
(the release line every kit guardrail keys on). Headless and web runs are left
untouched, and so is every release build: a shipped game never tears by default
nor caps a 240 Hz display at 120. Set `Options.keep_vsync = true` to retain the
engine's normal vsync policy in development, or set `Options.max_fps` to choose
a different development cap.

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

### Single player (the solo door)

`boot_single(b, name)` is the same game, alone: a full authority session over
`netgd.OFFLINE` — an `OfflineMultiplayerPeer` seats you as host id 1 and your
per-tick broadcasts cleanly reach nobody (without one, `send_bytes` with no
peer installed spams "peer isn't set" every tick — the gotcha every
hand-rolled solo path re-derived). The whole authoritative sim runs exactly
as it does with friends, the door ritual included, so solo stops being the
one path that bypassed `boot_open_host`. Succession never arms (nobody to
migrate to); works identically on native and web.

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
shim](netgd.md#link-simulation) then answers `MY_LATENCY` /
`MY_JITTER` / `MY_LOSS` without a separate `latency_env`, putting the whole
per-game env family under one prefix.

## Identity and tokens

Identity pairs with [`ksave.token`](save.md): the
env-or-file-or-per-instance ladder in one call. The same-machine seat-stealing
behavior is a documented option.

## Chat, keys, and net stats

`boot_chat(b, text)` is the whole `text_submitted` handler, focus release
included ([kui.chat_submit](ui.md)); it latches `b.talk_sent` so the
submitting ENTER can't reopen the chat. `boot_keys_frame(b, "talk", "board",
"esc")` is the flow-key trio once per frame — the HELD scoreboard
(refresh-then-show), ENTER-to-talk behind that latch, ESC handing the
keyboard back from the chat — returning whether the keyboard was IN CHAT at
frame start, which is the one gate your own hotkeys read
(`kui.chat_typing(&b.chat)` is the raw predicate). `boot_net_stats(b)` returns
the complete [`kui.Net_Stats`](ui.md#netgraph) fill: link quality,
packet/byte rates, malformed/policy/rate drops, and bytes-by-kind. If
`boot_lane` installed a simulation lane, the same call also fills lead/gaps,
ack age, rewind/clamps, replay ticks/cost, command pressure, snapshot mix, and
AOI pressure. Pass it directly to `netgraph_refresh`.

## The album (payload catch-up), registered

A game with a [kit/xfer album](xfer.md) (sprays, skins) hands it to boot once —
`boot_album(b, &album)` after `album_init` — and both of its chores become the
kit's: `boot_pump` pumps it once per net tick, and every `Ev_Player_Joined`
replays the kept payloads to the newcomer (`album_welcome`), so a late joiner
never again sees a blank spray wall because a game forgot the host's half.

## The web room, surfaced

The WebRTC door's rendezvous is pumped like the join-code phonebook's:
`boot_web_pulse` (inside `boot_pump`) logs `BOOT_ROOM_CODE <code>` the moment
the relay assigns one, words it in the lobby status pre-world ("share it with
the crew") or into chat mid-run (a room born mid-run is a takeover's), and
words a failed handshake with the relay's reason + the doors restored —
everything web games hand-latched in their own `process()`. `boot_room_code(b)`
answers for both coded doors now. The doors also `transport_close` whatever
the LAST door left open before binding, so a retry or a by-hand rejoin never
inherits a stale signaling socket.

## The entity factory

Tag each exported entity scene with its script type and stable wire ID. The
generated network attach installs the factory automatically; `<game>_entities`
is the lower-level installer for a custom shell:

```odin
// Game struct: assign this PackedScene in the Inspector.
mob_scene: ^gd.Resource `gd:"entity=Mob:3"`,

// custom _ready, after boot_attach:
scrapyard_entities(self, &self.boot)

// Optional bookkeeping hook. Spawn fields have not been applied yet.
@(gd_half)
mob_spawned :: proc(game: ^Scrapyard, self: ^Mob, id: knet.Net_Id, owner: knet.Player_Id) {
	game.mobs[id] = self
}

// Optional presentation hook. Spawn fields are now available.
@(gd_half)
mob_born :: proc(game: ^Scrapyard, self: ^Mob, id: knet.Net_Id, owner: knet.Player_Id) {
	gd.node2d_set_position(cast(gd.Node2d)self.owner, {self.x, self.y})
}

// Optional teardown hook. The struct and node are still alive here.
@(gd_half)
mob_freed :: proc(game: ^Scrapyard, self: ^Mob, id: knet.Net_Id) {
	delete_key(&game.mobs, id)
}
```

The tag generates the factory table, entity type constant, typed spawn and query
procedures, node map, and hook dispatch. The numeric ID (`3` above) is part of
the wire and save formats. Keep it stable across compatible builds. Script
generation rejects duplicate IDs, unknown structs, and invalid hook signatures.
IDs remain explicit rather than path/name-hashed: a scene or type rename must
not silently change save identity, and a visible small number keeps protocol
migrations deliberate.

Entity-specific options follow the type declaration in the same tag:

```odin
mob_scene:    ^gd.Resource `gd:"entity=Mob:3,stream_hz=30"`, // AI the eye reads through interp
runner_scene: ^gd.Resource `gd:"entity=Runner:2,avatar"`,    // a SEAT'S body, not an NPC
```

- `stream_hz=N` sets the default owner-stream rate for every entity of this
  type. `session_set_stream_hz` can still override an individual entity later.
- `avatar` marks a player's body. During host succession, an absent host's NPCs
  may move to the successor, while its avatar remains assigned to the absent
  player's reclaimable seat.

### Spawn timing and initial presentation

The generated `<entity>_spawned` hook runs when the factory creates and indexes
the entity, before received spawn fields are applied. Use it for bookkeeping
that only needs the ID and owner.

The generated `<entity>_born` hook is dispatched from `Ev_Spawned` after fields
are available. Use it for the first node position, tint, nameplate, and other
presentation derived from replicated state. Godot may not call `_process` on a
node added during the current process pass, so relying on `_process` alone can
display one frame at the scene's default transform.

On the authority, `boot_spawn_send` dispatches the born event synchronously
before returning. On clients it is dispatched as the ordered spawn record is
applied. In both cases the typed born hook sees initialized fields. The
authority's synchronous event is not repeated in the next `boot_pump` event
slice.

A predicted client-side spawn has no authoritative `Ev_Spawned` until it is
matched and rekeyed. Initialize its presentation at the prediction site or keep
the scene hidden until the first authoritative presentation.

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
index):

```odin
mob, ok := mob_of(&self.boot, id)          // the entity behind an id
mine, ok := mob_mine(&self.boot)           // this player's singular mob
theirs, ok := mob_owned_by(&self.boot, pid)
ref := mob_ref(id)                         // knet.Net_Ref(Mob), not a raw pointer
mob, ok = mob_of(&self.boot, ref)          // same lookup, type checked
for tracked in mob_all(&self.boot) {       // one-pass, temp-allocated
	tracked.entity.think()
	remember(tracked.ref)
	_ = tracked.id
	_ = tracked.owner
}
owner := kboot.boot_entity_owner(&self.boot, id) // the owner_pid map
_ = mob_teleport(&self.boot, mob)          // owner-stream jump; ptr/ref/id overloads
_ = mob_despawn(&self.boot, mob)           // authority lifecycle; exact-kind checked
```

`Net_Ref(T)` contains the stable `Net_Id`, not an entity pointer. Different
entity types are different Odin types, and `*_of` checks the live type again
when it resolves; a despawned or wrong-kind reference returns `(nil, false)`.
This is the value to retain across frames or store as a replicated POD relation.
The pointer in `Net_Entity(T)` is frame-local: retain `tracked.ref`, not
`tracked.entity`, across a despawn boundary.

The per-type index is sorted by `Net_Id`, so a query walks only that entity
kind and cross-entity simulation passes have the same order on every peer.
`*_all` is the sole enumeration surface: it resolves the pointer, stable ref,
ID, and current owner together in one pass.
Client-predicted entities are included while they live under provisional IDs;
Boot carries the provisional-to-authoritative alias when a predicted spawn is
rekeyed, so a reference retained at fire time continues resolving. The alias is
retired with the entity; the reference then resolves false like any despawn.

`*_mine` and `*_owned_by` are deliberately singular: zero matches returns
false, one returns the entity, and multiple matches assert in development and
return false in release instead of selecting an arbitrary first row. Filter
`*_all` when a player may own several entities of that kind. All generated
queries use the `<type>_*` prefix so they appear together in autocomplete.

Every registered kind also generates `<type>_despawn` with pointer (when the
struct has `net_id`), typed `Net_Ref`, and raw-id overloads; all verify the live
concrete kind before mutating it. Kinds with owner-streamed state additionally
generate `<type>_teleport`. The lower-level session procedures remain useful
for deliberately mixed-kind batches.

## Host migration

Declare up to four name-paired halves and wire the generated table in `ready()`:

```odin
kboot.boot_migration(&self.boot, self, <snake>_succ_hooks)
```

The halves are `<game>_backup(self, w)`, `<game>_took_over(self, r)`,
`<game>_wiped(self)`, and `<game>_migrating(self, step, target, try)`. Boot
coordinates backup transfer, takeover or reconnect, entity cleanup, retries,
and UI state. `boot_take_over` and `boot_chase` remain available for a manual
Resume flow, and a game that creates its own transports calls `boot_succ_config`
once. The detailed hook contract is in
[session.md](session.md#backup-hosting-and-resume).

Host migration is available for the session-replication model. A simulation
lane authority restarts; it does not migrate its live rollback state.
