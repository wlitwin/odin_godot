# Larger Box3D worlds

The capacity suite exercises a shared profile across native recovery, authoring,
Kit, Replay, presentation, and optional Godot SDK extraction. The reference scene
has 1000 bodies and 100 hinges. Its compound-body variant has 3997 shapes and
requires complete-state transfers beyond the original 32-chunk window.

Run from the repository root in the game development shell:

```sh
nix develop
python3 tests/box3d_capacity/run.py --out /tmp/box3d-capacity
```

The output directory must be new. The runner builds the native backend, runs
its registered C tests, and executes the larger-world and presentation suites.
The minimal `nix develop .#capacity` shell is sufficient without Godot.

To reuse a coherent build and include actual Godot extraction/module loading:

```sh
python3 tests/box3d_capacity/run.py \
  --native /absolute/path/to/libogb3.a \
  --godot "$GODOT" --out /tmp/box3d-capacity-sdk
```

`--profile /absolute/path/to/physics-capacity.json` selects a build override when
the runner builds its own backend. When selecting an existing archive, compiler
defines come from that build's manifest. The larger-scene suite requires at
least 1000 bodies and 100 joints.

CI runs both the default profile and `larger.json` (2048 bodies, 8192 shapes,
512 joints and a 2 GiB allowance), including rejection of mismatched native/Odin
capacities.

The native test compares normalized solver bytes after canonical reconstruction
and continued stepping, including contact state beyond the original profile.
Odin cases cover copied bake data, presentation, complete Kit welcome/reset,
Replay input revision/audit and a full 128-tick history, plus a large Replay
welcome. Invalid lower recovery quotas retain their rejection behavior.

These checks establish correctness at the stated scale, not a frame-time or
bandwidth guarantee for arbitrary geometry and joint topology. Original
qualification reports remain scoped to their recorded binaries and settings.
