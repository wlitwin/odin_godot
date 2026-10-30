# Claimball observer transport replay

The fixture copies the current Claimball app and adds a local observer-only
transport recorder. The server and players keep the original workload and fault
settings: 120 ms receive delay, 0–20 ms jitter, 10% unreliable loss/duplication.
The existing effect-completeness check remains in use.

```sh
REPLAY_CLAIMBALL_TRACE_OUT=/absolute/fresh/output \
  nix develop --command bash tests/replay_claimball_trace/run.sh
```

`build.sh OUTPUT` creates the instrumented app and a standalone receiver replayer.
`RCB_TRACE=/absolute/file` enables capture only for observers. The file records exact
transport results/bytes plus portable initial client configuration and actual pump
times. Per-frame marks retain state/frontier and drained-effect hashes. Playback
must consume the same callback sequence, produce the same outbound traffic and
match every frame; it does not use Godot or an active server.

Capture adds allocations and hashing; it is not timing-neutral. A replay proves
receiver behavior for the captured delivery schedule, not a counterfactual server
response or identical wall-clock scheduling across new live runs. Raw recordings
can contain credentials/private payloads. This fixture uses isolated explicit test
identities, and published evidence must state what data it retains.

The historical Claimball observer-effect failure remains open until a failing
trace establishes its cause. A clean capture/replay alone is not a fix claim.


Set `RCB_TRACE_PAUSE_MS=1800` or `2000` to introduce a single local observer stall
after confirmation reaches tick 174; larger pauses are refused by this fixture.
The actual subsequent pump timestamp is recorded. The historical receiver's code
can be built in an isolated collection overlay to compare the same transport stream.
Strict operation/state agreement is still required; a passing old/new comparison
means that schedule does not explain the prior failure.

`mutate/` changes one recorded state/effect expectation and reseals the record's
integrity digest. Replay must reject it, verifying that successful completion
requires more than opening a file or reaching the final score.

## Archived C2 comparison

`legacy_build.sh OUTPUT` extracts the original C2 prepared app and four runtime
files differing from the original failure snapshot into an isolated collection.
It adds only the observer recorder and builds old/current receiver executables
against that same archived game model. It never replaces the shipping examples.

`legacy_execute.py PREPARED LABEL` runs the original four-process fault checker;
`RCB_TRACE_FAULT_SEED` selects a positive seed at the existing delay adapter boundary
without changing loss/jitter/duplication rates. The same optional local pause applies.
`legacy_run.sh` builds once and compares five seeds. It preserves any live-checker
failure or replay difference as a failure; successful comparison is not a claim to
have reproduced or fixed the historical missing-effect case. The preparation skips
generated code because scriptgen must regenerate it for the instrumented build.

The preserved runtime set now also includes `replay/net/server.odin`, whose receive
loop changed in the byte-budget fix. Preparation restores that file's exact C2
archive bytes, alongside client, recent facts and Room. The independent budget-loss
reproducer does not establish the cause of the historical C2 effect loss.

## Checkpoint-refresh stimulus and WASM replay

Optional mark 3 records a test-requested same-epoch checkpoint refresh. The receiver
replayer consumes the mark and makes the same request-state transition before the
next pump. The trace header and existing marks are unchanged, so prior captures
remain readable. `tests/replay_claimball_resync` requests this refresh while a
confirmed kick is still waiting for its watched clock; no game state is edited.

```sh
nix develop --command bash tests/replay_claimball_trace/targets.sh /absolute/output /path/to/observer.trace
```

The standalone WASM receiver verifies the exact transport operations, per-frame
world/frontier/effect values and totals against native playback, and rejects
corruption. Its explicit fixture limits are 16 MiB of input and 100,000 operations;
these are verifier limits, not library or live capture limits. It uses separate
persistent and per-frame scratch storage. This proves receiver behavior for the
recorded schedule; it is not a live browser networking test.
