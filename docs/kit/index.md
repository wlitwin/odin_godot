# The friendslop toolkit

Reusable multiplayer game systems under `godot:kit/*`, for one shape of game:
**you and your friends, one of you hosts, things go wrong together.** 2–8
players, host-authoritative, drop-in join, reconnect, save/resume, ENet or
Steam. `examples/cavecrawl` is the reference implementation. It grows with
every package and doubles as the proof that they compose.

## New here? Start in this order

1. **Feel it in five minutes.** Run `examples/slopball` in two windows:
   `bash build/build_scripts.sh examples/slopball`, then `$GODOT --path
   examples/slopball` twice, with Host in one window and Join in the other.
2. **Build your own.** The **[quickstart](quickstart.md)** goes
   zero-to-two-windows in two small files (`examples/hello_net` is its living
   copy).
3. **Going competitive?** The **[sim quickstart](quickstart-sim.md)** promotes
   that same game to server authority for competitive shapes.
4. **Learn the whole surface.** The **[tutorial](build-a-game-in-a-day.md)**
   tours every package in cavecrawl, linking each page below at the moment you
   need it.
5. **Look up a term.** The **[glossary](glossary.md)** is one paragraph per term
   of art (halves, census, dress...).

Platform note: macOS is verified end-to-end by the suite; Windows ships
prebuilt cores with limited runtime verification so far; Linux is
build-verified only ([status](../../README.md#platform-status)). Co-op
means your friends' machines, so check before you promise a LAN party.

## Guarantees

- **There are zero role branches in gameplay code.** Mutation procs look single-player;
  the host runs them authoritatively, clients predict them, rejections carry
  truth back. Where a role branch would creep in, there's a hook instead.
- **Change a field and you're done.** `gd:"replicate"` fields ride a per-tick
  shadow-delta walk; `owner_stream` fields interpolate on remote screens.
- **A player IS a reconnect token.** Identity, stats, and owned entities
  survive crashes, rejoins, re-hosts, and resumed saves.
- **It never feels sloppy.** Predictions bite instantly under real latency; the
  built-in shim (`wire_set_latency`) is how you prove it for YOUR game.

## The packages

| Page | Package | What it owns |
| --- | --- | --- |
| [boot](boot.md) | `kit/boot` | The first thirty lines of every game, written once: lobby/chat/score/wire attach, the frame pump, the generated entity factory |
| [play](play.md) | `godot:play` | Drop-in gameplay blocks: Gun/Ability/Channel/Health/Telegraph verbs, FSM/edge/anim scratch, Puppet (engine physics with one simulator per body), and the `play/sim` shelf (Cool/Mover/Roller), the predicted twins that resim |
| [net](net.md) | `kit/net` | The engine-free core: wire format, registry, deltas, owner streams, the intent→command→result pipeline |
| [session](session.md) | `kit/session` | Identity, roster, events, spawn/despawn via factory, stats, moderation, backup hosting |
| [netgd](netgd.md) | `kit/netgd` | The Godot transport binding: Session_Wire, channels, the latency shim, kick-socket handling |
| [sim](sim.md) | `kit/sim` | The server-authority resim companion: inputs-only up, tick snapshots down, rollback reconcile, lag compensation, for the contested games the coop model isn't |
| [timelines](timelines.md) | — | Choosing a timeline model: coop, predict-self, contested object, predict-world, lockstep, what each never-shows-you costs, and the eight laws the showcases encode |
| [steamgd](steamgd.md) | `kit/steamgd` | Steam lobbies + invite overlay over GodotSteam, by name (same wire, different door) |
| [comms](comms.md) | `kit/comms` | Chat, system lines, positional pings, drop-in catchup |
| [xfer](xfer.md) | `kit/xfer` | Chunked large payloads (sprays, skins, level files), host-relayed, paced, web-safe; the ALBUM keeps the latest per (player, kind) and catches late joiners up |
| [interact](interact.md) | `kit/interact` | Range/facing gates, candidate picking. Prompt and host gate share the same math |
| [items](items.md) | `kit/items` | Item defs + stack-aware slot inventories that replicate as plain fields |
| [combat](combat.md) | `kit/combat` | Health/damage, host-validated projectiles, abilities, predicted-hp display |
| [ai](ai.md) | `kit/ai` | Host-ticked brains as a pattern, wave director, perception |
| [nav](nav.md) | `kit/nav` | Thin adapters over the engine's NavigationServer |
| [save](save.md) | `kit/save` | The versioned save envelope, one-call resume, persistent identity |
| [ui](ui.md) | `kit/ui` | Stock-theme lobby, chat, scoreboard, HUD widgets |
| [fx](fx.md) | `kit/fx` | Bursts, flashes, and the projectile tracer pool |
| [testing](testing.md) | — | Integration-test your game: the shipped harness template and the conventions it encodes |

## Beyond the basics

These capabilities are in the kit, demonstrated by cavecrawl's integration-test
acts: **ownership transfer** (`session_set_owner`: carry/mounts/possession; the
relic), **downed/revive** (`spelunker_revive`: one predicted command, no
hook), **host takeover** (`session_backup_parts` + `session_host_resume`:
when the host drops, its run resumes under the backup holder, friends rejoin
and reclaim themselves), **shared-seed procgen** (replicate the dice and grow
the world locally, as in the cavecrawl scatter), **wire codecs** (`wire=f16` /
custom fixed-size encodings; see [net](net.md)), and **entity blobs**
(`session_set_blob`: variable-length state that rides joins, backups, and
saves; see [session](session.md)).

## Design notes

This section is not on the learning path; it is for contributors and the curious:

- **[kit design notes and conventions](conventions.md)**: the house grammar
  every package shares (events vs. callbacks, the four lifecycle verbs, the
  one-grep API rule), and what the kit leaves out and where to reach instead
  (voice, mobile, async correspondence, database persistence).
