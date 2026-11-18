# Isolated original-game baselines

Run comparisons in a separate project so content edits, profiles, imports and
build output stay isolated from the developer's game:

```sh
work=$(mktemp -d)
python3 tests/replay_scrapyard/prepare_baseline.py ../scrapyard "$work/project" "$PWD"
nix develop --command bash build/build_scripts.sh "$work/project"
nix develop --command bash tests/replay_scrapyard/baseline_gauntlet.sh "$work/project"
```

Preparation copies the authored game/harness inputs, isolates the application name
and user-data namespace, selects the compatibility renderer, and installs a
project-local extension descriptor. It records original source hashes and the
repository revision. The strict gauntlet runner fails on cleanup errors as well
as unmet gameplay receipts. The original game's authored checks alone do not
include that cleanup requirement.

The sibling game now owns Resource discovery, its Kit stack, caches, and copied
catalog names directly. Current comparisons use those authored lifecycle paths;
the old source-rewriting ownership overlay has been removed. Historical results
with `cleanup-overlay.json` still describe their original overlay and must not be
relabelled as current-source runs. Preserve those recorded results.

`baseline_stress.sh` runs the original two-peer stress workload against an isolated
project. It rejects runtime and cleanup errors as well as failed gameplay checks.
Neither baseline runner makes the old and new workloads equivalent: player count, gun overrides, input traces,
optimization flags and authority models must still be matched or disclosed.
