The runner builds normal authored Kit/Replay projects into fresh case directories
and starts two independent official Godot processes over actual ENet. It contains
no framework/session/simulation implementation and sends no solver truth. Initial
scope is the small four-dynamic-body common profile for at least240 ticks after
complete Welcome; the32-body envelope, impairments, observer/rejoin and Gate B
performance are separate later cases.

Run inside the existing Nix environment, using a verified current P4 Native DSO:

```sh
python3 tests/box3d_slices/run.py --framework kit --configuration Release \
  --out /absolute/new/evidence --native /absolute/current/libogb3.dylib \
  --godot /Applications/Godot.app/Contents/MacOS/Godot
```

Default `--framework both` runs Kit then Replay. Linux uses `.so` and the verified
official binary in the existing VM. Each project is copied with its common sibling
package; the existing SDK build/deployment/prepared-import helpers remain the only
build path. A source/binary/native/log inventory is retained. Source changes during
a case prevent acceptance. No runtime commands or gameplay data enter stdin.

Exit0 means the actual processes exited0, all observed matching confirmed five-part
frames agreed byte-for-byte, final shared confirmation reached at least baseline+
240, all required scripted action verdicts and actual FX ID/payloads reconciled,
and explicit cleanup counters were zero. It is not a Gate B4ms performance pass.
Exit2 means NOT_READY/PARTIAL (for example an unauthored or unbuildable project);
exit1 means an actual runtime/evidence gate failed. The immutable result preserves
every attempt, including the log and exact process exits. No mock/in-process test
can produce an actual two-process PASS.

Launch contract agreed with both example owners:

- `B3_ROLE=host|client`, `B3_PORT`, `B3_ADDRESS=127.0.0.1`, `B3_SEED=1`,
  `B3_BODIES=4`, `B3_TICKS=240`, `B3_OUTPUT=<absolute endpoint directory>`.
- `godot --headless --max-fps60 --path <copied example>`; the example's own scene
  and existing Session runner drive all polling, simulation and input sampling.
- Physics starts only after the frozen two-player route/complete Welcome. READY
  is complete readiness, not an ENet socket-connect notification. Pump/drain must
  remain active until both can publish the confirmed final tick before cleanup.

Observation lines have `BOX3D_SLICE_<KIND> {JSON}`. Other ordinary Godot banner lines
remain in logs. Runtime errors, malformed JSON/duplicate keys, lost diagnostic tail,
queue/log overflow or missing required evidence fail; no unreliable transport
faults are manufactured by dropping output. Supported observations are:

- READY `{role,epoch,confirmed|tick,seat,stage}` establishes the explicit Welcome
  baseline; STAGE/STATUS are observations only.
- FRAME `{role,epoch,tick,head,confirmed,basePath}` refers to an immutable prefix
  with `.sig`480-byte diagnostic signature and `.part0` through `.part4` complete
  canonical Solver/Game/Side/Observations/Occurrences. Publish only retained
  confirmed ticks, after artifact writes finish. No private image punning.
- APPLIED `{epoch,tick,seat,kind,applied,...provenance}` is the actual published
  accepted decision, never a candidate/replay print. ACCEPTED and PREDICTED/
  USED_INPUT may additionally retain complete public ledger/input windows.
- FX `{epoch,tick,serial,lifetime,seat,kind}` is actual Kit post-local-commit
  callback output. Replay also supplies `{source,key,phase}` from actual
  `session_changes`/journal delivery; Begin/Update/Cancel are not Confirm.
  Expected authority occurrences must not be relabeled delivered effects.
- RESULT declares cleanup and explicit byte/count metrics: engine_live (or
  native_live), wrapper_live, meter_live, owners_live (or owners), all zero.
  Fixed Core registry/control storage is excluded explicitly from producer live;
  normal Scene shutdown must then have no live/not-empty diagnostic.

The verifier checks signature framing/version/metadata/checksum, all nonzero
identity fields, bounded file lengths and SHA256 for all five raw parts before
comparison. It compares only matching identity/epoch/confirmed tick and never
invents pre-Welcome history. Cookies are process-local and need not match across
OS processes. First mismatch copies full expected/actual artifacts and diagnostic
trace with real accepted/predicted windows; a readonly comparison uses from=to=
tick, depth0 and documented unavailable sequence0. No invented rewind context.

The early authoring probe is deliberately NOT_READY. This README describes the
assertions the actual runnable endpoint must meet, not completed network evidence.

The first real small-profile milestone has now passed on macOS Release for both
siblings using this runner. Kit confirmed0→240 with8 matching five-part checkpoints,
7 overlapping published decisions and12 reconciled actual effect payloads. Replay
confirmed1→241 with229 matching five-part frames,7 published decision/provenance
and fresh-issued causal joins,8 settled Game effect payloads, and zero remaining
managed callbacks/retained contexts. Both actual processes in each case exited0;
Native/wrapper/Meter bytes returned0 and checked owner cleanup completed. Kit had
no recovery episode; Replay had no rebased intent in those passing runs. These
unexercised branches are not counted as passed tests. Exact immutable evidence is
retained in the active goal stage `slices-first-milestone-report.json`; earlier
failed cases remain separate. This is the first milestone, not the full P4.2 or
Gate B envelope/soak/performance acceptance.

The next supported staged cohort is only `--cohort observer --end-tick300`: one
Host, one Client, one Observer, still the small4 profile. It sets
B3_EXPECT_OBSERVERS=1 and B3_END_TICK=300 as a stop coordinate only. Every actual
Welcome baseline must leave at least240 ticks before that stop. Tokens are
101/202/303 encoded at full width; semantic seats are1/2/0. The observer must never
submit an intent. Application GO is observed after complete role readiness,
without setting world state/head/confirmation through the control plane. The
Host must record real target-signature acknowledgement from both followers.
Each follower's five-part state and eligible actual effects are compared with
authority; the final300 frame is shared across all three. No observer-cohort run
is claimed until both example owners publish their readiness-contract freeze.

The32-body option is restricted to `--cohort pair --bodies32` for either sibling.
It explicitly launches B3_BODIES32 and requires a public
current-checkpoint cache to observe32 initial dynamics in each process. Actual
native world counters must exercise35 bodies/shapes and one joint while staying
within the147-contact limit; a published35-body cache cannot be replaced by a
historical Game peak or a rejected candidate. LIMITS/ENVELOPE/LEDGER records must
also bind H128/fixed60Hz/four substeps and the existing8-tick deterministic caps.
The shared ledger is checked as engine+snapshot+registeredHost live, plus current
reservations, with the actual composite committed peak bounded by67108864 bytes.
Ledger metadata storage/Godot/allocator overhead is explicit, not falsely counted
as RSS or silently omitted. Reservation sample maxima are labelled as sampled;
no nonexistent native reservation-highwater counter is invented. This new option
has not run or passed until the example owner publishes exact metadata and a
coherent current-source freeze; it does not inherit small4 evidence.
