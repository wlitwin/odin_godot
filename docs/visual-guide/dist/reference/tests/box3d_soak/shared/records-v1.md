# Gate B shared records v1

Test-only protocol, plain JSON lines. Events are `GATE_B_META`,
`GATE_B_SAMPLE`, `GATE_B_RESULT`; every record has `schema:1` and the SAME
nonempty `run_id`. One stream contains one framework/fixture/mode/build only.
No timing job is authorized merely by this document. Root grants exclusivity.

## META (once, first)

Required keys:

- `framework`: `kit` or `replay`.
- `timing_mode`: `functional_only` or `profile`.
- `fixture`: `{id,profile_hex,descriptor_sha256,initial_dynamic,reference_peak}`.
  IDs are exactly `dense32_boxes_extra_sphere` / profile `504859534e455431`
  and `common32_spheres_crates_extra_capsule` / `534c494345503031`.
  `initial_dynamic=32`. Reference peaks are respectively
  `{bodies:35,shapes:35,contacts:141,joints:1}` and
  `{bodies:35,shapes:35,contacts:122,joints:1}`. These are labelled historical
  references, not fabricated measured sample counts. Descriptor hash binds the
  actual geometry, placement, hinge, damping, input/action schedule and seed.
- `execution`: `{core,ownership,native_linkage,transport,native_images}`.
  `core`: `actual_godot_core`, `registry_fake_core`, or `none`;
  `ownership`: `sdk_meter` or `nil_owner`; linkage `shared_dso` or
  `static_diagnostic`; transport `offline_public_packets` or `actual_enet`.
  Final CPU candidate eligibility requires actual Core + SDK Meter + one shared
  native image. Fake-Core and nilOwner remain separate diagnostic groups.
  Offline public serialized packet CPU fixtures do NOT prove live ENet soak.
- `identity`: `{os,arch,configuration,godot,source_manifest_sha256,
  core_binary_sha256,script_binary_sha256,native_binary_sha256,
  native_build_sha256,native_target_sha256}`. All hashes are64 lowercase
  hex/nonzero. Use exact artifacts, not caller labels. Configuration is explicit.
- `limits`: `{normal_ns:4000000,repair8_ns:4000000,hz:60,substeps:4,
  history:128,prediction:8,ordinary_repair:8,bodies:35,shapes:35,contacts:147,
  joints:1,tracked_bytes:67108864}`. Timers are acceptance observations only.
- `boundary`: `{id,receiver_entry,clock_domain,clock_resolution_ns,
  included_work,excluded_work,source_refs}`.
  Full ID `core_public_ingress_v1`; lower diagnostic ID `lower_diagnostic_v1`.
  Full receiver entries: `session_frame`, `link_pump_then_client_pump`,
  `session_dispatch_then_lane_frame`. `client_pump_only` is lower-boundary
  diagnostic if input already bypassed Link dispatch/reassembly.
  The two additive normal-only entries below require their exact declared kind;
  they are never full repair8 boundaries.
  `clock_domain=godot_ticks_usec`, `clock_resolution_ns=1000` for actual Core.
  Source refs are `{path,symbol,sha256}` for the test method and required public
  pipeline entries. Composite C internals are source-audited coverage, not
  individually timed phases unless an actual existing timing hook measures them.
- `sample_plan`: `{normal:N,repair8:M}` exact timed counts, fixed BEFORE run.
  Functional-only uses both0. A complete CPU candidate needs both positive.

`included_work` lists actual coverage, using these exact names:

Normal: `public_dispatch`, `normal_step_capture_admission`,
`required_serialization`, `publication_events`, `operation_cleanup`, `core_return`.

Repair8: `public_dispatch`, `envelope_reassembly_inspect`,
`canonical_native_read_build_verify_reencode`, `typed_decode`,
`accepted_input_replay`, `complete_paired_compare`, `publication_events`,
`operation_cleanup`, `core_return`.

Kit ordinary wire-v2 repair is selected only by META `framework:"kit"` and
`descriptor.wire_revision` with integer value2. Its repair8 coverage replaces
`canonical_native_read_build_verify_reencode` with
`canonical_five_part_signature_verification`; every other required operation
above remains inside the whole call. The descriptor must explicitly declare
`native_recovery_read_in_operation:false`. Native recovery-read coverage is
forbidden under this ordinary signature-repair branch.

Each such SAMPLE supplies integer `accepted_packets:1`, `signature_packets:1`,
`signatures_before`, `signatures_after`, `full_states_before`, `full_states_after`.
Matched-signature delta must be1; full-state receives must stay unchanged from
an actual bootstrap count of at least1. `counter_kind:"model_step_callback"`
identifies the observed `actual_steps_*` delta8; it is not a Native engine-step
counter. All prior complete-five-part equality/hash, publication, tick, quota,
cleanup, source/binary, outer-clock and4ms rules remain unchanged. No absent,
wire1, differently typed/versioned or Replay metadata selects this branch.
`sample_findings(sample, meta=None)` preserves legacy requirements by default;
the analyzer passes the stream's actual validated META explicitly.

Use the union of ONLY the predeclared sample_plan operations in META.
A normal0/repair8-positive probe must not fabricate normal work; its overall CPU
candidate remains INCOMPLETE without normal coverage. Functional-only zero-sample
META declares the actual complete functional pipeline (normal or repair8), not an
unused union. Actual operation-specific coverage is repeated in SAMPLE.
Missing required coverage makes CPU acceptance INCOMPLETE, not a faster pass.
Exclude only declared `network_wait`, `render`, `diagnostic_output` and
`diagnostic_resource_read`. Mandatory validation/comparison/cleanup cannot be
relabelled diagnostic. Reference/input preparation is source-described; actual
receiver dispatch, canonical validation and required paired comparison remain
inside the timed operation.

## Full boundary without a production hook

A test-only GDScript caller reads `Time.get_ticks_usec()` immediately BEFORE
`node.call(test_method)` and immediately AFTER it returns. This includes Core
entry, typed producer work, operation cleanup and the entire return through Core.
The method must contain the public ingress path and required work above. Read
phase/result diagnostics in a SEPARATE method and serialize/write them after the
outer timer. No renderer, JSON, printf or file capture inside the timed method.
Do not move required cleanup or comparison into the diagnostic method.

## SAMPLE (profile mode only)

Required keys:

- `seq`: consecutive1..N; `operation`: `normal` or `repair8`.
- `epoch,base_tick,head_before,head_after,confirmed_before,confirmed_after`.
  `base_tick` is the predecessor BEFORE the first replayed tick. For repair8,
  `head_before-base_tick==8`; no from-tick inclusive/exclusive ambiguity.
- `requested_depth`:0 for normal,8 for repair8.
- `actual_steps_before,actual_steps_after`: operation-local observed step
  counter values, not a literal copied from requested_depth. Normal delta1;
  repair8 delta8. Any failed/short/noop attempt remains recorded and cannot be
  silently discarded as an ineligible fast success. The additive normal-only
  invariant below instead requires both fields explicitly `null` (unavailable),
  with no invented native/replay counter. Default counter semantics, including
  every existing repair8 stream, remain unchanged.
- `outcome`: `committed`, `rejected`, `hold_resync`, or `error`.
- `outer_start_us,outer_end_us,whole_ns` with
  `whole_ns==(outer_end_us-outer_start_us)*1000` and whole_ns>0.
  Normal requires head_after=head_before+1. Reference repair8 requires
  head_after=head_before, confirmed_before=base_tick and
  confirmed_after=head_before. Both before/after confirmation<=head and
  head-confirmed<=8. Failed/short/noop records remain raw and fail acceptance.
- `included_work`: actual operation coverage names above.
- `proof`: `{full_state_equal,publication_atomic,quota_ok,
  expected_complete_sha256,actual_complete_sha256}`. Equality refers to ALL
  Solver/Game/Side/Observations/Occurrences. Equal motion hash is insufficient.
  Hashes bind actual complete data; source describes the byte comparison.
- `counts`: actual observed `{bodies,shapes,contacts,joints}`. State if observations
  include candidates vs only published worlds in optional `counts_scope`.
- `ledger`: actual `{live_bytes,reserved_bytes,admitted_bytes,limit_bytes,
  committed_peak_bytes,storage_bytes}`. Require live+reserved=admitted and the
  unchanged64MiB cap. The peak is the combined ledger's observed highwater,
  not a sum of unrelated component peaks. SourceQuota/Meter paths remain active.
- `phases`: array of optional measured spans (empty is honest):
  `{name,duration_ns,clock_domain,start_us,end_us,relation}`. Same-Godot-clock
  spans may include absolute start/end and must fit outer bounds. Odin/native
  durations with another origin use `start_us:null,end_us:null`, labelled
  clock_domain and relation such as `nested_in_canonical_decode`.
  NEVER subtract cross-clock origins or sum nested timings into whole_ns.
  Existing profile callback durations may be emitted as operation-local spans;
  repeated names are allowed and retained, not averaged away before analysis.
- Optional `rss_sampled_bytes` / `rss_process_peak_bytes`, with actual source/unit
  identified in META. Sampled RSS is not an unsampled staging peak or64MiB claim.

All raw samples, including cold and over-target values, stay in input/output.
Nearest-rank p50/p95 and actual maximum are computed per exact stream/category;
there is no outlier discard or sum of marginal percentiles. The4ms candidate
ceiling is checked against EACH whole eligible call, never core-only timings.

## Additive normal-only streams

These two categories use separate descriptors, record streams and percentiles:

| Fixed `META.normal_kind` | Required `boundary.receiver_entry` |
| --- | --- |
| `client_prediction_send` | `link_pump_then_client_step` |
| `authority_step_requested_canonical` | `server_step_then_requested_snapshot_pump` |

Both require `META.step_observation="committed_tick_require_step"`.
Profile mode declares exactly `{normal:19,repair8:0}`; functional-only declares
`{normal:0,repair8:0}` and emits no SAMPLE or new timing reads. Each SAMPLE repeats
the identical `normal_kind` and `step_observation`, has `operation="normal"` and
`requested_depth=0`, and includes these additional `proof` fields:

```json
{
  "successful_public_step": true,
  "external_require_step": true,
  "committed_tick_before": 159,
  "committed_tick_after": 160
}
```

`actual_steps_before` and `actual_steps_after` are mandatory **null** values in
these streams. The proof uses actual published tick observations and the
successful public step under an enabled `External.require_step` contract; it
does not claim an independent native/global/replayed-tick counter. Proof ticks
must match `head_before/head_after`, advance exactly one tick and have
`base_tick=head_before`. Client prediction leaves confirmation unchanged;
authority work starts and ends with `confirmed=head`. The usual eight-tick
unconfirmed window, all full-state/quota/atomicity proofs and cleanup remain hard.
False step-success/require-step flags, no-op/extra ticks, errors and over-target
samples remain retained failures. Mixing kinds or repair8 into either stream,
using the new entries without their declared kind, or inventing counter values
is rejected. Legacy streams without these fields retain their existing rules.

Human source review is mandatory before interpreting these records as CPU
evidence: verify the actual `ph.step` path, enabled provider `require_step`,
failure propagation before publication, actual outer Core return, all required
serialization/ownership work and independent full-five-part reference. Bind the
relevant test/provider/public-step sources in `boundary.source_refs` and the
existing compiled/runtime artifact map. Boolean record claims alone do not prove
that source contract. A client normal includes its real INPUT serialization/send;
it does not invent a per-prediction canonical solver export. The authority entry
is the explicitly declared offline step plus correlated public-request canonical
egress composite, not a claim about live snapshot cadence or ENet throughput.

All `NORMAL_WORK` coverage, including `required_serialization`, still applies in
profile and functional mode. No mandatory work may move outside the outer timer.
Normal19/repair0 remains overall CPU-candidate **INCOMPLETE** for missing repair
coverage even if all19 calls meet4ms. Per-stream raw/p50/p95/max and each-call4ms
failures remain visible. Never pool the two normal categories or relabel them as
the dense repair8/common live-scene/long-soak gate.

## RESULT (once, last)

Required keys: `sample_count`, `functional_operations`, `correctness_ok`,
`source_fence_unchanged`, `binary_fence_unchanged`, `cleanup`.

Cleanup is actual `{native_live_bytes,snapshot_live_bytes,host_application_live_bytes,
all_explicit_drops_ok,core_shutdown_clean,ownership_evidence}`.
`ownership_evidence` names direct counters OR checked explicit drops + Meter0;
never invent a direct owner count. Include actual available owner/callback/mark
counts separately. Stable Core/ledger storage is separately labelled and is not
pretended to be application bytes0. Query failures/missing counters cannot become
synthetic zero. Root retains process natural exits and shutdown logs.

Functional-only mode emits NO SAMPLE and performs NO added profile clock reads.
Use RESULT sample_count0 and actual functional_operations count/proofs. Existing
runtime delivery/diagnostic clocks remain unchanged. Functional success returns
NOT_MEASURED timing status, never0ns or CPU acceptance.

## Optional Native observer records

Legacy records without `META.native_observer` keep their rules. This opt-in is
TEST-RECORDS only; it does not authorize a timing run or change game outcomes.
`META.native_observer` has these exact fields:

```text
abi_version:1, mode:off|structure_only|timed,
block_bytes:49392, span_bytes:48, capacity:1024, stack_capacity:16,
phase_mask:4095, clock_domain:godot_ticks_usec,
native_static_bytes:48, binding_control_bytes:32, clock_binding_static_bytes:24,
meter_context_bytes:219928, overhead:inside_whole,
native_status_names:{...}, source_phase_map:[{phase,name,path,symbol,sha256},...]
```

The three static/control/cache sizes are explicitly labelled instrumentation
storage, not successful Native allocation requests. Actual Meter context/block
allocation remains charged once; source audit verifies the exact leases and
global resource ledger. Fields are not permission to hide or double-count memory.
Status keys are decimal strings:0..7 map to the exact C names `OGB3_OK`,
`OGB3_INVALID_ARGUMENT`, `OGB3_INVALID_HANDLE`, `OGB3_OUT_OF_MEMORY`,
`OGB3_CAPACITY`, `OGB3_UNSUPPORTED`, `OGB3_INCOMPATIBLE`, `OGB3_CORRUPT`;
`-2147483648` is `UNAVAILABLE`, never fake success0.

The sorted12-entry source map binds phases1..12 and their names below to the
actual hashed C source sites. Every path/hash must also occur in ordinary
`boundary.source_refs`, so existing artifact-map verification binds it. Symbol
placement remains subject to actual source review. Initial mask4095 excludes
separately proposed phases13..15; no silent extra selection.

| IDs | Names |
| --- | --- |
|1|`native.step.fixed`|
|2..6|`native.snapshot.capture`, `native.snapshot.serialize`, `native.snapshot.normalize`, `native.snapshot.finalize`, `native.snapshot.validate`|
|7|`native.admission.world`|
|8..12|`native.recovery.read`, `native.recovery.parse_validate`, `native.recovery.build`, `native.recovery.verify_reencode`, `native.recovery.write`|

Mode timed requires profile mode and a nonempty top-level `META.exclusive_grant`
containing the ACTUAL Root grant label. A label alone never self-authorizes a run.
Functional-only allows off/structure_only, no SAMPLE, no added clock/prewarm.

### Raw SAMPLE and derived phases

`SAMPLE.native_observation` is the CLOSED actual C block header, exact fields:

```text
abi_version,struct_bytes,mode,capacity,count,stack_depth,error_flags,state,
scope_token,domain_cookie,next_span_id,root_count,clock_reads,clock_errors,
overflow_count,nesting_errors,last_clock_us,phase_mask,stack,spans
```

Header values use their actual u32/u64 integer ranges, never JSON doubles/bools.
stack is exactly16 u64s. spans contains exactly count written slots (<=1024),
each with EXACTLY seven keys:

```text
id,parent_id,root_ordinal,phase,native_status,start_us,end_us
```

No status-name strings or extra keys occur in raw spans. Span IDs are contiguous
BEGIN ordinals; parent is0 or an earlier recorded ID; roots are counted/ordered
and inherited by children. Closed state is2, mode2 for timed SAMPLE, ABI1 and
struct_bytes49392. Valid closed stacks are allzero; next_span_id=count+1;
clock_reads=2*count in a valid timed record, with last_clock_us matching the last
actual boundary. Empty selection, unknown status, invalid state/mode/IDs/parents/
roots or clock/nesting/overflow errors are observation failures.

For valid observations every raw span has ONE derived entry in SAMPLE.phases,
with ordinary phase fields plus EXACT extras `native_span_id`,
`native_parent_id`, `native_root_ordinal`, `native_phase`, `native_status`.
Name is the fixed mapped name, relation=`native_nested_in_whole`, same-Godot
absolute start/end and duration_ns=(end_us-start_us)*1000. Parents/children/whole
intervals must contain one another; root intervals are sequential. No sums,
subtractions, residual claims, rewritten statuses or overhead correction.

**Narrow failed-observation encoding:** actual nonzero raw error_flags,
clock_errors, overflow_count, nesting_errors or stack_depth may instead have ZERO
Native-derived entries. Keep ALL raw header/stack/spans EXACTLY, and retain other
existing phases. This avoids unsigned-wrap/negative/fake0 valid durations after
a clock failure. It STILL fails observation acceptance; actual game outcome,
state/proof and resources remain separately recorded. A bad model outcome alone
does not permit omission; valid error-free observations always require one-for-one
derivation. Never forge CLOSED or erase an error to make a sample eligible.

### Functional and final untimed result

`RESULT.native_clock_prewarm_calls` is0 for functional off/structure and1 for the
explicit timed profile setup. Functional off has `RESULT.native_observation:null`.
Structure-only has the exact closed raw block with mode1, clock_reads0,
last_clock_us0 and all raw times0 labelled UNAVAILABLE; no timing SAMPLE.
Optional `RESULT.native_functional_scopes` retains at most20 such raw structure
blocks before reuse. Any aggregate `native_observation_summary` is diagnostic
only and cannot replace those raw entries.

For the rolling19 profile, META.mode timed describes ONLY19 timed SAMPLEs at
heads8..152. Final160 remains an UNTImed oracle: RESULT.native_observation is its
closed structure block (mode1/no callback reads), with profile prewarm count1.
There is no synthetic SAMPLE160 and no pretend timed final block. Errors in a
functional/final block are hard observation failures, not a faster game result.

The shared analyzer reports CPU candidate PASS/FAIL/INCOMPLETE/DIAGNOSTIC_ONLY.
It NEVER declares the whole Gate B passed: long two-process ENet correctness,
impairment/recovery schedule, rolling evidence, memory/RSS and Root review remain
separate mandatory requirements. P5 remains blocked until Root's explicit Gate B.
