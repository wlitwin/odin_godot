# Mixed movement/status Scrapyard comparison

```sh
REPLAY_MIXED_OUT=/private/tmp/replay-mixed-new \
  nix develop --command bash tests/replay_mixed_comparison/run.sh
```

This extends the sustained swarm comparison in separately runnable copies of the
original sibling Scrapyard and Replay Scrapyard. Original sources and profiles are
preserved. The shared [contract](contract.json) fixes two players, seed 1337, 60 Hz,
a 60 FPS cap, 120 ms receive delay per process, a twenty-second window and three
pairs in alternating Kit/Replay order.

Both copies retain the existing explicit resource fixture: bolter magazine 255,
no random jams, and zero scrapbot bite damage. Enemy AI, collision, shots, damage,
death/reaping and pickups still execute. The host replenishes toward forty living
scrapbots every six ticks with at most four requests per batch. This is an offensive
workload with movement and status effects; it does not include player injury,
reloads/jams, dash, changing waves, all enemy types or transport faults.

Players repeat down/left/up/right input at one-second intervals while aiming at
the nearest living enemy and holding fire. Each player casts stock frostwave at
2 and 11 seconds and stock battlecry at 3 and 19 seconds. The abilities retain their
stock cooldowns/durations/effects. Only movement/cast intents are adapted; the real
game command and simulation paths apply them. Movement and cast dispatch run inside
the timed game callback, alongside spawn/aim selection. Replay's development aim
helper clears movement, so the adapter restores the movement input while retaining
that selected aim; it does not write positions or other gameplay state.

The per-frame read-only census records enemy IDs/positions/HP, player positions/HP,
ability loadout/cooldowns, rally exposure and chilled-enemy counts. Reports require
at least 1,000 observed pixels of path and 80 pixels of span on each axis per player,
20 chilled-enemy samples, 240 rally samples per player, two cooldown rises per slot,
four locally submitted casts and no locally refused casts. Input/cast timing is
checked against the schedule. Existing population, shots, churn, freshness, health/
kill/loot conservation and settled-peer convergence checks remain mandatory.

Cooldown rises and status observations are required in addition to submission
counts, so a queued intent alone cannot satisfy the ability workload. Path length
is reconstructed from each process's observed positions; it is not an independently
measured physical distance. Kit owner-streamed and Replay authority/prediction
observations differ, and the report retains those differences.

Inclusive callback timings cover game networking, simulation and presentation plus
spawn/aim/input adapters. Census work is outside that timer and separately reported;
its cost includes mixed-state collection, but later trace serialization/counter work
is not all included. RSS includes instrumentation. Application bytes exclude ENet
framing/retransmissions. Descriptive percentiles and across-pair median/range are not
CPU-only measurements, confidence intervals or a framework-only speed ratio.

`REPLAY_MIXED_PILOT=1` runs an explicitly partial one-pair plan; it cannot satisfy
full acceptance. `REPLAY_MIXED_REUSE=/path/to/previous-run` verifies compiled source,
content, framework and binary hashes before reusing a build. Only the external
driver and isolated project namespace may differ. The full gate includes report
acceptance/rejection cases for missing movement, cast/status work, corruption and
provenance errors. Native macOS is the current measured platform.

## Isolated owner-unwind control

```sh
REPLAY_MIXED_OWNER_CONTROL=1 REPLAY_MIXED_OUT=/private/tmp/replay-mixed-control \
  nix develop --command bash tests/replay_mixed_comparison/run.sh
```

This option builds Kit against a copied framework with the owner-unwind change
from the [movement audit](../replay_movement_audit/README.md). Replay continues to
use the original collection root. The extra packet/movement instrumentation used
by that causal audit is absent here; both games use the normal mixed benchmark
adapters and timing boundaries. The source game projects and original Kit remain
unchanged.

The run plan labels this variant explicitly. Build metadata records the collection
root for each implementation, while `owner-control.json` and
`kit-framework-source.json` identify the exact repair and every compiled framework
source. Reports require that only `kit/net/registry.odin` differs, verify both
source trees, and reject undeclared/missing/mismatched control provenance. The
corrected Kit client must have no backward observed motion within the constant-
direction portions of the input schedule. All other mixed-workload gates remain.
The report validator adds five control-specific rejection cases.

Binary reuse from an original-framework run is deliberately refused for this
option. The copied repair is a comparison control, not a production update to Kit
or a general validation of every command that writes owner-streamed state.

The reverse reuse path is refused too: a control binary set cannot be copied into
an original-framework run and lose its repair declaration. This keeps historical,
original and corrected-baseline measurements distinguishable.


`profile_run.sh /path/to/verified-cohort` runs the Replay fixture with its existing
nested phase timers enabled and writes `timing-host.csv`, `timing-client.csv` and
`phases.json`. It verifies the source cohort first. These diagnostic measurements
include timer overhead and overlapping subphases, so they must not be pooled into
the normal comparison or summed as disjoint CPU costs.

`REPLAY_MIXED_REUSE_EQUAL=1` enables the explicit client correction-reuse experiment.
The run plan and receipt record that setting; traces retain cumulative reused and
simulated correction ticks separately. It does not lower cadence or relax any
workload/freshness checks. Use the core differential corpus to validate reuse
semantics; a small reused count in a real workload does not establish a
performance improvement.
