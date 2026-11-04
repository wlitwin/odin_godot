# Prospective LONG policy classifier

`long_policy.py` is a pure, read-only classifier, not a launcher or a replacement
rolling store. Root must review/integrate/freeze the complete future plan before
execution. `run.py`, `rolling.py`, `records.py`, the short checker and all old
reports remain unchanged. A result here never establishes CPU/Gate B/P5.

## API

```python
plan = make_plan(
    run_id="fresh-run-id", framework="replay", target_tick=36600,
    source_hashes={"host": compiled_source_sha, "client": compiled_source_sha},
    rolling_budget_bytes=6144 * 1024**2,
    event_budget_bytes=512 * 1024**2,
    log_budget_bytes=128 * 1024**2,
    epoch=1,
    execution=dict(seed=17, required_ticks=36000, minimum_wall_seconds=600.0,
                   timeout_seconds=900.0, latency_ms=0, jitter_ms=0,
                   loss_percent=0, duplicate_percent=0, reorder=False,
                   lifecycle="primary_pair_only_separate_cases_required"),
    replay_rule_oracle=dict(path="/frozen/oracle-values-v1.json", sha256=oracle_sha),
)
digest = plan_digest(plan)
report = classify(plan, EvidenceBundle(
    report=Artifact(closed_report_path, report_sha),
    events=Artifact(closed_observations_sqlite, event_sha),
    store=Artifact(closed_rolling_sqlite, store_sha),
))
```

No output file is written by `classify`. It opens immutable read-only SQLite
inputs, verifies hashes/chains and produces a returned report. Inputs must be
closed/finalized, with no running writer. Artifact/hash/context errors fail;
unavailable timestamps or required observations produce INCOMPLETE. Hashes bind
local artifacts, not authentication of an arbitrary remote producer.

`execution` is a REQUIRED keyword payload with exactly the shown keys. It binds
actual seed, requested tick/wall duration, timeout, five impairment settings and
the primary-pair lifecycle scope. The module compares the closed `report.plan`
CLI fields/budgets to these values, and checks actual READY consumed request/
effective/channel settings. Kit's actual READY seed is required and its oracle
reference must be None. Replay REQUIRES the exact `replay_rule_oracle={path,
sha256}` reference in its plan. There is no constant-true or caller flag waiver.

`load_replay_rule_oracle(plan, verified_source_manifest, native_metadata=None)`
is the pure prelaunch verifier. Root first verifies that source manifest against
the compiled build/plan role hashes, then calls this with the frozen deployed
`box3d-runtime.json` as native_metadata. The classifier repeats verification
against that compiled/frozen metadata and actual public signatures. Missing
evidence is INCOMPLETE; mismatches fail. It performs no Native or other runtime
call.

The first descriptor is APPLICATION rules only: domain
`odin-godot.replay-box3d-slice.v1`, sorted adapter/common/launch fields, bound
SHA256 of `examples/replay_box3d/shared/adapter/model.odin` and
`examples/box3d_common/rules.odin`, and LEu32(32)||LEu32(seed). READY is a SECOND
bound digest, domain `odin-godot.replay.physics-rules.v1`, sorted fields
`application`, `provider_schema`, `provider_values`. The schema/value bytes come
from the actual public CodecInit/Schema.canonical/sc.encode oracle, never private
Game/Config layout guesses. `expected_replay_rules` returns only the application
digest and MUST NOT be compared directly with READY.

The loader verifies the referenced JSON, all five byte files' hashes/lengths,
build binding, compiler/executable/archive/manifest/source references, actual
public report statuses and cleanup. It recomputes BOTH descriptors and compares
raw bound bytes, metadata and both actual READY.game_rules. Actual oracle source
hashes must match the selected compiled sources, including network_codec.odin
and descriptor.odin. Human source review still binds the formula; there is no
current-tree substitution or CLI-only seed echo.

`validate_oracle_signature(proof, sig)` additionally binds solver/recovery format,
profile and the actual public signature identity's build_target40:72,
assets72:104 and solver_schema104:136. Frozen runtime build/target must match the
oracle before launch. Thus preserved9c66 parity proof cannot qualify a newly
selected Native build: generate/freeze a fresh public oracle for it. Saved oracle
verification never reclassifies an old case as PASS. No new production metadata,
private Game decoding, short/less impaired substitution or new gameplay clock.

The fixed descriptor is `long_recovery_cycle_coverage_v1`: origin0, period240,
Spawn40/Remove56/Motor80/Sleep120/Wake136/Query160; initial32/H128/8/64MiB;
minimum36000 ticks after actual admission and600 observed seconds after both GO;
at least120 complete verified cycles AND80% of ALL wholly scheduled cycles;
at least60 consecutive complete verified cycles after the final qualified gap.
Max8 recovery transitions, each gap<=128 ticks, union<=1024, latest gap end no
later than admission+3600. Each same-follower observation interval is<=5s.
Changing those constants requires a separately approved policy/version.

Evidence disk budgets are finite and explicit. They are CONTROL storage, not
Native's64MiB requested-byte quota. File/archive/export/log exhaustion fails;
there is no silent eviction or discarded old ID. The module's finite event,
frame, selected-byte, action, missing-key and cycle bounds are part of the plan.

## Required prospective adapter binding (not implemented by this module)

Root's future launcher must append the FIRST archive record before launching
actors, with role `controller`, kind `LONG_POLICY`, and this exact body:

```python
binding = dict(policy_id=POLICY_ID, policy_sha256=plan_digest(plan),
               run_id=plan["run_id"], marker_event_id=1, prelaunch=True)
```

The closed run report must contain `long_policy=binding`. This metadata does not
inject state or read a new clock. `observed_at=None` is appropriate for this
controller marker. Neither old reports nor copied saved logs may be retrofitted
with it: absent exact prospective binding means INCOMPLETE and can NEVER create
a new PASS for a historical case. Root's artifact/grant/source audit establishes
that the trusted launcher created the binding before execution.

The report also retains the existing compiled-build path/hash, source/driver
fences, observation/rolling database links and hashes, receipt chain, natural
exits/cleanup and raw strict rolling summary. `compiled_build` must bind actual
successful source-manifest/framework data. A source hash label alone is not a
compiled-build proof. Actual Core/one-DSO/SDK/fixture provenance remains a required
Root source/build review, not something an event boolean can certify.

## Archive time and recovery evidence

`events.observed_at` is the Actor's EXISTING record-read timestamp, normalized
float or None, separately bound in the chain. Raw body bytes/values do not gain
invented timestamps. Archive ID is controller CONSUMPTION order, not synchronized
cross-PID arrival. Per-role record order and timestamps govern recovery bounds.

Replay gaps require canonical-Welcome cause, advancing serial/baseline,
view-reset plus resync/catchup evidence, with a connected chain from admission.
Use `(old_head,new_baseline]`. Kit requires its paired preserved public request,
validated recovered signature/watermark, and uses actual previous-confirmed.
No ordinary same-serial catchup or unspecified history loss creates a gap.

Each qualified marker links the last actual preceding follower FRAME and the
first actual matched frame of that recovered baseline/new-head range before
another recovery. Duration is from that preceding FRAME's actual observation
to the matching post-recovery FRAME's observation. Label it an **observation
interval**, never transport latency. Missing time/link is INCOMPLETE; regression,
>5s, invented interval or overlap with previously confirmed state fails.

## Exact missing-only guard

`guard_raw_strict(raw_summary, exact_classification)` returns only
`ALLOW_MISSING_ONLY_CLASSIFICATION` or FAIL. It is NEVER an overall pass.
`exact_classification` contains independently enumerated `raw_missing_fx` and
`raw_missing_decisions` key arrays, plus `classified_fx`/`classified_decisions`.
Each classified row has the exact key, authority body hash/immutable raw link,
disposition `UNOBSERVED_PAST`, actual qualified `gap_ids`, and
`previously_settled=False`. `classify` derives this from the RO store; a caller
must not invent classification rows to match scalar counts.

Unique sets AND counts must reconcile exactly. The ONLY allowed raw findings
are the applicable missing-only strings `actual settled FX missing/payload
mismatch` and `actual decision/provenance missing/mismatch`, with changed/extra,
unmatched-required-frame/final-tail and every other integrity violation zero.
Unknown findings, first divergence, controller fatal errors, actual changed/extra
rows or missing outside-gap keys fail. Raw result/findings remain visible and
unchanged, including raw strict FAIL. All authority missing keys/bodies remain
in the original bounded store, never labelled matched or delivered.

## Intents, cycles and remaining hard obligations

The independent intent path keeps current sample/submission8 bounds,
sampled_head+1, unique immutable epoch/seat/sequence, exact authority kind/scope,
Scheduled target semantics, Receipt contract/schema/rules/reason identity and
per-seat FIFO. Kit MUST pass the existing pure `verify_kit_intent_catalog`,
including candidate publication and full reset-chain proofs. LocalRing/send is
not authority admission. A previously issued action is never retargeted.

Join cycles by original due/phase modulo240, not received tick. A complete cycle
is `[original_spawn_due-1, original_spawn_due+239]`; incomplete final cycles do
not enter its denominator. Every WHOLLY scheduled cycle enters the denominator,
including recovery-interrupted/unexercised cycles. A verified cycle has intact
admission/observations, no intersecting gap, real same-original-cycle Spawn pair,
one success then one Predicate rejection, no intervening successful Remove or
replacement Spawn,
all six successful action kinds in that SAME cycle, complete provenance and
full-state boundary evidence. No first-cycle short-checker behavior changes.

The LONG pair helper uses the common ORIGINAL due, not a shared execution tick.
For Scheduled actions, each authority decision must equal its own immutable
submitted target. Thus original-due40 with actual40 success and actual41
Predicate rejection may count when both independent sample/submission windows
and all other proofs pass. Different actual ticks remain within that same
original cycle. Equal actual ticks retain semantic seat1-before-seat2 order and
seat1 success/seat2 rejection. Receipt actions retain their existing separate
authority receipt ticks; neither policy rewrites issued targets.

Intervening state changes are checked in immutable authority event order,
including a Remove/replacement at either Spawn's actual tick. A successful
Remove before both verdicts or after both is not an intervening change, and a
rejected Remove cannot clear the slot. The fixture has exactly one extra-body
slot: two successful Spawns without an intervening successful Remove are a hard
model finding across the entire recorded authority stream, including cycles
already interrupted by a qualified gap. They cannot become merely ineligible
coverage. Two successes separated by a real Remove are possible state changes,
but do not establish the required contested pair. All denominator, suffix,
immutable issue-join and raw strict-result rules remain unchanged.

All actual follower exports remain hard-required and tied to sealed original
BYTE-comparison receipts. Full authority raw references remain retained; no new
follower image is manufactured from canonical authority bytes after retirement.
Initial32/native caps/global ledger, final authenticated remote ACK, final
matched tail, actual natural exits and successful zero-owner cleanup remain
required. Already settled FX IDs never disappear; skipped-past cosmetics cannot
newly start after reset. Actual in-gap data still remains in the raw ledger.

`PROSPECTIVE_LONG_COVERAGE_PASS` describes only this explicitly predeclared
coverage layer. Raw findings, known short/impaired/Kit-input failures,
whole4ms/dense-common CPU evidence, resource/RSS/staging/lifecycle obligations
and the sibling framework still require their own explicit results. This module
cannot finish Root's card or authorize P5.

## Pure controls

Run only the dedicated file:

```sh
python3 -B -m unittest discover -s tests/box3d_soak/controller -p test_long_policy.py -v
```

Fixtures use synthetic JSON/SQLite/clock values, never Native/Godot/processes.
They establish validator behavior, not a real long run or physical correctness.
The 23 groups include delayed Scheduled targets, equal-tick semantic ordering,
same-tick intervening Remove/replacement, impossible double success even in an
interrupted cycle, and the previous source/sequence/gap/density/final-tail/raw
strict guards. The pre-correction module SHA
`96425e00e1b0027e1e2d2e0c122a093d4d469eca4ba3f0de87b3b3b6f30c6ab2`
and its original report are retained in the stage directory
`box3d-gate-b-shared/long-policy-pre-pair-correction-v1/`. No saved case is
reclassified by this correction; Root must freeze a prospective plan before a
future execution.
