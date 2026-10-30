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

Cavecrawl content is now `0x4341564552504c39`. C4 corrected wave pacing and den
selection; C5 preserves avatar state on descent and separates run reset rules.
C6 retains the relic across descent and releases it in place on restart.
C7 retains relic ownership through death, respawn and ordinary disconnect.
C8 records the observed authority and adopts the previous host’s relic on takeover.
The ordinary loader rejects prior C1–C8 content, even where the value layout is unchanged.
Gameplay protocol 7 and checkpoint format 4 are unchanged. This is an explicit
conversion of earlier Replay saves, not an importer for original Kit saves.

Build the converter and give it an existing source and a **new** destination:

```sh
nix develop --command odin build examples/replay_cavecrawl/tools/upgrade_save \
  -collection:godot=. -out:/tmp/replay-cave-upgrade
/tmp/replay-cave-upgrade /path/to/old.replay /path/to/converted.replay
```

The converter validates the old archive, copies its complete world and session
ledgers, maps pending actions into the new command shape, and adds an already-playing
lobby with default seat names. Content 1 receives the original default floors;
content 2 retains its captured floors. The first connected seat becomes party leader.
It then computes the new schema contract and hashes. It preserves the source and refuses to replace an existing
file or symlink. Publication requires same-directory hard-link support. Conversion
alone grants no authority and does not increment the epoch; normal resume or Room
recovery still applies its authority rules. Use the owning profile/token when
resuming and retain the original archive. Protocol-7/content-1 through content-8 saves are
supported by this converter. C3 conversion preserves the complete checkpoint and
its scheduled spawn/rest deadlines; later spawns use corrected pacing. C4/C5/C6/C7 conversion
also preserves all saved values; future transitions use current rules. Lobby metadata/commands motivated content 3; gameplay
protocol 7 and checkpoint layout 4 remain unchanged.

## Acceptance gates

```sh
nix develop --command bash examples/replay_cavecrawl/definitions_run.sh
nix develop --command bash examples/replay_cavecrawl/definitions_network_run.sh
nix develop --command bash tests/replay_cave/upgrade/run.sh
nix develop --command bash tests/replay_cave/scatter_run.sh
```

These check captured Resource/marker edits and fresh-process resume, host settings
received by default-resource clients/observers under simulated network faults,
invalid definitions, a genuine old-binary save converted and resumed, and original
versus native/WASM scatter coordinates. The broader campaign and migration gates
exercise the same expanded world schema.

C8 adds `authority_known` and `authority_seat` to World. Old-world descriptors keep
the frozen C3–C7 layout. Conversion preserves prior fields and seeds the new
observation from the validated checkpoint header’s `local_seat`, independently of
lobby leadership. Adoption occurs on the first resumed simulation tick.

C9 adds generation-bound dweller Hit occurrences without changing saved world
layout. C8 conversion preserves its authority observation exactly. Both native
converters refuse coordinated archives; see [impact compatibility](impacts.md).
