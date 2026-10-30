# Canonical byte-scan checks and microbenchmarks

Run `nix develop --command bash tests/replay_scans/run.sh`.

The native executable first compares hash/delta results against independent
bytewise format oracles. A no-import WebAssembly module executes the same corpus,
and Node verifies its fingerprint against native output. The corpus includes
unaligned offsets, zero/dense/sparse/alternating bytes, empty/tail lengths and the
65,535-byte delta limit. Other schema/delta tests verify transactional rejection.

The benchmark compares seven alternating trials of 1,000 calls. Hash seeds depend
on each preceding result. Delta targets vary one counter byte each call to prevent
loop-invariant work from being hoisted. The timing reference is the complete
pre-optimization two-pass encoder from the recorded comparison archive; the
independent one-pass format oracle is used for correctness, not performance.

Cases cover zero bytes, a canonical Scrapyard world, equal random buffers, dense
random changes, alternating changes and changes every eighth byte. Raw durations, output lengths and fingerprints are retained.
`REPLAY_SCANS_OUT` selects the output directory. Results are algorithm-level elapsed
time and must not be substituted for full-game performance or a platform guarantee.
