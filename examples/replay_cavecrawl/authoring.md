# Authoring captured floors

Open `cave.tscn` and edit its `floor1_def` / `floor2_def` resources. The defaults
live in `levels/level_1.tres` and `level_2.tres`; the original Cavecrawl project is
separate. Each definition selects a floor PackedScene, chest stock, a wave plan and
the rectangular rift used by the pure navigation model.

The loader validates both definitions before opening a Session. It instantiates
each floor outside the SceneTree, reads its four direct Marker2D children
`ChestSpawn`, `DoorSpawn`, `Den1`, `Den2`, and destroys the temporary instance. The
scene must have a Node2D root with an identity transform. Marker positions are in
simulation coordinates: x 0–640, y 0–370. The rift must be a nonempty rectangle
inside those bounds. Its explicit `rift_min` / `rift_max` fields must describe the
same obstacle as the art; this loader does not convert Godot navigation meshes.

`gems` and `torches` accept 0–99. A zero stock leaves an empty chest slot; player
inventory retains its normal per-item limits. `wave_counts` and `wave_rests` must
have equal lengths between one and eight. Counts accept 0–255; rests accept
0–65535 simulation ticks at 20 Hz. The 16-dweller pool bounds simultaneous live
mobs; larger waves spawn as slots become available. A zero-count wave is legal.

The resulting two `Floor` values are copied into `World`. The host's values travel
with snapshots, replay history, save files and approved migration checkpoints.
Clients may have different local definition values: gameplay and entity positions
use the received world. Changes to the original Resource after initialization do
not alter an active game. Start a new game to use a changed definition, or implement
an explicit recorded rule change if live editing is required.

PackedScenes remain local presentation assets, retained independently of the
resource slots. Their contents are not serialized. Changing local art or navigation
assets can therefore change appearance without changing a saved world's gameplay
values; distribute matching assets when visual agreement matters. Mutating the
retained PackedScene itself is not supported as a live authoring operation.

Decoration is generated from the saved world seed and floor depth using the
original splitmix32 recipe. Each nonzero seed produces ten alternating rocks and
mushrooms at integer positions. Seed zero disables scatter. The default seed 1337
has checksums 976669602 and 4288723372 for the two floors. Decorations are views;
they do not consume gameplay RNG or enter collision state.

## Existing Replay saves

Cavecrawl uses content `0x4341564552504c3a` (C10). Normal loads require the current
schema/content contract. Retained C1–C8 checkpoints were migrated once before
removing their readers. Current fixtures preserve floor definitions, player and
relic values, membership and pending actions. [Original bytes and receipts](../../docs/replay/results/usability-legacy-2026-11-16/cavecrawl/receipt.json)
record the migration separately from the active inputs.

A checkpoint restores its exact saved frame. The first committed tick under the
new epoch applies current authority/adoption rules. Conversion itself grants no
authority. Use the saved identity when resuming. Explicit generic schema-evolution
APIs remain available; the game no longer carries retired application schemas.

## Validation

```sh
nix develop --command bash examples/replay_cavecrawl/definitions_run.sh
nix develop --command bash examples/replay_cavecrawl/definitions_network_run.sh
nix develop --command bash tests/replay_cave/saved_fixtures/run.sh
nix develop --command bash tests/replay_cave/scatter_run.sh
```

These check captured Resource/marker edits and fresh-process resume, host settings
received by default-resource clients/observers under simulated network faults,
invalid definitions, a retained current-format save resumed, and original
versus native/WASM scatter coordinates. The broader campaign and migration gates
exercise the same expanded world schema.

Current checkpoint fixtures include the authority observation and retain full
world state. Current C10/O4 recording fixtures are new captures with generation-bound
impact events; their old event histories remain historical evidence only.
