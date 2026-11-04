# Independent-process complete physics network validation

P3.5 uses separate Kit and Replay endpoint executables. Each process runs its
existing production session/runner and complete-world transaction path with
32 initial dynamic bodies. The native ZERO backend remains frozen: logical dump
3, resource 2, recovery format 1, and the declared primitive catalog.

The observed transport is **real local TCP framing with a bounded test-only
logical channel adapter**. It is not an ENet/UDP, Godot module, Internet-security
or throughput deployment claim. Kit packets enter `Session`/`SES_APP`/`Lane`;
Replay packets enter its `Transport`/`Server`/`Client`/`Timeline`. The harness adds
no simulation, authority, rollback or canonical game codec. Test models reuse
the primitive fixture and drive public APIs; fixture attribution is retained.

Reliable messages are copied into bounded endpoint buffers and retained in
source order. TCP supplies ordered reliable delivery. Configured logical loss,
duplication and reordering apply only to Unreliable messages; a blackout holds
Reliable messages. Kit Stream's ordered delivery fence is independent of the
Reliable channel. Old transport generations are retired on actual connection
replacement. Source authority/peer metadata comes from the endpoint connection,
not a gameplay field. These callback semantics are explicit and do not model
ENet's congestion/retransmission algorithm.

A separate stdin/stdout barrier advances virtual rounds, supplies test lifecycle
coordination and collects read-only diagnostics. It never sends solver truth.
All physical steps remain fixed 60 Hz/four substeps. Transport scheduling and
measurement clocks do not enter gameplay or frame identity. The relay records
actual logical sends, scheduling, channel, payload size/hash, copy and write
order; endpoints separately log consumed packet channel/sequence/hash and
connection generations. Relay scheduling/writes alone never establish receipt
or state agreement. All queues, captures and caller buffers are bounded.

## Executable cases and assertions

The source is [tests/box3d_network](../../../tests/box3d_network). A coherent build
manifest binds exact endpoint/test/framework sources, commands, native archive
and manifest, and executable SHA256. Output directories are immutable. Separate
per-generation directories prevent restarted sequence numbers from aliasing.

The ordinary corpus passes H128, checks lapped reads explicitly, and compares
confirmed signatures only at matching identity, epoch and tick. Every signature
covers Solver, Game, Side, completed Observations and Occurrences. The final
matched frame also compares all five actual byte arrays. Typed game state and
all overlapping accepted control/action decisions and provenance are compared.
All prescribed spawn/remove/sleep/wake/hinge commands must apply. Native body and
shape peaks must reach 35, contacts stay <=147, and one hinge is retained.
Native allocation keys must actually recycle with increasing generations.

Post-step destruction leaves a pending native end for the following tick. Its
absence, duplicate, wrong tick or overwrite by another removal fails. Completed
same-tick observations are checked separately across destruction. A dedicated
case destroys all source simulation/catalog owners before queued complete bytes
reach the other process, then checks the imported pending end exactly once.

A 24-round blackout deliberately exceeds eight. Prediction must hold, and only
an explicit existing resync/full recovery path resumes; no rewind is shortened
and no live state substitutes for missing history. Epoch reset, old legitimate
packet replay, full published-state preservation, a subsequent healthy suffix,
and reconnect in a new process/transport generation are tested. The rejoining
process also executes spawn/removal and reaches peak 35.

Asset, rules, schema and actual native build incompatibilities and malformed
actual authority packets must leave publication intact. Deliberately faulty
test-only model callbacks violate their claimed identity to prove the first
production divergence trace; this is an explicit negative control, not a normal
compatible game model. The full trace and observed input/repair context are
saved before recovery can hide the mismatch. The native-free inspector verifies
exact trace decode/re-encode. An independent confirmed-comparison fallback uses
a read-only point (from/to=tick, depth zero, source authority 1, sequence zero
unavailable), not prediction lead mislabeled as rewind depth.

Replay presentation evidence comes from actual `view.drain` changes, including
payload/previous payload. Begin/Update/Cancel/Confirm transitions are audited.
Every confirmed delivered ID/payload is reconciled with authoritative expected
occurrences after welcome, with explicit reset/rejoin baseline exclusions.
Missing or duplicate confirmed deliveries fail. Kit actual deferred callbacks
are tracked separately from its authoritative occurrences.

Each process separately checks native engine, snapshot wrapper, provider and
Odin ownership plus test socket allocations. Conservative independent requested
high-water sums remain <=64 MiB; RSS is reported separately, not subtracted as
an invented exact ownership overhead. Shutdown success requires actual zero
exit codes and zero owners before a result is marked successful.

## Corrections exposed during development

The retained failed reliable-backlog case showed an obsolete ordinary Correction
occupying Kit's sole assembly after one reset request, discarding the later
Reset. The owner added a narrow guard after normal header/auth/epoch/stale checks.
The stale accepted-input case then showed a valid old epoch poisoning readiness;
the owner preserved full old-packet validation but ignored it before current
window/ledger/replay admission. Both source changes have separate failed-before
and pass-after public regressions and owner reports. Historical P3.1 and pilot
artifacts are not relabeled as the new source.

Early fixture/logging corrections (missing pre-welcome history, Replay sensor
ray selection, initial gameplay event capacity and startup epoch on rejoin) are
retained as harness development history. They are not production gate results.

## Result scope

Final target/configuration counts, exact manifests, traces and owner/resource
measurements are recorded in the P3.5 stored report after the frozen matrix.
Mac and Linux physics are checked separately; their solver digests differ.
Linux runs x86-64 through the retained Podman/Rosetta VM and does not certify
native Linux throughput.

Whole-call depth-eight correction CPU <=4 ms remains **UNMET** GateB/P4.4 work.
This functional networking gate does not waive it, certify playable performance,
complete P5/P6 deployment, or declare the full implementation goal finished.

## Frozen final functional results

The acceptance source/controller set is `box3d-process-validation/frozen-final`.
It includes the exact local STEP0/head-confirmed=8 observation, one public Kit
reset request while Reliable traffic remains held, complete pair preservation
and no new cosmetics while awaiting that recovery. Historical `final-v1/v2/v3`
and earlier pilot directories remain separate and are not acceptance results.

| Target | Framework | Debug/Release cases | Confirmed comparisons in full corpora | Process lifetimes | Conservative requested-byte maximum |
| --- | --- | ---: | ---: | ---: | ---: |
| macOS arm64 | Kit | 18 | 532 | 40 | 40,426,314 |
| macOS arm64 | Replay | 18 | 1,214 | 40 | 43,713,222 |
| Linux x86-64/Rosetta | Kit | 18 | 532 | 40 | 40,425,338 |
| Linux x86-64/Rosetta | Replay | 18 | 1,219 | 40 | 43,711,062 |

All 72 cases passed. All 160 endpoint process lifetimes exited zero with native,
wrapper, provider, Odin and C socket ownership zero. Sixteen full corpora cover
two impairment seeds, H128 wrap, actual applied lifecycle verdicts, native key
recycling, mandatory pending-end deadlines, explicit deeper-than-eight recovery,
epoch/stale preservation with a healthy suffix, and a new client process in the
current authority epoch. The restarted process physically observes 35 bodies and
shapes through its own diagnostic sink, independently of imported game history;
its two post-rejoin spawns/removals/ends and applied verdicts are asserted.

Replay effects are checked from actual journal changes, including all four
speculative transition kinds and exact final confirmed payloads. Kit effects
are post-local-commit callbacks; a legitimate predicted cosmetic before an
explicit reset is recorded separately from confirmed eligible spans. Welcome,
reset and committed epoch baselines are explicit. No skipped-past callback may
be newly emitted while a full reset is pending. Both generation-1 post-epoch and
generation-2 post-welcome effect spans must reconcile with authority records.

Each target's `matrix-report.json` and endpoint manifests identify exact sources,
native archives, executables and commands. Every case retains actual generation-
scoped send/receive traces and SHA-addressed packet bytes. Induced production
traces on both frameworks pass the native-free inspector's exact roundtrip.
Root independently audits the frozen artifacts; its audit and the stored P3.5
report retain the complete paths and hashes. These results establish the named
functional network contract, not the remaining whole-CPU GateB requirement.
