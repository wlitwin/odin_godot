# Kit multiplayer toolkit

Kit is a set of Odin packages for building multiplayer Godot games. It provides
session management, replicated entities, reconnectable player identities,
transport adapters, common gameplay systems, and integration-test support.

Kit is designed primarily for small, real-time sessions in which one process is
the authority. A player can host the session, or the authority can run as a
dedicated server. ENet, WebRTC, and Steam use the same session and replication
layers; only the transport adapter changes.

## Choose a replication model

Kit supports two complementary models. A game can use either one or combine them
field by field.

| Model | Use it for | How state moves |
| --- | --- | --- |
| Session replication | Cooperative play and state that does not need rollback | The host writes `gd:"replicate"` fields. An entity owner writes `gd:"owner"` fields, which other peers interpolate. Player actions use validated commands. |
| Simulation lane | Movement, aiming, physics, or other contested state | The authority simulates `gd:"predict"` fields at a fixed tick rate. The owning client predicts the same ticks and reconciles against snapshots from the authority. |

The session layer is shared by both models, so identity, reconnects, chat,
spawning, saves, and transports do not change when an entity moves to the
simulation lane. See [Choosing a timeline model](timelines.md) for the tradeoffs
and [the simulation quickstart](quickstart-sim.md) for a small conversion.

Both models share one generated canonical wire ABI. scriptgen recursively
checks every raw network value for fixed widths, explicit enum storage, bounded
containers, and padding-free layout, then hashes the readable schema into the
session fingerprint. Incompatible builds are refused during JOIN instead of
discovering the mismatch by corrupting state.

The root scripts package also receives `NET_SCHEMA`, an allocation-free
`knet.Net_Schema` projection of that same ABI walk. It exposes entity fields,
inputs and constraints, immediate/tick actions and policies, facts and anchors,
profiles, messages, recursive type nodes, and both fingerprints for tooling and
diagnostics.

### Trust and security

The session-replication model trusts an entity owner to provide its streamed
fields. The host still validates command access and relays owner streams only
after checking the sender's current ownership, but owner-streamed movement is
not suitable for adversarial play.

The simulation lane moves selected state to the authority, but a public or
competitive game must also declare input constraints with `@(gd_input)`, keep
any game-specific predicates in the sample validator hook, and run the authority
on a trusted machine. Kit bounds input classes, aggregate input packet bytes,
and per-seat reliable/stream/action rates and bytes; games should tune the
named profile defaults against legitimate peaks and install a moderation hook.
ENet traffic is not
encrypted. WebRTC and Steam provide encrypted transports. The detailed boundary
is documented under [Session: trust and admission](session.md#trust-and-admission).
[Named network profiles](profiles.md) turn the three common trust models into
coherent, validated defaults plus benchmark-backed starting envelopes. The
test suites described in [Testing multiplayer](testing.md) cover the hardening
and operations gates.

## Start here

1. Complete the main [Getting Started](../getting-started.md) guide so you can
   build and run Odin scripts.
2. Follow [Hello, multiplayer](quickstart.md). It builds
   `examples/hello_net`, a two-player example using session replication.
3. Read [Choosing a timeline model](timelines.md) before selecting authority and
   prediction rules for your game.
4. If the authority must simulate player state, continue with
   [Server authority and client prediction](quickstart-sim.md), based on
   `examples/hello_sim`.
5. Use [Build a multiplayer game](build-a-game-in-a-day.md) for a longer tour,
   then keep the package pages below as references.

To see a complete project before writing one, build and open the 2D Slopball
example in two windows:

```sh
bash build/build_scripts.sh examples/slopball
$GODOT --path examples/slopball &
$GODOT --path examples/slopball
```

Host in the first window and join from the second. `examples/cavecrawl` is the
larger co-op reference; `examples/quickdraw` and `examples/speedball` demonstrate
the simulation lane.

## Architecture

Most games use the packages in these layers:

| Layer | Packages | Responsibility |
| --- | --- | --- |
| Game integration | [boot](boot.md), [network profiles](profiles.md) | Connects the stock lobby, validated network configuration, transport, session, generated entity factory, and per-frame pump. |
| Session | [session](session.md), [save](save.md), [comms](comms.md), [xfer](xfer.md) | Player identity and roster, reconnects, entity lifetime, app messages, saves, chat, and large payloads. |
| Replication | [net](net.md), [sim](sim.md) | Field descriptors, deltas, owner streams, commands, fixed-tick simulation, prediction, reconciliation, and lag compensation. |
| Transport | [netgd](netgd.md), [steamgd](steamgd.md) | Godot `MultiplayerPeer` integration, ENet/WebRTC setup, network simulation, join codes, and Steam lobbies. |
| Gameplay and presentation | [play](play.md), [items](items.md), [combat](combat.md), [interact](interact.md), [ai](ai.md), [nav](nav.md), [ui](ui.md), [fx](fx.md) | Optional building blocks that use the session and replication layers. |

`kit/net`, `kit/session`, and `kit/sim` do not import Godot and can be tested
headlessly. `kit/netgd`, `kit/steamgd`, `kit/ui`, and `kit/fx` contain the
engine-facing integration.

## Package reference

| Package | Purpose |
| --- | --- |
| [`godot:kit/boot`](boot.md) | Standard lobby-to-game lifecycle, frame pump, generated entity factory, transport forwarding, and host succession. |
| [`godot:kit/netcfg`](profiles.md) | Engine-free named session/lane profiles and complete-stack validation; re-exported through `kboot`. |
| [`godot:kit/net`](net.md) | Wire codecs, entity descriptors and registry, reliable deltas, owner streams, interpolation, and commands. |
| [`godot:kit/session`](session.md) | Stable player identities, roster, replication scheduling, entity lifetime, stats, moderation, interest management, and backup state. |
| [`godot:kit/netgd`](netgd.md) | Godot transport binding for ENet and WebRTC, including the latency/loss simulator and native join-code flow. |
| [`godot:kit/sim`](sim.md) | Server-authoritative fixed-tick simulation, input delivery, snapshots, client prediction, reconciliation, watched interpolation, and lag compensation. |
| [`godot:kit/steamgd`](steamgd.md) | Steam lobby and invite transport through GodotSteam. |
| [`godot:kit/comms`](comms.md) | Ordered chat, system messages, positional pings, and late-join catch-up. |
| [`godot:kit/xfer`](xfer.md) | Bounded, chunked transfer of payloads that are too large for replicated fields. |
| [`godot:kit/save`](save.md) | Versioned session snapshots and persistent reconnect tokens. |
| [`godot:play`](play.md) | Embeddable gameplay blocks such as health, weapons, abilities, channels, telegraphs, and owner-simulated Godot physics bodies. |
| [`godot:play/sim`](sim.md#simulation-blocks-in-godotplaysim) | Simulation-lane blocks for cooldowns, movement, and rolling bodies. |
| [`godot:kit/interact`](interact.md) | Dimension-independent range, facing, and target-selection helpers. |
| [`godot:kit/items`](items.md) | Item definitions, stack-aware fixed-slot inventories, and grid-packing helpers. |
| [`godot:kit/combat`](combat.md) | Co-op health, abilities, effects, projectile validation, and predicted-health presentation. |
| [`godot:kit/ai`](ai.md) | Perception, steering, patrol, and wave-director helpers for authority-run NPC logic. |
| [`godot:kit/nav`](nav.md) | Thin wrappers around Godot's navigation servers. |
| [`godot:kit/ui`](ui.md) | Code-created lobby, chat, scoreboard, HUD, inventory, and network-health widgets. |
| [`godot:kit/fx`](fx.md) | 2D bursts, flashes, floating text, screen shake, and projectile tracers. |

The [testing guide](testing.md) documents the multi-process harness used by the
examples. The [glossary](glossary.md) defines generated API terms such as
*command half*, *census*, *edge*, and *watched entity*. The
[conventions](conventions.md) page is intended for Kit contributors rather than
as required reading for game authors.

## Scope and current limitations

- The default session size is eight players. Some lower-level session tests
  cover 32 seats, but the shipped example games do not establish a production
  performance envelope at that size.
- Kit does not provide matchmaking, accounts, a persistent backend, voice chat,
  server orchestration, or TURN for native ENet. WebRTC or Steam is the safer
  choice when NAT traversal must work broadly.
- `kit/fx` is currently 2D. The replication, session, combat, interaction, and
  AI packages use dimension-independent data.
- macOS is verified end to end. Windows has prebuilt cores with limited runtime
  verification, and Linux is build-verified. See the repository
  [platform status](../../README.md#platform-status) before choosing deployment
  targets.
- The framework bounds malformed input and per-peer traffic with protocol-wide
  packet, field, container, and item ceilings. Deterministic decoder fuzz and
  property tests cover truncation, mutation, atomic rejection, and replay
  invariants. Treat invited co-op, a listen server, and a public dedicated server
  as different [network profiles](profiles.md).
