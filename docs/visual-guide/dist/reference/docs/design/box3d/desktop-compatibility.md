# Box3D desktop compatibility

Evidence snapshot: 2026-11-02. This describes the shared backend and **distinct
Kit and Replay** adapters. The initial target pair remains macOS arm64 and Linux
x86_64; a configured CI job is not an executed platform qualification.

## Tested and untested configurations

| Configuration | Kit | Replay | Actual scope and limits |
| --- | --- | --- | --- |
| macOS arm64 SDK/Native, official universal Godot launcher | Exported pair PASS | Exported pair PASS | Native ARM64 processes on macOS15.8; target120, complete five-part bytes/signature, nonzero remote inputs, final ACK, natural exits and observed cleanup/one Native image. No Intel/universal SDK claim. |
| Linux x86_64 userspace/export, Rosetta in Linux aarch64 VM | Exported pair PASS | Exported pair PASS | Actual ELF x86_64 Host/Client execution, **translated functional** evidence. Native Debug/Release twelve registered commands each were invoked by the direct runner; recorded CTest-run verdict is false, not rewritten to PASS. |
| Native Linux x86_64 hardware CI | Not executed in these records | Not executed in these records | Intended CI target. Workflow/plan/source checks do not certify a remote job, throughput or hardware behavior. |
| macOS Intel / universal SDK | Unqualified | Unqualified | Launcher contains an x86_64 slice, but supplied Core/scripts/modules/Native and selected execution are ARM64. |
| Windows | Unqualified Box3D runtime | Unqualified Box3D runtime | Generic SDK cross-build evidence is separate; no current Box3D exported pair. |
| Web/mobile | Unqualified Box3D runtime | Unqualified Box3D runtime | Generic browser SDK evidence does not qualify this Native shared-domain profile. No mobile/export claim. |

The authoritative [Gate C report](../../../tests/box3d_gate_c/report.json)
(`066df8b4a4ecbd8d97d505f06d3eeed6ebe044d5207b144016ba0a6a1dbac9ca`)
binds all four export/runtime records, raw PIDs, artifact hashes and source fences.
Each pair reached120; all five parts matched within that pair. Each role observed
one Native image and Native/wrapper/Meter cleanup0, with sample-owned owner delta0
against its actual baseline4. This is neither cross-platform state equality nor
a new long-soak, frame-time or manual pixel/usability certification.

The later [production suite](../../../tests/box3d_production/report.json) adds
current Kit and Replay exported108600-tick pairs on both configurations, each
with more than1809 seconds after both GO observations, complete five-part equality,
terminal ACKs, natural exits and observed cleanup. All eight300/3000ms service-pause
cases passed. These headless authored scenes contain four bodies/four assets/one
hinge; the separate Native stress bounds are unchanged. Sampled process RSS peaks
were below129MB on macOS and186MB on translated Linux. RSS is separate from the
64MiB tracked physics admission limit and is not a general process-memory bound.
See [production-validation.md](production-validation.md) for allocation-lifetime
regressions, the preserved earlier OOM/audit failures, CPU scope and exact records.

**Deployment floor:** the launcher plist declares11.0, but that is not the
bundle requirement. The actual Kit export inspection `inspect-rpaths-1..5.log`
under the report's `p5-gate-c-kit-macos-export-v4` record shows SDK14.4/minos14.0
for the SDK/Native consumers; launcher log0 shows minos11.0. The Native manifest
also records `-mmacosx-version-min=14.0`. Treat this bundle as requiring at least
macOS14.0; actual execution was on15.8. macOS11..13 are not supported by this
bundle, and a claimed minimum is not a substitute for an execution test.

Linux used Debian amd64 userspace in the recorded Podman/Rosetta environment.
The VM6144MiB/container4096MiB/export compiler thread-count1 are build-resource
settings, not a change to the simulation's64MiB admission cap. The Gate C report
records the environment change and its rollback separately from product limits.

## Exact build identity

Both builds use float32, meters/Y-up/right-handed coordinates, fixed60Hz/four
substeps and one simulation worker. Assertions and `BOX3D_VALIDATE` remain on in
Debug **and Release** (`-UNDEBUG` overrides Release's `-DNDEBUG`). Effective
engine/shim flags include `-fno-fast-math -ffp-contract=off`; no reassociation or
FP-policy relaxation is implied by optimized export. Native observation is OFF.

| Recorded input | macOS reference | Linux reference |
| --- | --- | --- |
| Native C toolchain | Nix clang21.1.8, target arm64-apple-darwin; CMake4.1.2; Apple SDK14.4 | Debian clang14.0.6/LLVM14.0.6, target x86_64-pc-linux-gnu; CMake3.25.1 |
| Resolved SIMD | `B3_SIMD_NEON`, width4 | `B3_SIMD_SSE2`, width4; `__FLT_EVAL_METHOD__=0` |
| ABI environment | Little-endian, pointer64 | Little-endian, pointer64 |
| Odin consumer compiler | dev-2026-04; binary SHA `ccdbd934fc1e42bd856cb1a05991d01e8e748b0174a1671cffc99c7812e386f2` | dev-2026-04-nightly:a896fb2, actual amd64 executable in toolchain report |
| Godot/templates | 4.7.1.stable.official.a13da4feb, matching official templates | Same release/revision, actual Linux x86_64 executable/templates |
| Native source library SHA | `bbdc7c61631026f8b322e04897743fe272b60edfd01d5dee7e530c9e7ba4e93d` | `edfe2fd8a1703d61cea7aa30d80d897037b0a30200c14923fee7f0780b156f5a` |
| Native domain build | `7afc14ca1862570db3148210cf94c226f85bd28fb0cdea81c8c20ddd6700b43c` | `1cd4bd6c93ef95f4df9a85f46656a61c836f69d82357e260a77d9e73a9620172` |
| Native domain target | `fbf45171357f68a60c98378b29bee1e6be069545dfbff27cbd0b6a4214d5455a` | `39312e841ef1e4f4e62fe204ea39ef75f632a80737fc60798daad3d9a88bb310` |

The Gate C report's Native and export links contain exact compiler argv, resolved
macros, manifests and deployed file hashes. macOS ad-hoc signing may change the
deployment copy's file SHA; record source-to-deployed mapping and domain identity,
not an assumed identical file hash. The common manifest version vector is
recorded literally as `[1,1,3,2,1]`; catalog-selected recovery formats below are a
separate contract. Build/target identities differ intentionally across targets.

The current production runs reused the later verified archive-cache build on
macOS: source library SHA
`ed2c5fcfa8e0cbba5ee835c8cd9c73c35b6c3e03b4ac4ae1628a1fb946559371`.
The actual signed bundle copies are
`e3264dad2b9d60013bdd5a36e9385b2d62082a74886520e9dfd8e8ce61a8ff1a`
(Kit) and
`df3ddf2629d75cd6b0bf7eed6eb49e5a6eded4796c522644b03039cb201ca0a2`
(Replay). Their recorded domain build/target remain the macOS identities above.
Linux reused
the recorded `edfe2fd8…` Release library and its original direct-command test
manifest. The older Gate C file hashes remain historical inputs, not rewritten
to the newer deployment bytes.

Keep35 bodies/shapes,32 initial dynamics, one joint, eight Native geometry assets,
H128/prediction8/ordinary repair8 and64MiB tracked Native+snapshot+Host/reservations.
RSS, rendering/engine overhead and build VM RAM are separate. Historical100/500
body probes did not expand this admitted profile. A scalar/SIMD/compiler/precision
change requires a new identity and its own evidence.

## Compatibility layers

| Layer | Current declared contract |
| --- | --- |
| Opaque local solver image | Resource2 / normalized solver dump3. Retained geometry/owners and exact compatible build/target/private ABI are required; bytes alone are not a portable saved state. |
| Native canonical recovery | Primitive catalog format1; authored geometry format2; motion catalog format3. Trusted assets, semantic validation, scratch reconstruction and full reencode/compare remain mandatory. |
| Authoring | Schema1 body/shape/resource identity retained; schema2 adds joint/character definitions. Current parsers explicitly accept the supported versions; no native handle is durable authoring data. |
| Owning bake artifact/import | `OGB3ART1`, artifact/import version1,200-byte little-endian header, bounded definition bytes and checked source/shared-bake/content/integrity identity. Load rebakes once and validates before publication. |
| Motion/query API | Version1, independent C/Odin layout queries for all13 records; this is not a recovery or network wire version. |
| Kit network | World protocol2, current catalog/schema identity and signature/accepted-input confirmation. Native/authoring versions do not silently select another wire. |
| Replay network/archive | Documented base protocol7/archive4 plus complete-physics codec/catalog/game/input contract fingerprints. Keep the actual READY/config/identity records; do not equate this with Kit World2 or Native recovery3. |
| Debug/presentation JSON | Version1 with exact16hex epoch/tick/revision and explicit source; visualization is detached value data, outside canonical Game/Side. |

Canonical encoding does not waive Native identity checks or establish mixed-target
network compatibility. Current exports compare Host/Client on the same target;
macOS-to-Linux exact solver agreement remains unclaimed. Unsupported versions,
assets, references or identities must reject before replacing published state.

## Evidence and performance boundaries

- [Gate B](../../../tests/box3d_soak/gate-b-report.json), bounded macOS32-dynamic
  reference: original whole-call4ms requirement met by its declared final artifact
  streams. Older Dense sample9=8.894ms remains FAIL/causeUNKNOWN. Fact-burst CPU,
  Common normal and later Native feature builds are not inferred from that corpus.
- [Authoring](../../../tests/box3d_authoring/report.json),
  [motion](../../../tests/box3d_motion/report.json),
  [editor](../../../tests/box3d_editor/report.json) and
  [authored samples](../../../tests/box3d_samples/report.json) retain their exact
  earlier macOS scopes. [Gate C](../../../tests/box3d_gate_c/report.json) adds the
  four normal exported pair results; it does not retroactively rerun those suites.
- Remote hardware CI and future release qualification need actual job/run records.
  The desktop CLI's default is an inspectable plan, not a runtime PASS. See
  [upgrade.md](upgrade.md) for the required maintainer gates and release changes.

## Later Web showcase evidence (2026-11-03)

The tables above retain their earlier desktop build scope. The later
[Dockyard handoff](showcase-candidate.md) records an executed wasm32 backend and
actual Chrome/Firefox multiplayer through the same reusable integration, plus
a relocated macOS ARM64 SDK pair. Its current candidate is functionally passing
but remains unqualified under the original Firefox correction maximum. This does
not admit mobile or rewrite the earlier desktop hashes/failures. See the
[current build status](../../../tests/replay_dockyard/qualification/handoff-status.json).

A later [bounded telemetry experiment](../../../tests/replay_dockyard/qualification/telemetry-report.json)
on Firefox 159.0.1 retained every operation row until checked close. Its
610-second pair completed seven jobs with matching complete state and clean
Native/Web ownership, but the Firefox normal maximum reached 29.56 ms against
the unchanged 10 ms limit. Deferring telemetry did not resolve the rare stalls;
their cause remains unknown. The attempted encoding reuse was restored after
it showed no measured latency gain. These are separate experimental artifacts,
and the earlier review archive remains unreleased and byte-identical.

A separate allocation-free signature reuse experiment copies a checksum-validated
signature from an already-due, locally owned Snapshot, with exact tick, codec,
epoch and peer scope checks. It preserves fact-before-chunk delivery and uses
fresh encoding when reuse is unavailable. Native tests reduced solver-part
materializations from two to one per recipient and preserved normative full5
bytes, receiver confirmation, failure recovery and balanced resources.

Its declared short Firefox 159.0.1 authority / Chrome 156.0.8078.80 comparison
still rejected the strict maximum: baseline 30.600 ms, candidate 18.299 ms.
Host p95 was 3.799 ms versus 3.800 ms, so no latency gain is established. Both
pairs confirmed all five state parts and cleaned up; neither 60-second case
establishes sustained admission. The unchanged sustained gate was not rerun.
See the [signature reuse report](../../../tests/replay_dockyard/qualification/tx-signature-report.json).

The optional [transaction phase observations](../../../tests/replay_dockyard/qualification/core-phase-report.json)
retain complete call timing and add bounded open/model/capture totals using the
existing clock. Native and native-free Wasm tests cover nil/backward clocks,
failed capture and unchanged state/cleanup. Captured slow calls distribute
differently across the observed envelopes; the cause of the rare wall-time
stalls remains unresolved. No clock overhead or outlier was subtracted.

A later [frame egress change](../../../tests/replay_dockyard/qualification/frame-egress-report.json)
keeps complete-physics authority reception and publication inside the same public
Room call, preparing its Snapshot after the current step. An actual browser
counter run reduced old-head preparations from 486 to zero; native tests retain
normative complete-wire bytes, receiver confirmation, zero-step publication,
permission checks and balanced resources. Both final 610-second browser roles
meet the original normal-frame limits. Firefox authority passes all measured
budgets; Firefox client retains one 45.92 ms actual eight-step correction against
the original 25 ms maximum (3,968 samples; p95=8.599 ms, p99=9.640 ms). That role is
rejected. No outlier was removed and no unchanged sustained retry was run.

The [audio lifetime fix](../../../tests/replay_dockyard/qualification/audio-drain-report.json)
stops and clears voices, then observes weak playback references until the mixer
has released them before graceful quit or scene reload. Controlled active-sound
exit, four simultaneous voices, muted exit and real leave/rejoin/rehost checks
retain their own evidence. The original leaked AudioStreamPlaybackWAV resources
and prior strict latency failures remain recorded. Public Internet validation,
two-person feedback and the failed correction limit remain separate gates.
