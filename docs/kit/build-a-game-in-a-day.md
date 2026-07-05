# Build a multiplayer game in a day

The friendslop toolkit exists for one shape of game: **you and your friends,
one of you hosts, things go wrong together.** This tutorial builds that game —
a small co-op cave crawler — the same way `examples/cavecrawl` was built,
brick by brick. Cavecrawl is the finished version of everything below; when a
step here feels terse, the corresponding file there is the long answer.

The promise you are holding the toolkit to: **gameplay code has zero role
branches.** You write mutation code that looks single-player; the host runs
it authoritatively, clients predict it, rejections revert it, and remote
screens interpolate it — without you checking `is_host` in gameplay. Where a
role branch would creep in, the toolkit hands you a hook instead.

## 0. The one struct

Everything hangs off your main script (cavecrawl calls it `CaveLobby`):

```odin
CaveLobby :: struct {
	owner: gd.Node,
	ses:   ksess.Session,
	wire:  netgd.Session_Wire,
	// ...your world: entity maps, UI handles, campaign state
}
```

One session, one wire, no globals. Everything the toolkit needs to survive a
re-host or a resumed save lives in the session; everything transport-shaped
lives in the wire.

## 1. Wire and lobby (15 minutes)

In `ready()`:

```odin
ksess.session_set_factory(&self.ses, self, cave_make_entity, cave_free_entity)
ksess.session_set_command_hook(&self.ses, self, cave_command_hook)
netgd.wire_attach(&self.wire, self.owner, &self.ses, MSG_SESSION)
netgd.wire_listen(&self.wire, "on_packet", "on_peer_left", "on_net_up", "on_net_down")
self.ui = kui.lobby_make(self.owner, "MY GAME")
```

Godot signals must land on script methods, so your game keeps four one-line
forwards (`wire_receive`, `session_peer_disconnected`, `session_client_join`,
`session_peer_disconnected(HOST_PEER)`) — see [netgd](netgd.md). **Do not skip
the disconnect forwards.** An unwired `peer_disconnected` means an alt-F4'd
friend haunts your roster forever; an unwired `connection_failed` means a
failed join hangs on "Joining..." — the first playtest bug of every
multiplayer game ever shipped.

Host button → `gd.host` + `session_host_start`. Join button → `gd.join` +
`session_client_start(ksave.persistent_token("user://my_token"), name)`.

That token IS the player. Same token later — after a crash, a quit, a resumed
save — reclaims the same identity, stats, and entities. Persist it; never
regenerate it. See [session](session.md).

In `process()`, drive everything and drain events:

```odin
ticks, _ := ksess.session_tick(&self.ses, delta, now)
netgd.wire_pump(&self.wire, now)
for {
	ev, ok := ksess.session_poll(&self.ses)
	if !ok {break}
	switch e in ev { /* react: joins, spawns, state, rejections... */ }
}
```

Events, not callbacks: nothing calls into your half-initialized script.

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
`registry_insert` writes `net_id` back so you can't forget it. Your factory
(one switch, used by EVERY peer — the host included) instantiates the scene
and returns the struct + generated set. The host spawns with the two-phase
pair, so creation code exists exactly once:

```odin
ep, id := ksess.session_spawn_make(&self.ses, CHEST_TYPE)
chest := cast(^Chest)ep
chest.x, chest.y = 300, 180
ksess.session_spawn_send(&self.ses, id)
```

Fields you change on the host after this ride the per-tick delta walk to
everyone. That is the whole replication story: **change a field, done.**

## 3. Movement that feels right (30 minutes)

Give players' avatars owner-streamed fields:

```odin
x, y: f32 `gd:"replicate=owner_stream"`,
```

The OWNER writes them every frame; the toolkit ships last-value snapshots on
the unreliable channel and remote screens interpolate ~3 ticks in the past —
smooth through jitter and drops. Two contracts to respect:

- **Only the owner moves the owner.** Respawns, level changes, knockbacks on
  someone else's avatar are expressed as replicated state the owner REACTS to
  (hp came back → walk out of the grave yourself).
- **Jumps are teleports.** Level change, blink, respawn — call
  `ksess.session_teleport(&ses, id)` on the frame you write the jumped
  position, or remote screens will slide your avatar across the whole map.

## 4. Verbs — the intent pipeline (1 hour)

A verb is a plain proc on the entity it mutates:

```odin
@(gd_command = "predict")
chest_take :: proc(self: ^Chest, slot: u8, count: u16, px, py: f32) -> bool {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false}
	taken := kitems.take(self.slots[:], int(slot), count)
	if taken.count == 0 {return false}
	self.last_take = taken // non-replicated scratch for the hook
	return true
}
```

Single-player-looking code, zero role branches. The generated `chest_take_cmd`
wrapper runs it authoritatively on the host and predictively on clients;
`false` means NO — state auto-reverts on every peer, and a rejection carries
the authoritative truth back. Two players race the last item: both predict
success, the host runs them in arrival order, the loser reverts. Conflict
resolution costs you nothing — it IS the pipeline.

A command may only mutate its target. The cross-entity half — "loot lands in
MY bag" — goes in the **command hook**, which fires on the authority for
client commands AND the host's own (no "inline authority half" beside each
issue site):

```odin
cave_command_hook :: proc(user: rawptr, player: knet.Player_Id, entity: knet.Net_Id, cmd: u16, ok: bool) {
	if !ok {return}
	switch cmd { case CHEST_CMD_TAKE: /* credit player's bag from last_take */ }
}
```

Gate verbs BEFORE issuing (stamina, cooldown, death) — a refused prediction
still rides the wire, and spamming ungated verbs floods your log with
rejections. See [items](items.md) and [interact](interact.md) for the
deterministic ops that are safe inside command procs.

## 5. Combat that never feels sloppy (1-2 hours)

The pattern (cavecrawl's `rocks.odin`, ~100 lines with kit/fx doing the
flying):

- The **cast** is a predicted command (ability slot: cooldown + cost checked
  in the proc, [combat](combat.md)).
- The shooter's screen draws its projectile **at cast time** — a
  `kfx.Tracers` visual, no entity, no wire. Press fire, see rock.
- The **host** simulates the authoritative projectile (the only one that
  hurts) and announces the `kcombat.Fire` on an app tag; other screens draw
  their visuals from that. Everyone skips their own echo.
- Visual contact plays the impact NOW: `kcombat.php_note_hit` dips the hp you
  DISPLAY (an overlay — never the replicated field); truth arrives a beat
  later as ordinary deltas and squares the number. A host-side miss heals the
  dip back.

**The moving-cast lesson, learned the hard way:** the Fire must carry the
shooter's OWN origin (their screen's truth), not the host's lagged copy of
their position — leashed within reach on the host (`kcombat.leash`). Without
it, a strafing shooter watches rocks connect while the host sails them wide.

Prove the feel with the latency shim before you trust it:
`netgd.wire_set_latency(&self.wire, 120)`.

## 6. Things that bite back (1 hour)

There is no NPC framework and that is the point ([ai](ai.md)). A dweller is
an ordinary entity owned by the host player: the host's brain tick writes its
streamed position like any owner, its mood is one replicated byte, and every
client watches the hunt through the same machinery that carries everything
else. `kai.Director` + `director_tick` pace waves from data; brains live in a
host-side map keyed by net id, rebuilt on resume from your save blob.

## 7. Levels: replicate the byte, not the scenery (1 hour)

A `Level` entity with a `depth: u8` byte is the entire level-migration wire
protocol. Each peer loads `level_N.tscn` LOCALLY on the depth edge (static
geometry never rides the wire); the host reads Marker2D spawn points from its
own instance and session-spawns the dynamic entities; wave plans live in
`.tres` resources. Descending = despawn the old floor's entities, bump the
byte, build the next floor. Drop-in joiners and resumed saves need no special
casing — the byte is already in the snapshot.

## 8. Runs end: match flow (1 hour)

One more byte on the Level entity: `won: u8`. The last floor's cleared door
sets it; every peer keys its end screen (scoreboard + status + the host's
Start reading as "again") off the won edge; restart clears it and rebuilds
floor 1 **in the same session** — seats, tokens, and the cumulative ledger
persist, because a restart is just deltas.

**The pulse lesson:** deltas carry STATE, not events. A byte flipped 1→0
within one net tick never ships (the shadow diff sees no change). Edges must
outlive a tick; anything genuinely event-shaped belongs in an explicit
message ([comms](comms.md) or an app tag).

And moderation, because you are shipping this to the public internet:
`session_kick(player, ban)`, `session_set_locked`, `Session_Config.max_players`
— with `netgd.wire_drop` closing the kicked socket AFTER the "you were
kicked" message flushes. Returning identities pass lock and capacity: their
seat is theirs.

## 9. Quit and resume (30 minutes)

```odin
// save: one call for everything the session knows + your blob for the rest
ksave.save_write(&self.ses, &w, GAME_VERSION, my_campaign_blob)
// resume: the whole Resume button
blob, err := ksave.resume(&self.ses, name, path, GAME_VERSION)
```

The session snapshot already carries identity, stats, and every entity —
saving is the backup-host contract pointed at a file. Your blob carries what
only you know (wave director, AI clocks). Friends rejoin a resumed run with
their persisted tokens like any reconnect. See [save](save.md).

## 10. Ship it on Steam (1 hour + a friend)

Swap the transport, change nothing else ([steamgd](steamgd.md)):

```odin
if steamgd.available() && steamgd.init(APP_ID) {
	steamgd.listen(self.owner, "on_lobby_created", "on_lobby_joined", "on_join_requested")
}
// host: create_lobby -> lobby_created -> host_peer -> invite_overlay
// guest: overlay "Join Game" -> join_requested -> join_lobby -> client_peer
```

The Session_Wire never changes — SceneMultiplayer's signals fire identically
over any MultiplayerPeer. Verify live with the Spacewar app id (480), a
`steam_appid.txt`, and one friend.

## 11. The habit that made all of this work

Every brick above landed with a **headless acid test**: two real processes,
real ENet, 120ms injected latency, driving the real scene tree and grepping
log lines (`examples/cavecrawl/run.sh` + `cave_test.gd`). When something felt
wrong at a friend's house, the first move was reproducing it in the driver —
the moving-cast miss, the kicked-message race, and the pulse-swallow above
were all caught by greps, not playtests. Steal the pattern: your game's
`@(gd_method)` surface is drivable by a test script exactly like keys drive
it in play.
