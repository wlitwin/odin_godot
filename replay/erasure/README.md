# Two-erasure parity

This allocation-free codec protects one to eight data shards with two parity
shards. `P` is their bytewise XOR; `Q` weights data shard `i` by `2^i` in GF(256).
The field uses `x^8 + x^4 + x^3 + x^2 + 1`, the byte-field polynomial described in
[RFC 5510 §8.1](https://www.rfc-editor.org/rfc/rfc5510.html#section-8.1). Replay's
P/Q layout and network framing are defined here; no RFC wire compatibility is
implied. Distinct nonzero weights make each two-data-erasure equation invertible.

`encode(data, parity)` fills both parity buffers. Each must equal the longest data
shard, at most 1,024 bytes. Short data shards are virtually zero-padded. All buffers
must be disjoint; data shards must be nonempty. The implementation uses Horner
steps for Q and does not retain a dictionary or allocate memory.

`recover(data, parity, missing, present_parity)` restores only data marked missing.
Missing data buffers retain their original declared lengths. `present_parity`
identifies received P/Q rows; erased parity bytes are ignored. Any two erasures
among data and parity can be repaired. Invalid buffers/masks or insufficient
parity fail without modifying data. No buffer outside a recovered shard changes.

This is an erasure codec, not a corruption detector. The networking layer checks
each packet and the reconstructed complete snapshot digest before decoding or
publishing state. More than two erasures in one group can remain unrecoverable;
normal later-snapshot and resync behavior still applies.

```sh
nix develop --command bash tests/replay_erasure/run.sh
```

The corpus checks parity against an independent polynomial-product/reduction
oracle, then enumerates every zero/one/two-erasure combination for 1–8 data shards,
three patterns, three widths and four alignments. Native and executed WASM,
default/speed builds, must agree across 8,064 cases. It also checks insufficient
parity, malformed masks, buffer boundaries and rejected aliasing.
