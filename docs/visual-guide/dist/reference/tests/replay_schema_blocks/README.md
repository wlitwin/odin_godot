# Zero-safe validation block oracle

Run `nix develop --command bash tests/replay_schema_blocks/run.sh`.

The corpus compares the current schema codec against the frozen pre-block codec
in native/default, native/optimized, WASM/default and WASM/optimized execution.
The old package declaration is renamed only to satisfy Odin's unique-package
rule; captured and adapted hashes are retained under `reference/`.

Cases cover zero, dense, sparse and nonzero-only-enum data under authority and
public projections. Every encoded byte and every native byte is mutated in turn,
including poisoned padding and excluded secret storage. Error category, first
field path, output bytes and decoded values must agree with the reference.
Rejected decode leaves the candidate unchanged. NaNs in excluded fields are
compared by bits, not floating-point equality.

Structural checks require every multi-check block to lie inside one direct-copy
span, excluding padding, private omissions, reversed scalars and union storage.
The general tagged-union path is unchanged and covered by the separate union suite.
