# Box3D bounds and authoritative state validation

Status: the bounded P6.3 checks pass on native macOS arm64 and translated Linux
x86_64. The [bounds report](../../../tests/box3d_bounds/report.json) binds the
actual baseline failures, repairs, source/tool/Native hashes and results. This is
not a whole-project security audit or a replacement for the original reports.

## Trust boundaries

| Boundary | Required checks and ownership |
| --- | --- |
| Authored definitions | Bounded definition bytes, stable keys, body/shape/asset counts, geometry indices/scalars, references and motion settings before publishing an owning baked scene. |
| Native canonical recovery | Exact compatible identity/version/lengths, bounded section counts, complete semantic/reference validation, detached reconstruction and reencode equality before returning an owned snapshot. |
| Managed physics publication | Profile/resource admission before publication, with a disposable candidate and unchanged published state on failure. |
| Kit World traffic | Actual Host/driver identity, current bootstrap/epoch scope, bounded input windows and assemblies, exact typed payloads and canonical signatures before confirmation. |
| Replay physics traffic | Actual authority peer, current generation/serial/epoch, bounded input/fact/history/assembly state, complete canonical recovery plus application state/control validation before publication. |
| Application Game/Side | Bounds for counts, indices, identities and references consumed by that application. A structurally valid integer is not proof that it is a legal array length or gameplay reference. |

A checksum or complete signature establishes integrity under its declared
identity; it does not authorize a sender. Transport peer/scope checks remain
separate. These records do not claim cryptographic authentication of ENet peers.
Opaque local solver images require their exact compatible build and owning
dependencies; they are not an untrusted portable byte format.

## Declared resource bounds

The managed stress profile retains35 bodies/shapes,32 initial dynamics, one joint,
eight Native geometry assets, H128, prediction8, ordinary repair8 and67108864
tracked bytes. The initial-dynamic setting is not a replacement for the total
body/shape gate. Geometry may be shared by multiple shapes; authored resource IDs
are distinct from deduplicated Native geometry identities.

Current Native canonical input is limited to512KiB, with a separate2MiB DTO
allowance and bounded pools/tree/contact/reference validation. Authoring bounds
definition bytes and copied aggregate geometry to2MiB and Native assets to8;
Hull inputs are limited to256 points. Kit and Replay additionally bound their
complete network envelope/assembly representation to1MiB and32 parts. These
limits belong to different layers and must not be treated as interchangeable.

Actual Host/Meter ownership must be included at the managed SDK boundary.
Standalone Native admission takes explicit external bytes; a scalar-only Host
claim is not a shared-service quota test. The genuine SDK64MiB operation,
preservation and resume records remain in the
[production report](../../../tests/box3d_production/report.json). OS RSS is
separate from tracked physics admission.

## Trusted factories and profile admission

The low-level body/shape factories and raw owned snapshot capture are trusted
backend operations. They can represent a detached world exceeding the managed
35-object profile. Their existence is not a remote publication bypass.

The new Native edge tests use separate candidates and published worlds. Actual35
body/shape states admit and canonical-roundtrip. Intentional detached36-object
candidates fail public admission and canonical query/fill with Capacity; output
sentinels and the independently published solver state remain unchanged.
Removing only the extra object permits valid resume, publication and matching
fixed-step continuation. The test's admit-then-capture helper is explicitly caller
composition, not a new production cap on raw capture. No fabricated36-object
wire packet or private parser is used.

## Proposal admission and canonical state

Kit's `Input_Validate_Proc` may clamp or normalize its scratch input and can read
the application user context. It is a proposal-admission contract. Replaying it
blindly over authoritative accepted bytes could alter signed canonical evidence
or apply a decision against a different current world. Proposal sanitization,
typed wire validation, sender authorization and pure Game/Side invariants must
remain explicit boundaries.

Replay's complete Snapshot now uses its existing full replica invariant, including
all held controls, before Native decode, pending state or publication. Both
adapters use the same pure `common.game_valid(Game)` for the shared example's
structural invariants. It bounds retirement entries before indexing, preserves
the legal inactive spawn slot's retained lifetime, and checks coherent nonzero,
unique live/retired bindings without interpreting opaque Native key bits.

Kit applications configure `Network(Side).side_valid` before `network_attach` and
keep that predicate immutable while attached. The optional value-only predicate
runs after typed Side decode, with the retained owner's EXECUTE access checked,
before SDK reservation, Native decode or publication. Nil retains structural-only
behavior for generic Side types; the library cannot infer arbitrary application
invariants. The actual shared-game model and regression fixture bind a wrapper
of `common.game_valid(value.game)`. Its semantics are included in the existing
game-rules source identity. The existing attach signature, wire representation,
proposal sanitizer and resource limits remain unchanged.

The malicious trusted test producer is still allowed to construct and encode a
bad candidate. Validation happens at the untrusted receive boundary. Tests do not
step an accepted unsafe count to manufacture a process crash.

## Evidence requirements

Every rejected candidate needs an appropriate unchanged-state oracle: complete
five-part state for adapter cases, normalized solver bytes for backend-only
cases, plus unchanged confirmation/effects where applicable. Follow rejection
with a valid control, real continued operation and checked cleanup. Resource
measurements must identify the allocator/domain actually observed.

Existing malformed/rechecksummed recovery, authored geometry, motion union and
H128 tests remain useful independent coverage; new tests should fill missing
boundaries rather than duplicate those corpora. The new source and commands live
in [tests/box3d_bounds](../../../tests/box3d_bounds/README.md). A source-only plan,
compiler success or expected rejection by itself does not prove whole-P6.3
completion. Concrete failing regressions precede any scoped production change.

## Recorded results and limits

The new suite contains two Native C edge groups, three shared Game groups, four
Kit groups and two Replay groups. All11 pass on both recorded targets. Shared
positive controls execute actual4/32-body300-tick trajectories, including the
33rd dynamic/35th total body, spawn/remove, retirement expiry, sleep/wake and
queries. Negative controls retain malformed payloads and require rejection,
unchanged complete state/frontiers/effects, valid recovery/resume and real cleanup.

Before repair, a real authority Snapshot with a model-invalid held control and
two unsafe Game Welcome variants were accepted by Replay. Kit accepted a real
signed Reset with retirement count9. Those baseline failures are preserved.
After repair, the same rejection oracles pass; Kit's fixture additionally binds
the new application predicate without changing its malicious producer or payload.

Normal current Core/SDK32-body Host/Client pairs passed on macOS and translated
Linux, with complete-state comparisons, action/effect checks, natural exits,
drained intake and observed cleanup. These are short functional regressions,
not new long-soak, throughput, hardware-CI or CPU certifications. The existing
current World2 eight-group suite, Replay physics-network eight-group suite and
Replay physics six-group suite also pass.

The older `tests/kit_box3d_net` suite still has six failures tied to pre-World2
full-correction/proposal-layout assumptions. An isolated pre-P6.3 decoder run
produced the same six failure identities. Neither run is relabelled PASS and no
old assertion is weakened here. Current-layout abuse/recovery checks are separate;
the remaining recovery-hardening card tracks migration of applicable old
invariants and archival of genuinely superseded cases. A fixture-only package
with no tests is recorded as a compile control, not additional passing groups.

Native C/Core, protocol versions, wire layouts, admission ceilings and backend
artifacts did not change. Existing malformed canonical/authoring/motion coverage
is reused under those unchanged artifacts. Cryptographic peer authentication,
native Linux hardware execution, cross-target equality and exhaustive fuzzing
remain outside this bounded result. The whole goal still has remaining cards.

## P6.3 requirement and artifact map

| Requirement | Actual enforcement and bounded proof |
| --- | --- |
| Input history | Kit's real INPUT2 eight-row edge, malformed whole-batch receipt/ledger rejection and H128 retained/outside boundary; Replay's actual complete Snapshot held-control invariant; valid continued work after rejection. |
| Recovery snapshots | Genuine Host/authority transfers, bounded Kit CHUNK size/index/duplicate conflicts, correct canonical-integrity malicious complete Side/Game, unchanged published five parts/frontiers/effects and valid recovery/resume. |
| Body/spawn counts | Actual Native35/36 admission and canonical boundaries; shared4/32 trajectories include legal33rd dynamic/35th total body, spawn/remove and retirement expiry. Trusted raw factories are not the remote admission gate. |
| Authoritative state | Shared pure `common.game_valid`, Replay's existing `state_valid`/full `replica_valid`, and Kit's application-configured typed `Network.side_valid` before Native allocation/publication. |

The exact saved records below are bound by SHA256 in
[report.json](../../../tests/box3d_bounds/report.json). All paths are relative to
`/tmp/odin-box3d-goal-t4jbbj4v/` unless marked as repository paths.

| Saved execution | Actual result | Record |
| --- | --- | --- |
| Native macOS arm64 focused corpus | PASS: Native2 + common3 + Kit4 + Replay2 =11 groups; source/Native/compiler fences true | `p6-bounds-all-after-macos-v4/report.json` |
| Translated Linux x86_64 focused corpus | PASS: same11 groups and fences | `p5-gate-c-linux-v1/out/p6-bounds-all-after-linux-v1/report.json` |
| macOS current SDK Kit pair | CONTROLLER_SMOKE_PASS; end300,10 full5 comparisons,17 matched FX; both natural0, cleanup/intake/fences | `p6-bounds-kit-sdk-short-v1/report.json` |
| macOS current SDK Replay pair | CONTROLLER_SMOKE_PASS; end600,159 full5 comparisons,23 matched FX; both natural0, cleanup/intake/fences | `p6-bounds-replay-sdk-short-v2/report.json` |
| Translated Linux current SDK pairs | PASS aggregate; both end600; Kit20 / Replay209 full5 comparisons; both pairs natural0, cleanup/intake/driver fences | `p5-gate-c-linux-v1/out/p6-bounds-linux-sdk-v1/report.json` |
| Existing current World2 | PASS8 in aggregate whose legacy KitNet step FAILS | `p6-bounds-existing-regressions-v1/report.json` |
| Existing Replay physics-network / physics | PASS8 / PASS6; common fixture package is compile-only, not extra tests | `p6-bounds-existing-regressions-v2/report.json` |

These are existing normal Core/SDK scene builds and functional pairs, not new
GateC export qualification. Source/deployed Native identities and each actual
build's Core/scripts/Native hashes remain distinct in the report. Comparisons
are within each pair. Extra authority exports are not asserted to be compared
when no follower export was required.

The unchanged backend's malformed canonical, authoring and motion corpora remain
referenced by repository reports `tests/box3d_native/report.json`,
`tests/box3d_authoring/report.json` and `tests/box3d_motion/report.json`; they are
not represented as newly rerun matrices. The genuine shared SDK quota evidence
is separately retained in `tests/box3d_production/report.json` (P6.2).

### Preserved RED and incomplete legacy coverage

`p6-bounds-kit-baseline-v2/report.json` remains FAIL: count9 was published,
rejection was false, complete5 preservation was false, ready became true and
scope advanced to2. The repaired identical rejection oracle records count0,
rejected true, preserved complete5 true, ready false and old scope1. Valid
recovery/resume and balanced cleanup are then required.

`p6-bounds-replay-baseline-v5/report.json` remains FAIL for all three malicious
variants across its two test groups: model-invalid held control and two unsafe
retirement Welcome values were accepted. The repaired tests retain every
malicious payload/rejection/preservation/resume assertion. Earlier compiler,
fixture and invalid-short-declaration attempts remain separately hashed and are
not labelled runtime RED or PASS evidence.

The old14-group KitNet suite has the same six failures with the isolated
pre-change decoder and current decoder. Both FAIL records and exact identities
are retained in the report (`p6-bounds-old-kit-baseline-v1` versus
`p6-bounds-existing-regressions-v1`). P6.4 owns migration of applicable current
World2 invariants and archival of genuinely superseded cases; no old assertion,
packet or acceptance criterion was relaxed here. This bounded P6.3 evidence does
not close that follow-up or the whole goal.
