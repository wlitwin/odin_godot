# Pinned Box3D upgrade and release workflow

The October baseline refresh is recorded below. The backend maintainer owns
the engine pin/private compatibility boundary and signs off with **both Kit and
Replay owners**; deployment/export and authoring/editor owners review their
respective contracts. Upstream does not promise this private ABI remains stable.
Current evidence and unsupported targets are in
[desktop-compatibility.md](desktop-compatibility.md).

## October baseline refresh

W0 selects `336263320469e5e9febfe18697ab562488f7e97a` (October 28, 2026),
30 upstream commits after the preserved July `d421e45c` build. The exact tree,
archive and shim patch are in [dependency.json](../../../box3d/dependency.json)
and [dependencies.md](dependencies.md#current-adopted-source-and-patch-set).
The upgrade evidence is [tests/box3d_upgrade/report.json](../../../tests/box3d_upgrade/report.json).

This port covers the new paired-node broadphase, fat AABBs, BodySim inertia and
safety factor, hull SoA data/edge cosines, restitution propagation/iterations,
isotropic inertia tolerance and runtime SIMD dispatch. Serialized body-sim index
caches are derived from the validated body/set graph on import. Canonical checks
validate tree/proxy/free partitions and bounds before Native construction.

The normalized solver version is now **4**, coverage
`ogb3-33626332-solver-v4`. Resource ownership stays2, the C ABI stays1, and catalog
recovery capabilities1/2/3 retain their framing with a changed solver schema and
build identity. July snapshots and mixed-build peers are rejected. There is no
save converter or native/browser cross-play qualification. Old libraries, demos
and reports remain available in their original outputs.

The current registered Native matrix has **13** cases, including
`upgrade_state_fields`: non-default new settings, canonical read/reencode,
source destruction, full-state equality/continuation and a corrupt paired-tree
moved-marker control. Original allocator/compound/broadphase regressions remain
active after retiring the three old engine patches. The complete matrix covers
existing malformed/allocation/geometry/joint/lifetime guarantees as well.

One existing Replay test assumed a three-tick repair plan despite the actual
Welcome-calibrated lead. The original assertion failed identically on July and
October. Its test-only correction requires a real nontrivial suffix and checks
`head - first + 1`, while retaining checked-prefix1/executed1, error, publication,
confirmation, trace and resume assertions. Both old-library control and refreshed
Replay network suite pass. No production Replay planner changed.

W0 establishes the refreshed backend and bounded native integration; the old
CPU/long-run/export results do not qualify this changed build. Browser execution,
final game performance and sustained qualification belong to the Web Showcase
cards. Native Linux execution under Rosetta is labelled translated functional
coverage throughout.

## Prepare one explicit candidate

1. Freeze the accepted baseline and preserve reports, failures, source patches,
   Native archives/shared libraries, SDK modules, toolchain manifests and exported
   bundles. Never rewrite an old failure as a pass or overwrite a validated cache.
2. Record candidate immutable commits/tree hashes and exact archive checksums for
   Box3D and the isolated rollback-shim reference. Compare the current three
   [engine patches](dependencies.md#current-adopted-patches) against their exact
   base/output files. Preserve notices, embedded third-party headers and local
   wrapper provenance; do not import upstream C++ sessions or godot-cpp runtime.
3. Review private layouts/enums/unions, world and object identity, collision/event
   buffers, pending sensor ends, geometry registries, ownership and error cleanup.
   Update compile-time checks and independent C/Odin sizeof/alignment/field-offset
   queries. A same-size record or motion hash is not a full solver proof.
4. Declare precision/SIMD/compiler/optimization/assertion/FP flags, endian/pointer
   width, OS deployment floor and target triple. Recompute actual Native build
   and target identities; copy/sign changes get actual deployment hashes. Stop
   live worlds/owners before replacing a Native image. Script reload is not a
   backend upgrade. Never independently static-link an engine into each SDK DSO.

## Decide compatibility before accepting bytes

Version/reject each affected boundary explicitly: local resource/dump/private ABI,
trusted canonical recovery catalog1/2/3, authoring1/2, owning artifact/import1,
motion API/layout, SDK ownership/module admission and each framework wire/archive
contract. Preserve declared legacy readers only when their actual tests pass.
Changed stable IDs, geometry/material/filter semantics, rules or side state need
a documented content/catalog migration and new identity. Never reinterpret a
raw local image from a different build as a compatible canonical artifact.

A migration is explicit conversion from a supported old format into new copied
validated definitions/state, followed by normal trusted construction/full5
verification. If no converter is proved, report incompatibility and require a
fresh bootstrap; do not promise mixed-version peers or cross-target equality.

## Mandatory candidate validation

Run fresh registered Native Debug/Release and unsuppressed ASan/UBSan where
supported, from the recorded pins/patches. Retain actual runner/exit semantics;
a direct invocation is not relabelled as CTest. Native tests compare complete
normalized solver state. Framework tests compare Solver, Game, Side,
Observations and Occurrences, not only transforms or cached hashes.

Required controls include clone/source-free geometry and callback/code/data
lifetimes; same/scratch restore, complete canonical export/import/reencode;
malformed/version/hash/reference and failed allocation/capacity cleanup; pending
events/sensors; all six authored shape kinds and eight separate one-joint families;
deterministic queries/character POD; identity/order/collision and corrupt artifact
controls. Preserve35/35/32/one-joint/eight-assets and64MiB/H128/8/8 limits; raising
bounds requires its own approved contract, not a test workaround.

Validate the **distinct** Kit and Replay transactions: staged advance, repair8,
rejection/abort/audit/actions, complete checkpoint/source-free recovery, actual
accepted-input/signature or signed-fact paths, FX/publication and explicit deeper
hold/resync behavior. Run both same-content authored samples through normal SDK
build/import/editor/resource roundtrips, ownership/reload/admission and actual
exported Host/Client pairs on each qualified target. Keep per-target full5,
nonzero remote controls, actual final ACK, natural exit/intake and cleanup/census
proof. No alternate packer, project-only run, raw handle or pose-only substitute.

Re-earn applicable long/lifecycle and whole-call performance gates on the changed
candidate. Record all retained cold/error/outlier samples, normal and repair
operations separately, exact boundary/workload/source/target and memory/RSS scope.
Do not pool unlike percentiles, subtract phases or attribute an old spike to a
change without measured evidence. Unmeasured workloads/hardware remain unknown.

## Desktop orchestration and CI

The concrete orchestration interface is `tests/box3d_desktop/run.py`. It stages an
inspectable plan by default and starts processes only with `--execute`. Supply
explicit official tools and a verified target shared Native library/hash; use a
NEW output **outside the repository**. Example plan (substitute actual paths):

```sh
python3 tests/box3d_desktop/run.py \
  --target macos-arm64 --framework kit --godot "$GODOT" --odin "$ODIN" \
  --native-library "$NATIVE" --native-sha256 "$NATIVE_SHA256" \
  --out "$WORK/kit-macos-plan" --port 45101 --ticks 120
```

For actual execution use a different NEW output and append `--execute`; repeat
separately for Replay. Linux additionally requires `--execution-mode native` or
`translated-linux-x86_64` and `--toolchain-report ACTUAL_REPORT`. A translated
preflight must not be presented as native hardware. The CLI reuses normal Gate C
export and exported-run helpers; the recorded export argv, actual executable,
artifact map and runtime report remain the evidence. No `--path` or
`ODIN_SCRIPTS_DLL` override substitutes for exported execution.

The published CI seam is manual `workflow_dispatch` on explicitly configured
self-hosted macOS/ARM64 or Linux/X64 desktop runners. Source/config/local checks
are not a remotely executed GitHub job. No push, remote trigger or platform
qualification is implied by adding workflow files. Actual CI evidence must bind
its runner/toolchain and all registered tests/exports separately.

## Caches and publication

Cache only declared immutable dependency/toolchain **archives** with full content
keys and checksum validation on restore. A git-archive identity and a downloaded
compressed archive's checksum are different values; validate the one declared by
the cache manifest. Test cold/warm identity and corrupt/wrong-pin/wrong-key
rejections. Native source/patch/toolchain/flags/target changes invalidate derived
builds. Every job still configures, builds and runs the required matrix; never
cache a test verdict, silently admit an extracted mutable tree or reuse target
DSOs as archive-cache proof. Authoring artifacts carry their own checked schema,
source/shared-bake/content identities and are not a dependency cache.

Before release, publish the changed compatibility table, pins/notices/patches,
version/rejection/conversion policy, target/toolchain/deployment identities and
actual Kit/Replay report links. List failures/unavailable jobs, translated versus
native execution, scoped CPU/memory limits and any content/save migration.
Retain old artifacts and a reproducible baseline. A launcher minimum/universal
slice list is not the SDK's deployment floor or Intel qualification. Release
signing/notarization/upload require their own authorization; local ad-hoc Gate C
bundles do not constitute distributed release certification.
