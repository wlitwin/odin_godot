# Odin × Godot: desk reference

Kit and Replay are independent frameworks. Kit starts from script entities and
field declarations. Replay starts from a complete replayable simulation frame.
Both support cooperative games and server-authoritative prediction. Replay is experimental.

## The engine boundary

Godot owns the editor, scene tree, input devices, rendering and audio.
An Odin node script is a struct and free procedures attached to a node. `self` addresses
the script struct; `self.owner` refers to the engine node.

`scripts/*.odin → scriptgen → Odin compiler → scripts library`

The core GDExtension registers Odin with Godot and loads that scripts library.
Pure Replay gameplay packages also run without Godot.

## Kit

- `gd:"replicate"`: authority-written state.
- `gd:"owner"`: cooperative owner-written streams, interpolated remotely.
- `gd:"predict,interp"` and `@(gd_tick)`: server-authoritative simulation lane.
- `@(gd_command)`: target mutation with generated submission and authority-result handling.
- Predicted commands mutate only their target. Cross-entity consequences belong
  in the authority command hook after acceptance.
- Start with `examples/hello_net`, then compare `examples/hello_sim`.

## Replay

`step(frame at T, input for T+1) → frame at T+1 + occurrences`

- `World` contains mutable gameplay dependencies: health, positions, bags, random-number-generator state,
  cooldowns, scheduled work, entity lifetime and allocation metadata.
- Keep node pointers, sockets, resources, live audio and storage outside World.
- A step reads its state, input, tick and immutable versioned definitions.
- Emit occurrences, recorded events with an identity, in the step. Handle their
  Begin/Update/Confirm/Cancel notifications outside the simulation.
- `revise_input` replaces a local recorded input batch. It does not establish
  network authority.
- `correct` ingests a complete verified authority frame and its occurrences,
  then stages the remaining predicted ticks before committing the operation.
- `Timeline`: local simulation. `Session`: direct network roles.
  `Party → Room`: invitations and authority recovery. `P2P_Party` plus the
  admitted peer runner: deterministic fixed-roster rollback.

## Three contracts to keep separate

1. Authority: the process allowed to settle a gameplay result.
2. History: the values that must be restored to compute the next tick.
3. Presentation: the frames and effects selected for this screen’s display time.

Client-filtered visible state is not a complete authority migration backup.
A new epoch scopes occurrence identities; it does not elect a legitimate host.
Saving body poses does not make Godot contact solving replayable.

## Run from the repository root

```sh
# Local restore/replay and independent reference comparison:
nix develop --command bash examples/replay_loot/run.sh

# Same model with a Godot view. Space revises the pickup winner:
nix develop --command bash examples/replay_hello/play.sh loot

# Kit's predicted movement example, headless behavior check:
nix develop --command bash examples/hello_sim/run.sh

# Replay authority, two clients and observer under injected delay:
nix develop --command bash examples/replay_hello/network_run.sh
```

## Reading order

1. `docs/getting-started.md`: extension and scripts library wiring.
2. `docs/kit/quickstart.md`: field/entity/command authoring.
3. `docs/kit/quickstart-sim.md`: promote owner motion to authoritative motion.
4. `examples/replay_loot/game/game.odin` and `main.odin`: complete local model.
5. `replay/getting-started.md`: runners and scene/session lifecycle.
6. `examples/replay_recipes/README.md`: checked lifecycle recipes.
7. `docs/replay/framework-audit.md`: implementation and tested support scopes.

## Exported diagrams

- `diagrams/two-models.svg`: authoring models.
- `diagrams/engine-boundary.svg`: compiler, extension and scene boundary.
- `diagrams/kit-pickup.svg`: target prediction and authority consequences.
- `diagrams/frame-boundary.svg`: frame dependencies and external owners.
- `diagrams/authority-path.svg`: client prediction and authority correction.
- `diagrams/correction.svg`: restore and replay a suffix.

The website's JavaScript model is an illustration. It does not run Odin, use a
transport, or establish performance or platform support.
