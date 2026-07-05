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

## Post-v1 (recorded, deliberate)

Ownership transfer (carry/mounts/revive-dragging), downed/revive, live host
migration (the backup snapshots already ship), shared-seed procgen, voice
(v1 assumes Discord). The architecture holds the door open for all of these;
see the design notes in the repository's knowledge base.
