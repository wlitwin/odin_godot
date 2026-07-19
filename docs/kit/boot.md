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

// process(): the whole loop, role-free — both procs are generated
events, marks, ticks := kboot.boot_pump(&self.boot, delta, now_s())
my_game_step(self, ticks)     // @(gd_step="authority") pass: host gate + edge pass inside (sim.md)
my_game_events(self, events)  // session-event dispatch over the declared halves (session.md)
```

**Everything stays yours.** Every widget is a public field on `Boot`
(`boot.ui`, `boot.chat`, `boot.score`, `boot.legend`, `boot.wire`,
`boot.stage`, `boot.world`) — reposition, restyle, or ignore them. `stage`
and `world` are Node2D containers, so screen shake ([kfx.Shake](fx.md)) can
nudge them both as one; a 3D game sets `Options.spatial = true` to get Node3D
containers instead (see `examples/slopball3d`).

**Your look, the kit's behavior:** `Options.lobby_scene` / `chat_scene` /
`score_scene` (nil = the stock builds) hand boot game-authored scenes to
ADOPT — the kit resolves the nodes it drives by name and pours the stock
behavior in; everything else in a scene is the game's own chrome. The node
names each widget requires live in
[ui.md's adopt contract](ui.md#full-replacement-the-adopt-contract).

**Boot unthrottles desktop windows by default** (vsync off + a 120fps cap):
every friendslop game gets playtested as two windows on one laptop, and with
vsync on, the OS pacing an occluded window's present makes the background
instance *simulate* slow, not just draw slow — the whole main loop blocks on
the compositor, and every timeline-synced screen stutters for it. Headless and
web runs are left untouched — and so is every RELEASE build: the unthrottle is
DEV BUILDS ONLY, keyed on the build (`-disable-assert`, the release line every
kit guardrail already draws), so a shipped game never tears by default nor
caps a 240 Hz display at 120. `Options.keep_vsync = true` remains the
dev-side opt-out (and a game may set its own vsync/fps policy after
`boot_attach`).

**Count game time in NET TICKS, never frames.** The unthrottle above means
frame rate is 120 on one machine and whatever vsync says on another — a
"3-second" countdown counted in frames halves or doubles per screen
(scrapyard shipped exactly that: its stage clock ran off frames and the
120fps unthrottle cut the countdown in half). `boot_pump` returns `ticks` —
how many fixed net ticks fired this frame — and that is the clock the host's
simulation and every timer should count. Declare the pass and hand it those
ticks; the generated proc holds the role gate and the loop:

```odin
@(gd_step = "authority")
my_game_tick :: proc(self: ^MyGame) { /* timers decrement HERE */ }

// process():
events, _, ticks := kboot.boot_pump(&self.boot, delta, now_s())
my_game_step(self, ticks) // generated: host-only fixed steps + the same-frame edge pass
```

The eight
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
(temp-allocated). The game's own reactions are its
[declared event halves](session.md#event-halves-game_event--the-switch-generated)
— hand the stream to the generated `<snake>_events` and each half runs
*after* boot's stock reaction, so a game-specific status line simply
overwrites the stock one.

**Where the boot stands:** `boot_phase(b)` returns the coarse lifecycle —
the `running`/`started` latch pair every game hand-kept, tracked once.
`Boot_Phase` is `.Menu` (no transport; the Host/Join doors showing),
`.Connecting` (a join door opened, no seat yet — a code resolving included),
`.Lobby` (seated; hosting counts), `.Playing` (the world reached this screen
— first spawn/state/resync). The doors advance it and `boot_pump`'s event
drain moves it: a failed or denied join and a kick fall back to `.Menu`,
while a host loss deliberately stays put — succession may re-seat, so the
welcome moves it, not the loss.

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
`boot_entities_wipe(b)` is the back-to-lobby/takeover wipe — CENSUS-DRIVEN:
it fires the `_freed` hooks per live entity (the by-type maps empty through
the same code that fills them) before freeing the nodes. The scene is read
through the field at spawn time, so editor wiring and hot reload keep
working — and `session_set_factory` remains the escape hatch for exotic
creation.

**The migration dance, danced by nobody.** Declare up to four name-paired
halves — `<game>_backup(self, w)`, `<game>_took_over(self, r)`,
`<game>_wiped(self)`, `<game>_migrating(self, step, target, try)` — and
wire the generated table in ready: `kboot.boot_migration(&self.boot, self,
<snake>_succ_hooks)`. The kit owns the torch, the takeover/chase fork (run
off the generated events tail, so words halves see the old world), the
census-driven wipe, the retry caps, and the window latches;
`boot_take_over`/`boot_chase` stay public for a manual Resume button, and
games that raise their own transports call `boot_succ_config` once. Details
and the arm-by-arm words contract:
[session.md](session.md#backup-hosting-and-resume). Coop lane only — a sim
lane's authority restarts, it does not migrate (asserted with a teaching
message).

**The census, written by nobody.** Every `entity=` tag also generates the
typed queries the hand-kept `map[Net_Id]^T` + owner + `avatar_of` mirrors
existed for — they read the kit's own ledgers (the registry's entity+owner,
the boot's type table):

```odin
mob, ok := mob_of(&self.boot, id)          // the entity behind an id
mine, ok := my_mob(&self.boot)             // this player's avatar
theirs, ok := mob_owned_by(&self.boot, pid)
for id in mob_ids(&self.boot) { ... }      // every live Mob (temp-alloc)
owner := kboot.boot_entity_owner(&self.boot, id) // the old owner_pid map
```

The hooks above shrink to the genuinely game-shaped lines (a hot `me_*`
pointer, death fx) — or vanish. The owned/ids scans walk the type ledger:
friendslop-sized; keep a map yourself in the rare game that makes them hot.

**The forwards, written by nobody:** the four transport forwards every
session game used to copy (`on_packet`/`on_peer_left`/`on_net_up`/
`on_net_down`) are generated from the `boot: kboot.Boot` field on your
script struct — routed through the boot's own wire/session pointers,
name-dispatched (so they survive hot reload), overridable by hand-writing a
same-named `@(gd_method)`. The `Options.methods` list still names them (the
method-name lint holds), but their bodies are no longer yours to get wrong.

**Identity from one prefix:** `Options.env = "MY"` makes `boot_port(b, def)`
/ `boot_name(b, def)` / `boot_token(b)` read `MY_PORT`/`MY_NAME`/`MY_TOKEN`
(token persisted in `user://my_token`), and the whole
[bad-link shim](netgd.md#wire_set_latency--the-bad-link-shim) answers
`MY_LATENCY` / `MY_JITTER` / `MY_LOSS` without `latency_env` — the per-game
env family, absorbed.

**The buttons:** `boot_host(b, port, name)` and
`boot_join(b, addr, port, token, name)` do transport-up + session-start + the
menu/status/chat ritual (via `netgd.begin_host/begin_join`, which exist
separately if you want the ritual your way — e.g. cavecrawl's Steam paths).
`boot_serve(b, port, name)` is the **dedicated-server door**: same transport,
but the authority holds an infrastructure seat (no avatar, no roster row,
uncounted by player gates, succession never arms — see
[session.md](session.md)). `boot_spectate(b, addr, port, token, name)` is the
**watching door** — the dedicated pattern pointed the other way: a seat that
sees everything and is nobody (bypasses a full room, counts toward nothing,
receive-only past the join; [session.md's spectator
paragraph](session.md) has the contract, and the game's spawn loops give it
the same `!p.spectator` skip they give `dedicated`).
Nobody presses Start on a server, so auto-start
your world once `session_count(players_only = true)` reaches your threshold
(`examples/slopball`'s `serve` role is the model).
`boot_chat(b, text, &sent)` is the whole `text_submitted` handler, focus
release included ([kui.chat_submit](ui.md)).

Identity pairs with [`ksave.token`](save.md): the env-or-file-or-per-instance
ladder in one call, with the same-machine seat-stealing footgun documented as
an option instead of discovered in production.
