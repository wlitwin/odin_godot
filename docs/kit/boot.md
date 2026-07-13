# kit/boot — the first thirty lines, written once

Two games proved that every friendslop project opens the same way: `ready()`
builds the same lobby/chat/scoreboard/stage/world/wire stack line-for-line,
and `process()` starts with the same pump-tick-drain preamble plus the same
five boilerplate event reactions — roughly a hundred duplicated lines before
any game code. `kit/boot` absorbs exactly that, and nothing game-shaped.

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

// process():
events, marks, ticks := kboot.boot_pump(&self.boot, delta, now_s())
if self.ses.is_host {
	for _ in 0 ..< ticks { my_game_tick(self) }
}
for ev in events {
	#partial switch e in ev { /* ONLY game cases — see below */ }
}
```

**Everything stays yours.** Every widget is a public field on `Boot`
(`boot.ui`, `boot.chat`, `boot.score`, `boot.legend`, `boot.wire`,
`boot.stage`, `boot.world`) — reposition, restyle, or ignore them. `stage`
and `world` are Node2D containers, so screen shake ([kfx.Shake](fx.md)) can
nudge them both as one; a 3D game sets `Options.spatial = true` to get Node3D
containers instead (see `examples/slopball3d`).

**Boot unthrottles desktop windows by default** (vsync off + a 120fps cap):
every friendslop game gets playtested as two windows on one laptop, and with
vsync on, the OS pacing an occluded window's present makes the background
instance *simulate* slow, not just draw slow — the whole main loop blocks on
the compositor, and every timeline-synced screen stutters for it. Headless and
web runs are left untouched. A shipping build that prefers tear-free rendering
opts out with `Options.keep_vsync = true` (and may set its own vsync/fps
policy after `boot_attach`). The eight
`@(gd_method)` names are declared in *your* script (Godot signals must land on
the game's class); their bodies are one-liners — see either example game's
`net.odin` — and **scriptgen validates every name in `methods` against the
class's registered methods at build time**: a typo'd forward is a build
error, not a haunted roster ("" still skips a signal on purpose).

**`boot_pump` handles the boilerplate and re-yields everything.** It runs
`wire_pump` + `session_tick`, reacts to the five events every game reacts to
identically (Welcomed/Joined/Left → lobby+score repaints and the host's Start
gating at `min_players`; Stats → score repaint; Join_Failed/Host_Left →
status lines), then returns **every** session event plus the comms markers
(temp-allocated) so your switch sees the full stream. Your cases run *after*
boot's, so a game-specific status line simply overwrites the stock one.

**The factory, written by nobody:** tag each exported entity scene with what
it bodies and its stable wire id, and pass the GENERATED table to
`boot_entities` — the make/free switches, the `TYPE` consts, the
`spawn_scene` helper, and the id→node map all stop existing:

```odin
// on the game struct — ordinary drag-drop exports, plus the declaration:
mob_scene: ^gd.Resource `gd:"export,resource=PackedScene,entity=Mob:3"`,

// ready(), after boot_attach (the factory parents under boot.world):
kboot.boot_entities(&self.boot, self, scrapyard_entity_kinds[:])

// the game-shaped half stays yours, as typed name-paired hooks (optional):
mob_spawned :: proc(game: ^Scrapyard, self: ^Mob, id: knet.Net_Id, owner: knet.Player_Id) {
	game.mobs[id] = self   // bookkeeping — fields NOT set yet; dress on Ev_Spawned
}
mob_freed :: proc(game: ^Scrapyard, self: ^Mob, id: knet.Net_Id) {
	delete_key(&game.mobs, id) // node + fields still alive — death fx go here
}
```

The id is EXPLICIT on purpose — it rides saves, rejoins, and migration
backups, so auto-numbering would scramble worlds across builds; scriptgen
errors on duplicates, unknown structs, and mis-shaped hooks at build time.
`boot_node(b, id)` looks up an entity's node (the old `nodes[id]` map);
`boot_entities_clear(b)` is the back-to-lobby/takeover wipe. The scene is
read through the field at spawn time, so editor wiring and hot reload keep
working — and `session_set_factory` remains the escape hatch for exotic
creation.

**The buttons:** `boot_host(b, port, name)` and
`boot_join(b, addr, port, token, name)` do transport-up + session-start + the
menu/status/chat ritual (via `netgd.begin_host/begin_join`, which exist
separately if you want the ritual your way — e.g. cavecrawl's Steam paths).
`boot_serve(b, port, name)` is the **dedicated-server door**: same transport,
but the authority holds an infrastructure seat (no avatar, no roster row,
uncounted by player gates, succession never arms — see
[session.md](session.md)). Nobody presses Start on a server, so auto-start
your world once `session_count(players_only = true)` reaches your threshold
(`examples/slopball`'s `serve` role is the model).
`boot_chat(b, text, &sent)` is the whole `text_submitted` handler, focus
release included ([kui.chat_submit](ui.md)).

Identity pairs with [`ksave.token`](save.md): the env-or-file-or-per-instance
ladder in one call, with the same-machine seat-stealing footgun documented as
an option instead of discovered in production.
