# Testing components independently

Run the core for the component you changed. These commands use the existing test
scripts and result reporting; they do not run the whole game-example matrix.

```sh
nix develop --command bash tests/run_core.sh bridge
nix develop --command bash tests/run_core.sh kit
nix develop --command bash tests/run_core.sh replay
nix develop --command bash tests/run_core.sh utilities
```

Bridge checks and the real Replay ENet recovery check need `GODOT` set to the
supported engine executable. To run only the engine-free checks:

```sh
nix develop --command bash tests/run_core.sh replay --unit
nix develop --command bash tests/run_core.sh all --unit
```

Inspect the selection or run one existing test directly:

```sh
bash tests/run_core.sh --list
bash tests/run_core.sh kit --list
nix develop --command bash tests/run_all.sh replayview
nix develop --command bash tests/replay_recovery/run.sh
```

`tests/core.tsv` is the small maintained core selection. It groups 20 entrypoints
by component and declares which need Godot. Add a core gate only for a distinct
library contract that the existing set does not establish. Prefer adding a
focused assertion to the responsible package over another aggregate wrapper.

## Box3D

Native ABI/sanitizer, capacity and timing checks have their own workflows. The
capacity fixture can be run independently:

```sh
nix develop .#capacity --command python3 tests/box3d_capacity/run.py --out /tmp/box3d-capacity-check
```

Use a fresh output directory for each run. See the fixture README for custom
profiles and supplying an already verified native backend. The strict managed
Replay runner can also be run against that backend without launching a game:

```sh
nix develop .#capacity --command python3 tests/box3d_modules/replay/runner/run.py \
  --native /path/to/libogb3.so --out /tmp/box3d-managed-runner
```

On macOS supply the corresponding shared `.dylib`. A static archive cannot prove
the shared native-domain contract.

## Full application acceptance

Use the broad suite when deliberately validating examples, release scenarios or
a subsystem's larger matrix:

```sh
SKIP_WEB=1 nix develop --command bash tests/run_all.sh
```

Browser and hardware checks require their own setup. Keep skipped capabilities
explicit. Core success means the selected contracts passed; it does not turn an
omitted game, browser or benchmark result into a pass.

The [CI review](ci-review.md) records the actual framework defects, fixture
failures, duplication and unresolved findings behind this boundary.
