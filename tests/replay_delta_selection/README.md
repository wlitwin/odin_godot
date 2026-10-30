# Bounded snapshot-delta selection

```sh
REPLAY_DELTA_SELECTION_OUT=/absolute/fresh/directory \
  nix develop --command bash tests/replay_delta_selection/run.sh
```

The corpus compares `encode_smallest` with fully encoded sparse and LZ4 candidates,
including the sparse tie preference, and decodes the chosen bytes. It covers 768
pattern/length/alignment combinations at seven output budgets, sparse-only peers,
unchanged short-buffer output, untouched bytes outside the chosen extent, and
invalid length/alias boundaries. Native and executed WASM, default and speed builds,
must produce the same fingerprint. The ordinary sparse tests retain their separate
bytewise format oracle; the existing LZ4 gate retains its independent native oracle.

`tests/replay_payload_profile` separately measures both selection orders over
6,000 actual Scrapyard canonical snapshot pairs. It alternates timed method order
and requires identical selected kind, length and bytes. These are descriptive
single-process CPU measurements; the paired Godot jam cohort remains a separate
gameplay, networking and performance gate.
