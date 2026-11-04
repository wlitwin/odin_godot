# Box3D dependency pins and reuse provenance

Current baseline: Box3D `336263320469e5e9febfe18697ab562488f7e97a`
(October 28, 2026), promoted by the Web Showcase W0 refresh. The July desktop
qualification remains historical and build-specific. See the
[upgrade record](upgrade.md#october-baseline-refresh) and
[current evidence](../../../tests/box3d_upgrade/report.json).
The P0.4 inventory below records the original dependency/reuse decision; its
July pin and patch receipts are retained as provenance.

Recorded 2026-10-30 for task `t_959ce076efb449df` (P0.4), board
`b_cdde1cdfea104035`. This records source/dependency decisions for the native
spike; no upstream implementation is vendored by this documentation change.

## Selected spike dependencies

| Component | Immutable source | Disposition |
| --- | --- | --- |
| Box3D engine and public C headers | `erincatto/box3d@d421e45c828f6f853a145f726f0b9425d31146eb` | Selected native-spike engine pin. Compile one engine instance and include its exact private headers only in the compatibility shim. |
| Snapshot shim reference | `pdaddyo/rollback-in-a-box@9e1fe882a0ea4eb52e160d5754a752580b4db462`, `core/src/rollback_shim.c` and `core/include/box3d_rollback/rollback_shim.h` | Selected starting source for isolated C compatibility code. Ownership, loader failure, event buffers and complete-state digest need explicit work; the existing slot API is not a finished adapter. |
| godot-cpp | `godotengine/godot-cpp@e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77` | Upstream reproduction only, resolved from its `godot-4.5-stable` tag. Not a dependency of the proposed direct Odin/C runtime. |
| Godot executable | `4.7.1.stable.official.a13da4feb` on local macOS arm64 | Observed upstream headless-test environment, not a new project toolchain lock. |

Pinning selects an auditable starting point, not a claim that the current shim
already meets Gate A or that every pair of supported builds agrees. The two
framework adapters use the same engine/shim source and configuration.

The original upstream setup script trusts an existing dependency directory
without verifying its revision. The Odin build must instead verify the exact
commit/content hash, precision, SIMD settings and compiler flags. A branch or
tag name alone is insufficient. The native
build manifest now records source/content pins, applied patches and resolved
simulation/toolchain identities; the earlier P1.1 instruction is completed.

For provenance checks, the inspected original shim files have these SHA-256s:

| File at `rollback-in-a-box@9e1fe882` | SHA-256 |
| --- | --- |
| `core/src/rollback_shim.c` | `3553c8e430d3561230be509803dc3c4e3cfcf4e66442e3d7033fe99fd52ef921` |
| `core/include/box3d_rollback/rollback_shim.h` | `992c796ac3b6c79580992378ee10ee4a6dcd3b962c1ef557233b546aee0ab24e` |

These identify the reference files before local modifications. Record subsequent
changes as a patch against that source rather than presenting a modified shim as
an unmodified upstream file.

## Source and notice inventory

| Source | Inspected notice | Reuse boundary |
| --- | --- | --- |
| [Box3D LICENSE](https://github.com/erincatto/box3d/blob/d421e45c828f6f853a145f726f0b9425d31146eb/LICENSE) and engine source headers | MIT, copyright 2026 Erin Catto; preserve individual file headers as recorded. | Engine/public headers/private snapshot code may be the pinned native dependency. Retain source notices and distributed license text. |
| [Box3D `src/qsort.h`](https://github.com/erincatto/box3d/blob/d421e45c828f6f853a145f726f0b9425d31146eb/src/qsort.h) | Embedded MIT notice, copyright 2013, 2017 Alexey Tourbin. | Preserve this embedded notice; the root engine notice does not replace it. |
| [Box3D `src/verstable.h`](https://github.com/erincatto/box3d/blob/d421e45c828f6f853a145f726f0b9425d31146eb/src/verstable.h#L412) | Embedded MIT notice, copyright 2023–2025 Jackson L. Allan. | Preserve the embedded notice when distributing the engine/source or derived runtime package. |
| [rollback-in-a-box LICENSE](https://github.com/pdaddyo/rollback-in-a-box/blob/9e1fe882a0ea4eb52e160d5754a752580b4db462/LICENSE) | MIT, copyright 2026 Paul Barrass. | Preserve with reused C shim/header or adapted generator code. The shim's lack of a per-file copyright header is not a reason to discard the repository notice. |
| [godot-box3d LICENSE](https://github.com/bearlikelion/godot-box3d/blob/f073c2de2523bf12163095e920347881352dc8a9/LICENSE) | MIT, copyright 2026 Mark Arneman. | Reference-only during the spike. If compatibility/query code is later ported, preserve this notice and the exact source/patch provenance. |
| [box3d-godot root LICENSE](https://github.com/Stink-O/box3d-godot/blob/72bf5f2f9a803e18949507f46dc38916be21ca1c/LICENSE), [addon LICENSE](https://github.com/Stink-O/box3d-godot/blob/72bf5f2f9a803e18949507f46dc38916be21ca1c/godot/demo/addons/box3d/LICENSE) and Godot source SPDX headers | Root MIT notice names Erin Catto. Packaged addon explicitly names Stink-O for the extension and Erin Catto for the engine; source names box3d-godot contributors under MIT. | Editor/custom-node reference only until later selective reuse. Preserve all applicable engine/extension/contributor notices for any port. |
| [godot-cpp LICENSE.md](https://github.com/godotengine/godot-cpp/blob/e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77/LICENSE.md) | MIT, copyright 2017-present Godot Engine contributors. | Reproduction dependency only. Include its notice if redistributing reproduction artifacts or later linking it; direct Odin/C integration does not need it. |
| multi-box-3d `987f4ca44d0065676f17cab35edad57fcbb63b13` | No root license/notice or game-wide licensing statement located in tracked files. `addons/godotsteam/license.md` covers that separate addon. | Build/run and inspect as the original behavioral reference; do not copy its game implementation/assets into odin_godot based on the unrelated addon notice. Write the Odin scenario independently. |

The inventory was checked against pinned tracked source and file headers, not
only GitHub's license badge. The missing game-wide notice does not block the
chosen engine and shim dependency, which have their own recorded source notices.

Box3D's library target also builds the included sorting/hash-table headers above.
Its sample tree contains other third-party components, and enabling profiling
can fetch Tracy. Keep sample/benchmark/UI/profiling fetches outside the minimal
native library build; if additional code is enabled or distributed, extend this
inventory to that actual dependency closure. Source-only references and locally
built upstream demos do not mean all of their dependencies are adopted by Odin.

The original P0.4 plan deferred production notices until adoption. The adopted
closure is now recorded in [THIRD_PARTY_NOTICES.txt](../../../box3d/native/THIRD_PARTY_NOTICES.txt)
and each Native manifest. Preserve these and individual embedded headers in
source/binary distributions, together with the repository's Apache-2.0 notices;
separate upstream MIT components are not relabelled as repository-owned code.

## Current adopted source and patch set

The current engine tree is `50877041b7e4de95ff0b6c194182aa50d453b736`,
with git-archive SHA-256
`a9143675b297bb6c6f3d031d1bdf5c265d8642139eea26f265958066bd947935`.
`engine_patches` is empty: upstream rounds block allocator strides to alignment,
packs compound geometry at aligned offsets, and replaces the old broadphase
with paired nodes/parents/proxies. Lifecycle tests retain alignment/free-list,
compound ownership and last-moved-proxy destruction regressions.

The rollback reference pin remains unchanged. Its C shim is adapted by
`rollback_shim_box3d_33626332.patch` (SHA-256
`92cc54f8c2dfc27de6d09f92accebbb5f6e8356099c4b75ac6bf03227f63568d`),
whose declared output and reversed upstream preimage are verified by the build
driver. It changes private registry/replay-header/SIMD access. The copied header
and all original reference hashes remain recorded in
[dependency.json](../../../box3d/dependency.json). Local wrapper/snapshot/recovery
code remains independently hashed. License text and original notices are retained.

The admitted backend explicitly selects SIMD width4 through upstream's runtime
dispatch API. Compiler-resolved macros record the actual available implementation;
the old global `B3_SIMD_WIDTH` macro is no longer assumed. Scalar/web execution
and browser compatibility need their own results. Build/target identities and
logical solver version4 reject old images; fresh bootstrap is required.

## July baseline patches (historical)

The verified motion NativeV2 Release manifest records ABI1 and these exact
changes to the selected engine. The copied rollback shim/header retain the
original file hashes above (`shim_patches=[]`); local owned snapshots, trusted
recovery, motion and API wrappers are separately hashed repository code.

| Engine patch | SHA-256 | Purpose |
| --- | --- | --- |
| `block_allocator_alignment.patch` | `4e1c5c3f567cfbc06987123bc3528a1fe546493faf6db4d4d43b3ac878c90677` | memcpy free-list pointer access for unaligned element strides, preserving layout/order. |
| `compound_geometry_alignment.patch` | `d81f1b8d8488c64d4ca9d3044d64a89cebe78084d2c39b890aedcda8cba531d1` | Typed hull/mesh blob alignment, including odd instance counts and recorded padding/offsets. |
| `broadphase_rebuild.patch` | `f9f69900eb955639745705f057bc838a2284634ff5006c3a2db8bcdbe34b3df6` | Rebuild dynamic/kinematic trees before zero-move early return; preserve nonzero-move task ordering. |

Pinned Box3D tree `6ad02fc909b70c0c2f4c7d6c1bfa6c8dcfd53f7a`, git-archive SHA
`f423100def3aed95b6c653f42bda276a6c830a15163cb36b71c83536dd8e48f9`;
rollback reference tree `7cefe9ae72bd39788473bb318d160fca7eee8a91`, git-archive SHA
`f2f2a2488a1d88d4eb79f448a627b2adc820e36697d07c65a949551aea8e279d`.
These are the manifest's git-archive content identities, not automatically the
checksum of a compressed download. Archive caches must use their declared exact
transport bytes/checksums. Per-file patch base/output hashes and the full local
source closure remain in the Native manifest referenced by
[Gate C](../../../tests/box3d_gate_c/report.json).

## Reproduction pins kept separate

The game baseline is deliberately not advanced to the selected spike source:

```text
multi-box-3d  987f4ca44d0065676f17cab35edad57fcbb63b13
  rollback-in-a-box  91e01dc75e8dfe3fbd890f21361e27b31fa2e994
    Box3D  540ea387b0c02bf714fbfdcc8fb88c039c35fe6f
    godot-cpp  e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77
```

The two authoring/compatibility references were inspected at
`godot-box3d@f073c2de2523bf12163095e920347881352dc8a9` and
`box3d-godot@72bf5f2f9a803e18949507f46dc38916be21ca1c`. They are not the engine
revision used by the native spike. See [reuse-matrix.md](reuse-matrix.md) and
[upstream-baseline.md](upstream-baseline.md) for dependency differences and actual
test results.

## Upgrade ownership and procedure

The **odin_godot maintainer responsible for the shared Box3D backend** owns the
engine pin, private-header shim, binding ABI, snapshot/digest version and release
compatibility table together. Upstream is not responsible for preserving the
private API. The same owner signs off changes affecting both sibling adapters;
Kit and Replay adapter owners review their respective transaction contracts.
This establishes repository responsibility without assigning a new person or
service account.

An upgrade is one explicit reviewed change following [upgrade.md](upgrade.md):
record candidate pins/notices/patches/toolchains; version incompatible boundaries;
validate private C/Odin ABI and full solver/source-free/malformed/rollback paths;
re-earn distinct Kit and Replay transaction/network/recovery/export gates; rerun
applicable scoped CPU/memory/lifecycle evidence; invalidate derived caches and
publish migration/release limits. The historical100/500-body spike benchmark is
not an admission or performance guarantee for the current35-body profile.

The pins remain fixed; this documentation does not upgrade them or promise
compatibility beyond the exact tested builds and targets.
