# Exact correction reuse corpus

The corpus compares ordinary full correction with explicit `correct_reusing` over
128 deterministic scenarios: matching prefixes, changed inputs, convergence after
resets, changed authoritative events and failures after reusable work. Every stored
frame, input, event batch, confirmation value and rewriter call sequence must agree.
Failures report zero published reuse. Default/speed native and executed WASM must
agree on the canonical output fingerprint. The WASM wrapper supplies an explicit
arena; the library API is unchanged by that test allocation choice.

```sh
nix develop --command bash tests/replay_correction_reuse/run.sh
```

A separate native timing loop uses a 65,544-byte state and a 32-tick matching suffix.
It alternates full/reuse order over 100 samples. Initialization/advancing is outside
the measured correction, and every result is checked. This is a best-case synthetic
measurement, not a game-wide speedup claim.
