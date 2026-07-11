# The friendslop toolkit

Reusable multiplayer game systems under `godot:kit/*`, for one shape of game:
**you and your friends, one of you hosts, things go wrong together.** 2–8
players, host-authoritative, drop-in join, reconnect, save/resume, ENet or
Steam. Built and proven by `examples/cavecrawl`, which grows with every
package and doubles as the reference implementation.

**Start with the [tutorial](build-a-game-in-a-day.md)** — it builds the whole
game in order and links each page below at the moment you need it.

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
| [boot](boot.md) | `kit/boot` | The first thirty lines of every game, written once: lobby/chat/score/wire attach + the frame pump |
| [net](net.md) | `kit/net` | The engine-free core: wire format, registry, deltas, owner streams, the intent→command→result pipeline |
| [session](session.md) | `kit/session` | Identity, roster, events, spawn/despawn via factory, stats, moderation, backup hosting |
| [netgd](netgd.md) | `kit/netgd` | The Godot transport binding: Session_Wire, channels, the latency shim, kick-socket handling |
| [steamgd](steamgd.md) | `kit/steamgd` | Steam lobbies + invite overlay over GodotSteam, by name — same wire, different door |
| [comms](comms.md) | `kit/comms` | Chat, system lines, positional pings, drop-in catchup |
| [interact](interact.md) | `kit/interact` | Range/facing gates, candidate picking — prompt and host gate share the same math |
| [items](items.md) | `kit/items` | Item defs + stack-aware slot inventories that replicate as plain fields |
| [combat](combat.md) | `kit/combat` | Health/damage, host-validated projectiles, abilities, predicted-hp display |
| [ai](ai.md) | `kit/ai` | Host-ticked brains as a pattern, wave director, perception |
| [nav](nav.md) | `kit/nav` | Thin adapters over the engine's NavigationServer |
| [save](save.md) | `kit/save` | The versioned save envelope, one-call resume, persistent identity |
| [ui](ui.md) | `kit/ui` | Stock-theme lobby, chat, scoreboard, HUD widgets |
| [fx](fx.md) | `kit/fx` | Bursts, flashes, and the projectile tracer pool |
| [testing](testing.md) | — | Acid-test your game: the shipped harness template and the conventions it encodes |

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
code): character-portable saves and private per-player state. See the design
notes in the repository's knowledge base.
