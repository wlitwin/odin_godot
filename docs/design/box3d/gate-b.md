# Gate B: contested physics, recovery and budgets

Gate B **passes for the declared macOS arm64 reference profile**. Kit World v2
and Replay have separate passing clean/impaired long pairs, declared recovery
and lifecycle coverage, complete-state/effect agreement, ownership and memory
evidence, and final-artifact CPU measurements below the unchanged4ms ceiling.
The requirement audit and artifact references are in
[the Gate B report](../../../tests/box3d_soak/gate-b-report.json).

P5 authoring may proceed. Gate C and P6 remain required; this is not full-board
completion or an unconditional60Hz/100-or500-body/cross-platform claim. The old
Replay artifact's8.894ms call remains a failed historical result with unknown
cause. It was not filtered or reclassified; the final artifact was validated
separately once, after real implementation changes. No criterion was relaxed.

The current P4.4 card now implements the
[Kit World v2 protocol](kit-world-protocol-v2.md): small canonical signatures
and accepted-input/receipt traffic replace routine full checkpoints. Throttle
experiments are stopped. Earlier Kit wire1 results and CPU measurements remain
evidence for their recorded graphs; they do not certify v2. After functional
validation, superseded Kit timing/owner prototypes and transport diagnostics
were removed from the ordinary implementation. Temporary Replay allocator and
schema traces were also restored away before the accepted measurements. Replay
remains a separate integration.

## Current acceptance matrix

| Requirement | Kit | Replay |
| --- | --- | --- |
| Primary impaired32/seed17, at least600 seconds | Cleaned v2 PASS:610.0597 seconds,152/152 cycles,1,220 full5 comparisons, no recovery/missing records; report `15f851a0…83906b` | Final current-build PASS:609.8589 seconds,152/152 cycles,20,841 full5 comparisons,1,069 issue joins, no missing/changed/extra decisions or FX; `6d8dc5c2…406fd` |
| Primary clean-network long case | Cleaned v2 PASS:610.1258 seconds,152/152 cycles,1,220 full5 comparisons; report `1e1b9892…51fee5` | Final current-build PASS:609.5908 seconds,152/152 cycles,12,107 full5 comparisons,1,069 issue joins, zero missing/changed/extra decisions or FX; `0b8b1477…b4cb5`. Original `1201a27f` FAIL preserved |
| Separately declared second-seed recovery/deeper-window case | Fresh declared intentional-reset classification PASS `dbf34809…c8f3b6`: real300ms blackout, one validated21-tick gap, exact42 skipped control rows, future240 controls/full5/effects and clean exits. Raw rolling FAIL remains preserved | Final-build seed42 fact recovery PASS `f16434a4…d77c7`: real300ms pause, observed16-tick gap,655 full5 comparisons, same scope/no Reset notice, complete future240 coverage, raw rolling PASS and natural cleanup0. This does not claim canonical Reset recovery |
| Late join/spectator/reconnect/reset and final ownership | Seed42 declared exit390 reconnect PASS `183a70e0…ba918b`; late observer PASS `8d7544cf…a991e`, including actual authority final ACK,71 full5 matches and all3 natural cleanup0. Intentional-reset scope is recorded separately | Final-build observer PASS `0dcea122…16a96` with782 full5 matches; original exit400 reconnect PASS `ff936ab3…4c036` with636 full5 matches, both first-Spawn contests and all35 issue joins. Both have raw rolling PASS, zero missing/changed/extra decisions or FX, actual final ACKs, natural cleanup0 and all fences |
| Normal and eligible-eight whole-call4ms ceiling | New v2 CPU workloads PASS:114 retained calls; normal maximum0.492ms, repair-eight maximum2.088ms; six separate provenance-verified streams, closure `5ebb7de5…7367e` | Final-artifact OFF suite PASS:76 retained calls; normal maxima0.325/1.591ms, Dense/Common repair maxima3.348/3.180ms. Four separately validated streams, seal `572d00d4…00df4`; old8.894ms artifact remains FAIL |
| H128/prediction8/repair8/tracked64MiB | Passed declared primary, CPU and lifecycle cases; no limit increase | Passed declared primary, CPU and lifecycle cases; highest current CPU tracked peak51,543,669 bytes, no limit increase |

The Kit v2 original coverage audit is
`007defa8445d647f194ecffdc4774ad32a3947ff0296ebda73e2deb7854a0626`.
No historical fail was reclassified and no recovery/cycle criterion changed.
The independent Kit two-case closure is
`8c8c07eb90db46d012fbd8d046f34a1e721cbf1b48644dfc397e684e7a96412c`.
Each case verifies305/305 published Client action matches, remote controls
Submitted36,600/Held0/nonzero24,440, no missing decisions/effects or recovery,
final acknowledgement and natural cleanup0. Those are final cleaned-v2 primary
results; lifecycle and CPU requirements remain separate.

The Replay focused recovery regression delivers a genuine ordinary Snapshot20
while the client is at confirmed9/head13 with contiguous signed facts through20.
It now confirms20 without resync or snapshot catch-up, preserving scope, complete
five-part equality and cleanup0 (`a4683450…a492c`). The original failing long
result remains unchanged. This deterministic regression does not establish the
cause of the earlier live confirmation slowdown.

The rebuilt clean Replay pair then passed609.8502 observed seconds with152/152
verified cycles,1,069 action joins,12,037 required full5 matches, no missing,
changed or extra decisions/effects, no recovery or resync notice, final ACK and
natural cleanup0. Host remote controls were Sample36,590/Held10. Independent
saved closure `ed683192…bad2882f` preserves the original controller/audit and
source/binary/intake bindings. It does not replace the separate impaired case.

The declared Kit reconnect case preserves the earlier exit400 capture failures:
the client exported final402 while the host exported390/420, although Query400
was actually admitted/applied on both sides before exit. Exit390 was separately
declared at the existing shared capture boundary. Its PASS does not claim
arbitrary-exit full-state export coverage. The later declared Kit reset case
passes its separate prospective recovery classification; the earlier missing
post-reset action failures remain unchanged.

Replay's spectator regression first failed with complete signed facts retained
through20 but confirmed2. The corrected spectator path imports a genuine full
Snapshot20 only with contiguous facts and presentation headroom, then verifies
the complete state before confirmation. The identical test and existing driver
and physics regressions pass. The live observer subsequently reached1200, but
the host forgot its terminal obligation after disconnect. A fixed16-entry
roster now retains actual admitted token/peer/generation and matching final ACKs
independently of current Running-peer counts. The fresh observer case passes.

A genuine public duplicate-Hello test separately reproduced serial1->2 and
view-reset1->2 after the original Welcome ACK was complete. Physics Hello
retries on the same connection/token/incarnation now refresh liveness without
creating another Welcome. The unchanged test passes with serial/view-reset1;
all eight existing physics tests pass. Explicit Resync and fresh-incarnation
admission paths are unchanged. The SDK roster build's initial syntax failure
and every prior failed runtime remain preserved.

The earlier reconnect case preserves its FAIL. The old process exported400 and
exited cleanly; its replacement entered generation2/serial2 at baseline439 and
reached1200 without another canonical recovery. Client Spawn520 was sampled at
head519 while its observed authority frontier was540. It executed at555, after
the host's successful Spawn520 and Remove536, so both Spawns legitimately
succeeded under Receipt timing. This fails the existing verifier's requirement
that each interval's first Spawns form one occupied-slot contest. All three
processes exited naturally with cleanup0 and source/project/driver fences held.
Later verifier checks were not reached; this is not a lifecycle PASS. The cause
of the transient confirmation lag remains unmeasured.

The subsequent public work-count regression showed a concrete inefficiency:
eight signed facts received in one pump caused36 replayed ticks and eight
repairs, with complete-state equality and cleanup passing. Validated partial
prefixes now share the existing pump presentation boundary. A prefix covering
the current predicted head still applies immediately, preserving confirmation
progress before farther packets can reach H128. The identical regression now
performs eight replayed ticks and one repair. Existing driver, spectator and
all eight physics checks pass; no packet, signature, ownership, wire or limit
contract changed. This does not attribute the recorded8.894ms CPU outlier.

The next reconnect passed both original first-Spawn contests and all issue
joins, but the raw rolling check found four controls missing from its ledger.
All four actually existed in the immutable client log at ticks436/437, seats1/2,
and exactly matched authority provenance. They preceded READY, so the harness
could not register them against a process scope. The producer now reuses its
existing admission announcement immediately after a successful Welcome makes
the client Running, before publishing FX, inputs or frames. The checker was
unchanged and no records were filtered or exempted.

Fresh original exit400 reconnect then passed636 full5 comparisons, both actual
contests,35 issue joins, raw rolling coverage with zero missing/changed/extra
decisions or effects, final acknowledgement, new connection identity and three
natural cleanup0 exits. The same final build also passed observer and300ms
same-scope fact-recovery cases. Their saved closure is
`ea34efa030ecf55658f732b9ccb9acf61564986e0e70bc76fedb913de9c99f1e`.
Every earlier failure remains unchanged.

The final current build then passed the original primary impaired LONG policy:
609.8589 observed seconds,152/152 contested cycles and152 consecutive cycles,
1,069 issue joins,20,841 full5 byte comparisons, no recorded recovery gap,
zero missing/changed/extra decisions or effects, final acknowledgement, complete
intake and both natural cleanup0 exits. Source and driver changes were empty.
Report SHA is
`6d8dc5c2e2c9b71d8e22dc928d2a6d9aa939fdcc4b23bf681e92ea60529406fd`;
audit SHA is
`0749853e6f274858683b3e2f1957687324a0a88ce0ebe7ac919251fe71e992a1`.
The policy differed from its previous run only in run ID and source bindings.
This functional soak does not replace the failed CPU measurement.

The same build also passed the original clean-network LONG policy:609.5908
observed seconds,152/152 contested and consecutive cycles,1,069 issue joins,
12,107 full5 comparisons, no recovery gap and zero missing/changed/extra
decisions or effects. Both processes exited naturally with cleanup0 and fully
drained intake; source and driver changes were empty. Report SHA is
`0b8b147743125d3788888a37b5b5ab948219fb13eb657c3bdb46ee8dd9eb4cb5`;
audit SHA is
`ed08791be1afbb006461f97f4ff043217a44dd9e160f72a8d847e42dc732f1f6`.
The saved two-case closure is
`2596d781424ab60f215da6725a3a9488bcc49241f820470b228e2d12a5b71351`.
These functional cases did not waive the CPU requirement; the final-artifact
CPU closure below separately satisfies it.

### Earlier reconnect criterion proposal — not adopted or needed for these passes

A bounded alternative would keep every issued action, authoritative outcome,
FIFO check, complete-state comparison, effect check, identity fence and final
ACK requirement, while requiring a genuine contested Spawn pair in an intact
post-rejoin cycle rather than assuming the first pair contests. Every cycle's
actual outcomes and any intervening Remove must remain visible. The primary
LONG contest-density rule stays unchanged. This would version the lifecycle
contract and require a fresh case; it cannot turn the recorded reconnect FAIL
into a PASS. The alternative was not implemented or accepted; the original
criterion subsequently passed after the code and publication-order fixes.

Saved affected-case closure:
`a236a20ca7486dd45aeb94c1292eaac27913030d12ef4cec0a12676fa2a513e4`.
The suggested criterion change was not adopted. The final-artifact CPU suite
below satisfies the original ceiling; no historical outlier was filtered.

The completed prerequisites are recorded in
[the playable report](../../../tests/box3d_slices/report.json) and
[the presentation report](../../../tests/box3d_presentation/report.json).
Their functional results are not a performance or soak pass.

## Workloads and timing boundaries

Two workloads are kept separate:

| Workload | Geometry and schedule | Counter interpretation |
| --- | --- | --- |
| Dense reference | Original 32 dynamic boxes, extra sphere; Spawn40/41, Remove95, Motor115, target160 | Historical run peaks35 bodies/35 shapes/141 contacts/1 hinge; report actual counts for each timed sample |
| Authored common scene | Two spheres and30 crates, extra capsule; production common controls/actions, target160 | Historical run peaks35/35/about122/1; this is a different descriptor and cannot replace the reference measurement |

The extra body has already been removed at tick160 in both schedules. A run
peak must not be copied into a sample's current counters. Each dataset binds
geometry, placement, joint, accepted inputs, seed, source/build/target identity
and the exact correction interval.

The initial test-only CPU probes use the real Godot Core, SDK ownership, Meter
and one shared native image. A GDScript timer immediately before a public Node
method and after its complete return includes Core entry and return. The method
must perform public receiver dispatch/reassembly, canonical and typed decoding,
independent native reconstruction and reencoding, normalized comparison, eight
accepted-input replay steps, complete paired comparison, publication, event
bookkeeping and required cleanup. Rendering and separately identified diagnostic
output may be excluded. Required work cannot be moved into the later diagnostic
method. Transport wait is distinguished from active receiver work.

That full-state reconstruction boundary describes the earlier checkpoint
protocol. Kit v2 ordinary repair receives Reliable ACCEPTED rows and a canonical
five-part signature, performs eight real replay steps, verifies the signature
before publication, and returns through Core. It does not decode a full native
recovery image. The new measurement includes that signature verification;
Welcome/Reset full-state work remains a separate recovery operation. The old
record validator's full-native-read requirement must not be claimed as executed
by these new ordinary-repair samples. Its original rejection is preserved while
the explicit Kit wire2 coverage branch validates ACCEPTED/signature counts,
matched-signature advancement, unchanged full-state counters and all existing
step, full5, quota, cleanup and timing checks. The focused record suite passed34
controls, including unchanged legacy/Replay behavior and retained outliers.

The cleaned v2 whole-call results below use19 samples per separate stream on
macOS arm64, actual Core/SDK/Meter and one unchanged shared Native OFF Release
image. Values are microseconds; p95 equals maximum for these19-sample batches.

| Operation | Dense p50 / maximum | Common p50 / maximum |
| --- | --- | --- |
| Client prediction |301 /311 |283 /316 |
| Authority normal step with due signature |402 /492 |375 /403 |
| Eight-step accepted/signature repair |1998 /2088 |1878 /2015 |

Every raw call remains present; no phase subtraction or cross-stream percentile
pooling was used. Each category-only analyzer still reports CPU INCOMPLETE on
its own. The explicit six-workload closure records their separate normal and
repair coverage without relabelling those individual reports or establishing
the remaining live/lifecycle gate requirements.

An earlier Replay CPU run retains76 calls across four separate19-sample
streams. Client prediction has p50/maximum0.291/0.305ms; authority requested-output
has1.314/1.350ms; Common repair-eight has2.992/3.059ms. Dense repair-eight has
p50 3.265ms and maximum8.894ms, with one call above the unchanged4ms ceiling.
All calls passed correctness and cleanup, but that does not turn the timing
failure into a pass. Raw closure `55d14a81…51ac0` preserves the outlier; its cause
is not classified. No threshold change or replacement run is authorized by this
record.

After the final implementation changes, a source audit established that this
CPU corpus receives a full Snapshot rather than the signed-fact burst used to
prove coalescing. One existing-hook diagnostic did not reproduce the old spike;
its19 calls were3.227–3.890ms, including observer overhead. Those calls are
excluded from acceptance and do not establish the old spike's cause.

The final current artifact then passed all four original functional controls
and one OFF acceptance stream per declared operation. Every stream retains19
raw calls. Values below are microseconds; nearest-rank p95 equals maximum for
these19-sample streams.

| Replay operation | p50 | p95 / maximum |
| --- | --- | --- |
| Dense client prediction/send |291 |325 |
| Dense authority step/requested canonical output |1317 |1591 |
| Dense complete eight-step repair |3272 |3348 |
| Common complete eight-step repair |3026 |3180 |

The unchanged analyzer validates each stream's records and provenance. The
separate category-only CPU reports remain INCOMPLETE individually; the Gate B
audit explicitly checks coverage of both normal operations and both required
repair geometries without pooling statistics or rewriting those reports.
All76 raw values/types match the logs, every call meets4ms, all full5/real-step/
quota/ownership checks pass, and source plus three-binary postfences hold.
No shutdown-field adjustment was needed. A coordinator reader error occurred
after the first normal runtime completed; that stream was retained and only
the three unrun streams resumed. No timed stream was repeated.

The saved CPU seal is
`572d00d459bdd48b1d31fcbb7e7920a55a151d5492a191af1035bcc36b200df4`.
This is observed performance for the named current artifact, not an explanation
of historical timing variation or an unmeasured Common-normal/live-frame claim.

Tracked admission and OS RSS are separate. The final Replay CPU peak was
51,543,669 tracked bytes against67,108,864. In the final clean long pair, sampled
whole-process RSS peaks were428,081,152 bytes on Host and347,357,184 on Client
(602 samples each); impaired peaks were314,982,400 and320,159,744 (603 each).
Kit's recorded v2 impaired peaks were288,276,480 and265,568,256 (603 each), and
clean peaks266,616,832 and270,761,984 (602 each). No RSS sample was unavailable.
These include Godot/runtime overhead and are sampled peaks, not exact highwater
values or the64MiB tracked-resource quota.

Offline public serialized packets isolate CPU work; they do not prove actual
ENet delivery or the long independent-process soak. Nil-owner and fake-Core
probes remain diagnostic comparisons, with their limitations named explicitly.
The shared record contract is
[records-v1.md](../../../tests/box3d_soak/shared/records-v1.md).

## Candidate acceptance ceilings

The existing bounded profile remains unchanged:32 initial dynamics, at most35
live bodies/shapes,147 contact records and one hinge; H128 at60Hz/four substeps,
one caller, prediction and ordinary repair at most eight ticks, and64MiB tracked
native/wrapper/Host live bytes plus remaining reservations. Godot, allocator,
static ledger, driver and RSS overhead are labelled separately.

Normal and eligible-eight correction work retain their4ms candidate ceilings.
Every measured call, including cold and over-target calls, is retained. Reports
must provide raw samples, counts, p50/p95/maximum and the actual operation depth.
Nested phase timings cannot be summed into a substitute whole-call value.
Clocks are observations for the acceptance suite and never gameplay rejection
or state-identity inputs.

Historical negative measurements remain evidence: Replay whole5.170417ms versus
core3.589333ms, and Kit complete-eight whole median4.860584ms/maximum8.957208ms.
They are not current SDK/Godot measurements and are not erased by newer
results. Current measured batches are listed separately below.

The first current Replay dense-reference batch used real Godot Core/SDK/Meter,
explicit `-o:speed -debug` Core and scripts, and the verified native Release
library. All19 full eight-step repairs were correct and over the4ms ceiling:
median4.854ms and p95/maximum5.402ms. No samples or outliers were removed. The
whole timer bracketed public Link ingress, canonical validation/reconstruction,
typed decode, checked replay/comparison, journal work and complete Core return;
optional phase hooks were off. Actual repair counts were34 bodies/34 shapes/
141 contacts/one joint, with the separately recorded35-body run peak.

Peak admitted tracked memory was51,497,861 bytes, below64MiB. Whole-process
Godot RSS peaked at352,141,312 bytes across setup, operations, diagnostics and
teardown; it is a different measurement. All operations and final cleanup
passed. This repair-only batch has zero normal samples, so overall CPU coverage
is incomplete in addition to the observed correction-budget failure. Raw
records remain bound by SHA256
`2666d117a8bbd48d4407ed0bed1925f988e5ff7ec777c3141d626ad5420bb858`.

A separate instrumented Replay batch retained all19 calls, including its first
10.612ms call. Median whole time was4.884ms; all19 exceeded4ms. Observed phase
medians were3.360ms for checked replay/comparison and1.016ms for decoding, with
0.885ms native reconstruction/reencoding nested inside decoding. Link ingress
was0.124ms; entry and return-tail intervals were3µs and1µs. These overlapping
phase statistics are not added, subtracted, or used to replace the whole timer.
The raw record hash is
`323573419ae7cd223c3a6777fc47cf5f2b22ca039afce703d8da8ab28a9238e1`.

The first current Kit dense-reference batch also retained19 correct calls:
median4.529ms, maximum4.814ms, all over4ms. It measured consecutive eight-tick
windows ending8 through152, with tick160 checked separately without timing.
Those windows differ from Replay's19 fresh152→160 repairs; results are not
pooled as identical workloads. Kit's peak tracked admitted memory was59,375,473
bytes; its whole-process RSS was184,025,088 bytes. Its raw normalized records
have SHA256
`aefdfdd46a7b2f17fc06d2d0bd2b0787dda7010171ed9164c05436c9b5eb9fcb`.

The first bounded optimization candidate replaces Meter's repeated allocation
table searches with an exact-pointer index and free-slot stack. Its additional
20,488 bytes per context are included in actual requested-memory accounting.
Allocation and alias capacities, guards, accounting calls, generation/pin rules,
and rejected-resize atomicity remain required. Functional validation passed,
but the new whole-call batches did not establish useful improvement: Replay
median4.829ms/maximum4.987ms, all19 over budget; Kit median4.536ms/maximum5.248ms,
18 of19 over budget. The changed Replay diagnostic bookkeeping is recorded, so
these observations do not establish an isolated Meter cost.

The private snapshot-constructor helper now counts once and fills once, reducing
the normalized traversals from24 to16 across eight required captures. Public
sizing/no-partial-output behavior, all fields, final resource/seal validation
and the eight captures remain. Native Debug, Release and unsuppressed ASan/UBSan
checks passed. The subsequent complete repairs still exceeded the ceiling:
Replay median4.741ms/maximum7.065ms, all19 over; Kit median4.479ms/maximum4.658ms,
18 of19 over. The different window plans remain separate. These changes have
not resolved the correction budget.

Two separate normal-operation batches on the current Replay fixture completed
19 correct samples each, with actual Core entry/return, SDK ownership, the
indexed Meter and the count-once native Release build:

| Operation | Median | p95/maximum | Calls above4ms |
| --- | ---: | ---: | ---: |
| Client public Link/pump, one prediction step and input send |0.470ms|0.531ms|0/19|
| Authority step plus public requested canonical checkpoint output |1.754ms|1.864ms|0/19|

Both retain every cold/outlier sample and pass full-state, actual public-step,
H128, requested-memory and cleanup checks. Step evidence is committed tick
159→160 with `External.require_step` enabled; native/replay step counters are
explicitly unavailable. The authority operation is an offline composite with a
real public checkpoint request and five actual sent chunks, rather than a
measurement of normal live checkpoint cadence. Each distribution has19 normal
and zero repair samples; neither alone establishes complete CPU coverage or
Gate B. Their raw record hashes are respectively
`f442536995565b64a73df80347b911407e75eb918af5b78b8d18434780f68d88`
and `6a1a69f73619dfea134a4e8d6fbdf7f28eea3cef3775eaca2a7f0c5703ea97b5`.

The native phase observer is now implemented as an explicit opt-in. Default
builds retain96 ordinary exports and have no observer state or callbacks;
opted-in builds add three diagnostic symbols. Debug/Release and default-platform
ASan/UBSan checks pass. An additional forced LeakSanitizer run fails on recorded
libobjc/XPC startup allocations; that failure is retained without suppressions
or a process-wide leak-pass claim.

Actual Core/SDK dense and common functional runs pass with observation disabled
and with structure recording:20 operations in each configuration, complete
five-part agreement, eight replay steps, source teardown and zero application
resources. Structure records distinguish eight replay captures from the single
capture inside canonical reading, without clock reads. The49392-byte record
block and its219928-byte Meter context are charged; static C control48 bytes,
binding32 bytes and the later clock cache24 bytes are separately identified.
The first19-call observer measurement completed with correct game results;
whole median4.549ms, maximum6.063ms,18 calls over4ms. Its native observation
schema failed because the test driver converted integer JSON fields to floats.
Those original records remain failed and unchanged. Earlier functional schema
passes used a normalizing collector and do not prove verbatim integer output;
their game-state and application-ownership checks are separate facts.

The producer now preserves original numeric text, and the collector no longer
normalizes it. Four fresh functional configurations pass with exact integer
records, including producer controls for2^53+1 and UINT64_MAX. The corrected
19-call measurement is independently valid: median4.563ms, maximum4.854ms,
18 over4ms. All raw calls, source/build bindings, eight-step and complete-state
proofs, ownership and cleanup checks pass. Snapshot capture medians were291µs
inside recovery reading and296µs for repair roots. Finalization includes caches,
hashes/seal and nested validation, rather than an isolated hashing cost.
Whole-call overhead stays inside the measured boundary; component timings
cannot remove validation or replace the whole timer.

A subsequent private constructor change establishes the fresh resource seal
once after all structural checks. Existing-resource validation still recomputes
and compares it; thirteen reviewed function bodies retained their original
bytes for that change. Normalized fields, complete and motion hashes, allocation
cleanup and both observer callbacks remain required. Debug, Release and
platform-default unsuppressed ASan/UBSan checks pass, including corruption,
pending-event and allocation-failure controls. Four actual Core/SDK dense/common
functionals with observation off or structure-only also pass full-state,
eight-step, ownership and quota checks on the new native identity. Subsequent
whole-call batches retain all19 samples: Kit median3.731ms/maximum4.050ms with
one over4ms; Replay median4.008ms/maximum4.428ms with12 over4ms. All operations
passed their state, step and cleanup checks, but both correction budgets still
fail. Kit's diagnostic observer remains inside its whole call; Replay uses
the ordinary observation-disabled library and its separate tick-window plan.

The next scoped candidate extends the private FNV implementation's existing
eight-zero-byte fast path to four- and two-zero-byte groups. It preserves the
same per-byte recurrence and output for every seed; zero groups use the exact
prime power modulo2^64. Bounds, byte order and public validation remain
required. Reference vectors, mixed inputs and guard-page controls are passing;
the full native Debug/Release/OFF/ON/sanitizer matrix and four SDK functional
cases pass. Subsequent dense repair batches retained19 calls each: Kit
median3.032ms/maximum3.395ms and Replay median3.309ms/maximum3.518ms, all correct
and below4ms. Kit's separate common workload retained19 correct calls at
median2.769ms/maximum2.858ms. Current Replay normal client prediction/send and
authority step/requested-output batches also retained19 correct calls each,
with maxima0.324ms and1.693ms respectively. These are distinct workloads and
boundaries. Kit normal-operation coverage and the remaining live gates are
still required; no timing outliers or prior failures were removed.

## Long-soak evidence

Before execution, freeze duration/ticks, seeds, impairment and lifecycle/recovery
schedule, target/configuration and acceptance checks. Both Kit and Replay need
actual separate Godot processes and their own existing session/runtime paths.
The current candidate schedule is ten minutes per sibling on a primary fixed
seed, with a separately declared second-seed recovery case. The clean Replay
primary-pair result below covers one part of this schedule.

The first actual clean Replay32 attempt requested36,000 ticks and600 observed
seconds, but stopped after about35 seconds. All1,116 exported follower states
matched the authority's five full parts. The client then failed its scripted
intent bound and exited1; the controller stopped the authority. The run is a
failed attempt, with no long-soak or whole-case cleanup pass.

A subsequent public regression reproduced an action-queue defect:16 actions
were accepted, confirmed by complete physics snapshots, and their outcomes
drained, while the pending-action count still reached16. Issuing action17
returned Capacity. The physics confirmation path now retires only the minimum
of the canonical settled frontier and actually confirmed outcome frontier,
after all successful comparisons and journal work. Forty same-client public
settlements, focused failure controls and existing native/pure suites pass.
The original failed run and regression remain preserved. This does not
justify changing the eight-tick limits or relabeling local sends as admission.

A fresh32-body extended clean attempt then reached2700 ticks with both natural
zero exits, zero resources and1,395 exact full-state comparisons. The same
client issued23 actions, including21 in its final serial, exceeding the former
16-action boundary. It remains an overall failure:523 decision rows and13
effects were missing within four observed recovery intervals, and its initial
Spawn pair was not contested. Later successful cycles do not repair that
original scenario verdict. Its approximately46-second duration is not a
600-second soak.

The next predeclared clean Replay long attempt stopped after about107 seconds
when the controller's1,024-event intake queue overflowed. It retained3,367
full-state comparisons and failed with forced exits and incomplete evidence.
Independent readback found399 Host records in the raw log but absent from the
archive. All33 unmatched follower states equalled the corresponding retained
Host raw artifacts; these checks do not retroactively register comparisons or
pass the failed run. Four actual recoveries also exceeded that plan's latest
allowed recovery tick, independently failing its coverage policy.

Kit's same-epoch fragmented-transfer stall has a focused fix and passing FIFO,
default and strict-SDK controls. Its fresh impaired32-body run progressed through
validated resets but failed required future-intent coverage. A separate clean
32-body run matched all10 full-state checkpoints and effects with zero resources,
but failed because Query authority execution was not observed. Neither is a
Gate B pass.

A later copy-only observational Kit pair recorded the public confirmed
authority input at160: Query, Submitted origin, sequence160, applied true and
query total2. Both processes exited naturally with zero resources and10 exact
full-state comparisons. The copied observer also measured eight positive
prediction-time clips, despite successful Query admission. Its added callback
work may change staging cadence; this result neither explains nor relabels the
original missing-Query failure. No production input/clock policy changed.

Two subsequent generic four-body public input controls distinguish admission
from sending. The same actual packet is admitted when timely and correctly
ignored after its tick has settled; both arms agree in all five parts and
clean up. An imported-example helper regression then showed that it could
start a new intent in a slot already known to contain an authority decision.
The helper now defers that first candidate within its existing eight-tick
sampling window. Its focused test retains original due40, skips known None40,
then makes its first genuine Spawn proposal at41; authority receipt, full state,
effects and cleanup match. Eight focused/legacy groups pass. Existing attempted,
published and transported identities stay immutable; no clocks, due rebases or
manual-input policy changed. Subsequent SDK32 attempts still fail required
authority-action and recovery coverage, as described below.

The streaming controller now uses finite SQLite/raw-archive budgets and complete
five-part comparison before sealing receipts. Unmatched required follower
exports remain a failure or hold; authority references are retained and counted
separately. Durable effect identities, payloads and lifecycle records detect old
duplicates after the hot history rotates. A first mismatch preserves complete
expected/actual parts, signatures and bounded actual input/provenance context
before cleanup. Sealed receipts and retained replayable raw data are reported
separately. Existing per-record receive timestamps are now bound into the
archive chain; unknown saved-case times remain unavailable. Fourteen controller
failure controls pass, including tamper, cleanup containment, prelaunch policy
binding and rejection of a descriptor oracle from a different native build.
The source inventory includes both example trees, and copied authored inputs
must match the source snapshot taken before copying.

The long recovery/cycle validator is an explicit opt-in policy frozen before
execution. It retains strict findings, requires sustained complete contested
cycles and bounds actual recovery gaps. It does not reclassify old attempts or
change the short checker. The observer repair now adds bounded disk intake,
fair complete draining through EOF and indexed history lookups. Archive
durability, complete comparisons, quotas and recovery limits stay required.

The repaired observer then completed a fresh bounded Replay32 run to tick7500,
past the former6272-reference overflow point. Both processes exited naturally
with zero application resources. All4601 follower exports matched complete
authority bytes, with7500 retained authority references,220 actual issue/decision
joins and253 settled effects. Required missing/changed/extra evidence was zero,
the actual tail matched, and no recovery was recorded. Host38396 and client29889
indexed events were all seen, published and consumed; EOF, fsync, file integrity
and consumer closure passed. Peak disk backlog was10/14 events. Its124.857-second
duration is a capacity check, not the required600-second soak.

The next clean Replay primary pair completed609.8367 observed seconds and
36,600 ticks, with152 of152 complete contested cycles and1,069 immutable
issue-to-authority joins. All22,023 required follower exports matched complete
authority state; all36,600 authority references were retained. No recovery,
missing/changed/extra evidence or duplicate settled effects was recorded. Both
processes exited naturally, with zero application resources and clean Core
shutdown. Every187,292 Host and144,466 client intake record was consumed,
verified and closed. Independent saved-artifact verification confirmed the
original receipts, duration, cycles, identities and cleanup. This establishes
the clean Replay functional soak on its recorded native build; impairment,
lifecycle, Kit and correction CPU remain separate requirements.

The latest short Kit pair consumed all its disk intake and exited naturally
with zero application resources and a real final acknowledgement. It still
failed the strict checker: six actual resets skipped two required decisions and
three effects. Query227 and client Spawn280 were locally issued, but their
authority execution was not recorded; the exact authority input rows are
unavailable. Five complete checkpoints matched, including270 and300 after the
last reset at266. These observations neither waive the omissions nor establish
the required Kit scenario or long soak.

A fresh short Kit case on the seal-once native build again exited naturally
with clean application/Core shutdown, complete intake and a real final
acknowledgement. All eight exported follower states matched. The strict checker
still failed with two missing decisions and four missing effects. Its original
failure is retained; faster native capture does not establish the required
action/recovery coverage.

Natural process exits, real resource queries, drained tails, actual endpoint
consumption and successful owner cleanup are required. Socket writes, missing
metrics, forced termination or a pose digest cannot establish success. Deep
loss/blackout must use the existing explicit hold/reset/rejoin policies without
widening the eight-tick ordinary window or manufacturing history.

## Current scope

The current native macOS arm64 machine is available for measured reference
runs. Existing Linux x86_64 execution through the container/Rosetta environment
provides functional evidence; it is not native Linux throughput certification.
No mixed-target exact final-physics or unobserved remote-CI claim is made.

Source optimizations and production instrumentation require a measured cause,
a narrow owner partition, unchanged validation/atomicity/limits, and appropriate
regression checks. Separate recorded normal and repair batches now meet4ms.
Both siblings' live recovery, impairment and lifecycle requirements keep Gate B
open. The clean Replay functional soak is recorded separately.

Four Kit normal batches have now been sealed and independently checked, with
all19 calls retained in each. Median/maximum whole-call times in microseconds
are dense client298/327, common client280/305, dense authority1491/3567 and
common authority1330/1351. The authority operation includes automatic output
and an explicit requested canonical checkpoint. Each call proves its public
one-step return, actual sent-buffer copying/freeing, independent local five-part
oracle and checked ownership/cleanup. Its Game proof covers all registered
local checkpoint fields; its model-step callback counter is labelled separately
from Native engine counters. These are distinct observed batches on recorded
source graphs, without pooled timing or an unconditional CPU guarantee.

The subsequent impaired Replay pair completed609.3097 observed seconds and
36,600 ticks with natural exits, clean application/Core shutdown and complete
disk intake. All12,936 paired exports matched the original authority state.
It still fails the frozen policy: a recovery baseline10987 exceeds the3601
deadline. The653 missing decisions and13 effects remain recorded, and one
published issue/decision pair has different issue-time and execution-time
serials. A separate public Memory/Link regression demonstrates automatic
same-epoch resend under the new serial while preserving logical action
identity, with stale-copy rejection and one outcome. It does not establish the
path taken by the saved live case or waive its policy failure.

The latest short Kit run failed its first client intent's sampling window
before issuing a client proposal. Exact lookup results and the fatal callback
tick were not logged, so its cause remains unproved. A prospective caller-time
accounting test separately exposes positive eligible time clipped at prediction
depth eight. Bounded client credit now retains at most eight ticks outside the
Lane, with explicit ownership receipts and lifecycle dispositions. Seventeen
pure test groups pass. A fresh32-body/seed17 short Scene passes the unchanged
strict checker: ten action joins cover all six kinds and the contested Spawn;
ten complete checkpoints and17 settled effects match without missing, changed
or extra records. Both processes exit naturally with clean application/Core
shutdown, complete intake and an actual final acknowledgement. Meter observes
the full21,480-byte Runtime allocation on both endpoints. The5.0956-second
observed scenario establishes short functional coverage; long stability remains
unproved. No old Query, recovery or intent failure is thereby explained or
reclassified.

The first subsequent clean Kit long attempt stopped after about209 seconds
when the client intent due at12,280 exceeded its sampling window before issuing
a proposal. All409 exported state pairs matched through12,270. The exact fatal
callback tick and earlier accepted-slot lookup outcomes were not recorded, so
this does not establish why the opportunity was missed. The client exited with
failure and clean application resources; the controller terminated the Host,
whose final cleanup is unverified. The missing tail, duration and strict
omissions keep this attempt failed. Its evidence is preserved for diagnosis.

A separate 120-cap service experiment also failed. Both Engine getters reported
the requested cap; physics remained at60Hz. Its retained trace records known
accepted None values at client sample ticks362 and368 while Query remained
unattempted with due362. Two validated resets left that due unchanged, and the
callback at371 exceeded its window. The trace has an explicitly lost prefix;
it neither establishes the cause of those resets nor an isolated transport
bottleneck. The helper and current verifier both require a reset to cross a due
tick ahead of the old head. A focused public regression is being prepared for
the still-unsampled known-slot case; production and verifier behavior remain
unchanged pending that evidence and a separate contract review.


The subsequent V2 contract changes only wholly unattempted intent rebasing at
an existing signature-validated Reset. A public regression proves Reset45
rebases due40 to46 while preserving original40, then first samples and admits
Spawn46 with complete state and one effect. Attempted identities stay pinned.
Versioned producer/verifier controls and a fresh strict300-tick Scene pass.
The earlier failures remain unchanged.

A clean Kit V2 run then completed610.082810209 observed seconds through tick
36,600 with both natural exits and clean application/Core shutdown. Independent
audit verifies1,220 original five-part state comparisons,1,069 action joins,
152 complete cycles and1,227 matched effects per actor, with complete disk
intake and no observed recoveries. Acceptance remains incomplete: the Kit
producer logged none of the73,200 required authority per-tick control rows.
Sampled state matches cannot replace that evidence.

Revision61 scopes prospective public confirmed-control logging and strict
validation of those rows. Missing or malformed values remain unavailable;
they cannot count as coverage. The old run stays FAIL/INCOMPLETE. A fresh
source-bound build and short proof must precede any newly selected long run.
GateB, impairment/lifecycle coverage and P5 remain open.


The confirmed-control producer and strict Kit proof are now implemented. Six
focused producer groups and59 checker controls pass. A fresh coherent Scene
then passes the strict300-tick scenario: each endpoint logs600 accepted
controls covering both players at every tick, with equal typed bodies and no
unavailable values. Both Meter observations charge the full109,968-byte
Runtime. Ten complete state comparisons, all six action kinds,17 effects per
endpoint, the final acknowledgement and checked cleanup pass. This remains
short evidence; the old600-second run is still incomplete. A new long plan
uses the same fixed quality bounds and awaits separate execution selection.


The fresh control-complete clean Kit run reports functional and prospective
LONG coverage passes:610.072722 observed seconds through36,600, all73,200
required authority controls,152/152 complete cycles,1,069 action joins and
1,220 original complete-state comparison receipts. Both actors report1,227
matched effects, natural exits, clean application/Core shutdown and complete
disk intake. There are no gaps, missing or changed records. Source, driver,
wrapper and official Godot identities remain bound. Independent saved audit
verifies the original raw/index/archive chains, all control bodies, canonical
state bytes and comparison receipts, cycles, effects, duration and cleanup.
This establishes clean primary-pair functional coverage on the recorded graph; impairment, lifecycle/rejoin and explicit GateB remain open.
The earlier missing-control600-second attempt remains incomplete.


The same-graph modeled10ms-latency/1ms-jitter short300 case passes the strict
checks and independent saved audit. The subsequent single impaired long
attempt fails: repeated recoveries leave Client original280 unsampled and
rebased past the36,600 target. Only seven paired complete-state exports were
recorded, with73,693 missing decisions and1,067 missing effects. The
prospective checker stops at its intent/recovery observation bound. The
Client exits with failure and selfreported clean application resources; the
controller terminates the Host, whose final cleanup is unverified. Complete
disk intake and unchanged source bindings do not waive these failures.
No retry, threshold change or inferred transport/caller-policy fix follows
from this attempt. Saved classification is pending; GateB remains open.


The optional World timing feedback implementation is now frozen for focused
validation. Its checked send path records actual local transport acceptance;
feedback remains separate from authority admission. Source review cleared the
World changes and the caller packet-inspection fixes, and ordinary Example
script generation completed with unchanged production sources. No feedback
runtime result is claimed yet. Safe teardown is still open: a declined owner
drop must retain the Runtime and transfer cleanup into durable Core ownership
before Node storage disappears. That handoff is currently a design proposal.
Pure caller tests proceed independently; they cannot establish wire or owner
lifecycle correctness. Gate B and P5 remain gated.



## Independent review and simpler input-feedback repair

The independent Claude review exposed an input-fidelity gap in the recorded
acceptance evidence. Root reproduced the archive queries: Replay's authority
used Held zero controls for the remote seat on all36,600 ticks in both recorded
clean and impaired long runs. Those original results still establish their
recorded state-integrity properties; they did not establish that client
movement reached the authority. In Kit, all269 joined client actions coincide
with Submitted control rows, while all36 unjoined actions coincide with Held
rows. This proves fallback/no timely admitted proposal, but does not supply
missing packet arrival or validation timing.

The optional TIMING1/INPUT2 and related retirement integration are frozen.
Existing artifacts and code remain preserved, default timing stays OFF, and
their additional functionality is not on the next experiment's critical path.

The minimal repair reuses Replay's existing input_newest field and timing
controller. Its complete-physics snapshot path now calls the existing feedback
routine after successful verification, and that routine no longer bypasses
physics clients. The same public complete-physics test failed with inactive
feedback before the change and passed afterward with a real nonzero control
admitted and committed. Five existing generic timing regressions also passed.
No packet, schema, input admission rule, clock algorithm, head setter or resource
limit changed.

The first live run with that repair still used held zero remote controls on
all11,400 ticks. Read-only observations in a subsequent4,200-tick run showed
lead2, accumulating stalls/catch-ups and no received control sequence. The
remaining minimal change removes the physics-only exclusion from the existing
Welcome RTT lead seed, retaining its formula and2..6 clamp. A genuine zero-RTT
public Welcome regression failed at lead2 before the change and passed at
lead4 afterward; the feedback test and five generic timing regressions passed
on the same source.

The next live32-body pair, with10ms latency/1ms jitter/loss0, completed69.878
observed seconds to tick4,200. Authority remote controls were Sample on4,184
ticks (99.62%), including2,822 nonzero values; the only Held run was16 startup
ticks. All35 client issues had logical authority counterparts. The original
strict checks passed:2,228 full-five-part comparisons,143 eligible effects,
real final acknowledgement, complete intake and natural exits with cleanup0.
Sampled diagnostics showed lead6, one catch-up and802 timing samples, with no
sampled host input rejections. The original report SHA is
`d4883590e83b789a5309babe26a2bd6c34ce4fe6be5c12d329698798934d1256`;
the independent control audit SHA is
`24e8bf24775033e17cf8bb6b56389137c807fe3c3bbd0f61d77d699e8bcd7dec`.
These are short-run results.

One fresh impaired long pair on the same frozen build completed609.837
observed seconds to tick36,600. The authority used real client samples on
36,343 ticks (99.30%), with24,430 nonzero controls and257 Held ticks; its
longest Held run was43 ticks. All19,844 exported follower checkpoints matched
the authority's five parts, no eligible effects were missing or changed, and
both processes exited naturally with complete intake and cleanup0. This
demonstrates sustained input delivery on this recorded run.

The original LONG result remains **FAIL**. One recorded recovery advanced
confirmed15791 to baseline15808. All34 missing post-admission decisions are
the two seats' class0 controls at15792..15808, inside that17-tick interval.
The recovery occurs after the frozen admission1+3600 deadline; no exemption
was granted. The existing checker stops at that deadline failure, so its
remaining checks must not be presented as passed. The original report SHA is
`d1eb8c40915eb28f8ccb0c70fe4bd8b3f4b5b98b5b328ed26b451f7b4fe6c1ee`.
The actual resync trigger was not logged. Additional protocol work is parked;
the next bounded investigation should record the existing recovery reason
before deciding whether the prospective recovery requirement should change.
The independent saved audit SHA is
`9c88e6be6c9cb2f83b92e9f7b3a9c1e8fbcce675f38b536903ebacf3cd37dfea`.
It also found logical counterparts for all305 client issues, with no reported
serial difference; missing incarnation metadata remains unavailable.

A caller-only diagnostic now records changes to the existing retained resync
notice around the unchanged session-frame call. It labels trigger fields,
after-call observations and latest-only limits separately. Its confirmed field
comes from the journal, unlike the timeline-confirmed value in WAIT. In the
subsequent609.848-second impaired pair, no notice or recovery occurred, so the
earlier trigger was not reproduced. Raw rolling checks passed with no missing,
changed or extra decisions/effects,20,445 matched five-part exports, a real
final acknowledgement and natural cleanup0. Authority controls were Sample on
36,559 of36,600 ticks (99.89%), with41 Held and a longest Held run of15.

That run's original LONG result is also **FAIL**, for a different reason: only
62 of152 cycles fit its fixed authority window. All152 actual Spawn pairs had
one success and one Predicate rejection, but90 client successes executed before
the window's original-due-minus-one start. For example, the client Spawn due760
executed757 and the host Spawn was rejected760; the window begins759. Early
execution is valid under Receipt timing. This identifies an exercise/window
mismatch rather than missing contests or a state mismatch. The original report
SHA is `907f0a8cb9003ac756e006a43b44480cbe1b27d11088837c637dc193cb70903c`;
independent audit SHA is
`777feeb7d521ad6e784100502091572d00184fb3f1359635d2b823d084d62e07`.
The next narrow scenario change waits to sample a fresh client Spawn until the
existing authority frontier can place it inside that window. The original
eight-tick submission bound and checker remain unchanged; issued requests are
never retimed.

That scripted-scenario alignment passed a fresh short functional pair and the
original impaired LONG policy on one frozen build. The long pair completed
609.8668 observed seconds to tick36,600:152/152 verified contested cycles,
152 consecutive cycles,1,069 issue-to-authority joins,21,870 matching five-part
exports, no recovery or missing/changed/extra decisions/effects, a real final
acknowledgement, complete intake and natural cleanup0. All153 observed client
Spawns met both their copied authority-frontier lower bound and the unchanged
sample-within-eight bound. Sample offsets were3..7 ticks; none reached8.
Authority remote controls were Sample on36,521 ticks, Held on79, with24,425
nonzero values and a longest Held run of26. The original result is
`FUNCTIONAL_SOAK_PASS`, with no checker or threshold change. Report SHA:
`e3173a438daf3819a28f7ad19fb717e122046dad4e667100f9bb52dcb28df4dc`.
Independent saved closure SHA:
`9d9439f125508da497240b9ddd7e4520a53e213b321dbb3a161782b30caf49b9`.
This establishes that recorded Replay primary impaired pair. Kit quality and
the remaining matrix keep Gate B open; the prior late recovery's cause was
not reproduced or explained.

Kit's current-call capacity hypothesis now has direct observations. A bounded,
default-off caller diagnostic preserves the old credit helpers and three Lane
calls, records fixed receipt/coverage counters and one by-value account example,
and charges its fixed storage through Runtime allocation. Six pure groups plus
19 saved-JSON records passed. The initial runner setup failure remains preserved.
A fresh actual Kit short pair then passed all strict checks to tick300 with
ten full-five-part comparisons,17 reconciled effects, complete intake and
natural cleanup0. Both constructors reported Runtime size and actual requested/
live Meter deltas of113,328 bytes. Configured service cap120 and physics60
match the latest saved Kit failure configuration; no timing policy changed.

All645 observed NORMAL returns reconciled with valid settlements. Of227
OwnedAll calls, two had positive offer-time capacity exclusion. The first had
8dt pending plus0.5dt newly eligible, offered/owned2dt,6dt still pending and
about0.5dt excluded, with no raw/end exclusion. Its real Lane call advanced
head170 to172 while confirmed165 and received-sequence56 stayed fixed.
This establishes a current-call exclusion while caller-pool space exists;
it does not establish the cause of the old36 lost actions or authorize replay
of historical discarded time. No_Offer capacity exclusions are counted
separately; a null OwnedAll example would not prove their absence.
Original short report SHA:
`7e6ed68cfbb13046d43301b405fb7c5e39135837509506ee74cfb99ba96d9826`.
Independent saved audit SHA:
`d8a8fccc4732e602d5acc3aef16ce7c12c24aec055d70a16c74edb84bd7cf478`.

A prospective default-caller change now retains only current-call capacity
time after a valid OwnedAll receipt, within the same8dt pending limit and
captured target-end budget. Exact offered debit, other receipts, lifecycle,
raw/end exclusions and Kernel limits stay unchanged. The unchanged recorded
vector first failed only the new criterion, then passed with6.5dt pending and
zero net capacity exclusion. Eight pure groups,320 finite properties and the
adjacent-float repeat-settlement control passed. A fresh actual Kit short pair
also passed all strict checks with cleanup0, but it had no capacity clips, so
the positive restoration branch was not exercised live in that short run.

The following original impaired long attempt failed after about161 seconds.
Both processes received GO; target-duration0 means the target was never reached,
not that GO was absent. The first reason7 recovery request was observed about
0.608 seconds after client GO at head8/confirmed0, and the first reset completed
at baseline34 about4.917 seconds after GO. These are collector observation
times, not network timing. The client completed1,001 recoveries and never issued
its first original40 intent; its later rebased submission window was exceeded.
Only one confirmed five-part pair matched before abort. Missing19,350 decisions
and285 effects remain recorded. Client exited1 and reported zero application
resources; the controller terminated the host, whose cleanup is unproven.
The probe stayed reconciled and recorded zero OwnedAll capacity clips, so this
run did not exercise positive restoration or establish its causal effect.
Original report SHA:
`8b87a5e739877e073547a0e6cabe47cfe6d378f78770636ab9656927cb136b53`.
Independent bounded saved audit SHA:
`95b5704856fca04821b1b2a33f1e9d9726d5b0d1c8a44344dddf691d50a322a4`.
No retry, gap waiver, recovery-cause or policy-regression claim follows from
this attempt. Kit's startup/recovery path remains open.

ENet observations at the existing telemetry cadence subsequently captured both
healthy and failed launches of the same frozen Kit build. A190.085-second
diagnostic passed380 complete comparisons,387 effects and95 client issue joins,
with all11,400 remote controls Submitted, no recovery and natural cleanup0.
Its actual OwnedAll example retained clipped time within8dt; the remaining net
exclusion was the positive value2^-57, not zero. Both peers' sampled throttle
remained32. Original report SHA:
`16cfda184bac30f49105e01242ed92f46140f0f62eeba5cdcdd27fdea6d7e8e0`;
independent audit SHA:
`5541e7f3e46f354ff1dac73d59ec2f38cb73969ea9a829b39e2b3200c00b93c8`.
This is diagnostic evidence, not the required600-second case.

The next original primary impaired attempt on those same binaries failed after
about612 seconds. It recorded5,009 reason7 requests and recoveries; fresh intents
originally due40 and160 remained unissued through the final baseline36,600.
Only two complete comparisons matched, with73,930 missing decisions and1,069
missing effects. Client exited1 with self-reported resources0; Host was terminated
by the controller and its cleanup remains unproven. The caller probe reconciled
and included one actual positive restoration, so this failure cannot be described
as an unexercised restoration branch. Original report SHA:
`4497e03279a64863ded94ad0887bb145d8f478c9d97d72dee6e734e96a459280`;
independent bounded audit SHA:
`ba068079fb3cd4ad937a29095e50d49a8462e8b25526b84c6514135adff7a68c`.

Early local windows showed Host application output2.0–2.67 MB while Host ENet
sent0.10–0.25 MB and Client ENet received similar amounts. Host throttle was0,
then2, against limit32. Later throughput recovered to roughly3.9 MB per window
while the recovery storm continued. The first request precedes the first
post-GO backend sample. These differently scoped windows do not establish exact
packet loss, queue size or a complete causal chain.

Godot4.7.1's [vendored ENet](https://github.com/godotengine/godot/blob/4.7.1-stable/thirdparty/enet/protocol.c#L1338)
scales its reliable in-flight window by the throttle, with an MTU floor, and also suppresses
unreliable commands. Kit sends checkpoint chunks reliably and accepted/input
rows on Stream. A bounded test-only loopback experiment will compare existing
ENet throttle settings using the same compiled binaries. Production transport,
Gate B criteria and all historical results remain unchanged; disabling RTT
deceleration in that experiment is not an Internet transport remedy.

The test-only experiment reused those compiled binaries with a separate Godot
autoload. Its initial setup failed before connection because a scene-pointer
guard was invalid; that attempt remains preserved. A corrected guard checked
actual ENet transport absence before registering the observers. Both subsequent
arms verified the real Host configuration before its first incoming scene
packet: interval5000/acceleration2, with deceleration0 or32 respectively.
Both completed70.063 seconds to tick4200 with140 complete comparisons, no
missing decisions/effects, no recovery and natural cleanup0. Every one of the
71 backend samples per role had throttle32 in both arms. The aggressive arm
therefore **did not induce the proposed mechanism**; these healthy short runs
do not establish causation or a production fix. Their report SHAs are
`c94747545fb95e6277feb20ca25eff46747753e7d1b54abfc7673cc2d7f87859`
and `5d4480e3bb7d59873186f1c316e26f1fdf012284020f0a215e8d739e29b750bb`.
No600-second/Gate B acceptance or automatic tuning follows.

A separate read-only archive diagnostic reports submitted/held controls,
held runs and actual values, flagging a wholly held zero remote seat as
degenerate input fidelity. Existing LONG criteria and historical pass/fail
records remain unchanged. Logical identity across recovery, bounded logged
late recovery and a possible state/input gate split remain prospective design
decisions; none is an automatic acceptance waiver or P5 unblock.
