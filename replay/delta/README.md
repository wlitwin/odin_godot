# Canonical snapshot deltas

`replay/delta` provides a sparse XOR codec and a bounded snapshot cache over
canonical bytes from `replay/schema`. Use it to send changes against an acknowledged
snapshot baseline. It never compares compiler-layout padding.

The little-endian delta format contains a u16 run count, then sorted,
non-overlapping `(offset:u16, size:u16, XOR bytes)` runs. Values are at most 65,535
bytes. Encode/decode preflight the complete operation before modifying output and
allocate nothing. Dense changes can produce larger deltas; the sender then uses
a full snapshot.

`Cache` owns fixed-size values keyed by nonzero stream-local snapshot IDs.
`cache_find` returns borrowed bytes. Copy a promoted baseline if it must survive
cache eviction. Clear history when the connection/checkpoint serial changes.

`cache_note_prehashed` avoids repeating a digest calculation. It is a trusted
local optimization: its digest must have been computed over the exact supplied
bytes. It does not validate a wire-provided hash. The networking receiver still
computes and compares the reconstructed target digest before using this path.
The cache owns its byte copy; duplicate IDs require the same digest and bytes.

The network runner promotes only ACKs matching a snapshot actually sent on the
current connection generation and checkpoint serial. Receivers reconstruct into
scratch, validate checksum/schema/game state, then cache and acknowledge. Missing
baselines request a full snapshot without inventing state or resetting the game
when normal simulation history remains available.

```sh
nix develop --command bash tests/replay_delta/run.sh
nix develop --command bash tests/replay_net/run.sh
```

Checksums detect compatibility/corruption issues; they do not authenticate peers
or prove that a client simulated honestly. The session retains that responsibility.

Encoding keeps very short equal prefixes on the byte path, then skips equal
eight-byte regions with explicitly unaligned, bounded loads. A differing word
locates its first changed byte from the appropriate endian-dependent end.
Differing runs keep their original byte boundaries and ordered XOR format. Complete
preflight and failure-without-output-mutation remain in place. Native and executed
WASM corpora compare the resulting bytes with the bytewise reference.

`encode_bounded(base, target, dst, budget)` emits the identical sparse format only
if it fits both the budget and destination. It can stop scanning once the candidate
is too large. Unlike `encode`, failure does not report the required size; output
remains untouched. Output must not overlap either input.

`encode_smallest(base, target, dst, workspace)` chooses the smallest existing sparse
or LZ4 encoding that fits, preferring sparse on a tie. A bounded tiny-sparse trial
can rule out LZ4; otherwise LZ4 stays in its existing scratch stage while bounded
sparse encoding attempts to beat it. A nil workspace selects sparse-only behavior.
Failure leaves output unchanged, and success changes only the returned extent.
Workspace/input/output aliasing is rejected. Selection adds no allocation or
workspace bytes, changes no decoder or wire format, and retains exact chosen bytes.
The network runner bounds the result so that a delta must beat the full snapshot.
