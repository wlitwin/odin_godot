# Rolling evidence API v1 (early contract)

Pure Python/controller storage, not a simulation/runtime API. Root owns process
launch, parsing, schedule and acceptance. No actor timing or Native calls here.
Implementation module: `tests/box3d_soak/shared/rolling.py` (in progress).

```python
from rolling import RollingConfig, RollingStore, ProcessScope, FrameRef, StoreOutcome

cfg = RollingConfig(
    directory=Path(...),
    authority_role='host', follower_roles=('client',),
    allowed_sources={'host': ('<source-manifest-sha>',),
                     'client': ('<source-manifest-sha>',)},
    expected_identity_hex=None,  # bind ONCE from first registered authority sig
    max_hot_frames=256,          # declared per-role active raw-frame bound
    disk_budget_bytes=...,      # finite, includes declared SQLite staging reserve
    mismatch_reserve_bytes=6*1024*1024,
    segment_target_bytes=1024*1024,
    raw_policy='canonical_archive',  # or explicit 'receipts_only' in strict mode
    frame_policy='all_exports_required',  # DEFAULT unchanged
    decision_coverage='all_registered',   # DEFAULT unchanged
    max_context_bytes=1024*1024,
)
store = RollingStore(cfg)  # new directory only; config immutable thereafter

scope = ProcessScope(role='client', scope_id='client-g2-p1234', pid=1234,
    source_sha256='<allowed-source-sha>', epoch=1, baseline_tick=143)
store.register_process(scope) -> None
```

Scopes come from actual launch/READY, including process generation, and cannot
silently change source or identity. Allowed source versions are predeclared;
no wildcard source updates. A new source needs an explicit new configured run.
Identity is the FULL diagnostics signature identity bytes, not just profile.
If identity is initially None, a follower cannot bind it before the authority.

## Existing Frame reuse

```python
outcome = store.register_frame(role, scope_id, frame, context=...)
```

`frame` reuses `tests/box3d_slices/harness/evidence.py` Frame as-is: `.epoch`,
`.tick`, `.sig`480bytes and `.parts()` returning all5 full byte strings. A duck
compatible Frame is fine. No duplicate canonical Game/occurrence codec.

Context is a plain mapping with `from_tick,to_tick,depth,source,sequence,
sequence_available,accepted_inputs:bytes,predicted_inputs:bytes,provenance:dict`.
Supply real observed repair context; out-of-band confirmed comparison uses
from=to=tick/depth0 and explicit unavailable sequence. Bound context bytes.

Registration immediately validates signature/version/lengths/all5part hashes,
copies data into bounded storage and returns `StoreOutcome`. It does not trust
paths after registration. FrameRef is `{role,scope_id,epoch,tick}`. Duplicate
same-scope/frame is idempotent only if full immutable bytes agree; mutation is a
preserved first divergence. Unsigned/raw pointer-bearing images are never input.

```python
store.compare_and_seal(frame_ref) -> StoreOutcome
store.retire(frame_ref) -> StoreOutcome
```

For follower frame, compare against actual authority same identity/epoch/tick.
For authority frame, compare all registered follower scopes with that frame.
The store uses exact all5 byte equality before appending/hash-chaining a complete
comparison receipt. Hash equality alone is not a new full-byte comparison.
Receipts bind actual process/source scope, signature, part lengths/hashes and
comparison context. `retire` succeeds only for already compared/sealed required
frames. Unmatched required retirement returns HOLD/raises EvidenceHold; it never
silently evicts. Reaching max_hot_frames with required unmatched data is HOLD.

`canonical_archive` retains ONE compressed canonical full5part copy after match,
allowing a later generation to compare against older authority bytes. Root can
choose `receipts_only`: raw bytes may retire after seal, but late comparison
without reference bytes is HOLD, not a hash-only pass. Final coverage reports
sealed receipts vs independently retained raw bytes explicitly.

## Actual observations, no second journal

```python
store.record_fx(role, scope_id, row) -> None
store.record_decision(role, scope_id, row) -> None
store.record_recovery(role, scope_id, row) -> None
store.register_exit(role, scope_id, *, exit_code, last_epoch, last_confirmed,
                    cleanup) -> None
```

FX row is ACTUAL framework delivery with epoch/tick/source/key, phase,
confirmed and full payload. Existing short-harness phase rules are reused in
meaning, not replaced: Begin/Update/Cancel/Confirm or Kit confirmed commit.
The on-disk settlement ID/payload index spans the ENTIRE run/epoch and process
rejoins; late duplicate confirmation cannot escape at H128 or generation change.
New epoch may reuse numerical IDs without aliasing prior-epoch records.
Production journal_reset may Cancel a previously confirmed old-epoch visual;
allow that only with an actual recorded epoch-reset marker and unchanged payload,
while retaining its permanent settled-ID entry. A later confirmation still fails.

Decision row is actual accepted/provenance data, not ISSUED intent. Repeated
same logical decision must be identical; follower/authority comparisons are
recorded separately. Recovery marker retains actual baseline/epoch/sequence and
previous-confirmed evidence. It erases nothing and waives NO missing frame/FX
on its own. Root owns declared eligibility policy and expected-vs-delivered
reconciliation; this storage must not silently invent recovery exclusions.

Exit records require actual natural exit and real cleanup queries/checked drops.
Cleanup keys are `ok`, `native_live_bytes`, `snapshot_live_bytes`,
`host_application_live_bytes`, `all_explicit_drops_ok`, `core_shutdown_clean`;
missing fields cannot be synthetic zero. Process scope metadata is capped4096.
A confirmed visual Cancel needs recovery row `{kind:epoch_reset,old_epoch,epoch,
observed:true,basis:framework_epoch_reset}` for the SAME role/scope; no inferred
transport flush. Repeated Cancel and later Confirm still fail after settlement.
Frame baseline is inclusive for raw comparison; expected NEW follower effects
are strictly after its actual admitted baseline, matching existing Welcome
semantics. Authority baseline effects remain in the permanent actual ledger and
are explicitly reported outside that follower delivery coverage, never erased.
Recovery markers alone do not create additional exclusions.
Source scopes retain actual admitted baseline and final confirmed frontier, so
initial welcome/rejoin tails are not manufactured as old history.

## Returns and failure artifacts

`StoreOutcome`: `{state:'stored'|'matched'|'duplicate'|'retired'|'reference_archived'|'hold',
frames:tuple[FrameRef,...], receipt_ids:tuple[int,...], reason:str|None}`.
Errors are `EvidenceError`, `EvidenceHold`, `EvidenceDivergence`, `EvidenceBudget`.
First divergence is durably saved BEFORE throwing, with both complete5parts,
signatures, actual input windows/provenance/context. No later failure replaces it.
A reserved logical mismatch budget is separate from normal storage; no guarantee
against OS/disk hardware failure is implied.

```python
store.finalize() -> dict
store.export_receipts(directory) -> list[dict]  # bounded compressed segments
store.first_mismatch() -> dict | None  # decoded complete bytes/context, durable first failure
store.verify_chain() -> dict         # full append-chain recheck
store.close() -> None
```

Finalize reports actual counts, unresolved required frames, source/process exits,
cleanup, decisions, FX IDs/payload lifecycle, receipt-chain head and raw coverage.
Missing tail/exits/cleanup/unmatched required records yields FAIL/HOLD, never a
partial PASS. Root still owns final Gate B acceptance. Export is a versioned
copy of the durable receipt ledger; no overwrite or append to unrelated runs.

Disk policy is fixed before launch. Backend uses a bounded SQLite database:
one third of configured bytes for main DB, one third conservative rollback
staging, one third compressed receipt exports plus64KiB slack; first mismatch
reserve is withheld INSIDE main DB during normal writes. Defaults need enough
space for that6MiB reserve. Exports are single-use under the store directory.
Config also accepts smaller test-only max_frame_bytes/max_part_bytes bounds.
With explicit main/journal/first-mismatch/segment budgets; exhaustion rolls back
without publishing a receipt or retiring source data. No unbounded in-memory
frames/effects/status arrays. No actual soak/profiling job is part of this API.

## Explicit optional authority-reference policy (Root approved)

Root's live controller may predeclare:

```python
RollingConfig(...,
    frame_policy='all_follower_exports_required',
    raw_policy='canonical_archive',
    decision_coverage='after_admission_baseline')
```

Both defaults above remain strict/unchanged when omitted. The SAME register_frame
receives EVERY actual export. In the optional frame policy, authority rows are
references until used by a real follower export. Authority retirement copies or
retains the FULL canonical reference and appends an explicit non-comparison
receipt, returning `reference_archived`, never `matched`. No reference raw may be
lost; optional policy rejects receipts_only. A later follower export still must
compare ALL5 bytes against that retained authority reference.

The hot cap applies to required/unsealed follower rows in this mode; reference
raws are bounded by finite SQLite quota. Every follower row is hard-required,
including its actual final tail. Finalization checks actual tail records for
both authority and followers and matching complete receipts. Root separately
checks the predeclared target/duration; a shorter natural exit is not its gate.

Fresh stores include `frames_tick_lookup(epoch,tick,role,scope)` for authority
and follower lookups. Multiple follower scopes at one tick retain insertion
order for their comparison receipts. This changes lookup work, not the full
five-part validation/comparison or any receipt content.

In the optional policy only, `pending_required_frames(role,scope,epoch,tick)`
is an exact derived set of follower frames without comparison receipts. A new
follower frame and its pending key commit together. Its first complete match,
comparison receipt and removal of that exact pending key commit together.
Duplicate/already-matched calls cannot remove another key. Failed transactions
roll back both sides; unmatched follower retirement still HOLDs. The hot count
uses this bounded set rather than repeatedly visiting all retained history.
Matched-but-not-yet-retired frames are excluded without approximating them as
retired. Default `all_exports_required` retains its existing hot policy.

Finalization reconciles both directions against the original frames and matches
tables. Orphan/authority pending keys, matched keys left pending, unmatched
frames missing a pending key, or retired unmatched followers are hard findings.
The index never substitutes for raw bytes or complete comparison receipts. New
index/table pages consume the existing finite SQLite evidence quota. FULL
synchronous DELETE-journal durability, transaction boundaries, caps and all
retirement/ownership/FX/decision rules stay unchanged. This is a fresh-store
schema addition; no saved database/report is migrated or reclassified.

Pure controls use thousands of synthetic matched SQL rows, half retired and
half intentionally not yet retired, plus a small required hot set. Query-plan
and SQLite VM-opcode counts check indexed lookup and history-independent hot
count work, together with public duplicate/rollback/scope/cap/reconciliation
controls. They are not elapsed-time, Native CPU, runtime or soak evidence.

Finalize explicitly reports `frame_policy`, `authority_export_count`,
`unmatched_authority_references`, `authority_archived_reference_count`,
`required_follower_exports`, `required_follower_matches`, `unmatched_required_frames`,
`final_tail_missing`, raw retained counts and sealed comparison receipts.
Unrequested authority references are NOT renamed comparisons or silently dropped.
This is not an intersection-only pass: every actual follower export, tail,
eligible actual FX and provenance row remains mandatory.

The separate decision opt-in is based on observed saved keys [1,1,1,0] and
[1,1,2,0]: Host INPUT for tick1/seats1+2/controlclass0, at the follower's actual
Welcome baseline1. `after_admission_baseline` records those authority rows
permanently and reports `decision_outside_admission_count=2`; it does not
synthesize follower baseline inputs. All POST-baseline authority decisions and
controls remain hard-required; any observed baseline counterpart must still be
identical. Default all_registered still reports them missing. Neither optional
policy waives recovery gaps, erases old IDs, or changes the framework stream.
