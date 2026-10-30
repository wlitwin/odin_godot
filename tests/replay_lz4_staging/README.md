# LZ4 staging comparison

The frozen reference is the previous pure Odin encoder/decoder, with only its
package name changed. `run.sh` verifies its source hashes before executing the
comparison. The 440 cases combine eleven repeating/mutated patterns, eight input/
output alignments and five lengths up to 65,535 bytes. Encoded output must match
the reference exactly; decoded values and truncation rejection must agree.

```sh
nix develop --command bash tests/replay_lz4_staging/run.sh
nix develop --command bash tests/replay_lz4/run.sh
```

The synthetic timing rows compare encoder work at 52,724 bytes. They are diagnostic
elapsed timings, not a game-speed claim. The existing larger corpus separately
checks short-output atomicity, alias rejection, native LZ4 interoperability and
executed WASM/default/speed fingerprints.

The staged encoder searches once into a bounded workspace buffer, then copies the
completed result if the caller's destination fits. Workspace grows from 16,384 to
82,192 bytes; output remains unchanged on failure. The extra 65,808 bytes are
per-workspace scratch, with no retained dictionary or wire-format change.
