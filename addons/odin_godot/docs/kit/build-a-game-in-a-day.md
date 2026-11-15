# Build a multiplayer game in a day

This guided tour explains the co-op replication workflow by following the
structure of `examples/cavecrawl`. Its snippets are excerpts, not a complete
project. Start with the [session quickstart](quickstart.md) if you want the
smallest buildable example first; use the [glossary](glossary.md) for Kit
terminology.

The tutorial builds an invited-peer game in which one player hosts a small
co-op cave crawler. Cavecrawl is the complete reference implementation for the
features introduced below.

Generated wrappers apply the declared authority, prediction, rejection, and
presentation policies. The game implements target validation and mutation,
accepted cross-entity consequences, authority steps, and presentation hooks.

<a id="0-the-one-struct"></a>

## 0. The main game script

Declare the session, communications, and Boot fields on the main game script.
Cavecrawl calls this script `CaveLobby`:

```odin
CaveLobby :: struct {
	owner: gd.Node,
	ses:   ksess.Session,
	comms: kcomms.Comms,
	boot:  kboot.Boot,
	// ...your world: entity maps, UI handles, campaign state
}
```

Keep one session and one Boot on the script instead of in package globals.
The session retains network identity, entities, and stats for rehosting and
saved runs. Boot ([kit/boot](boot.md)) holds the Godot-facing lobby, chat,
scoreboard, stage/world containers, and transport wire. Its widgets are public
fields that the game can restyle or ignore. Game-specific campaign state will
need a separate save blob, described below.

## 1. Boot and lobby (15 minutes)

In `ready()`:

```odin
my_game_net_attach(self, kboot.Options{
	title    = "MY GAME",
	status   = "Host a cave, or join one at localhost",
	msg_kind = MSG_SESSION, // MSG_SESSION :: u8(0) — all kit/session traffic under one game byte
	env      = "MY", // MY_PORT/_NAME/_TOKEN identity + the MY_LATENCY shim
	methods  = {"on_host", "on_join", "on_start", "on_chat",
	            "on_packet", "on_peer_left", "on_net_up", "on_net_down"},
}, kboot.network_profile(.Friends_Coop))
```

The attach call creates the lobby title, status, player list, Host/Join/Start
buttons, chat, scoreboard, and session transport wire. The `boot: kboot.Boot`
field also generates four transport forwarders:
`on_packet`/`on_peer_left`/`on_net_up`/`on_net_down`. They report transport
changes to the session, which clears disconnected peers from the roster after
Alt-F4, a crash, or connection loss. A hand-written method with the same name
overrides a generated forwarder.

`.Friends_Coop` records that invited entity owners may author their streamed
movement. Choose `.Listen_Server_Action` when clients send validated inputs to
a player-hosted simulation, or `.Dedicated_Competitive` when that authority
runs on trusted infrastructure. See [Network profiles](profiles.md).

Implement the four UI methods for hosting, joining, starting, and chat. The
Host handler calls `kboot.boot_host(&self.boot, port, name)`; Join calls
`kboot.boot_join(&self.boot, addr, port, token, name)`. Each connection handler
checks whether the action is allowed, calls Boot, and updates status text.
Use an example game's `net.odin` as a starting point; its connection handlers
take about 60 lines.

The join's `token` is the player identity (`kboot.boot_token(&self.boot)`,
persisted in `user://my_token`, overridable via `MY_TOKEN` so same-machine
tests pick distinct seats). Presenting the same token later (after a crash, a
quit, a resumed save) reclaims the same identity, stats, and entities. Persist
it; never regenerate it. See [session](session.md).

The attach call is generated from the shell's direct Boot, Session, and Comms
fields. It also installs generated entity/message/migration wiring. In
`process()`, one generated call pumps the wire, ticks the session, applies the
stock reactions, and dispatches your [event
halves](session.md#event-halves-and-generated-dispatch). A co-op authority step
remains an explicit game decision because it commonly runs only while playing:

```odin
frame := my_game_net_frame(self, delta, now_s())
```

Generated dispatch runs synchronously inside `my_game_net_frame`, applying
each hook's execution policy. For custom ordering, the component calls
`boot_attach`/`boot_pump`/`my_game_events` and underlying
`wire_attach`/`wire_pump`, `session_tick`/`session_poll` remain public.
See [boot](boot.md), [netgd](netgd.md), and [session](session.md).

## 2. Your first replicated entity (30 minutes)

An entity is a plain script struct with tagged fields:

```odin
//gd:extends Node2D
Chest :: struct {
	owner:  gd.Node2d,
	glyph:  gd.Label `gd:"onready=Glyph"`,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"replicate"`,
	slots:  [4]kitems.Slot `gd:"replicate"`,
}
```

Scriptgen generates serialization, dirty tracking, and a `Command_Set`.
`registry_insert` writes the registered id into `net_id`. Add an `entity=` tag
to the scene export to declare the scene's entity type and stable wire id:

```odin
// CaveLobby field: assign the scene in the Inspector and declare its entity type.
chest_scene: ^gd.Resource `gd:"entity=Chest:2"`,
```

The generated `cave_lobby_net_attach` installs `cave_lobby_entities`. On every
peer, including the host, that factory instantiates scenes under `boot.world`,
records each id and node, and frees the node on despawn. The tag also generates
typed lookup and iteration procedures, so the game does not need a parallel
entity map:

```odin
if chest, ok := chest_of(&self.boot, id); ok {
	inspect(chest)
}
for tracked in chest_all(&self.boot) {
	inspect(tracked.entity)
}
```

A custom shell may call the entity installer directly. Typed `_spawned` and
`_freed` hooks remain for game-specific indexes or bookkeeping, not for
recreating the registry.

On the host, call the generated `chest_spawn` helper. It returns a typed
`Chest` pointer and id; initialize its fields, then announce the spawn:

```odin
chest, id := chest_spawn(&self.boot)
chest.x, chest.y = 300, 180
kboot.boot_spawn_send(&self.boot, id)
```

After replication starts, the per-tick delta walk sends changes to registered
authority-written fields. Clients receive the current value; late joiners
receive it in their snapshot.

<a id="3-movement-that-feels-right-30-minutes"></a>

## 3. Owner-streamed movement (30 minutes)

Give players' avatars owner-streamed fields:

```odin
x, y: f32 `gd:"owner"`, // continuous owner fields interpolate by default
```

The entity owner writes these fields every frame. Kit sends their latest
values over the unreliable channel; remote peers interpolate about 3 ticks
in the past to absorb jitter and packet loss. Follow two rules:

- Only the entity owner writes its owner-streamed position. For respawns,
  level changes, and knockbacks, the authority replicates state that tells the
  owner how to move its avatar. For example, restored hp can trigger the
  owner's respawn positioning.
- Announce discontinuous position changes as teleports. On the frame of a
  level change, blink, or respawn, call the generated helper, such as
  `spelunker_teleport(&self.boot, self.me)`. Otherwise remote peers interpolate
  across the position jump and show the avatar sliding across the map.

<a id="4-verbs--the-intent-pipeline-1-hour"></a>

## 4. Commands and authority consequences (1 hour)

A Kit command is a procedure on the entity it validates and mutates. Here a
player requests items from a chest:

```odin
@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
chest_take :: proc(self: ^Chest, slot: u8, count: u16, px, py: f32) -> (ok: bool, taken: kitems.Slot) {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false, {}}
	taken = kitems.take(self.slots[:], int(slot), count)
	return taken.count > 0, taken
}
```

The generated `chest_take_cmd` wrapper runs this command authoritatively on
the host and predictively on clients. Returning false as the first result
rejects the request and reverts its writes. An authority rejection also sends
accepted state back to the predicting client. If two players request the last
item, both can predict success. The host executes requests in arrival order,
accepts the first, and rejects the second; that client then reverts its
prediction.

A command may mutate only its target. To add the accepted loot to the player's
inventory, implement its paired [consequence](net.md#command-consequences),
`<verb>_then`. Results after the applied boolean become payload arguments to
that procedure, alongside the issuer and wire arguments. The consequence runs
only on the authority, for both client-issued and host-issued commands. Client
prediction never calls it:

```odin
@(gd_half)
chest_take_then :: proc(game: ^CaveLobby, self: ^Chest, by: knet.Player_Id, slot: u8, count: u16, px, py: f32, taken: kitems.Slot) {
	cave_credit(game, by, self, taken) // authority mutation replicated through deltas
}
```

Check stamina, cooldown, and life state before issuing a command. A locally
refused prediction is still sent, so repeated unavailable actions create
avoidable requests and rejection logs. See [items](items.md) and [interact](interact.md) for the
deterministic ops that are safe inside command procs.

<a id="5-combat-that-never-feels-sloppy-1-2-hours"></a>

## 5. Predicted combat presentation (1-2 hours)

Cavecrawl's `rocks.odin` implements this projectile pattern in about 100 lines,
using kit/fx for presentation:

- The cast is a predicted command that checks its ability slot's cooldown and
  cost; see [combat](combat.md).
- At cast time, the shooter starts a local `kfx.Tracers` visual. It needs no
  replicated projectile entity or network message before appearing.
- The host simulates the projectile that applies damage and announces a
  `kcombat.Fire` through an app tag. Other peers start their visuals from the
  announcement, while the shooter skips the echo of its predicted cast.
- On local visual contact, `kcombat.php_note_hit` reduces displayed hp through
  an overlay without changing the replicated field. An authoritative hp delta
  later consumes the overlay. If the host judges a miss, the overlay expires
  and displayed hp returns to its authoritative value.

Include the shooter's local origin in `Fire`. The host's owner-streamed copy
of the shooter is delayed and would launch along a different path, especially
while strafing. Bound the supplied origin on the host with `kcombat.leash`.

Test this behavior with injected latency: set
`Options.latency_env = "MY_LATENCY"` and run under `MY_LATENCY=120` (or call
`netgd.wire_set_latency(&self.boot.wire, 120)` directly).

## 6. Enemies (1 hour)

Use [ai](ai.md)'s helpers from a game-owned NPC update loop. A dweller is an
ordinary entity owned by the host player. The host writes its streamed position
and one replicated behavior byte; clients interpolate its motion and display
that behavior. `kai.Director` and `director_tick` schedule waves from data.
Private decision state lives in a host-side map keyed by net id and is rebuilt
from the game's save blob on resume.

<a id="7-levels-replicate-the-byte-not-the-scenery-1-hour"></a>

## 7. Loading levels from replicated state (1 hour)

Store the current floor in a `Level` entity's `depth: u8` field. When that
value changes, each peer loads `level_N.tscn` locally. Static geometry stays in
the scene files. The host reads Marker2D spawn points from its own scene and
creates the dynamic session entities; `.tres` resources hold wave plans.

To descend, despawn the old floor's entities, increment depth, and build the
next floor. New joiners and resumed saves receive the depth in the snapshot,
so they can load the corresponding local scene through the same path.

## 8. Runs end: match flow (1 hour)

Add `won: u8` to the Level entity. Clearing the last floor sets it, and peers
respond to the change by showing the scoreboard and status; the host's Start
button offers another run. Restart clears `won` and rebuilds floor 1 within
the same session. Seats, tokens, and cumulative stats remain in place while
deltas carry the new run state.

Keep replicated state changes visible across a network tick. A byte that
changes 1→0 within one tick produces no delta if its final value equals the
stored comparison value. Use an explicit [comms](comms.md) message or app tag
for one-shot events that must be delivered.

If strangers can join, add moderation and admission policy deliberately.
The tools are `session_kick(player, ban)`, `session_set_locked`, and
`Session_Config.max_players`, with `netgd.wire_drop` closing the kicked socket
after the "you were kicked" message flushes. Returning identities pass lock and
capacity checks when reclaiming their existing seats.

## 9. Quit and resume (30 minutes)

```odin
// Save session state and the game-specific campaign blob.
ksave.save_write(&self.ses, &w, GAME_VERSION, my_campaign_blob)
// Restore session state and read the campaign blob.
blob, err := ksave.resume(&self.ses, name, path, GAME_VERSION)
```

The save snapshot carries session identity, stats, and entities using the
same data used for backup hosting. The game adds a blob for private state such
as the wave director and AI clocks. Friends rejoin the resumed run with their
persisted tokens through the normal reconnect path. See [save](save.md).

## 9b. Carryable entities (30 minutes)

To carry an entity, give it owner-streamed position. A grab command's `_then`
calls `session_set_owner(ses, id, by)`. The game handles `Ev_Owner_Changed`
and lets the carrier update its position each frame, such as
`relic.x = me.x + 10`. Dropping assigns `PLAYER_ID_INVALID`, leaving the
entity at its last position. Mounts, possession, and dragging bodies use the
same ownership transfer and position update pattern.

For downed players, add a predicted revive command that checks range and sets
`hp = REVIVE_HP`. The host tracks bleed-out time. When hp changes, the owner
checks its value to distinguish revival in place from a bleed-out respawn.
Cavecrawl's `spelunker_revive` demonstrates the pattern.

## 9c. Host migration (30 minutes)

Periodic authority backups let another player resume hosting after the host
disconnects. Declare four halves and pass their generated table to
`kboot.boot_migration` in `ready`:

- `<game>_backup` writes game-specific campaign bytes into each backup.
- `<game>_took_over` reads them on the successor and restores private game state.
- `<game>_wiped` clears non-entity pools after Kit removes tracked entities.
- `<game>_migrating` updates status for each migration step.

Kit starts the handoff on `Ev_Backup_Target`. After dispatching session events,
it either takes over or reconnects to the successor, bounds retries, and
retains the timing state needed to manage the attempt. Act 4 of Cavecrawl's
acceptance test kills the host with `kill -9` and checks that handoff needs no
manual input. See [session.md](session.md#backup-hosting-and-resume) for setup.

## 9d. Shared-seed procgen (30 minutes)

Replicate a `seed: u32` field on the level entity and generate decoration
locally on each peer. Only the seed crosses the wire; generated scenery needs
zero additional wire bytes. Cavecrawl's `splitmix32` scatter uses integer math
throughout so peers derive the same result. Floating-point generation can vary
with FMA contraction, libm implementations, and fast-math flags; even a low-bit
difference can change the generated cave. Cavecrawl's acceptance test compares
checksums printed by both processes to verify matching decoration.

<a id="10-ship-it-on-steam-1-hour--a-friend"></a>

## 10. Connecting through Steam (1 hour + a friend)

Use [steamgd](steamgd.md) to connect the existing session through Steam lobby
and peer APIs:

```odin
if steamgd.available() && steamgd.init(APP_ID) {
	steamgd.listen(self.owner, "on_lobby_created", "on_lobby_joined", "on_join_requested")
}
// host: create_lobby -> lobby_created -> host_peer -> invite_overlay
// guest: overlay "Join Game" -> join_requested -> join_lobby -> client_peer
```

Session_Wire continues receiving SceneMultiplayer signals through the selected
MultiplayerPeer. Verify the Steam connection live with the Spacewar app id
(480), a `steam_appid.txt`, and one friend.

## 11. Headless acceptance tests

Cavecrawl's headless acceptance test starts two processes over ENet with
120ms injected latency. Its driver operates the scene tree and checks log
lines from each peer (`examples/cavecrawl/run.sh` + `cave_test.gd`). Reproduce
observed gameplay failures in a driver so its assertions can check the result
on both peers. A test script can call the same `@(gd_method)` procedures used
by gameplay input.

## 12. Moving contested state to the simulation lane

This tutorial uses peer-owned movement, which is appropriate when the host
trusts each owner to report its fast state. A duel, ranked game, or other
contested design should derive movement from admitted input on the authority.
Retag that state with `predict`, move its writes into `@(gd_tick)`, and attach
the simulation lane. Session identity, entities, commands, chat, and saves can
remain on their existing lanes. Read [Timelines](timelines.md) to choose a
model and [kit/sim](sim.md#promoting-a-coop-game) for the migration checklist.
