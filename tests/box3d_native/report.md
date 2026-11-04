# P1.3 owned snapshots and complete solver comparison

Historical P1.3 closure evidence for dump v1. Subsequent coordinator-approved
P1.4 support changes use dump v2 and are recorded in [p1.4-support.md](p1.4-support.md).

Task `t_cfe2df256c194c2d`, board `b_cdde1cdfea104035`, worker
`box3d-snapshots`, completed implementation evidence recorded 2026-10-30.
The supplied task, worker and claim token were verified before editing and
rechecked before closure. No other card was claimed; no agents were spawned;
no commits, publishing, pushes or framework/scene edits were made.

Implemented `owned_snapshot.c/h` and `state_dump.c/h`; native lifecycle and Odin
integration tests are in their assigned directories. The native/Odin build and
binding owners integrated the authoritative headers. Snapshot capture, clone,
release, same/scratch restore, dump/digest, compatibility and memory accounting
are actual linked C/Odin operations. Complete solver bytes/digest remain separate
from the upstream diagnostic motion hash. The coverage manifest and detailed
ownership/failure contract are in [README.md](README.md) and [fields.json](fields.json).

Validation on macOS 15.8 arm64, Apple Clang 16, Odin dev-2026-04 via Nix, Debug,
assertions plus heavy validation, float precision, single worker, fixed 60 Hz/four
substeps, FP contraction/fast math disabled:

- Native static/shared API plus lifecycle CTest: 3/3 pass.
- Full AddressSanitizer+UndefinedBehaviorSanitizer CTest: 3/3 pass, including
  alignment; no undefined-behavior or alignment suppressions.
- Actual Odin integration: 5/5 pass, one test thread.
- Independent world construction/stepping: 90 ticks compare normalized bytes.
  Two restored 180-tick branches compare every tick against retained independent
  baseline bytes and a scratch world. Mutation controls detect gravity, contact
  impulse, motor, sleep time, ID pool and free-list order changes.
- Identity reuse, real sensor begin/end histories, both end-event buffers,
  forced sleep after restore, userData clearing/rebinding and source/clone
  destruction before destination stepping pass. Restored hull/mesh/heightfield/
  compound lifetimes pass, including odd/even compound arrays with all four child
  families and 240 extra contact ticks after original assets are destroyed.
- Seven truncations, eight corruptions and a version mismatch reject before the
  destructive loader. Three staged-resource rejection points safely destroy
  valid candidates. Five actual wrapper allocation failures cover all capture
  sites and restore Lease allocation. Published normalized bytes and native/
  wrapper live totals stay unchanged on failure.
- Final native tracked bytes: 0; final owned-wrapper requested bytes: 0. Native
  totals 4,136 allocations, 9,977,984 aligned requested bytes, peak 1,182,192;
  snapshot/digest wrapper totals 90 allocations, 1,560,762 requested bytes,
  peak 79,592. macOS `leaks --atExit` reports 0 leaks/0 leaked bytes.

Full sanitizers exposed two real upstream alignment errors. Coordinator t12
explicitly approved both additions to the initial file scope:
`box3d/native/patches/block_allocator_alignment.patch` and
`box3d/native/patches/compound_geometry_alignment.patch`. The former uses
`memcpy` for free-list pointer loads/stores at odd element strides; the latter
aligns each packed compound hull/mesh blob. Both preserve existing explicit
offsets/zero fill where applicable, retain MIT notices, and are applied by the
native build owner only to a derived source tree after pristine-source checks.
Their base/patch/result hashes and observed stacks are recorded in
[alignment-patches.md](alignment-patches.md). Original Phase 0 fetched source was
read only. Full sanitizers pass after both fixes, without masking either error.

The owned-resource contract deliberately has no arbitrary raw-image import.
Corrupt/truncated test candidates exercise the production seal/version gate and
never enter the destructive upstream loader. A nonmutating full structural walk
also checks trusted image sections before staging. Native allocator exhaustion
asserts/aborts upstream; an unexpected loader failure after sealed exact-build
validation is a fatal invariant, not falsely claimed partial-load recovery.
Untrusted portable recovery needs a separate codec, semantic validation and
fallible-allocation/cleanup design.

Distinct captures currently duplicate their immutable geometry registries;
clones share one resource. Per-capture registry ownership prevents unrelated
append-only speculative history, but duplicates must be budgeted in retained
history. Metrics expose image/geometry/normalized/native/wrapper bytes and
separate cumulative/native/wrapper peaks. Wrapper counters include Resource,
owner, slots, normalized storage, world Lease and temporary digest buffers;
they exclude caller buffers, flat API geometry wrappers and allocator overhead.
The dump covers solver state only; deterministic game side-state and fixed host
callback/process configuration remain the adapters' responsibility.

Large 100/500-body corpus benchmarks, final optimized/Linux evidence and the
Gate A proceed/pivot/stop decision belong to the coordinator/build work. This
card does not claim portable transfer, framework transactions, cross-target
agreement or production memory budgets. The own scratch Odin link emitted a
macOS 15-vs-14 deployment warning; the tests ran on macOS 15.8 and do not establish
a macOS 14 deployment target.

Machine-readable counts, environment, source hashes and log hashes are in
[report.json](report.json). Detailed logs/builds live under:

```text
/var/folders/f5/n795h3hd5nxbqwzvt3t6bpcw0000gp/T/box3d-goal-t4jbbj4v/box3d-snapshots
```
