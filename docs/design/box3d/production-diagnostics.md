# Production diagnostics

Kit and Replay share `box3d/diagnostics`; each framework retains its own Session,
authority, confirmation and recovery contracts. Diagnostics inspect evidence and
do not authorize a sender, advance simulation or replace a recovery mechanism.
The [frame/trace contract](network-diagnostics.md),
[Kit World2 contract](kit-world-protocol-v2.md),
[production validation](production-validation.md) and
[recovery hardening](recovery-hardening.md) define the underlying boundaries.
Earlier results in those documents retain their original build and phase scope.

## Bounded offline bundles

`tools/box3d_diagnostics.py` has three explicit actions. No action prints usage
and exits2. There is no implicit execution, environment/account capture, repository
copy, download, physics replay or automatic discovery of an inspector.

Select absolute input/output paths and obtain the inspector SHA-256 from a
trusted build record. The inspector is executable code; a digest supplied by an
untrusted bundle does not make it trusted. For example:

```sh
python3 tools/box3d_diagnostics.py collect \
  --framework kit --trace "$TRACE" \
  --inspector "$INSPECTOR" --inspector-sha256 "$INSPECTOR_SHA256" \
  --attachment "log:client=$CLIENT_LOG" \
  --attachment "build:profile=$BUILD_MANIFEST" \
  --attachment "source:identity=$SOURCE_MANIFEST" \
  --attachment "report:original=$ORIGINAL_REPORT" \
  --out "$NEW_BUNDLE"

python3 tools/box3d_diagnostics.py verify \
  --bundle "$NEW_BUNDLE" --manifest-sha256 "$TRUSTED_MANIFEST_SHA256"

python3 tools/box3d_diagnostics.py inspect \
  --bundle "$NEW_BUNDLE" --inspector "$INSPECTOR" \
  --inspector-sha256 "$INSPECTOR_SHA256" \
  --manifest-sha256 "$TRUSTED_MANIFEST_SHA256"
```

Use `--framework replay` for the sibling adapter. Attachment syntax is
`KIND:LABEL=ABS`, repeatable with kind `log|build|source|report|other`.
`--manifest-sha256` is optional on verify/inspect; an independently trusted pin
binds the selected manifest, rather than merely checking internal consistency.
The framework label is explicit context, not an authentication claim.

| Action | Work and result |
| --- | --- |
| `collect` | Bounds/checks explicit inputs, runs the pinned inspector, stages/verifies copies, then atomically publishes a **new** directory without replacing an existing bundle. Result `BUNDLE_COLLECTED`. |
| `verify` | Read-only manifest/file verification; launches no processes. Result `BUNDLE_VALID`. |
| `inspect` | Verifies the bundle and invokes only the explicitly pinned native-free inspector as `INSPECTOR TRACE_FILE`. Result `TRACE_INSPECTED`. |

Success exits0; rejection exits2. All success results retain
`run_verdict: NOT_INFERRED`: bundle validity is not a gameplay, test, recovery or
release verdict. Collection failure cleans its unpublished staging output and
never replaces an earlier bundle or edits original inputs. Symlinks, traversal,
duplicates, over-limit data, changed inputs and corrupt content are rejected.

Schema1 output contains `manifest.json`, exact `trace.bin`, labelled
`attachments/<kind>-<label>` files and exact `inspector.stdout`/`inspector.stderr`.
Fixed bounds are32 files,16MiB per file,64MiB aggregate,9MiB trace,256KiB manifest,
64KiB per inspector output stream and a30-second inspector timeout. No CLI option
raises those bounds. Retained reports are opaque original bytes: a FAIL stays
FAIL; an intentional-divergence case with `success:true` stays successful. The
tool does not normalize either into a new verdict.

## What a trace establishes

The existing [native-free inspector](../../../tests/box3d_protocol/inspect/main.odin)
bounds `trace_decode`, re-encodes the trace byte-for-byte, and prints
`BOX3D_TRACE_INSPECT_OK` only after both succeed. Its exit0 proves that inspection
contract. It loads no Native backend and performs no simulation.

A trace retains both compared frames, each containing Solver, Game, Side,
Observations and Occurrences, plus the accepted/predicted input window and
`Trace_Context` fields `from_tick`, `to_tick`, `source`, `sequence`, `depth`.
Identity binds format versions/profile and exact build-target, assets, solver,
game, observation and input schemas. Retain the corresponding source/model-rule
hashes, Native metadata/library hash, compiler/FP/SIMD configuration and target
record as labelled attachments. A current inspector can inspect an older valid
trace without making its physics compatible with the current runtime.

Inspection identifies retained differences and available context. Complete
gameplay reproduction additionally needs compatible runtime/model code, asset
catalog, a suitable preceding complete checkpoint, all required admitted inputs
and scope, and the existing framework's execution entry. A trace's two compared
frames and bounded window do not promise that entire reproduction set. Missing
context remains unavailable. Checksums/signatures detect integrity/divergence;
Session authority, peer, epoch and bootstrap checks remain separate obligations.

`Frame_View` borrows its part bytes. `Trace` owns one copied allocation after
successful capture/decode; assignment aliases that owner. The first captured
mismatch survives source-world teardown and later captures return
`Already_Captured`. Destroy it exactly once with `trace_destroy`; release encoded
buffers and `trace_text` with their declared allocators. Default trace limits are
1MiB/part,2MiB/frame,64KiB/input window; hard ceilings are2MiB,4MiB and256KiB.
The inspector uses those ceilings, not an unbounded parser.

Kit's `lane_world_network_trace` exposes a borrowed trace pointer. Its
`lane_world_diagnostic_frame` is an owning, confirmed-only five-part diagnostic
output with `world_diagnostic_frame_destroy`; it is not a recovery image.
Replay's complete views/checkpoints and first-desync trace likewise retain their
explicit owners. Charge copied diagnostic storage and temporary encode buffers
to the applicable allocator/budget; detached bytes do not erase ownership costs.

## Existing timing and operation observations

The [raw record contract](../../../tests/box3d_soak/shared/records.py) retains
`GATE_B_META` and `GATE_B_SAMPLE`: declared receiver entry/included work, operation,
epoch/base tick, head/confirmed before/after, requested depth, outcome,
`outer_start_us`, `outer_end_us`, `whole_ns`, phase durations and proof fields.
`whole_ns=(outer_end_us-outer_start_us)*1000`; these are elapsed wall durations,
not thread CPU time. Whole-call work includes dispatch, required processing,
publication/events, operation cleanup and Core return. Nested phases overlap
inclusive work and must not be added to the outer duration or subtracted to
improve its result. Keep rejected/held/error attempts and every raw outlier.

Normal entry variants carry actual committed-tick/required-step proof and may
explicitly have null model-step counters. Repair8 requires its declared depth and
observed model-step delta. Kit descriptor `wire_revision:2` ordinary repair uses
typed accepted replay plus canonical five-part signature comparison: one ACCEPTED,
one SIGNATURE, matched-signature delta1 and unchanged received-full-state count
after a real bootstrap. It does not claim a Native recovery read. Replay operation
coverage follows its own declared entry. Neither a phase sample nor a functional
soak independently certifies the complete whole-call boundary.

Replay's existing [runner profiling](../../../replay/net/profiling.md) exposes
`profile_clock`, bounded `profile_metrics` and optional `profile_sample`; values
are microseconds and callback overhead belongs to the measured scope. Production
diagnostics introduce no new profiler or timing clock.

The [Native observation ABI](../../../box3d/native/native_observe.h) is opt-in
test instrumentation, absent from ordinary builds. It defines OFF,
STRUCTURE_ONLY and TIMED modes; actual spans carry
`id/parent_id/root_ordinal/phase/native_status/start_us/end_us`. Selected phases
cover fixed step, snapshot work, admission, recovery parse/build/verify/write and
canonical validate/count/emit. Metadata must declare the selected map/mask;
absence is not a measured zero. Fixed1024-span/16-stack bounds and overflow,
clock/nesting/unclosed flags qualify attribution. Structure-only timestamps and
unavailable statuses must not be converted into invented timings or simulation
results. Observation overhead remains inside the declared whole-call scope.

## Live status, cached memory and terminal evidence

Authored samples expose the same public `status()` JSON and scripted
`SAMPLE_STATUS` schema1. Emission/resource sampling uses the existing roughly1Hz
process-delta cadence, plus a first real-GO row; it is not a wall-clock cadence
certification. Public frontier getters remain live when status is called.

| Fields | Meaning and availability |
| --- | --- |
| `framework/role/phase/go/frames/head/confirmed/epoch` | Actual adapter state and source-local callback frames; unavailable frontiers are null. Receipt of a status line is not a terminal ACK. |
| `native_observed/native_sampled_frame` | Cached ledger observation. Nullable `native_live_bytes`, `wrapper_live_bytes`, `host_live_bytes`, `reserved_bytes`, `admitted_bytes`, `limit_bytes`, `owner_count` belong to that sampled frame. |
| `meter_observed/meter_sampled_frame/meter_live_bytes` | Cached sample-category Meter observation, not a fresh UI read or a complete process heap measurement. It overlaps registered Host accounting; do not sum it into admission again. |
| `recovery_available/recoveries/recovery_serial/baseline` | Validated committed scope only. Kit uses its matched bootstrap signature; Replay also reports actual generation/epoch. A head jump or request does not manufacture a recovery. Host/invalid scope remains unavailable. |

Replay's `controls_by_seat`/`nonzero_by_seat` count actual retained committed
Timeline controls. Receipt-origin coverage is separate:
`origin_observed+origin_unavailable=accepted_rows`; Sample/Held/Local/Neutral are
counted only with corresponding matching typed receipt metadata. Explicit
`SAMPLE_INPUTS_UNAVAILABLE` spans add no control/origin counts and make input
coverage incomplete. A canonical-anchor exception requires the tested actual
catch-up/window/retained-frame-without-input gate; other missing reads remain
fatal with `SAMPLE_INPUT_AUDIT_MISSING` evidence. No origin is inferred from stamps.

Saved P6.2 Mac client logs contain1800 Kit/1799 Replay status rows. First-GO rows
have false observation flags and null cache frames/memory; later observations
record limit67108864 and owner_count4. Kit's last status is head/cf108600;
Replay's last logged status is108555/108551. Its terminal proof occurs later and
must not be replaced by that status row. These are existing saved observations,
not a new cadence/runtime qualification.

OS RSS/cgroup memory includes Godot heaps, script temp arenas, loaded images and
other process resources outside the tracked64MiB physics admission contract.
Read each ledger's units/scope; a flat Native/Meter sample does not prove flat
RSS or identify an OOM victim. Owner cleanup compares observed before/after
baselines, not an assumed global zero. Preserve raw exit status, teardown,
EOF/fsync/fences and external-stop sidecars: a controller bookkeeping flag alone
does not prove natural exit. Kit's verified `SAMPLE_ACK` and Replay's verified
`SAMPLE_TAIL` stages are distinct from sent messages or status frontiers.

## Evidence scope and retention

| Existing record | Scope retained |
| --- | --- |
| [P6.2 production](../../../tests/box3d_production/report.json) | Four supported exported long pairs, service pauses, resource/window/lifetime and explicitly scoped timing records; preserved failures and incomplete coverage labels remain. |
| [P6.3 bounds](../../../tests/box3d_bounds/report.json) | Bounded Native/Kit/Replay validation corpus and recorded SDK pairs; trusted factories and untrusted ingress remain distinct. |
| [P6.4 recovery](../../../tests/box3d_recovery_flows/report.json) | Current recovery/migration and SDK lifecycle evidence, including explicit zero-only Kit spectator policy and unsupported manual Replay Reset. |

Root's P6.5 native-free inspectors decoded/re-encoded both real historical
frozen-final P3.5 Kit/Replay mismatch traces on native macOS arm64 and translated
Linux x86_64. Those intentional-divergence case reports have `success:true`.
Separately retained Kit legacy-suite and Replay SDK-observer FAIL reports are
different attachments. Preserve each original verdict and identity exactly;
neither inspection nor collection requalifies old physics, resolves a preserved
failure, proves cross-target simulation equality or establishes a new PASS.
See [release policy](release.md) and the existing
[desktop compatibility](desktop-compatibility.md) contract for deployment scope.
