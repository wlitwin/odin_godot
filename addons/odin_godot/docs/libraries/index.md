# Libraries

Use the SDK's small packages without adopting every framework. Start here to
choose an event, sequencing, or gameplay helper. The dependency column tells you
which runtime the package expects.

## Standalone and engine helpers

The [API reference](../api/index.md) lists public declarations for these packages
and supports searching by function or type name.

| Package | Use | Dependencies | Guide |
| --- | --- | --- | --- |
| `godot:events` | Typed one-to-many callbacks in the same scripts library | Odin only | [Events](../events.md) |
| `godot:flow` | Sequences, delays, parallel work, and polling predicates | Odin only | [Timed sequences](flow.md) |
| `godot:flowgd` | Godot Tween steps inside a flow tree | `flow` and Godot | [Tween steps](flowgd.md) |

Use Godot signals when an editor connection, GDScript listener, or module boundary
needs the engine's signal system. Use `events.Event(T)` for direct typed callbacks
inside one library. Neither event system is a network protocol.

## Gameplay and framework helpers

| Package | Use | Dependencies |
| --- | --- | --- |
| [`godot:play`](../kit/play.md) | Embedded health, weapons, abilities, channels, telegraphs, and cooperative body replication | Networked blocks use Kit; local helpers vary |
| [`godot:play/sim`](../kit/sim.md) | Tick cooldowns and movement blocks | Kit simulation lane |
| [`godot:kit/items`](../kit/items.md) | Item definitions, fixed-slot inventories, grid packing | Pure algorithms with Kit integration |
| [`godot:kit/interact`](../kit/interact.md) | Range, facing, and target selection | Dimension-independent values |
| [`godot:kit/combat`](../kit/combat.md) | Health, effects, abilities, and hit validation | Kit gameplay model |
| [`godot:kit/ai`](../kit/ai.md) | Perception, steering, patrol, and wave helpers | Authority-run gameplay |
| [`godot:kit/nav`](../kit/nav.md) | Navigation server helpers | Godot |
| [`godot:kit/ui`](../kit/ui.md) | Lobby, HUD, inventory, and network widgets | Godot and Kit |
| [`godot:kit/fx`](../kit/fx.md) | Bursts, text, flashes, shake, and tracers | Godot; currently 2D |
| `godot:replay/play` | Value-based movement, queries, combat, inventory, guns, effects, and wave directors | Restorable value state; [package reference](https://github.com/wlitwin/odin_godot/blob/main/replay/play/README.md) |

Kit and Replay gameplay helpers follow their framework's state and timing model.
Do not copy a component between them without checking who owns its state, tick,
and effects. The [gameplay guide](gameplay.md) explains that choice.

## Replay tools

These packages support Replay state, presentation, and operations. Their source
references describe the lower-level APIs; start with the Replay guides when
setting up a game.

| Package | Use | Reference |
| --- | --- | --- |
| `replay/schema` | Canonical value codecs, field bounds, and schema diagnostics | [Schema](https://github.com/wlitwin/odin_godot/blob/main/replay/schema/README.md) |
| `replay/view` | Interpolation and occurrence journals | [Presentation guide](../replay/presentation.md) |
| `replay/assets` | Versioned immutable content references and exchange | [Assets](https://github.com/wlitwin/odin_godot/blob/main/replay/assets/README.md) |
| `replay/transfer` | Bounded large-payload delivery outside snapshots | [Transfer](https://github.com/wlitwin/odin_godot/blob/main/replay/transfer/README.md) |
| `replay/telemetry` | Session round-trip probes outside rollback state | [Telemetry](https://github.com/wlitwin/odin_godot/blob/main/replay/telemetry/README.md) |
| `replay/diagnostic` | Captures, recordings, and field differences | [Diagnostics](https://github.com/wlitwin/odin_godot/blob/main/replay/diagnostics.md) |
| `replay/testing` | Reusable gameplay scenarios and checks | [Testing](https://github.com/wlitwin/odin_godot/blob/main/replay/testing/README.md) |
| `replay/evolution` | Freeze revisions and explicitly convert state | [Evolution](https://github.com/wlitwin/odin_godot/blob/main/replay/evolution/README.md) |

## Ownership across reloads

Event subscriptions and flow trees can hold procedure pointers or pointers to
script state. Rebuild them in a script's reload hook and release them during
scene teardown. A saved callback into an old library or reallocated script
instance can outlive its owner. The individual guides explain the cleanup rules.
