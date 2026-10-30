# Erasure codec corpus

Run `nix develop --command bash tests/replay_erasure/run.sh`.
`REPLAY_ERASURE_OUT` may name a fresh output directory.

The independent parity oracle multiplies binary polynomials then reduces by
0x11d; it does not call the encoder's arithmetic helpers. All zero/one/two-erasure
combinations across 1–8 data shards, three patterns, three lengths and four
alignments produce 8,064 recovery cases. The corpus checks exact data and output
boundaries, short final shards, rejected three-data erasures, invalid masks and
alias rejection. Native and executed WASM, default/speed builds, must have equal
fingerprints. No timing threshold stands in for correctness.

`tests/replay_net/snapshot_erasure_test.odin` separately exercises negotiated
wire packets, repeated data loss, digest/scope/duplicate checks, memory bounds,
egress backpressure, early ACK eligibility and a peer with parity disabled.
The large-snapshot fixture also drops two data parts per group beyond part 128.
