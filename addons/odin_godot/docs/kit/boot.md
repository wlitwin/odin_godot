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

Declare one direct `Boot`, `Session`, and `Comms` field on the game script.
A simulation game also declares one direct `Lane`. Scriptgen uses those fields
to generate `<game>_net_attach`, `<game>_net_pump`, `<game>_net_frame`, and
`<game>_net_detach` without an additional annotation.

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
typed message routes, connects declared migration hooks, and initializes/attaches
the generated simulation lane when the class owns one. Its optional third
argument is a complete `kboot.Network_Config`; zero selects `.Friends_Coop`.
Start with `kboot.network_profile`, then override ordinary `session` or `lane`
fields. The whole pair is validated before either layer starts. See
[Network profiles](profiles.md).

Use `my_game_net_frame` for the standard frame loop. It pumps the network and
dispatches events, then runs the generated cooperative authority step and
same-frame field-change checks when declared. It returns a `kboot.Net_Frame`: `marks`
contains positional comms markers and `ticks` is the number of co-op network
ticks advanced this frame. The marker slice is temporary and must be consumed
this frame.

`my_game_step` exists when a co-op game declares an
`@(gd_step = "authority")` proc. A game with `kit/sim` attaches its lane with
the generated facade, and the pump advances that lane itself.

### Advanced: custom frame composition

`my_game_net_pump` advances the network stack and dispatches every declared
session-event half without running the generated cooperative step. Use it with
`my_game_step` only when visuals or authority work must sit on a different side
of event dispatch.

The lower-level `boot_attach`, `<game>_entities`, `<game>_messages`,
`<game>_lane_init`, `boot_lane`, `boot_pump`, and `<game>_events` procedures
allow custom frame ordering. Use them when event dispatch or lane installation
must occur at a particular point outside `<game>_net_frame`. A game script
with multiple direct sessions or lanes must use these explicit APIs because
the generator cannot infer which components to connect.

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

Declare the authority pass with `@(gd_step = "authority")`. The generated
procedure checks the role and calls the pass once per advanced network tick:

```odin
@(gd_step = "authority")
my_game_tick :: proc(self: ^My_Game) { /* decrement authority timers */ }

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

Set `Options.lobby_scene` / `chat_scene` / `score_scene` to use a game-authored
scene; `nil` builds the stock widget. Boot finds the nodes it controls by name
and connects the standard widget behavior. The game controls the rest of the
scene's layout and appearance. Required node names are listed in
[ui.md's scene requirements](ui.md#adopting-your-own-scenes).

## The generated event loop

`<game>_net_frame` is the normal loop: it runs the generated pump, passes its
event slice to `<game>_events`, and then runs any generated cooperative
authority step and same-frame edge pass. Boot applies stock reactions before
the game's declared [event halves](session.md#event-halves-and-generated-dispatch).
The lower-level `<game>_net_pump` and `boot_pump` remain available when a custom
frame graph must choose exactly where dispatch or stepping occurs.

### The forwarding table

The forwarding table refreshes roster and score widgets, controls the host's
Start button from `min_players`, forwards ownership changes to an attached
simulation lane, advances host succession, updates the world-seen latch, and
restores the menu after failed, denied, or ended sessions. The switch is
exhaustive, so adding a new `ksess.Event` requires an explicit Boot decision at
compile time.

## Lifecycle: boot_phase

`boot_phase(b)` reports the coarse lifecycle as a `Boot_Phase`:

- `.Menu`: the player has no seat or pending connection; Host/Join controls
  are visible.
- `.Connecting`: a join is pending, including join-code lookup or an attempt to
  reconnect after host migration.
- `.Lobby`: the player holds a seat, including when hosting.
- `.Playing`: this peer has received world state through a first spawn, state
  update, or resync.

The phase is derived from the session's run, join, and timeout state plus Boot's
join-code rendezvous. Boot stores only whether replicated world state has
reached this screen. A failed or denied join and a kick return to `.Menu`. A
host disconnect may remain in the current phase while succession attempts to
re-seat the player.

`boot_phase` is current state, not an event. To run work once when the world
arrives, read the phase before `<game>_net_frame` and compare it with the phase
after the frame call. See `examples/hello_sim`.

## Teardown

Call the generated `<game>_net_detach(self)` when returning to a menu and later
re-attaching in the same process. It destroys the simulation lane and comms
routes first, releases Boot's wire/UI/entity state, then resets the session's
live run and registry. Pre-start session wiring and configuration survive, so a
fresh `<game>_net_attach` plus Host/Join starts from a clean run without losing
the game's settings. The operation is idempotent.

The generated detach is not called automatically on scene exit. Godot frees
its node tree, but Odin maps, slices, and other allocations still need their
matching teardown when the process stays alive. On final scene removal, detach
the stack and destroy the retained Session wiring:

```odin
my_game_exit_tree :: proc(self: ^My_Game) {
	my_game_net_detach(self)
	ksess.session_destroy(&self.ses)
}
```

Use detach alone when the same script instance will attach again; use both
calls when that instance is finished. HelloNet and HelloSim include this exit callback.

At the lower level, `boot_net_detach(b)` performs the same full ordered
teardown using the session/comms/lane pointers retained by `Boot`.
`boot_detach(b)` releases only the state created by `boot_attach` and Boot's
connection helpers. The caller must destroy its lane, comms, and session with
their corresponding procedures. All three forms are idempotent.

Boot lives as long as its node. Each lower layer destroys the resources it
initializes, while the scene owns node trees. `boot_detach` queues Boot's
container nodes (`ui_layer` / `stage` / `world`) for deletion. Their widget,
legend, and entity children are freed with the subtree. The
[kui `*_destroy`](ui.md) calls release only Odin tracking arrays;
`netgd.wire_detach` releases the wire's gauge and shim containers. Connection
helpers close the peer they installed and leave externally installed peers
alone. A raw `wire_attach` borrows its peer, so its caller closes that peer
separately. These ownership rules prevent duplicate frees.

## Desktop unthrottle

In development builds on desktop, Boot disables vsync and caps rendering at 120
fps. This prevents an occluded local test window from having its whole main loop
paced by the compositor while two peers run on one machine.

This setting applies only to development builds, identified by the absence of
`-disable-assert`. Boot leaves rendering policy unchanged in headless, web,
and release builds, so it does not impose a 120 fps cap on a 240 Hz display in
release. Set `Options.keep_vsync = true` to retain the engine's normal vsync
policy in development, or use `Options.max_fps` for a different development cap.

<a id="connecting-the-doors"></a>

## Starting connections

`boot_host(b, port, name)` and `boot_join(b, addr, port, token, name)` do
transport setup, session start, and menu/status/chat updates. They call
`netgd.begin_host` / `netgd.begin_join`, which remain available for custom
lifecycle ordering.

Both call transport-independent helpers that accept a transport and endpoint:

```odin
boot_open_host(b, t: ^netgd.Transport, at: netgd.Endpoint, name, token = 0, dedicated = false) -> bool
boot_open_join(b, t: ^netgd.Transport, at: netgd.Endpoint, name, token, spectate = false, status = "Joining...") -> bool
```

Named host/join entry points use these helpers for lifecycle setup, reconnect
identity, [host-migration](netgd.md#swapping-transports) configuration, phase,
menu, chat, roster, and status updates. Transport-specific migration settings
come from the `netgd.Transport` record. Implementing that record lets a new
transport reuse the shared setup. Steam provides it as `ksteam.TRANSPORT`,
documented in [steamgd.md](steamgd.md).

<a id="single-player-the-solo-door"></a>

### Single player

`boot_single(b, name)` starts an authority session over `netgd.OFFLINE`.
An `OfflineMultiplayerPeer` assigns the player host id 1, and per-tick
broadcasts have no remote recipients. That peer is still required; without
it, `send_bytes` reports "peer isn't set" every tick. Authority simulation
and `boot_open_host` setup work as in multiplayer, on both native and web.
Host succession is disabled because there is no successor.

### Dedicated server

`boot_serve(b, port, name)` starts a dedicated server on the same transport.
Its authority holds an infrastructure seat with no avatar or roster row. The
seat does not count toward player gates, and host migration is disabled; see
[session.md](session.md). Start the world automatically when
`session_count(players_only = true)` reaches the game's threshold, as the
`serve` role in `examples/slopball` does.

### Spectator

`boot_spectate(b, addr, port, token, name)` joins as a spectator. The seat
receives the game state, can join a full room, does not count toward player
gates, and is receive-only after admission. See
[session.md's spectator rules](session.md). Skip spectators in avatar spawn
loops with `!p.spectator`, just as those loops exclude `dedicated` seats.

## Transport forwards

The four transport forwards, `on_packet`, `on_peer_left`, `on_net_up`, and
`on_net_down`, are generated from the `boot: kboot.Boot` field on your script
struct. They route through the boot's own wire and session pointers, dispatch by
name (so they survive hot reload), and can be overridden by hand-writing a
same-named `@(gd_method)`. `Options.methods` still names these methods, and
scriptgen checks those names at build time.

## Identity from an env prefix

Set `Options.env = "MY"` and `boot_port(b, def)` / `boot_name(b, def)` /
`boot_token(b)` read `MY_PORT` / `MY_NAME` / `MY_TOKEN`. The token persists
in `user://my_token`. The [link-simulation shim](netgd.md#link-simulation)
also reads `MY_LATENCY` / `MY_JITTER` / `MY_LOSS` from that prefix without a
separate `latency_env` setting.

## Identity and tokens

Boot uses [`ksave.token`](save.md) to choose an identity token from an
environment override, a persisted file, or a per-instance value. See that
reference for the option to reclaim a seat from another local instance.

## Chat, keys, and net stats

Use `boot_chat(b, text)` as the `text_submitted` handler. It submits the
message, releases focus through [kui.chat_submit](ui.md), and sets
`b.talk_sent` so the Enter key that submitted it cannot reopen chat.

Call `boot_keys_frame(b, "talk", "board", "esc")` once per frame to refresh
and display the scoreboard while its key is held, open chat with Enter, and
release chat focus with Escape. It returns whether chat held keyboard focus
at frame start; use that result to suppress gameplay hotkeys. For a direct
focus query, call `kui.chat_typing(&b.chat)`.

`boot_net_stats(b)` returns [`kui.Net_Stats`](ui.md#netgraph) with link quality,
packet/byte rates, malformed/policy/rate drops, and bytes-by-kind. If
`boot_lane` installed a simulation lane, the same call also fills lead/gaps,
ack age, rewind/clamps, replay ticks/cost, command pressure, snapshot mix, and
AOI pressure. Pass it directly to `netgraph_refresh`.

<a id="the-album-payload-catch-up-registered"></a>

## Registering payload catch-up

Register a [kit/xfer album](xfer.md), such as one holding sprays or skins,
with `boot_album(b, &album)` after `album_init`. `boot_pump` then advances it
once per network tick and calls `album_welcome` on every `Ev_Player_Joined`
to send retained payloads to the new player. No separate player-joined handler
is required for those payloads.

<a id="the-web-room-surfaced"></a>

## Web room codes and connection retries

During `process()`, `boot_pump` advances WebRTC rendezvous through
`boot_web_pulse`, as it does join-code lookup. When the relay assigns a room code, Boot logs
`BOOT_ROOM_CODE <code>` and displays it in lobby status before play or in chat
during a run. A room created during play belongs to a host takeover. If the
relay handshake fails, Boot displays the reason and restores connection
controls. `boot_room_code(b)` returns the code for either connection method.

Before binding a new transport, the connection helpers call `transport_close`
on the previous one. Retries and manual rejoins therefore release the old
signaling socket.

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
mob_scene:    ^gd.Resource `gd:"entity=Mob:3,stream_hz=30"`, // interpolated NPC position updates
runner_scene: ^gd.Resource `gd:"entity=Runner:2,avatar"`,    // marks the player avatar for succession
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
`boot_entities_wipe(b)` removes entities when returning to the lobby or taking
over as host. It enumerates live entities and calls each `_freed` hook before
freeing its node, allowing per-type game maps to clear through their usual
teardown code. The factory reads the scene field at spawn time, preserving
Inspector wiring and hot reload. Use `session_set_factory` for custom creation.

## Entity queries

Each `entity=` tag generates typed queries that read the registry's entity and
owner records and Boot's per-type index. Use them instead of maintaining a
parallel `map[Net_Id]^T`, owner map, or `avatar_of` lookup:

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
Enumerate with `*_all` to resolve each entity's pointer, stable reference, ID,
and current owner together in one pass.
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
