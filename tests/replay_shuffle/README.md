# Schema-derived shuffle corpus

```sh
REPLAY_SHUFFLE_OUT=/absolute/fresh/directory \
  nix develop --command bash tests/replay_shuffle/run.sh
```

A checksum-verified frozen schema implementation proves canonical fingerprints and
bytes remain unchanged. The corpus covers authority/public projections, private
fields, padded records, nested arrays, arrays of tagged unions, standalone union
variants, alignment, short buffers, alias rejection and truncated compressed data.

An independent permutation loop checks output layout, and an inverse checks every
canonical byte. The optimized XOR-first encoder must produce exactly the same
LZ4 block as shuffling both inputs separately. All 256 cases run on native and
executed WASM in default/speed builds with equal fingerprints. The WASM fixture
uses a bounded arena for compiler-derived schema metadata.

Network tests separately cover negotiated selection, plan/target hashes, malformed
payloads, missing baselines, parity/loss, opt-out and exact settled world equality.
The actual-game payload profile and full jam cohort measure whether savings are
worth the additional CPU work; neither is replaced by this byte corpus.
