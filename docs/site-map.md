---
sidebar: false
prev: false
next: false
---

# Site map

Browse all the documentation by topic. Every section is expanded so you can scan
the whole map or use your browser's Find command to locate a subject.

## Start here

| Page | Topics |
| --- | --- |
| [Documentation home](index.md) | The SDK's five layers and where to begin |
| [Learning paths](learn/index.md) | Tutorials in order, from a first script to multiplayer and physics |
| [Choosing Kit or Replay](multiplayer/index.md) | State ownership, prediction, authority, and framework tradeoffs |
| [Example projects](examples/index.md) | Small examples, complete games, and engine interop |
| [API reference](api/index.md) | Search public types, functions, aliases, constants, and variables |
| [API package index](api/generated/index.md) | Every generated package reference, grouped by SDK layer |

## Odin and Godot

| Page | Topics |
| --- | --- |
| [Scripting overview](scripting/index.md) | Script state, engine nodes, compilation, and the bridge |
| [Your first Odin scene](scripting/first-scene.md) | An empty project, a visible moving square, and an Inspector property |
| [Getting started](getting-started.md) | Nix, compiler setup, extension manifests, and project wiring |
| [Authoring reference](authoring-guide.md) | Lifecycle callbacks, exports, signals, methods, resources, autoloads, RPCs, and engine helpers |
| [Development workflow](workflow.md) | Building, reload on save, editor settings, completion, and validation |
| [Debugging](debugging.md) | Logging, native breakpoints, IDE setup, and crash backtraces |
| [Script modules](modules.md) | Subpackages, shared types, independent libraries, and module reload |
| [Exporting](exporting.md) | Desktop and browser builds, WebAssembly, export presets, and serving headers |
| [Distribution](distribution.md) | Installing the addon, compiler compatibility, cross-compilation, and platform support |

## Multiplayer concepts

| Page | Topics |
| --- | --- |
| [Multiplayer learning path](multiplayer/concepts/index.md) | A reading order from a shared game model to deployment and recovery |
| [Authority and ownership](multiplayer/concepts/authority.md) | Input permission, authority, listen hosts, trust, and validation |
| [State and input](multiplayer/concepts/state-and-inputs.md) | Persistent state, tick controls, discrete actions, events, and ordering |
| [Ticks and clocks](multiplayer/concepts/clocks.md) | Simulation, packet arrival, prediction, confirmation, and display time |
| [Prediction and correction](multiplayer/concepts/prediction.md) | Guessed inputs, repair, history boundaries, and interaction dependencies |
| [Determinism](multiplayer/concepts/determinism.md) | Replayable dependencies, RNG, ordering, state boundaries, and physics targets |
| [Presentation and effects](multiplayer/concepts/presentation-and-effects.md) | Event identity, interpolation, speculative feedback, cancellation, and smoothing |
| [Connections and compatibility](multiplayer/concepts/connections-and-compatibility.md) | Reachability, transport, admission, identity, baselines, and compatible content |
| [Bandwidth and relevance](multiplayer/concepts/bandwidth-and-relevance.md) | Recipient cost, update rates, filtering, privacy, deltas, and baseline recovery |
| [Performance and scale](multiplayer/concepts/performance-and-scale.md) | Active work, interaction cost, correction CPU, history memory, and capacity |
| [Testing and debugging](multiplayer/concepts/testing-and-debugging.md) | Gameplay assertions, impaired networks, accepted histories, audits, and recordings |
| [Recovery and trust](multiplayer/concepts/recovery-and-trust.md) | Reconnect, persistence, checkpoint loss, succession, fencing, and external effects |

### Feature walkthroughs

| Page | Topics |
| --- | --- |
| [Feature map](multiplayer/recipes/index.md) | Choosing one behavior to implement inside a working Kit or Replay project |
| [Player movement](multiplayer/recipes/movement.md) | Input, authority, collision dependencies, prediction, and display |
| [Pickups and inventories](multiplayer/recipes/pickups-and-inventories.md) | Contested requests, item conservation, target mutations, and accepted consequences |
| [Weapons and damage](multiplayer/recipes/weapons-and-damage.md) | Shot identity, validation, historical aim, projectiles, and health |
| [Spawning and lifetime](multiplayer/recipes/spawning-and-lifetime.md) | Entity identity, generations, membership, despawn, and view cleanup |
| [Joining and reconnecting](multiplayer/recipes/joining-and-reconnecting.md) | Readiness, reservations, baselines, pending decisions, and host loss |
| [Scenes and rounds](multiplayer/recipes/scenes-and-rounds.md) | Simulation phases, content readiness, transition barriers, and stale actions |

## Kit multiplayer

### Tutorials and concepts

| Page | Topics |
| --- | --- |
| [Kit overview](kit/index.md) | Sessions, entities, replicated fields, commands, and package responsibilities |
| [Two moving players](kit/quickstart.md) | Host and client setup, entity spawning, ownership, and interpolated movement |
| [Authority and prediction](kit/quickstart-sim.md) | Converting movement to fixed ticks, validated input, and client prediction |
| [Build a multiplayer game](kit/build-a-game-in-a-day.md) | A longer walkthrough of game setup and gameplay systems |
| [Timeline models](kit/timelines.md) | Reliable state, owner streams, prediction, and presentation timing |
| [Network profiles](kit/profiles.md) | Cooperative, listen-server, and dedicated-server configuration |
| [Glossary](kit/glossary.md) | Kit terminology and generated API names |

### Sessions and networking

| Page | Topics |
| --- | --- |
| [Game lifecycle](kit/boot.md) | Lobby, transport, session, generated frame loop, factories, and host succession |
| [Sessions](kit/session.md) | Player identity, admission, reconnect, roster, spawning, moderation, and interest |
| [Fields and commands](kit/net.md) | Field tags, wire codecs, deltas, ownership, command validation, and outcomes |
| [Fixed-tick simulation](kit/sim.md) | Input, prediction, reconciliation, simulation blocks, and lag compensation |
| [Godot transports](kit/netgd.md) | ENet, WebRTC, join codes, packet routing, and network fault simulation |
| [Steam transport](kit/steamgd.md) | GodotSteam, lobbies, and invites |
| [Saves](kit/save.md) | Session snapshots, persistence, and reconnect tokens |
| [Chat and pings](kit/comms.md) | Ordered messages, system notices, positional pings, and catch-up |
| [Large transfers](kit/xfer.md) | Bounded chunked payload delivery |
| [Multiplayer testing](kit/testing.md) | Multi-process game tests, scripted actions, probes, and network faults |

### Gameplay libraries

| Page | Topics |
| --- | --- |
| [Embedded components](kit/play.md) | Weapons, health, abilities, channels, telegraphs, and cooperative physics bodies |
| [Items and inventory](kit/items.md) | Item definitions, stacks, slots, and grid packing |
| [Combat](kit/combat.md) | Damage, health, abilities, effects, and projectile validation |
| [Interactions](kit/interact.md) | Range, facing, and target selection |
| [AI](kit/ai.md) | Perception, steering, patrols, and wave directors |
| [Navigation](kit/nav.md) | Godot navigation servers and movement helpers |
| [UI](kit/ui.md) | Lobby, chat, scoreboard, HUD, inventory, and network-health widgets |
| [Effects](kit/fx.md) | 2D bursts, flashes, floating text, screen shake, and tracers |

### Physics adapters

| Page | Topics |
| --- | --- |
| [Complete physics state](kit/box3d.md) | Kit world participants, Side state, checkpoints, effects, and correction |
| [Physics networking](kit/box3d-networking.md) | Accepted inputs, complete-state transport, recovery, and settled frontiers |

## Replay multiplayer

| Page | Topics |
| --- | --- |
| [Replay overview](replay/index.md) | World, frames, occurrences, runners, and runtime owners |
| [Correct an inventory transfer](replay/quickstart.md) | Local history, input revision, entity lifetime, and replay |
| [Connect a Godot session](replay/godot.md) | Starter setup, native dependencies, solo play, host, client, and observer |
| [World and history](replay/architecture.md) | Restorable values, transactions, pools, handles, RNG, and confirmation |
| [Networking](replay/networking.md) | Authority, controls, actions, transports, prediction scope, and correction |
| [Presentation](replay/presentation.md) | Copied frames, interpolation, and effect Begin, Update, Confirm, and Cancel changes |
| [Owner streams](replay/owner-streams.md) | Trusted engine physics observations, handoff, and interaction context |
| [Recovery](replay/recovery.md) | Party, Room, checkpoints, persistence, authority fencing, and host migration |
| [Physics networking](replay/box3d-networking.md) | Complete Box3D checkpoints, codecs, accepted history, and recovery |
| [Support and compatibility](replay/support.md) | Runtime modes, platforms, bounds, native dependencies, and versioning |

## Box3D

| Page | Topics |
| --- | --- |
| [Box3D overview](box3d/index.md) | Offline physics and separate Kit and Replay adapters |
| [Knock down a tower](box3d/quickstart.md) | World creation, stepping, copied poses, density, and a browser build |
| [Physics ownership](box3d/ownership.md) | Authored content, the live solver, complete checkpoints, presentation, and cleanup |
| [Author a world](box3d/authoring.md) | Bodies, sensors, shapes, stable keys, extraction, and construction |
| [Editor tools and baking](box3d/editor.md) | Mesh collision, winding, cleanup, artifacts, and debug drawing |
| [Characters, queries, and joints](box3d/motion.md) | Character movement, collision queries, joint families, and restorable motion state |
| [Kit and Replay integration](box3d/multiplayer.md) | Authored samples, host/client setup, adapters, and teardown |
| [Build and export](box3d/building.md) | Backend builds, native library selection, deployment, reload, and export |
| [Configure capacities](box3d/capacities.md) | Body, shape, joint, asset, memory, and transfer capacities shared by all layers |
| [API map and limits](box3d/reference.md) | Packages, lifecycle calls, schemas, geometry constraints, and identities |
| [Support](box3d/support.md) | Platforms, determinism, complete-state bounds, memory, and deployment limits |
| [Authoring topics](box3d-authoring.md) | A compact index of Box3D authoring guides |

### Physics concepts

| Page | Topics |
| --- | --- |
| [Physics reading path](box3d/concepts/index.md) | How the conceptual guides relate to the offline and multiplayer tutorials |
| [Bodies and motion](box3d/concepts/bodies-shapes-and-motion.md) | Body types, shapes, mass, impulses, prescribed motion, and Godot views |
| [Collision and queries](box3d/concepts/collision-and-queries.md) | Category and mask filtering, sensors, motion queries, and result capacity |
| [Simulation and rollback](box3d/concepts/simulation-and-rollback.md) | Fixed stepping, complete solver history, correction, and display state |
| [Authoring and identity](box3d/concepts/authoring-and-world-identity.md) | Editor definitions, baking, catalogs, durable IDs, content, and native keys |
| [Joints and characters](box3d/concepts/joints-and-characters.md) | Constraint choices, prescribed character motion, contacts, and stored mover state |

## Libraries

| Page | Topics |
| --- | --- |
| [Library map](libraries/index.md) | Standalone helpers, gameplay packages, Replay tools, and their dependencies |
| [Typed events](events.md) | Publish/subscribe callbacks, engine signals, ownership, and reload |
| [Timed sequences](libraries/flow.md) | Waits, callbacks, parallel work, predicates, reset, and cleanup |
| [Godot Tween steps](libraries/flowgd.md) | Engine animation inside a flow sequence, cancellation, and signal waits |
| [Choose gameplay helpers](libraries/gameplay.md) | Kit components, Replay values, pure algorithms, and engine adapters |
| [Gameplay composition](recipes.md) | Component state, tick ownership, cross-entity changes, and related guides |

## From GDScript to Odin

| Page | Topics |
| --- | --- |
| [Onboarding series](onboarding/index.md) | The complete series for Godot developers learning this SDK |
| [Compiled scripts](onboarding/01-what-if-your-scripts-were-compiled.md) | Ahead-of-time compilation and the Godot development loop |
| [Script state and objects](onboarding/02-thinking-in-structs.md) | Structs, procedures, composition, and Godot object handles |
| [Replicated state](onboarding/03-state-not-messages.md) | Field ownership and synchronization |
| [Commands](onboarding/04-verbs-not-rpcs.md) | Validated interactions, prediction, and authoritative consequences |
| [Presentation timing](onboarding/05-the-two-timelines.md) | Local response and remote interpolation |
| [Sessions and shipping](onboarding/06-the-shape-of-a-shippable-game.md) | Game structure, session lifecycle, and release considerations |
| [Competitive simulation](onboarding/07-the-competitive-turn.md) | Server authority, fixed ticks, prediction, and lag compensation |

## Contributing

| Page | Topics |
| --- | --- |
| [Contributor overview](contributing/index.md) | Source layout, focused checks, and documentation development |
| [SDK architecture](contributing/architecture.md) | Build, load, reload, desktop export, and browser composition |
| [Core and scripts boundary](contributing/native-boundary.md) | ABI compatibility, callbacks, allocation ownership, and lifetimes |
| [Kit conventions](kit/conventions.md) | Contributor rules for Kit APIs and implementation |
| [Writing documentation](contributing/writing-docs.md) | Audience, page types, prose, examples, and link conventions |
| [Documentation maintenance](contributing/documentation.md) | Local preview, validation, adding pages, publishing, and redirects |
| [Publishing the addon](publishing.md) | Release-branch and Godot Asset Library procedure |
