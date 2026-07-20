# The friendslop toolkit

Reusable multiplayer game systems under `godot:kit/*`, for one shape of game:
**you and your friends, one of you hosts, things go wrong together.** 2–8
players, host-authoritative, drop-in join, reconnect, save/resume, ENet or
Steam. Built and proven by `examples/cavecrawl`, which grows with every
package and doubles as the reference implementation.

**Want to feel it in five minutes?** Run `examples/slopball` in two windows
(`bash build/build_scripts.sh examples/slopball`, then `$GODOT --path
examples/slopball` twice — Host in one, Join in the other). **Then build
your own:** the **[quickstart](quickstart.md)** goes zero-to-two-windows in
two small files (`examples/hello_net` is its living copy), and the
**[sim quickstart](quickstart-sim.md)** promotes that game to server
authority for competitive shapes. From there the
[tutorial](build-a-game-in-a-day.md) tours the whole surface in cavecrawl,
linking each page below at the moment you need it — and the
[glossary](glossary.md) is one paragraph per term of art (halves, census,
dress, acid...).

Platform note: macOS is verified end-to-end by the suite; Windows ships
prebuilt cores with limited runtime verification so far, Linux is
build-verified only ([status](../../README.md#platform-status)) — co-op
means your friends' machines, so check before you promise a LAN party.

## The promises

- **Zero role branches in gameplay code.** Mutation procs look single-player;
  the host runs them authoritatively, clients predict them, rejections carry
  truth back. Where a role branch would creep in, there's a hook instead.
- **Change a field, done.** `gd:"replicate"` fields ride a per-tick
  shadow-delta walk; `owner_stream` fields interpolate on remote screens.
- **A player IS a reconnect token.** Identity, stats, and owned entities
  survive crashes, rejoins, re-hosts, and resumed saves.
- **Never feels sloppy.** Predictions bite instantly under real latency; the
  built-in shim (`wire_set_latency`) is how you prove it for YOUR game.

## The packages

| Page | Package | What it owns |
| --- | --- | --- |
| [boot](boot.md) | `kit/boot` | The first thirty lines of every game, written once: lobby/chat/score/wire attach, the frame pump, the generated entity factory |
| [play](play.md) | `godot:play` | Drop-in gameplay blocks: Gun/Ability/Channel/Health/Telegraph verbs, FSM/edge/anim scratch, Puppet — engine physics with one simulator per body — and the `play/sim` shelf (Cool/Mover/Roller), the predicted twins that resim |
| [net](net.md) | `kit/net` | The engine-free core: wire format, registry, deltas, owner streams, the intent→command→result pipeline |
| [session](session.md) | `kit/session` | Identity, roster, events, spawn/despawn via factory, stats, moderation, backup hosting |
| [netgd](netgd.md) | `kit/netgd` | The Godot transport binding: Session_Wire, channels, the latency shim, kick-socket handling |
| [sim](sim.md) | `kit/sim` | The server-authority resim companion: inputs-only up, tick snapshots down, rollback reconcile, lag compensation — for the contested games the coop model isn't |
| [timelines](timelines.md) | — | Choosing a timeline model: coop, predict-self, contested object, predict-world, lockstep — what each never-shows-you costs, and the eight laws the showcases learned |
| [steamgd](steamgd.md) | `kit/steamgd` | Steam lobbies + invite overlay over GodotSteam, by name — same wire, different door |
| [comms](comms.md) | `kit/comms` | Chat, system lines, positional pings, drop-in catchup |
| [xfer](xfer.md) | `kit/xfer` | Chunked large payloads (sprays, skins, level files) — host-relayed, paced, web-safe; the ALBUM keeps the latest per (player, kind) and catches late joiners up |
| [interact](interact.md) | `kit/interact` | Range/facing gates, candidate picking — prompt and host gate share the same math |
| [items](items.md) | `kit/items` | Item defs + stack-aware slot inventories that replicate as plain fields |
| [combat](combat.md) | `kit/combat` | Health/damage, host-validated projectiles, abilities, predicted-hp display |
| [ai](ai.md) | `kit/ai` | Host-ticked brains as a pattern, wave director, perception |
| [nav](nav.md) | `kit/nav` | Thin adapters over the engine's NavigationServer |
| [save](save.md) | `kit/save` | The versioned save envelope, one-call resume, persistent identity |
| [ui](ui.md) | `kit/ui` | Stock-theme lobby, chat, scoreboard, HUD widgets |
| [fx](fx.md) | `kit/fx` | Bursts, flashes, and the projectile tracer pool |
| [testing](testing.md) | — | Acid-test your game: the shipped harness template and the conventions it encodes |

## The house grammar

Three conventions run through every package. They were real but folkloric —
written nowhere, learned by reading. Stated here as rules, they are why a new
package feels familiar before you have read its page.

**Events out; callbacks only for answers.** Seven delivery mechanisms exist,
and the choice among them is mechanical, not taste:

- A module with *many* event shapes drains a named `Event` union — `session_poll`,
  `comms_poll`, `xfer_poll` loop until `ok = false`.
- A module with *one* event shape polls a **bare tuple** — `album_poll` (which
  `(player, kind)` landed), `fire_poll` (the next projectile to spawn). No union
  for a queue of one thing.
- A *value you read* rather than a queue you drain is a **state poll** —
  `code_poll` (the rendezvous phase), `boot_phase` (where the game is).
- A **synchronous callback** exists ONLY where the kit needs an answer
  mid-operation and cannot proceed without it: the factory's `make`/`free` (the
  registry needs the pointer before a snapshot can apply), the interest
  `Locator_Proc` (the session can't read your positions), sim's
  `Sample_Proc`/`Step_Proc`, `Later_Proc`, the command hooks, fx's `On_Hit_Proc`.
- The **`_then` suffix** is the authority-only half of a generated event pair —
  the consequence, gated by the generated dispatch so the half never checks a role.
- **`boot_pump`** forwards slices of the session and comms queues in one call —
  the composed convenience over the two polls.
- Engine-side wiring rides Godot signals through **`@(gd_connect)`**.

The rule the seven collapse to: poll unions for multi-event, tuple-poll for
single-event, synchronous callbacks only for the answer the kit cannot proceed
without, and **everything else is an event.** Handlers file bytes; game code runs
on the game's own stack in the pump — never in a callback into half-initialized
script state, which is the whole reason `session_poll` exists instead of a
delegate.

One refinement the list above compresses, spelled out in
[session.md's three tiers](session.md#three-tiers-of-entry-into-your-code) because
kit/session has the most entry points of any package: the synchronous half is
really *two* kinds. A **pull callback** is the kit asking a question it cannot
answer — the factory's `make`, the interest locator, the backup blob writer, sim's
`Sample_Proc`/`Step_Proc`; you answer and return. An **atomic authority hook** runs
inside an operation whose state does not survive it — the command hooks and
`_then`, an app handler holding a live `^knet.Reader` into the receive buffer; you
act, on the authority, and you do not re-enter. Everything remaining is tier three,
and the derivation is mechanical: *if the same meaning survives being queued and
drained next frame, it must be queued.* That is why `ksess.App_Queue` exists as a
type — the file-and-drain discipline every `SES_APP` rider follows was a convention
each package re-earned, until it wasn't.

**Four verbs name a lifetime.** A type's constructor tells you who owns its
memory, so nobody has to guess whether to free it:

- `_make` returns the value — the caller owns it (`chat_make`, `registry_make`,
  `writer_make`).
- `_init` initializes memory the caller already holds, in place (`session_init`,
  `comms_init`, `lane_init`).
- `_attach` binds to a Godot node whose lifetime the *scene* owns (`wire_attach`,
  `boot_attach`).
- **A zero value is ready to use** — every `*_Config` means the defaults at zero,
  so a zero config is the out-of-the-box session.

Teardown is as precise, and matched to the constructor: `_destroy` frees exactly
what the module allocated and **never a scene node** (the node tree belongs to the
scene); `_clear` / `_reset` empty a container without freeing it
(`chat_clear_input`, `tracers_clear`, `writer_reset`, `later_clear`); `_close`
ends a connection (`code_close`, `web_close`). Match the teardown verb to the
constructor and both leaks and double-frees become errors of habit rather than
runtime surprises.

**A type's whole API is one grep.** The proc prefix IS the type's snake-cased
name — `registry_*` for `Registry`, `lane_*` for `Lane`, `chat_*` for `Chat` —
with no exceptions, so `grep registry_` is the complete surface of `Registry` and
nothing hides under a cleverer name. It is enforced retroactively, and the TYPE
is usually what moves: kit/ui's last two holdouts, `Health_Bar` and `Ability_Bar`
wearing `hp_*` and `abilities_*` procs, became `Hp_Bar` and `Abilities_Bar`
rather than stretching every call site into `health_bar_refresh` — the call site
is what the rule is for, and a widget named for the noun games already say (`hp`,
beside `Inv` and `Score`) is the one that reads.

## Beyond the basics

The former "post-v1" staples are in, demonstrated by cavecrawl's acid acts:
**ownership transfer** (`session_set_owner` — carry/mounts/possession; the
relic), **downed/revive** (`spelunker_revive` — one predicted command, no
hook), **host takeover** (`session_backup_parts` + `session_host_resume`
— the murdered host's run resumes under the backup holder, friends rejoin
and reclaim themselves), **shared-seed procgen** (replicate the dice, grow
the world locally — the cavecrawl scatter), **wire codecs** (`wire=f16` /
custom fixed-size encodings — [net](net.md)), and **entity blobs**
(`session_set_blob` — variable-length state that rides joins, backups, and
saves; [session](session.md)).

**Voice, the stance:** not in the toolkit, deliberately. Friendslop groups
already sit in a Discord call — building voice would spend the complexity
budget on a solved problem. If you ship on Steam, GodotSteam exposes Steam
voice as a near-free add-on ([steamgd](steamgd.md) gives you the singleton
access pattern). The one thing that would change this calculus is PROXIMITY
voice — the horror-co-op signature mechanic — which needs positional mixing
the toolkit's replicated positions make easy to drive; revisit when a game
needs it.

Still deliberately out (documented as recipes in [session](session.md), not
code): character-portable saves, private per-player state, and player-to-
player trade (the mediating-entity transaction). See the design notes in the
repository's knowledge base.
