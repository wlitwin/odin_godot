# Partial editor preview checks

Run pure geometry/contract checks with:

```sh
nix develop --command bash tests/box3d_editor/preview/pure.sh
```

The real editor gate builds the ordinary core/scripts/tool module and requires a
coherent native backend library for allocation-counter checks:

```sh
nix develop --command python3 tests/box3d_editor/preview/run.py \
  --native-library /path/to/libogb3.dylib --out /path/to/new/evidence-directory
```

It covers invalid IDs, duplicate shape slots, shared geometry conflicts, bad
shapes/placement/settings, unique joint resolution, character overlays, scalar
overflow, bounded whole fragments, unavailable tools, repair, and actual gizmo
cache invalidation on editor edits/undo. Each query compares authored properties
and real native allocation counters before/after. Strict validation remains a
separate assertion. The runner keeps the copied project, logs, and report.
