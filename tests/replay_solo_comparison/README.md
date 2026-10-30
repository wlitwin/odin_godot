# Matched solo gauntlet

```sh
REPLAY_SOLO_OUT=/absolute/fresh/output \
  nix develop --command bash tests/replay_solo_comparison/run.sh
```

The runner builds separate copies of the original sibling `../scrapyard` and the
Replay port, then executes the same GDScript controller in both. Original sources,
profiles and runner scripts are untouched. Every pair uses fresh test identities;
each game must begin with zero cores and ten HP.

Contract version 2 retains the original-style one-player wave setup: 4/4/5 enemies,
300-tick rests, the same circle-strafing and nearest-target autofire, magazine 255,
no jams, damage two, and no support casts, granted healing or invulnerability.
Both real games retain their AI, collision, damage, pickups and clear reward.
Their authority/update/spawn timing differs, so matching inputs do not imply
identical trajectories or difficulty.

After the clear and projectile drain, two barrels are still requested at offsets
`(150,0)` and `(150,50)`. If cover blocks the shots, a bounded visibility-graph
controller walks the player to a safe firing position using ordinary movement
input. It reads each game's actual cover rectangles and barrel positions, never
moves an entity directly, removes cover, changes damage, or relocates a barrel.
Autofire continues to use each game's existing input/aim path. The 25-second finale
limit and two-blast requirement remain.

## Cohort and obstruction control

The default runner requires three normal-start pairs (the second reverses order)
and one separately identified obstruction pair. The latter first **walks** to the
previously failing location near `(788,588)`, then checks 1,500 ms of stationary
shots: both barrels must remain at full admitted health, with no blasts. It must
then move through the same controller and finish the real finale.

The earlier [stationary version-1 cohort](../../docs/replay/results/solo-gauntlet-2026-09-13/README.md)
remains rejected. Version 2 treats blocked shots as a negative collision check and
ordinary player repositioning as the positive continuation. It does not redefine
that older record as a pass.

The independent report checks the actual seed-derived cover layout, fixed barrel
spawn offsets, path visibility/clearance and bounds, recorded movement, obstruction
health and firing duration, all waves/rests/rewards, survival, blasts and shutdown.
The movement bound accounts for both wall time and simulation ticks: Kit can run
several catch-up ticks in a short wall-clock interval. It rejects large position
jumps without incorrectly treating legitimate catch-up as teleportation.

`navigation_test` covers the known obstruction, reachable routes, unreachable
routes, bounds and the real inside-cover escape convention. Report mutation checks
include changed cover/spawns, illegal paths, unbounded planning, teleports, missing
blocked shots and damage through cover in addition to the existing wave/health/
reward/finale checks. Engine errors and exit leak reports still reject a run.

## Reuse a verified build

```sh
REPLAY_SOLO_OBSTRUCTED=0 nix develop --command python3 \
  tests/replay_solo_comparison/execute.py /absolute/output dylib normal-1
REPLAY_SOLO_OBSTRUCTED=1 nix develop --command python3 \
  tests/replay_solo_comparison/execute.py /absolute/output dylib obstructed
python3 tests/replay_solo_comparison/report.py /absolute/output obstructed
python3 tests/replay_solo_comparison/verify_report.py /absolute/output obstructed
python3 tests/replay_solo_comparison/cohort.py /absolute/output
```

Use `so` on Linux and `REPLAY_SOLO_REVERSE=1` for reversed order. All labels require
fresh result directories. The exact executed controller and navigation script are
retained with hashes, independently of the original prepared files. `cohort.py`
accepts an optional second argument naming a previously recorded obstruction label.
`REPLAY_SOLO_FINALE=stationary` retains the old shooting policy for explicit
comparisons; it cannot satisfy the version-2 cohort gate.

Global post-scene resource counts remain observations, since stable engine caches
need not return to a cold count. This fixture is neither a CPU benchmark nor a
substitute for human gameplay/difficulty comparison.
