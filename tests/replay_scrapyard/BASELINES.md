# Isolated original-game baselines

Never run the original `run.sh` as part of Replay acceptance: it deletes profiles
from the original game's user-data directory. Prepare a separate project instead:

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

For comparisons that need complete resource teardown, an **explicit, optional
ownership overlay** is available. Apply it before building a fresh isolated copy:

```sh
python3 tests/replay_scrapyard/baseline_cleanup.py "$work/project"
```

It releases scanned definition resources/temporary engine values, tracks ownership
of loaded textures/audio/scene resources, closes the game-owned Kit stack and
tracking containers, and resets the texture cache after the last game exits.
The copied harness frees the game and waits for the resource count to return to
its pre-game level, with a two-second deadline, before asking the engine to exit.
This permits asynchronous audio playback retirement without declaring success
after an arbitrary number of frames.

Original sources are retained in `cleanup-originals/`, and `cleanup-overlay.json`
records before/after hashes for changed files. The added `baseline_lifetime.odin`
is part of the overlay. This changes ownership and shutdown behavior; it is not
a pristine-source result. Report that distinction, and preserve the unmodified
baseline evidence too. Combat, movement, director rules and harness gameplay
assertions are unchanged. The overlay does not claim to repair every original
application path, such as repeated user-spray replacement.

`baseline_stress.sh` runs the original two-peer stress workload against an isolated
project. It rejects runtime and cleanup errors as well as failed gameplay checks.
Neither baseline runner makes the old and new workloads equivalent: player count, gun overrides, input traces,
optimization flags and authority models must still be matched or disclosed.
