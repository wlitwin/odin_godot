# Compact observation comparison

`cohort.py PREPARED FRESH_OUTPUT` runs three pairs of raw/compact owner-motion
Cavecrawl cases, alternating order. Both modes use the same built binary, game
content, cadence, 120 ms receive delay, backup policy and contract-2 workload.
`CAVE_COMPARE_RAW_OBSERVATIONS` sets Session's capability opt-out before admission.
Packet instrumentation is disabled during timing measurements.

```sh
nix develop --command bash tests/replay_cave_comparison/build.sh /absolute/fresh/prepared
nix develop --command python3 tests/replay_observation_codec/cohort.py /absolute/fresh/prepared /absolute/fresh/cohort
```

The output preserves all process traces and a six-run report for the three pairs. It checks quiet
gameplay, inventory, two confirmed client actions, completed backups and bounded
measurement windows. Network tests cover malformed encoding, independent decode,
reordering/loss, signed zero and dense fallback. `tests/replay_observation_compat`
checks frozen old/new peer combinations. Native/browser owner/context gates are
separate regressions; local cost reduction is not broader deployment acceptance.
