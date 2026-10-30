# Claimball confirmed effects through checkpoint refresh

```sh
REPLAY_CLAIMBALL_RESYNC_OUT=/absolute/fresh/output nix develop --command bash tests/replay_claimball_resync/run.sh
```

This isolated copy runs the existing four-process contested fault checker at
120 ms receive delay, 0–20 ms jitter and 10% unreliable loss/duplication. When the
observer has a confirmed Kick waiting for the watched clock, the fixture explicitly
requests a same-epoch checkpoint through the ordinary Resync/Welcome protocol.
It changes request state only; it never edits a gameplay frame, fact or journal.

The original match/effect-completeness assertions must still pass. The additional
check identifies the pending kick, proves it was not yet visible, requires a view
reset and exactly one later confirmed presentation, and replays the complete
transport recording with exact operation/state/effect equality in native and standalone WASM receivers. Mark 3 records
the explicit refresh stimulus; automatic resync statistics remain unchanged.

For a comparison against explicitly preserved prior receiver sources:

```sh
nix develop --command python3 tests/replay_claimball_resync/compare.py \
  /absolute/fresh/comparison /path/to/old-client.odin /path/to/old-events.odin \
  /path/to/observer.trace /path/to/current-replay-trace
```

The comparison creates an isolated collection with only those two files replaced.
It requires the prior receiver to fail frame equality and the current receiver to
pass the same recording. The preserved source hashes identify which prior behavior
was tested. No shipping file is replaced. The historical C2 Facts_Overflow incident
still lacks a failing trace; this independently demonstrated journal-loss defect
does not establish why that older overflow happened.
