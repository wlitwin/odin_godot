# Web and mobile target evaluation

This P6.6 evaluation covers browser wasm32, Android arm64 and iOS arm64 after
the scoped desktop work. It authorizes no platform port, dependency/tool upgrade,
production integration or new supported-target claim. Kit and Replay retain
distinct adapters over one shared Box3D backend.

Root's finite installed-tool probes establish the fragments below. They do not
link or execute the Native implementation, make a foreign call, export a game or
run on a device. `UNAVAILABLE` means not measured or not demonstrated; it is never
zero cost, desktop-inherited performance or a successful platform integration.

| Prospective target | Installed-tool/ABI result | Complete Native/full5 runtime | Kit deployment/runtime | Replay deployment/runtime | Solver determinism | Snapshot bytes and operation cost | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Browser wasm32 | Emscripten public-header LLVM compile0: pointer32, assetV2 size64/align4. Kit and Replay physics Odin checks0. | UNAVAILABLE | Integration unqualified; see gaps below | Integration unqualified; see gaps below | UNAVAILABLE | UNAVAILABLE | **DEFER production admission** |
| Android arm64 | Freestanding C header LLVM compile0: pointer64, assetV2 size72/align8. Odin authoring check **exit1: `ODIN_ANDROID_NDK not set`**. | UNAVAILABLE | NDK configuration/deployment unqualified | NDK configuration/deployment unqualified | UNAVAILABLE | UNAVAILABLE | **DEFER production admission** |
| iOS arm64 | Apple SDK18.2/header LLVM compile0: pointer64, assetV2 size72/align8. Odin authoring `darwin_arm64` + `iphone` check0. | UNAVAILABLE | Target artifact/export/device proof absent | Target artifact/export/device proof absent | UNAVAILABLE | UNAVAILABLE | **DEFER production admission** |

Actual commands, source/tool versions and logs are retained in:

- [Tool readiness](/tmp/odin-box3d-goal-t4jbbj4v/p6-target-tool-readiness-v1/report.json): Emscripten5.0.6-git, Node24.14.1 and wasm-ld present; conventional NDK location and selected PATH checks are not an exhaustive machine-wide inventory.
- [Target probes](/tmp/odin-box3d-goal-t4jbbj4v/p6-target-probes-v1/report.json): the two header compilations and Kit/Replay freestanding wasm32 type checks above. Existing Native-free protocol `All`, Node imports and verification exit0; native/WASM golden signature480, trace1325 and descriptor32 bytes match exactly.
- [Mobile probes](/tmp/odin-box3d-goal-t4jbbj4v/p6-mobile-probes-v1/report.json): real Apple iphoneos SDK18.2/clang/header and iOS authoring checks; Android authoring check exit1, with `Error: ODIN_ANDROID_NDK not set`. Preserve this failed check separately from the successful freestanding Android header compile, which required no NDK/runtime.

The initial devshell Apple probe exit255 remains retained: its `xcrun` was a Nix
xcbuild shim. The separate actual `/usr/bin/xcrun` query succeeded, and the Apple
child used explicit `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
with `SDKROOT` unset. iOS SDK absence is not an observed blocker. Odin's actual
mobile mechanism uses `darwin_arm64` with `-subtarget:iphone`, or `linux_arm64`
with `-subtarget:android`; no standalone invented mobile OS target is implied.

## Distinct adapter/deployment gaps

| Target | Kit | Replay |
| --- | --- | --- |
| Browser wasm32 | Physics package type-checks. Existing generic Kit Web transport does not supply a selected wasm Box3D archive, shared Native/domain deployment or complete-physics runtime proof. | Physics package type-checks. Existing RTC/WebSocket surfaces do not supply that selected backend/domain integration or complete-physics runtime proof. |
| Android arm64 | Authoring type-check stops at missing NDK configuration; no qualified mobile Native library, SDK export, one-domain load or device execution. | Same concrete NDK configuration blocker and absent target artifact/export/device proof; no recovery or snapshot-cost result. |
| iOS arm64 | Authoring type-check and header feasibility pass; Native implementation, SDK integration/export/signing/loading and device ownership/recovery proof remain unexecuted. | Same positive feasibility fragments and unexecuted target-specific pipeline; Darwin arm64 desktop results do not qualify the iPhone subtarget. |

The existing Web route compiles Odin freestanding wasm32/PIC AOT and links an
Emscripten side module, but its selected link/deployment path does not currently
provide the Box3D backend/profile/domain integration. Current desktop scripts,
profile preparation and authored GDExtension declarations likewise provide no
qualified mobile pipeline. Existing Darwin/Linux loader branches can include
mobile subtargets; these gaps are not proof of engine impossibility.

## Existing contracts a new target must satisfy

1. **Actual C ABI and pointer width.**
   [Native `api.h`](../../../box3d/native/api.h) exposes fixed-width handles and
   `ogb3_abi_layout`; its domain contract records pointer bits, byte order and
   versions. Odin mirrors query C sizes/alignment/offsets before use. Pointer-
   bearing authoring descriptors require their own layout query:
   [`authoring_catalog.h`](../../../box3d/native/authoring_catalog.h) documents
   size72/align8 only for the supported64-bit layouts. Those values cannot be
   copied into a wasm32 binding. The opt-in Native observation test ABI has its
   own64-bit-pointer requirement; it is not evidence that every base C value
   interface universally requires64-bit pointers. The observed header/layout
   compilations establish those particular ABI/type fragments, not an actual
   cross-language foreign call or solver execution.
2. **Effective FP/SIMD configuration.**
   [CMake](../../../box3d/native/CMakeLists.txt) uses C17/GNU extensions, Clang/GCC,
   active assertions/validation, `-fno-fast-math` and `-ffp-contract=off`.
   The [Native driver](../../../build/build_box3d.sh) checks effective commands
   and records compiler-resolved precision, SIMD, pointer-size, byte-order and
   evaluation macros. Target/compiler/SDK/options enter target identity. Matching
   architecture names or FP flags alone do not prove equal trajectories, and a
   browser/mobile build must not silently weaken the existing policy.
3. **Snapshot and recovery identity.**
   [Opaque snapshots](../../../box3d/native/owned_snapshot.h) are owned exact-build
   local resources, with destination callbacks and separately restored application
   mappings. Their normalized dump is not a portable loader. Canonical
   [`recovery_codec.c::read_header`](../../../box3d/native/recovery_codec.c)
   requires matching build/target, profile, assets, schema and versions before
   bounded DTO validation/reconstruction/re-encoding. Current primitive1,
   authored2 and motion3 catalog contracts are explicit. Little-endian wire bytes
   and SHA-256 agreement do not authorize cross-target Native recovery.
4. **One Native image and managed ownership.**
   The domain cookie identifies the loaded image, not durable data; callers must
   validate/pin the same backend before exchanging handles. SDK/Core code/data
   owners and exact allocator leases remain mandatory. The existing
   [shared profile/deployer](../../../build/box3d_profile.py) handles desktop
   `macos|linux|windows` library forms; an arm64 name or copied desktop DSO does
   not establish Android/iOS deployment. New target integration needs actual
   consumer-symbol/load inspection, target metadata and one-domain handshake,
   followed by typed teardown and observed owner baselines. It must not embed a
   second engine independently in Kit, Replay or each script module.
5. **Target runtime and cost evidence.**
   Keep35 body/shape,32 initial dynamics,one joint,eight assets,64MiB admission,
   H128/prediction8/repair8 and authority contracts. A meaningful target fixture
   must execute actual complete solver+Game+Side+Observations+Occurrences,
   compare retained full5, roundtrip canonical state, continue after source
   release, reject invalid/bounded cases and clean up real owners. Record actual
   snapshot storage/canonical byte sizes and whole-entry capture/restore/normal/
   repair costs with their units, boundary, tools and raw outputs. If that fixture
   cannot execute, those results remain UNAVAILABLE; a header compile, pose list,
   Native-free codec run or desktop measurement is not a substitute.

## Evidence retained separately

The [desktop compatibility contract](desktop-compatibility.md),
[production report](../../../tests/box3d_production/report.json),
[bounds report](../../../tests/box3d_bounds/report.json),
[recovery-flow report](../../../tests/box3d_recovery_flows/report.json) and
[release policy](release.md) retain their admitted scopes and preserved failures.
Native macOS arm64 and translated Linux x86_64 functional/export results do not
establish native Linux hardware, Windows, remote CI or any target in this matrix.

Native-free WASM signature/trace vector agreement is diagnostic format evidence,
not Box3D solver determinism or snapshot performance. Historical mismatch traces
also keep their historical build/target identity when a current inspector reads
them. No old report, raw outlier or failure is rewritten by this evaluation.

## Bounded recommendation and next proof

**DEFER production admission for all three targets.** The positive header/type
fragments justify considering a separately scoped, bounded port spike; they do
not authorize one automatically or establish a new shipping target. Android's
failed authoring check additionally requires a genuine configured NDK before
that type-check result can change. Do not retry with a fabricated environment,
copied desktop backend or silently weakened policy.

Any future spike must bind its actual target toolchain/SDK and FP/SIMD identity,
link the selected pinned Native implementation through one checked domain, then
exercise Kit and Replay separately through actual target export/load/runtime.
Require complete5 and canonical roundtrip/continuation, real owner/resource
cleanup, malformed/boundary rejection, and target-specific raw determinism and
snapshot/storage/whole-operation cost records. Mobile needs device execution;
browser needs the actual browser/module/memory integration. Until those proofs
exist, all physics equality, snapshot byte sizes and costs remain UNAVAILABLE.
This evaluation changes no desktop guarantee or historical report.
