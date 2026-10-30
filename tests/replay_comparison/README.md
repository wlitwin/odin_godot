# Paired Scrapyard comparisons

```sh
nix develop --command bash tests/replay_comparison/run.sh
nix develop --command bash tests/replay_comparison/firing_run.sh
```

The harness prepares isolated original/Replay projects, applies the explicitly
recorded baseline ownership overlay, and instruments each game's real process
callback. It does not replace gameplay. Three paired repetitions alternate
Kit→Replay / Replay→Kit ordering. `REPLAY_COMPARISON_DIR` chooses a fresh output
directory; `REPLAY_COMPARISON_REPETITIONS` controls the number of pairs.
The original sibling project is required. If it is absent, the ordinary repository
suite reports this gate as skipped; that is not comparison acceptance evidence.

Both games use seed 1337, two players, 60 Hz, a 60 FPS process cap and 120 ms receive
delay per participant. The default idle controller waits for authoritative skin/weapon choices,
enters an empty single-wave floor, and checks stage, population, health, loadouts
and both positions throughout a three-second window after 500 ms warmup. Inputs
contain no movement, gunfire or casts. It compares the settled empty arena, not
enemy AI, combat, prediction feel or the games' complete mutable schemas.

`firing_run.sh` uses the same arena and stationary players with bolter magazine
size 3 and jam probability 0 in both isolated content copies. Cooldown, projectile
speed/lifetime/damage and reload duration retain their shared stock settings. Both
players complete warmup before arming, hold eastward fire until nine rounds have
been locally observed as spent, then release. This drives each game's existing
input/cadence, authority, projectile and reload paths. The total measurement window
is six seconds, followed by an unmeasured drain/reload period.

The active gate requires exactly nine accepted rounds from each player, at least
two observed reload entries per player, the original stationary position/health,
unchanged content knobs, no jams, and complete projectile/reload cleanup. It records
input transitions and each process's observations of rounds, ammo and weapon mode;
the host also samples its authoritative projectile population. `summary.json`
reports sampled peak/time-weighted occupancy and the first/ninth shot observation
offsets. Original client weapon observations can include owner prediction; Replay's
probe reads received authority frames. Host measurements are the common authority
observation scope. The timing offsets are not round-trip latency estimates.

The workload matches intent, weapon settings and final shot totals. It does not
assume identical transient projectile populations or firing times. The trigger
ends at a fixed shot budget because equal trigger duration produced different
shot counts in the original host/client reload paths. Those timing differences
remain in the observations and in the measured game callback costs. This range
has no AI, hits, damage, movement or contested outcomes; it does not replace the
remaining full combat/stress comparisons or paired human playtests.

A runtime failure writes its state, input trace and available observations to
`failure-ROLE.json` before exiting. Failures are retained; there is no automatic
retry. The output directory must be fresh so earlier projects/results cannot be
mixed into a new comparison.

Scripts use `-debug -o:speed`. Editor import can rebuild them, so the harness
exports the flags, performs a final explicit build after the editor exits, records
DLL hashes, and verifies those hashes again after measurement. `build-manifest.json`
is required by the report; a claimed optimization flag alone is insufficient.

An editor worker can outlive editor exit. `wait_builds.py` observes the actual
project-specific compiler/linker processes before the final build; its wait log
is retained. A stale staging directory alone is not treated as a running build.

The baseline byte counter includes its one-byte wire tag. Both counters therefore
cover their own application protocol output, excluding ENet framing/retransmission.
The callback timer is inclusive elapsed wall time, not CPU-only time. It includes
different UI/audio implementations and must not be interpreted as a framework-only
ratio. RSS is an approximate peak over process lifetime, including startup. Input
aim/presentation internals, authority models and protocol cadences differ. Actual
RTT distributions are not yet sampled by this gate; it records the per-process
delay configuration. No network loss or jitter is injected here.

`summary.json` retains per-run nearest-rank percentiles, median/range aggregates,
the workload contract and build manifest. Raw samples, process logs and RSS records
remain beside it. `REPLAY_COMPARISON_PHASES=1` enables Replay's existing phase
profiler and writes timing CSVs; keep that diagnostic run separate from paired
uninstrumented results. All failures remain failures; no automatic retry chooses
a favorable run. The original game and its user-data directory remain untouched.

The firing wrapper also runs `verify_report.py` against copied receipts. A valid
result must pass, while an extra accepted round, missing reloads, an empty
projectile trace, wrong input, reordered observations or a changed binary digest
must fail without publishing a summary. The report verifier never mutates the
original receipts or binaries.


The current driver also records Replay's configured lead, prediction depth,
replayed ticks, fact/snapshot progress, baseline misses and resync counters. Before
measurement, the receive-side world must remain within four ticks of fact progress
and within the configured lead plus four ticks for at least 500 ms. This strengthens
the settled-workload warmup; the measurement tick, duration, shot and state limits
remain unchanged. The additional counters are diagnostic observations outside the
game callback timer, not a change to simulation or network policy.

## Combat encounter

```sh
nix develop --command bash tests/replay_comparison/combat_run.sh
```

The combat scenario starts from the same empty floor and stationary player poses.
The host requests four stock scrapbots at offsets (80,-20), (80,0), (80,20) and
(100,0) from seat 2. Both games use their existing spawn paths, NPC brains, body
collisions, damage, projectile/reload rules, death/reaping and pickup behavior.
The adapters execute spawning and nearest-enemy targeting inside the timed game
callback, so those costs are included in both implementations.

Each process waits until it observes player damage, then holds nearest-living-enemy
fire until its player has spent nine rounds. The eight-second measurement includes
the encounter and ensuing weapon/cleanup work. Both peers must finish with four
kills, 12 clamped damage, 12 collected scrap, nine rounds per player, no surviving
enemies/drops/projectiles, and at least two reload entries per player. Neither
player may die. No player movement, casts, statuses or additional waves are issued.

A read-only census captures every observed enemy's identity, position, health and
kind, plus living population, drop amount, health loss and combat counters. The
report checks actual enemy motion, the four initial spawn regions and authoritative
health/damage conservation. The game callback samples also carry timestamps, so the
report can select samples whose latest preceding census contained a living enemy.
Those are observed combat intervals, not exact simulation-phase boundaries. Census
and observation overhead are separately measured outside the game callback.

This matches requested encounter content and final offensive/pickup/shot totals.
It does **not** assert identical transient gameplay: the original spawns immediately
inside its callback while Replay queues actions, both target through their own
observations, and authority, crowd ordering and presentation differ. Player damage,
kill attribution, NPC occupancy and completion timing remain reported outcomes.
This is a small encounter comparison, not a sustained-swarm benchmark or full-game
parity/adoption verdict.

The capture includes original/workspace revisions and dirty state, hashes of shared
framework sources, isolated authored sources/assets, exact binaries, Godot/Odin,
CPU/RAM, process configuration and requested pair ordering. Reporting refuses
changed sources/binaries or missing repetitions. Mutation checks also reject missing
damage/loot/motion/enemies, wrong spawn regions/health and invalid sample times.
A one-pair run is useful as a pilot; the default comparison requires three alternating
pairs. Earlier idle/firing receipts used less complete source/environment capture.

The input-timing revision additionally records acknowledged-input turnaround,
arrival margin, clock scale, sample counts and lead updates. Turnaround includes
application/queue/snapshot work and is labeled separately from transport RTT.
The controller/workload gates remain unchanged, allowing the three-pair combat
contract to be repeated before and after this timing policy change.

Replay application output now uses the session router's accepted-byte counter,
including enabled telemetry and other application lanes. Historical results before
the tally telemetry change used gameplay-runner bytes. Their archived contracts
retain that older scope. The isolated original game still counts protocol payloads
plus its one-byte transport tag; neither count includes ENet overhead/retransmission.
