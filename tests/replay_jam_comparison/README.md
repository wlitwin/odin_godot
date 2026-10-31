# Jam-clearing swarm comparison

```sh
REPLAY_JAM_OUT=/absolute/fresh/directory \
  nix develop --command bash tests/replay_jam_comparison/run.sh
```

This is a separate stress profile layered on the endurance preparation. It keeps
moving players, forty replenished scrapbots, casts and scheduled burn/salve/surge,
but sets the bolter's jam threshold to 200 per mille. That is a declared stress
fixture, not the stock 12-per-mille frequency. The stock eight-round magazine,
72-tick reload and three clear pulls remain. Both games use ordinary paced fire
input; their current implementations clear jams through successive trigger pulls,
including while fire is held.

Original identity-derived salts are retained and recorded. Kit uses runner net IDs
and Replay uses seat IDs, so their deterministic jam streams differ. The report
recomputes the roll for every consumed round and checks duds separately from fired
shots. The inherited report's `shots`/minimum-shot envelope denotes consumed rounds;
`jam_work.shots` and `final_guns.shots` explicitly record live shots. Kit exposes
live-shot/pull counts on the authority only; Replay's shot counter is replicated.

The isolated Kit consequence hook counts its actual gun-pull outcomes without
altering the command or game effect. The report checks Fired + Jammed = spent,
the seeded jam count, clear-tap/cleared counts, mode/tap/ammo validity and final
peer gun-state convergence. Replay's authoritative transitions are observed per
frame; its cooldown exceeds the maximum simulation catch-up burst, so at most one
pull occurs between those observations. Client observations may skip intermediate
transitions; they must remain valid and converge to authority.

At least three jams and two completed clears per player are required, with visible
jam exposure, repeated reloads, movement/cast/status work and the existing damage/
kill/loot conservation gates. An uncleared final jam is permitted and must remain
in the final state; the harness does not clear it to make the test pass. The mechanism
checks are in addition to ordinary world accounting and transport validation.

The full plan uses three alternating Kit/Replay pairs in each of the existing
delay and raw-loss conditions. `REPLAY_JAM_PILOT=1` selects a partial one-pair plan;
`REPLAY_JAM_CONDITIONS=delay` or `lossy` selects a condition. Partial plans cannot
satisfy full acceptance. Kit uses the isolated owner-unwind control; original Kit,
Scrapyard sources, data, saves and prior benchmark results remain intact.

Callback/RSS/application-byte observations retain the endurance methodology and
its limits. Different salts, pull counts, actual shots, authority and presentation
prevent a framework-only cost ratio. Natural incoming-hit rates, stock-frequency
jam statistics, changing waves, migration during a jam and human play-feel remain
separate roadmap work.

The [first full cohort](../../docs/replay/results/jam-clearing-2026-09-09/README.md)
passes its twelve delay windows and 60 scoped report checks. Raw loss remains
rejected for stale Kit cooldown observations and a lost Replay dash; successful
runtime exits alone do not satisfy this gate.

`freshness.py OUTPUT_DIRECTORY` reports observed world-progress gaps with the
contiguous-fact and snapshot-stage counters in each trace. It is diagnostic and
does not alter acceptance. A fact jump when a gap ends must not be interpreted as
facts advancing throughout the gap. Repair counters distinguish client requests
from authority reply packets and oversized fallbacks.

For nested CPU phases, run `profile_run.sh COMPLETED_FULL_COHORT` with
`REPLAY_JAM_PROFILE_OUT` pointing to an empty directory. It reuses the verified
Replay binary and the ordinary jam driver in the delay condition, enables existing
phase timers, and requires complete runtime receipts with no dropped timing samples.
It is a diagnostic pair, separate from the uninstrumented full comparison.

An optional second argument names an archived result directory when the live
framework has advanced. `profile_provenance.py` verifies the prepared sources,
exact binaries, archived cohort receipts and every required framework source byte
against the archive and its checksums. Binary/source proofs must still match after
the run. This permits a measured before run without rebuilding it from newer code.

If a completed full cohort fails outside delay/Replay, the phase runner can profile
its accepted delay/Replay condition using live source proof. The provenance records
both full-matrix and raw-loss Replay acceptance explicitly. This diagnostic path
does not accept a failed full comparison or support a raw-loss performance claim.

`RSY_SHUFFLE=0` or `1` can be used with the phase runner for same-binary delivery
comparisons. Its before/after provenance records `RSY_SHUFFLE`, `RSY_FEC` and
`RSY_LZ4` explicitly; counters in the raw trace identify selected encodings. This
is a diagnostic pair, not a replacement for the ordinary full comparison matrix.

`REPLAY_JAM_SNAPSHOT_EVERY=N` evaluates Replay's requested snapshot interval in
simulation ticks (1..30). Simulation remains at the contract's 60 Hz. The run plan
records the requested interval and each process records its actual configured
interval; the report rejects a mismatch. Kit retains its existing delivery policy.
All gameplay, convergence and freshness gates remain unchanged. A lower requested
frequency is not evidence of acceptable responsiveness until those gates and the
measured progress intervals have been assessed.

On macOS, `REPLAY_JAM_SAMPLE=1` adds a ten-second, one-millisecond `sample` trace of
the actual client during the measurement window. The exact PID and requested
sampling parameters are recorded in `sample-plan.json`. The sampler is tracked and
cleaned up with the game processes. This is a separate instrumented diagnostic;
it is not part of the uninstrumented full-cohort timings. Verify its workload with
`rate_report.py` as for other single-pair phase diagnostics. Samples include idle
and system activity, and their stack counts are not exact CPU-time measurements.

When verifying a historical cohort after model edits, `REPLAY_SOURCE_ROOT` may
name its exact archived source tree. Model and framework hashes are still checked;
this is source-location selection, not a bypass for changed data or binaries.
