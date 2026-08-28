# Build a multiplayer game in a day

> This is the guided tour. It explains the whole surface in reading order,
> using cavecrawl as the finished artifact; its snippets are excerpts, not a
> follow-along. For the copy-paste-run path (empty folder → two windows in ten
> minutes, every line compiled), do the **[quickstart](quickstart.md)** first;
> terms of art live in the [glossary](glossary.md).

The friendslop toolkit is built for one shape of game: **you and your friends,
one of you hosts, things go wrong together.** This tutorial builds that game,
a small co-op cave crawler, the same way `examples/cavecrawl` is built, brick
by brick. Cavecrawl is the finished version of everything below; when a step
here feels terse, the corresponding file there is the long answer.

The core guarantee: **gameplay code has zero role branches.** You write
mutation code that looks single-player; the host runs it authoritatively,
clients predict it, rejections revert it, and remote screens interpolate it,
without you checking `is_host` in gameplay. Where a role branch would otherwise
creep in, the toolkit hands you a name-paired proc instead (a verb's `_then`,
an entity's `_spawned`).

## 0. The one struct

Everything hangs off your main script (cavecrawl calls it `CaveLobby`):

```odin
CaveLobby :: struct {
	owner: gd.Node,
	ses:   ksess.Session,
	comms: kcomms.Comms,
	boot:  kboot.Boot,
	// ...your world: entity maps, UI handles, campaign state
}
```

One session, one boot, no globals. Everything the toolkit needs to survive a
re-host or a resumed save lives in the session. Everything engine-shaped
(lobby, chat, scoreboard, the stage/world containers, the transport wire)
lives in the boot ([kit/boot](boot.md)), and every widget is a public field
you may restyle or ignore.

## 1. Boot and lobby (15 minutes)

In `ready()`:

```odin
kboot.boot_attach(&self.boot, self.owner, &self.ses, &self.comms, kboot.Options{
	title    = "MY GAME",
	status   = "Host a cave, or join one at localhost",
	msg_kind = MSG_SESSION, // MSG_SESSION :: u8(0) — all kit/session traffic under one game byte
	env      = "MY", // MY_PORT/_NAME/_TOKEN identity + the MY_LATENCY shim
	methods  = {"on_host", "on_join", "on_start", "on_chat",
	            "on_packet", "on_peer_left", "on_net_up", "on_net_down"},
})
```

That is a hosted, joinable lobby: title, status line, player list, Host/Join/
Start buttons, chat, scoreboard, and the session's transport wire. The four
transport forwards (`on_packet`/`on_peer_left`/`on_net_up`/`on_net_down`) are
**generated**: your `boot: kboot.Boot` field declares them, and a peer that
drops (Alt-F4, crash, lost connection) is cleared from the roster
automatically. Hand-write a same-named method to override one.

You declare the four game-shaped doors: Host presses land on
`kboot.boot_host(&self.boot, port, name)`, Join on
`kboot.boot_join(&self.boot, addr, port, token, name)`. Each is just a guard,
the boot call, and a flavor status line. Copy either example game's `net.odin`
to start (it is about 60 lines, all doors).

The join's `token` is the player identity (`kboot.boot_token(&self.boot)`,
persisted in `user://my_token`, overridable via `MY_TOKEN` so same-machine
tests pick distinct seats). Presenting the same token later (after a crash, a
quit, a resumed save) reclaims the same identity, stats, and entities. Persist
it; never regenerate it. See [session](session.md).

In `process()`, one call pumps the wire, ticks the session, reacts to the five
events every game handles identically (lobby/scoreboard repaints, the
join-failed status line), and re-yields every event; two generated procs route
the rest: your host tick (declared with `@(gd_step = "authority")`) and your
[event halves](session.md#event-halves-game_event)
(`my_game_player_joined`, `my_game_entity_spawned`, …):

```odin
events, _, ticks := kboot.boot_pump(&self.boot, delta, now_s())
my_game_step(self, ticks)    // hosts run the declared tick; clients no-op
my_game_events(self, events) // dispatch to whichever halves you declared
```

This is an events model, not callbacks, and it has no role branches: nothing
calls into your half-initialized script, and the generated dispatch holds
every `is_host`. The raw layer underneath (`wire_attach`/`wire_pump`,
`session_tick`/`session_poll`) stays public for games that want to drive it
directly: [netgd](netgd.md), [session](session.md).

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

scriptgen generates the serialization, dirty-tracking, and a `Command_Set`;
`registry_insert` writes `net_id` back so you can't forget it. The factory is
one tag on the scene export you already have, and it names what the scene
embodies and its stable wire id:

```odin
// on CaveLobby — an ordinary drag-drop export, plus the declaration:
chest_scene: ^gd.Resource `gd:"entity=Chest:2"`,
```

`cave_lobby_entities(self, &self.boot)` (one call
in `ready()`, after `boot_attach`) installs the generated table: every peer,
the host included, builds a spawn the same way (instantiate under `boot.world`,
free on despawn, id→node ledger). Your bookkeeping is a typed, name-paired
hook:

```odin
@(gd_half)
chest_spawned :: proc(game: ^CaveLobby, self: ^Chest, id: knet.Net_Id, owner: knet.Player_Id) {
	game.chests[id] = self
}
```

The host spawns typed. The tag generates a `chest_spawn` helper, so
world-building code exists exactly once and no cast ever appears:

```odin
chest, id := chest_spawn(&self.boot)
chest.x, chest.y = 300, 180
kboot.boot_spawn_send(&self.boot, id)
```

Fields you change on the host after this ride the per-tick delta walk to
everyone. That is the whole replication story: **you change a field, and you
are done.**

## 3. Movement that feels right (30 minutes)

Give players' avatars owner-streamed fields:

```odin
x, y: f32 `gd:"owner,interp"`,
```

The owner writes them every frame; the toolkit ships last-value snapshots on
the unreliable channel and remote screens interpolate about 3 ticks in the
past, staying smooth through jitter and drops. Two contracts to respect:

- **Only the owner moves the owner.** Respawns, level changes, and knockbacks
  on someone else's avatar are expressed as replicated state the owner reacts
  to (hp came back → walk out of the grave yourself).
- **Jumps are teleports.** On a level change, blink, or respawn, call
  `ksess.session_teleport(&ses, id)` on the frame you write the jumped
  position, or remote screens will slide your avatar across the whole map.

## 4. Verbs — the intent pipeline (1 hour)

A verb is a plain proc on the entity it mutates:

```odin
@(gd_command = "predict,any_seat")
chest_take :: proc(self: ^Chest, slot: u8, count: u16, px, py: f32) -> (ok: bool, taken: kitems.Slot) {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false, {}}
	taken = kitems.take(self.slots[:], int(slot), count)
	return taken.count > 0, taken
}
```

The code looks single-player and has zero role branches. The generated
`chest_take_cmd` wrapper runs it authoritatively on the host and predictively
on clients; a false first return means no: state auto-reverts on every peer,
and a rejection carries the authoritative truth back. Two players race the
last item: both predict success, the host runs them in arrival order, the
loser reverts. Conflict resolution costs you nothing: it is the pipeline.

A command may only mutate its target. The cross-entity half ("loot lands in my
bag") is the verb's name-paired
**[consequence](net.md#consequences-verb_then)**: results after the applied
bool are its payload, threaded into `<verb>_then` with the issuer and the wire
args. It runs on the authority only (for client commands and the host's own)
and never for a prediction:

```odin
@(gd_half)
chest_take_then :: proc(game: ^CaveLobby, self: ^Chest, by: knet.Player_Id, slot: u8, count: u16, px, py: f32, taken: kitems.Slot) {
	cave_credit(game, by, self, taken) // an ordinary host mutation — deltas carry it to everyone
}
```

Gate verbs before issuing (stamina, cooldown, death): a refused prediction
still rides the wire, and spamming ungated verbs floods your log with
rejections. See [items](items.md) and [interact](interact.md) for the
deterministic ops that are safe inside command procs.

## 5. Combat that never feels sloppy (1-2 hours)

The pattern (cavecrawl's `rocks.odin`, about 100 lines with kit/fx doing the
flying):

- The **cast** is a predicted command (ability slot: cooldown + cost checked in
  the proc, [combat](combat.md)).
- The shooter's screen draws its projectile **at cast time**: a `kfx.Tracers`
  visual, no entity, no wire. Press fire, and you see the rock immediately.
- The **host** simulates the authoritative projectile (the only one that hurts)
  and announces the `kcombat.Fire` on an app tag; other screens draw their
  visuals from that. Everyone skips their own echo.
- Visual contact plays the impact now: `kcombat.php_note_hit` dips the hp you
  display (an overlay, never the replicated field); truth arrives a beat later
  as ordinary deltas and squares the number. A host-side miss heals the dip
  back.

**The moving cast rule:** the Fire must carry the shooter's own origin (their
screen's truth), not the host's lagged copy of their position. The origin is
leashed within reach on the host (`kcombat.leash`). Without it, a strafing
shooter watches rocks connect while the host sails them wide.

Prove the feel with the latency shim before you trust it: set
`Options.latency_env = "MY_LATENCY"` and run under `MY_LATENCY=120` (or call
`netgd.wire_set_latency(&self.boot.wire, 120)` directly).

## 6. Enemies (1 hour)

There is no NPC framework ([ai](ai.md)). A dweller is an ordinary entity owned
by the host player: the host's brain tick writes its streamed position like any
owner, its mood is one replicated byte, and every client watches the hunt
through the same machinery that carries everything else. `kai.Director` +
`director_tick` pace waves from data; brains live in a host-side map keyed by
net id, rebuilt on resume from your save blob.

## 7. Levels: replicate the byte, not the scenery (1 hour)

A `Level` entity with a `depth: u8` byte is the entire level-migration wire
protocol. Each peer loads `level_N.tscn` locally on the depth edge (static
geometry never rides the wire); the host reads Marker2D spawn points from its
own instance and session-spawns the dynamic entities; wave plans live in `.tres`
resources. Descending means despawning the old floor's entities, bumping the
byte, and building the next floor. Drop-in joiners and resumed saves need no
special casing: the byte is already in the snapshot.

## 8. Runs end: match flow (1 hour)

One more byte on the Level entity: `won: u8`. The last floor's cleared door
sets it; every peer keys its end screen (scoreboard + status + the host's Start
reading as "again") off the won edge; restart clears it and rebuilds floor 1
**in the same session**: seats, tokens, and the cumulative ledger persist,
because a restart is just deltas.

**Deltas carry state, not events.** A byte flipped 1→0 within one net tick
never ships (the shadow diff sees no change). Edges must outlive a tick;
anything genuinely event-shaped belongs in an explicit message
([comms](comms.md) or an app tag).

Moderation matters too, because you are shipping this to the public internet.
The tools are `session_kick(player, ban)`, `session_set_locked`, and
`Session_Config.max_players`, with `netgd.wire_drop` closing the kicked socket
after the "you were kicked" message flushes. Returning identities pass lock and
capacity: their seat is theirs.

## 9. Quit and resume (30 minutes)

```odin
// save: one call for everything the session knows + your blob for the rest
ksave.save_write(&self.ses, &w, GAME_VERSION, my_campaign_blob)
// resume: the whole Resume button
blob, err := ksave.resume(&self.ses, name, path, GAME_VERSION)
```

The session snapshot already carries identity, stats, and every entity. Saving
is the backup-host contract pointed at a file. Your blob carries what only you
know (wave director, AI clocks). Friends rejoin a resumed run with their
persisted tokens like any reconnect. See [save](save.md).

## 9b. Carryable entities (30 minutes)

Give an entity owner-streamed position and it can be carried: a grab command
whose `_then` calls `session_set_owner(ses, id, by)`, an `Ev_Owner_Changed`
handler, and per-frame glue on the carrier (`relic.x = me.x + 10`). Drop hands
it to `PLAYER_ID_INVALID`, and it rests where it was left. Mounts, possession,
and dragging bodies are the same three pieces.

On top of that, the co-op staple, **downed/revive**, is one predicted command
on the downed player's entity (`hp = REVIVE_HP` behind a range gate), a
bleed-out clock on the host, and an hp-at-the-edge check so the owner knows a
revive-in-place from a bleed-out respawn. No new machinery is needed; see
cavecrawl's `spelunker_revive`.

## 9c. Host migration (30 minutes)

The backup snapshots that ship every few seconds make the loss of the host
survivable. The handoff is driven by `kboot.boot_migration`: declare four halves
and make one `ready` call with the generated table.

- `<game>_backup` writes your campaign bytes onto every backup.
- `<game>_took_over` reads them back on the heir and mends.
- `<game>_wiped` clears the never-entity pools after the kit's census-driven
  wipe.
- `<game>_migrating` words each arm.

The kit begins the handoff on `Ev_Backup_Target`, runs the takeover/chase fork
hands-free off the events tail, caps the retries, and holds the window latches.
Cavecrawl is the worked example, and its acceptance test act 4 kills the host
with `kill -9` to prove nobody has to press anything. See
[session.md](session.md#backup-hosting-and-resume) for the recipe.

## 9d. Shared-seed procgen (30 minutes)

Replicate the *seed*, not the scenery: one `seed: u32` field on your level
entity, and every peer grows identical decoration locally: zero wire bytes for
the world it implies. The one rule: **integer math end to end** (cavecrawl's
`splitmix32` scatter). Floats are the classic procgen divergence trap: FMA
contraction, libm differences, and fast-math flags all vary by platform, and a
single divergent low bit becomes two different caves. Cavecrawl's acceptance
test proves convergence directly: both processes print a checksum of what they
grew, and the test demands they match.

## 10. Ship it on Steam (1 hour + a friend)

Swap the transport and change nothing else ([steamgd](steamgd.md)):

```odin
if steamgd.available() && steamgd.init(APP_ID) {
	steamgd.listen(self.owner, "on_lobby_created", "on_lobby_joined", "on_join_requested")
}
// host: create_lobby -> lobby_created -> host_peer -> invite_overlay
// guest: overlay "Join Game" -> join_requested -> join_lobby -> client_peer
```

The Session_Wire never changes: SceneMultiplayer's signals fire identically
over any MultiplayerPeer. Verify live with the Spacewar app id (480), a
`steam_appid.txt`, and one friend.

## 11. Headless acceptance tests

Every brick above lands with a **headless acceptance test**: two real
processes, real ENet, 120ms injected latency, driving the real scene tree and
grepping log lines (`examples/cavecrawl/run.sh` + `cave_test.gd`). When
something feels wrong in play, reproduce it in the driver rather than in
playtests. The greps show you exactly what shipped. Steal the pattern: your
game's `@(gd_method)` surface is drivable by a test script exactly like keys
drive it in play.

## 12. Server-authoritative games

This tutorial builds the friendslop shape: host-authoritative, friends-only,
trust-your-peers. If the game you actually want is contested (a duel, a ranked
ladder, anything where a client must not be trusted with its own position),
the same declarative surface has a server-authoritative twin: tag fields
`predict`, move their writes into a `@(gd_tick)`, and rollback-resimulation
with lag compensation comes generated. It is chosen per field, so everything
you built today (sessions, entities, verbs, chat, saves) carries over and the
two models compose in one game. Read [timelines](timelines.md) to choose,
[sim](sim.md) to build, including the "Promoting a coop game" checklist for
exactly the game you just finished.
