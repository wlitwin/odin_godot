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

**Teardown — `boot_detach(b)`, and THE OWNERSHIP RULE.** `boot_attach` builds
a boot-owned stack; `boot_detach` is its symmetric twin, for the one flow that
crosses `attach` without freeing the game's node: **back to menu, then re-host
or re-join in the same live process.** Without it every return leaked (the
widget tracking arrays, the wire's gauge + shim containers, the entity ledgers,
the succession clones) and every re-host *doubled* the node forest (a second
`ui_layer`/`stage`/`world` piled onto the first). `boot_detach` frees exactly
what `boot_attach` and the doors allocated and zeroes the `Boot` back to
pre-attach — a fresh `boot_attach` rebuilds everything. It is **the game's
explicit verb, wired to no scene-exit hook**: a game returning to its menu
calls it; the engine tearing the whole node down frees the same nodes anyway
(boot lives as long as its node) and the Odin memory dies with the process, so
there is nothing to hook. It is idempotent — safe on an already-detached
(zeroed) `Boot`.

The rule it embodies, one line for every layer: **boot lives as long as its
node; below boot, X destroys what X inits; node trees belong to the scene.**
boot *created* the container nodes (`ui_layer`/`stage`/`world`), so
`boot_detach` queue-frees THOSE — and the widgets, the legend, and the world's
entities parented under them ride the subtree down with one free each. The
[kui `*_destroy`](ui.md) calls free only their Odin-side tracking arrays (the
nodes belong to the container, i.e. boot); `netgd.wire_detach` frees the wire's
own gauge + shim containers. Nothing is freed twice — no layer frees a node
another layer created.

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
`wire_pump` + `session_tick`, then walks every drained session event through
the kit's own forwarding table (`kit/boot/forward.odin`), then returns
**every** session event plus the comms markers (temp-allocated). The game's
own reactions are its
[declared event halves](session.md#event-halves-game_event--the-switch-generated)
— hand the stream to the generated `<snake>_events` and each half runs
*after* boot's stock reaction, so a game-specific status line simply
overwrites the stock one.

**The kit's forwards are complete by construction.** `forward.odin` holds ONE
switch over `ksess.Event`, and it is not `#partial`: every variant is named,
and the ones with no kit-side consequence are named with an empty case and
the one word that says why (`FACTORY`, `SIM WIRE`, `GAME-FACING`…). Adding a
session event is therefore a *compile error* in `kit/boot` until somebody has
decided what the kit owes it. This replaced three hand-written partial
switches — the lane's `lane_set_owner`, the lane's `lane_drop_player`, and
the succession machine — where a new event with a lane or migration
consequence compiled perfectly clean with its forward simply missing. What
the table pays for today: roster/score repaints and the host's Start gating
at `min_players`, `lane_set_owner`/`lane_drop_player` (so no game ever forgets
them), the succession dance's five arms, the phase's world latch, and the
status line + **restored Host/Join doors** on every way a seat can end
(failed, denied with the host's reason, kicked).

**Where the boot stands:** `boot_phase(b)` returns the coarse lifecycle —
the `running`/`started` latch pair every game hand-kept, answered once.
`Boot_Phase` is `.Menu` (no seat and none coming; the Host/Join doors
showing), `.Connecting` (a join in flight — a code at the phonebook and a
survivor's succession chase both count), `.Lobby` (seated; hosting counts),
`.Playing` (the world reached this screen — first spawn/state/resync).

It is **derived, not tracked**. Every coarse answer is read off the session
(`ran` / `joined` / `join_waited`) plus boot's own rendezvous, so a game that
started its run the RAW way — `netgd`/`ksess` by hand, `boot_pump` for
everything after — gets a truthful phase without having touched a door. The
one fact nothing below boot knows, *the world reached this screen*, is the
single latch left, and `boot_pump` is its only writer: raised in the drain on
the first spawn/state/resync, dropped at the top of any frame that finds no
seat (`boot_open_host` drops it too, for the one re-seat with no unseated
frame — menu → Host again in a live process). Consequences: a failed or
denied join and a kick fall back to `.Menu` because the session disarms its
own join clock; a BARE host loss stays put, because the seat outlives the
socket and succession may re-seat it; a survivor's chase reads `.Connecting`,
because the dial genuinely restarts the session as a client.

`boot_phase` is a LEVEL. A swap that must happen exactly once (hide the
lobby, print a receipt) wants the rising EDGE, and no bool is needed for it:
`boot_pump` is the only place the phase rises, so read the phase before the
pump and compare after — see `examples/hello_net`'s `process`.

**The factory, written by nobody:** tag each exported entity scene with what
it bodies and its stable wire id, and pass the GENERATED table to
`boot_entities` — the make/free switches, the `TYPE` consts, the
`spawn_scene` helper, and the id→node map all stop existing:

```odin
// on the game struct — ordinary drag-drop exports, plus the declaration:
mob_scene: ^gd.Resource `gd:"entity=Mob:3"`,

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
separately if you want the ritual your way).

Under both is **one door per direction**, parameterized by transport:

```odin
boot_open_host(b, t: ^netgd.Transport, at: netgd.Endpoint, name, token = 0, dedicated = false) -> bool
boot_open_join(b, t: ^netgd.Transport, at: netgd.Endpoint, name, token, spectate = false, status = "Joining...") -> bool
```

Every named door on this page is those two plus a status line. The ritual —
reconnect identity, [succession](netgd.md#swapping-transports) config (the
torch flavor comes from the transport's own record, so a door is never told
twice), phase, menu, chat, roster — is written once, and a new transport
inherits all of it by filling a `netgd.Transport`. Steam is the proof: it had
no boot door at all, so it forgot every part of the ritual; it now has both
doors for the price of one record (`ksteam.TRANSPORT` —
[steamgd.md](steamgd.md)).
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
`boot_net_stats(b)` returns the shared coop [`kui.Net_Stats`](ui.md#the-netgraph--is-it-healthy-drawn)
fill (rtt, link jitter/loss, malformed drops, bytes-by-kind); a sim-lane game
lays its `sim`/lead/resim rows on the result before `netgraph_refresh`.

Identity pairs with [`ksave.token`](save.md): the env-or-file-or-per-instance
ladder in one call, with the same-machine seat-stealing footgun documented as
an option instead of discovered in production.
