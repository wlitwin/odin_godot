# Loaded browser host migration

```sh
REPLAY_LOADED_OUT=/absolute/fresh/planned REPLAY_LOADED_MODE=planned \
  nix develop --command bash tests/replay_loaded_migration/run.sh
REPLAY_LOADED_MODE=crash nix develop --command bash \
  tests/replay_loaded_migration/execute.sh /absolute/fresh/planned /absolute/fresh/crash
```

Builds an isolated Scrapyard Replay copy and runs the existing twenty-second,
forty-mob jam workload in two Chrome processes. The report reuses the native
workload's gameplay/observation gates unchanged. Controlled RTC message faults
apply 40±10 ms delay and 5% unreliable loss/duplication with bounded queues and
reliable FIFO order. Hardware WebGL, the 1280×704 viewport, and speed WASM match
the browser stress fixture. These are local signaling/coordinator experiments,
not raw IP/SCTP loss, public deployment or cross-device performance claims.

After the workload, both peers resume movement/fire and replenishment for five
seconds. Planned mode requests an ordinary Room handoff. Crash mode kills the
exact original host browser process, waits for the nominated candidate to recover,
then opens member 1 with a new incarnation. The coordinator retains its default
120-tick maximum known rollback. No wait for a specially fresh checkpoint occurs
before the trigger.

Success requires exact restored checkpoint state, the expected recovery kind,
one authority in epoch 2, both original seats, a newly confirmed follower dash,
and at least ten common canonical world hashes. Planned transfer must lose zero
known ticks. Raw and compressed checkpoint sizes, prepared/known ticks, transfer
credits, assembly bounds, faults and renderer are recorded. A report additionally
validates the initial gameplay work and rejects altered receipts through
`verify_report.py OUTPUT`.

Godot release exports omit assertions. The handoff call must execute outside
`assert`; the initial fixture mistake and its timeout are retained as failed
harness evidence. `execute.sh` reuses a built fixture and writes a fresh runtime
directory. Original Kit and original Scrapyard projects remain separately runnable.

The trigger now records a fresh population census and shots spent by both players;
32–44 mobs must be alive and both players must have fired during the resumed load.
Browser startup is bounded to 120 seconds and the browser is tracked before page
creation, so a stalled startup can be cleaned up without leaking an owned process.

`REPLAY_CAPTURE_ARCHIVES=1` optionally captures at most three outgoing checkpoint
streams before the existing message faults. `capture_test.mjs` exercises the
observer's forwarding, copies and bounds. Native analysis must validate the raw
hash and typed checkpoint; interception alone is not trusted decoding. To inspect
a completed capture, write its `wire` array to a file and run:

```sh
nix develop --command odin run tests/replay_loaded_migration/analyze \
  -collection:godot="$PWD" -collection:sample=/absolute/build/replay/project/shared \
  -o:speed -- /absolute/capture.wire RAW_BYTE_COUNT /absolute/capture.raw
```

Compare the raw file's SHA-256 to the capture's `hash`. The analyzer checks typed
checkpoint decoding and compares plain, schema-grouped and simple byte-plane
compression offline. It also roundtrips the schema-grouped result to exact raw
bytes. These diagnostics do not enable a new transfer format.

Use `REPLAY_SOURCE_ROOT=/absolute/archived/source` when validating an older build
whose live framework checkout has changed. Every framework hash is still checked.
The early checkpoint scheduling candidates were removed after violating gameplay
freshness; the regular Session/Link scheduling remains in place.


Current migration reports also require schema-grouped checkpoints to have been
selected by the sender and fully validated by the receiver before the trigger.
The capture observer recognizes both ordinary compressed and schema-grouped
checkpoint offers, retaining the layout fingerprint for the latter. The analyzer's
input remains an ordinary compressed capture; it now also sends that decoded
checkpoint through the real typed schema-aware transfer and compares the restored
canonical bytes. The separate `tests/replay_transfer/layout_corpus/run.sh` executes
layout transfer, fallback and plan rejection in native and WASM builds.


Current probes distinguish capture tick, chunk progress, latest validated tick,
and prepared/approved tick. `stages.py OUTPUT` derives first-observed stage ages;
its sampling interval limits precision. Capture files are also saved on failed
runs. `compare_archives/` verifies consecutive captured checkpoints, then measures
self-contained array predictors and inter-checkpoint XOR offline. These diagnostics
do not enable a delta or new codec.

`REPLAY_RELIABLE_HOLD=1` adds one FIFO pause to the host's reliable RPC traffic
at the first checkpoint chunk at tick 1000 or later. `REPLAY_RELIABLE_HOLD_MS`
selects 1–2000 ms (default 200). The wrapper records requested/actual duration,
copies buffers, preserves order, bounds memory and leaves unreliable traffic flowing.
The report checks that the requested pause occurred and drained before migration.
This is message-level injection, not raw SCTP/IP loss.

`REPLAY_RELIABLE_HOLD_AT_KILL=1` instead arms after the resumed five-second load,
then kills the host while the next checkpoint transfer is held. It requires crash
mode and a 1000–2000 ms hold (default 2000), with at least 300 ms observed before
killing. Queued bytes must still be present. No new completed checkpoint is awaited.
The previous approved point must support exact recovery within the unchanged
120-tick rollback limit. Samples during the hold retain the existing 30-tick
facts-lag, credit, memory and no-resync requirements.

The declared fault plan and measured hold/frontier records accompany the usual
workload and migration receipts. `reliable_hold_test.mjs` checks copied FIFO data,
transparent unreliable traffic, one-shot/late arming and rejected configurations.
`verify_report.py` rejects missing, mistimed or stale held-transfer observations.

## Real UDP TURN traffic

`build.sh OUTPUT` now prepares both an isolated game export and an isolated
coordinator. `run.sh` builds in `REPLAY_LOADED_OUT` and executes into its `run/`
subdirectory; `execute.sh BUILD FRESH_RUN` reuses the recorded artifacts. Native
and Web binary hashes are verified before execution. Original Kit and Scrapyard
sources remain separate.

To run the loaded scenario through the shared datagram proxy:

```sh
nix develop --command bash tests/replay_loaded_migration/build.sh /absolute/build
python3 tests/replay_turn_faults/run.py --game loaded --mode crash \
  --web /absolute/build --out /absolute/fresh/run \
  --turnserver /absolute/path/to/turnserver
```

`--mode planned` requests handoff. All other fault arguments match the
[proxy runner](../replay_turn_faults/README.md). In this mode the driver omits application-message fault injection and installs
native relay statistics observation,
and activates UDP faults only after both populated-world barriers and selected
relay pairs. Faults continue through the workload, resumed combat, migration and
rejoin. The original gameplay, snapshot-freshness, memory/credit, population/fire,
rollback and state-equality gates remain in force. The build's browser contract
records the default message-fault scenario; the runtime `fault-plan.json`, zero
application-fault counters/config, and parent `faults.json` describe this distinct
UDP scenario. A mixed or undisclosed application-fault configuration is rejected.

The proxy runner closes and reconciles its packet record before executing the
loaded report. `browser/turn-network.json` contains the checked network summary;
`result.json` combines it with the loaded-game report. To recheck original files:

```sh
python3 tests/replay_turn_faults/report.py /absolute/fresh/run --game loaded
python3 tests/replay_loaded_migration/verify_report.py /absolute/fresh/run/game
```

Do not infer success from the network summary alone: the final report requires
both network evidence and all loaded-game gates. This is a local test using
synthetic identities and an existing deterministic workload, not public deployment
or a paired Kit/browser benchmark.


`REPLAY_RTC_CREDIT_TRACE=1` optionally records up to 32,768 credit/fence send and
receive observations per browser. It preserves the native send result, exceptions
and exact payload, and records only envelope metadata and browser timestamps.
`credit_report.py RUN/game/browser` pairs the pre-migration observations from both
browsers. These same-machine timestamps approximate send-to-delivery time; they
are not application acknowledgement latency or a cross-device clock protocol.
`credit_trace_test.mjs` checks transparent forwarding, error preservation, channel
association and bounds.

`control_report.py RUN/game/browser separate` checks real native channel options
and bidirectional traffic on negotiated control stream 2. `legacy` instead requires
zero traffic on that stream. `legacy_run.py --current BUILD --legacy OLD_BUILD
--member 1 --out FRESH_OUTPUT` (also member 2) runs the complete message-fault
handoff workload against genuinely earlier compiled two-channel peers. The old
build's hashes are checked and recorded before serving its export.

## Snapshot-path diagnostics

`REPLAY_SNAPSHOT_TRACE=1` records bounded metadata for native snapshot fragments,
parity, decode acknowledgments and checkpoint chunks. It preserves native sends,
results, exceptions and payloads. Recorder version 2 retains generation and serial
alongside snapshot IDs, avoiding collisions across admission scopes. No raw
payload is retained. `snapshot_trace_test.mjs` checks framing, forwarding and bounds.

`snapshot_report.py RUN/game/browser` separates fragment submission span, native
send-to-delivery time, and time until the receiver emits a decode acknowledgment.
The latter is not proof that the snapshot was applied. Where telemetry is available,
the report also gives an upper bound until a confirmed state at least that new is
observed. This includes sampling delay and can include fixture pauses; it is not
an exact correction-latency metric. Earlier version-1 recordings are explicitly
marked as lacking generation/serial headers.

`REPLAY_BACKGROUND_BYTES=1200` during **build preparation** produces a separately
hashed test-only checkpoint pacing variant. Its `background-plan.json` follows
runtime copies. The default value is zero, which makes no pacing override.
No gameplay, freshness or recovery acceptance limit is relaxed by this diagnostic.

## Public history projection and adaptive codec coverage

Scrapyard content 48 excludes rewind `hit_history` from public snapshots and
explicitly declares its public replication/prediction policies. Complete recovery
archives retain that history. The loaded fixture keeps the same forty-mob combat
workload, input schedule, 30-tick freshness bound, prediction bounds, memory/credit
limits, 120-tick recovery limit, and canonical public-world equality checks.

For builds with private fields, `snapshot-contract.json` must show positive field
exclusion, identical public snapshot sizes on both peers, a public snapshot smaller
than half the complete recovery archive, enabled grouped-codec support, and actual
compressed snapshot delivery. Grouping need not be selected when smaller adaptive
deltas do not benefit from it. Legacy builds retain the original grouped-snapshot
selection requirement. Both paths still require actual grouped recovery archives.
The report mutation suite rejects missing projection, lost codec support, absent
snapshot delivery and oversized public payloads, alongside the gameplay gates.

`REPLAY_SNAPSHOT_APPLY_TRACE=1` records a bounded per-frame client frontier probe.
`application_report.py RUN/game/browser` classifies measurement-phase freshness
failures as missing decoded snapshots, decoded snapshots waiting for facts, or
usable snapshots not applied. Probe cost excludes the subsequent JavaScript write.

`REPLAY_CAPTURE_SNAPSHOT_PAIR=1` captures one frozen sender baseline/target pair
between workload completion and resumed combat. **These optional files contain
synthetic game state**, unlike the metadata-only snapshot trace. The
`analyze_snapshot` Odin tool uses the exact prepared model and Public schema,
validates canonical decoding, scope/IDs and baseline digest, then roundtrips the
existing sparse/LZ4/grouped codecs and lists changed fields. Supply the prepared
model using `-collection:sample=BUILD/replay/project/shared`. It enables no new codec.
