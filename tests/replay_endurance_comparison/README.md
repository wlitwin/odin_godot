# Mixed injury/dash/reload comparison

```sh
REPLAY_ENDURANCE_OUT=/absolute/fresh/directory \
  nix develop --command bash tests/replay_endurance_comparison/run.sh
```

This prepares separate Kit and Replay Scrapyard copies. Kit uses the isolated
owner-unwind repair from the movement audit; original Kit and the sibling game
remain untouched. The contract fixes three pairs in alternating Kit/Replay order
for each of two conditions: 120 ms receive delay per process, and a raw UDP proxy
with 120 ms delay each direction, up to 20 ms jitter, 5% loss and 5% duplication.
The latter acts below ENet, including its reliable retransmissions.

Each twenty-second window keeps the moving forty-scrapbot swarm, nearest-enemy
fire, frostwave and battlecry from the mixed comparison. The bolter uses its stock
eight-round magazine and 72-tick reload; random jams remain disabled. Each player
receives ten dash intents through normal input paths. The host schedules stock
burn and salve exposure on both players through normal status application. Status
decay, DOT damage, healing and the rally-plus-salve surge reaction execute in the
real game. Scrapbot bite remains zero: this is a defined hazard-exposure workload,
not a measurement of natural incoming-hit rates. No HP or positions are written
by the per-frame benchmark adapter. Kit uses its normal host status function;
Replay uses its admitted development action path, including its action/fact
bookkeeping. That plumbing cost difference remains part of the fixture.

Census/report gates require observed HP loss/recovery, burn/salve/surge exposure,
ten executed dashes and repeated reload entries, alongside movement, casts,
occupancy, churn, health/kill/loot conservation and final peer convergence. HP
edges are net observed changes, not counts of every underlying DOT/healing pulse.
Authority and presentation models differ. Stock dash is owner-clocked in Kit and
fixed-tick predicted in Replay; distances and transient timing remain measured
outcomes rather than assumed parity.

The delay condition requires no measurement resync and at most thirty extra fact
lag ticks. The lossy condition permits up to three explicit resyncs, a 120-tick lag
bound and at least 1,000 received-tick progress in twenty seconds. Those are
correctness/recovery bounds, not a responsiveness endorsement; up to two seconds
of unavailable authority frames may occur in the lossy window and are explicitly
recorded instead of interpreted as zero health; reports retain
actual lag distributions and resync counts. Proxy event logs are reconstructed to
verify loss/duplication, queue bounds and accounting. Both peers must settle to
identical final health, dash, shot, damage, kill and loot totals.

Inclusive callback time covers networking, simulation, presentation and workload
intent dispatch. The read-only census runs outside that timer and has its own
reported cost; later trace serialization is not entirely inside that cost. RSS
includes instrumentation. Application byte counts exclude ENet framing and
retransmission; raw proxy traffic remains separately recorded. Median/range of
three runs is descriptive and cannot establish a framework-only cost ratio.

`REPLAY_ENDURANCE_PILOT=1` selects one pair. `REPLAY_ENDURANCE_CONDITIONS=delay` or
`lossy` selects a condition. Such partial plans cannot pass full acceptance. The
runner requires fresh verified builds and keeps correction reuse disabled. The
full report gate also runs acceptance/rejection checks for missing workload,
changed provenance, invalid final state and corrupted proxy evidence. Random jams,
changing waves, richer incoming-hit sources, human play-feel and platform coverage
remain separate roadmap work.

The isolated Replay model explicitly selects `net.Action_Timing.Receipt`. Its
modified model source and before/after hashes are recorded in `action-policy.json`;
the report checks that choice. Stock Replay Scrapyard retains Scheduled mode and
its existing checkpoint contract. The earlier full scheduled-action cohort is
retained as a failed comparison: remote casts were rejected as stale, and one raw
case exceeded the unavailable-frame bound. Receipt scheduling is a declared
cooperative semantic choice, not a retry added to hide rejected requests.

Replay's prediction horizon now stalls forward prediction while retaining a
readable world, instead of immediately discarding it for a Welcome. Reports retain
prediction-stall attempts, snapshot catch-ups, warmup/measurement/settling resyncs,
and the largest observed tick-progress gap. A stall or old readable frame is not
counted as evidence of fresh authority state. The gap for Kit's tick probe follows
its local session clock and is not directly equivalent to Replay's received-frame
progress.

The [latest full matrix](../../docs/replay/results/receipt-resync-2026-09-09/README.md)
passes all 24 process windows and 56 report-validation cases. Earlier raw-loss
failures remain recorded. Receipt-mode actions now queue during a same-epoch
resync, while scheduled input fencing and consumption receipts preserve their
existing boundaries. A passing cohort is not a guarantee across arbitrary loss,
latency, incoming-hit mixtures or platform behavior.

```sh
# Preserve the strict overall failure and assess each condition separately.
python3 tests/replay_endurance_comparison/audit.py /path/to/run
python3 tests/replay_endurance_comparison/verify_report.py /path/to/run delay
python3 tests/replay_endurance_comparison/plot.py /path/to/run /path/to/figures --condition delay
```

`assessment.json` labels the full matrix rejected and keeps failed-condition
observations separate. `summary-delay.json` contains only the independently
verified condition. The input audit fixes a proven obsolete-tick capture path. Wider timing-envelope
validation remains open; the earlier Kit submission-refusal
classification was a measurement error. Implementation-scoped report
selection requires `--allow-partial` and cannot produce full-matrix acceptance.

Contract version 2 distinguishes Kit submission from local prediction. The
original `command_ok`/`try_*` boolean answers whether the cast applied on the local
screen. A predicting client may return false with a nonzero command sequence while
still sending the request for the authority to judge. The earlier classification
of that result as a submission refusal was incorrect; the recorded authority
cooldown edges and nova logs showed the casts executing.

The isolated adapter now records the actual generated `Action_Outcome` while
preserving the original issue and presentation paths. Four immediate-model
receipts must be observed. A client submission requires a nonzero sequence;
an authority-local submission requires Applied. Local prediction rejection is
reported separately and cannot satisfy the independent authority/cooldown/status
gates. Missing receipts, zero-sequence refusals, wrong models and reused sequences
are rejected by report tests. Original Kit/game behavior is unchanged.
