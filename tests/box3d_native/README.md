# Native snapshot lifecycle acceptance

This suite tests the framework-neutral backend only. Run the reproducible native
build driver; its CTest `lifecycle` target uses `lifecycle.c`. For Odin integration,
use `nix develop --command bash tests/box3d/run.sh /absolute/path/libogb3.a`.
The Odin test runner must use one thread because the initial backend has one
caller and one global engine allocator/world domain.

The native suite tests independent construction in different world slots, 90
paired stepping ticks, 180 retained independent baseline states, and two restored
branches of 180 ticks each. Every replayed tick compares normalized bytes against
the independent baseline and a scratch world. Tests also cover actual contact
impulses, motor settings, sleep time and free-list order mutation controls;
sensors and both end buffers; userData clearing/rebinding; forced sleep directly
after restore; future handle disappearance and numerical reuse; and source/clone
geometry ownership for hulls, meshes, heightfields and compounds.

`state_dump.c` emits scalar fields individually, without struct padding or
pointers. `fields.json` lists generated scalar members, including nested types;
`generate_fields.py` regenerates those emitters from the exact pinned Clang AST.
Manual active-union and variable-length dispatch is adjacent to the generated
code. The dump is exact-build local comparison data, version 4 and coverage
`ogb3-33626332-solver-v4`. It is not a network/recovery codec. Its digest covers
solver state; callers must additionally compare deterministic game side-state
and hold callback/process configuration fixed.

| Pinned `world_snapshot.c` section | Normalized comparison |
| --- | --- |
| Header/configuration | Independent dump version, gravity, tuning, restitution propagation/iterations, isotropic inertia tolerance, locked SIMD width, flags, fat AABBs, step/inverse times, split island, end-buffer index, capacities |
| Six ID pools | Next index and ordered free arrays |
| Solver sets | Set indices and ordered body sims/states, active joint data, contact indices, island sims |
| Bodies | Live metadata, sleep/mass/inertia/forces, generations; free slots retain ID/generation |
| Shapes | Live shape/filter/AABB data; active materials exactly once; geometry by typed content; free slots retain ID/generation |
| Contacts | Linkage/generation, friction/restitution/recycling state, manifolds and warm-start impulses, active SAT/GJK/mesh caches |
| Joints | Linkage/generation and all seven native joint families, active settings/limits/motors/impulses and solver data |
| Sensors | Shape ID and all hits/overlaps1/overlaps2 visitors with generations |
| Islands | Set/local/ID/removal count and ordered body/contact/joint link arrays |
| Broadphase | Tree structure/counters, active nodes and free links, paired nodes, parent/proxy arrays, moved markers, DFS ordering, free sibling pairs and free proxies, pair-set slot/probe layout |
| Constraint graph | Per-color bitsets, joint simulations, convex-contact order and contact specs |
| Pending sensor/contact ends (owned supplement) | Current-index future-delivery queue counts and ordered local shape/contact allocation keys, with full 32-bit contact generations |
| Name cache | Excluded; names and name IDs affect diagnostics only |

Other deliberate exclusions are host addresses, padding, unused union/point/cache
storage, free-slot payload except generation/identity, profiling/rendering,
userData/debug-shape associations, `bodyMoveIndex` output linkage, and unused
geometry-registry history. SAT cache `hit` is a diagnostic counter. Restore
clears completed outputs and resets `bodyMoveIndex`; sensor histories and
current-index future end queues remain. The completed opposite end buffer stays
empty after restore.
Immutable geometry traversal emits typed vertices/edges/planes/BVH data and
compound child transforms/material indices; it never hashes geometry pointers
or registry insertion IDs. Native stored handles can recur after resimulated
spawns, so application identity maps remain adapter-owned.

A snapshot owns its detached native image, normalized bytes and per-capture
geometry registry. Clone creates a distinct owner of the shared immutable
resource. Each imported world keeps a separate lease until replacement or
native world destruction; the destroy hook runs after world teardown. This
per-capture registry contains reachable geometry only, avoiding an append-only
context shared across speculative history. Captures still allocate/copy/intern
geometry; distinct captures duplicate their immutable registry blobs, while clones
of one capture share those costs. This trades cross-snapshot deduplication for
bounded independent lifetimes and must be included in history budgets. `snapshot_metrics` reports native image
used/capacity and geometry blob bytes/count. `snapshot_storage` additionally
reports normalized bytes, wrapper malloc bytes (including normalized storage),
and native unrounded retained requests including registry/dedup/mutex/image and
lazy compound reconstructions. Shared clones report one resource: budget each
resource once, plus additional owner/lease objects. Engine allocation statistics
measure temporary requests and native high water separately.
`snapshot_allocation_stats` accounts for every snapshot wrapper Resource, owner,
slot array, normalized buffer and imported-world Lease, plus temporary
`state_digest` storage; it exposes cumulative calls/bytes and live/high-water
requested bytes separately from engine allocations. Caller buffers, flat API
geometry wrapper objects, and allocator headers/rounding remain outside that
domain. Native tests sweep actual allocation failures at all four capture
allocation sites and at restore Lease allocation, and require both native and
owned live bytes to return to their previous values. Allocator overhead
is not included in requested-byte totals.

Restore accepts only an opaque resource created in the current exact build.
Compatibility/seal checks and a complete nonmutating structural walk happen
before any destructive loader call. There is no public raw-image import. Seven
truncations, eight corruptions and a version mismatch exercise the production
validation path before candidate creation. Three injected resource failures test
cleanup before shell creation, after shell creation, and after complete import
but before publication. All leave published bytes and native live allocations
unchanged. Tests never feed corrupt bytes to the destructive upstream loader and
then attempt ordinary destruction of its damaged partial result.

Engine allocation exhaustion aborts/asserts upstream and is not a recoverable
status in this backend. An unexpected loader failure after a trusted sealed
full preflight is also a fatal exact-build invariant; it is not falsely reported
as a recovered partial-world load. A future untrusted codec must provide its
own full semantic validation and fallible-allocation/cleanup contract.

Three coordinator-approved source patches are required. The free-list patch uses
`memcpy` for pointer loads/stores without changing allocator strides. The
compound patch aligns each packed shared hull/mesh blob while preserving its
explicit offsets and zero-filled padding. `lifecycle.c` directly tests odd
allocator stride 12, plus odd/even compound instance arrays containing capsule,
hull, mesh and sphere children; it restores detached compounds and steps 240
collision ticks after destroying original assets. The broadphase patch runs tree maintenance even when pair-query moves are empty;
destroying the last moved proxy can leave dirty ancestors. Focused dynamic and
kinematic three-body cases reproduce that condition. Dump v2 also ignores the
inactive inline material when an owned material array is active, and emits the
active material representation once. Controls prove inactive mutations leave the
digest unchanged while active array changes are detected. Full ASan+UBSan includes
alignment checking. See [alignment-patches.md](alignment-patches.md) for the
observed alignment errors, source provenance and corrected checks. See
[P1.4 support report](p1.4-support.md) for the broadphase assertion, patch
provenance, v2 normalization and saturated-world fingerprint regression.


P2.4 format correction: historical Gate A/P2.1 v2 evidence remains untouched.
Post-step destruction queues future sensor/contact ends that the upstream raw
image omits. Owned resource version 2 retains them, and logical dump v3 includes
their ordered local IDs. Native tests cover same/scratch restore, detached source
lifetime, generation reuse, exact-once next-step delivery, completed-output
clearing, queue count/order/generation mutation controls, supplement integrity,
capacity and allocation-failure cleanup. Runtime native/Odin state-version
agreement is required before world/provider use; the retained-v2 negative control
expects `Incompatible`, not silent old-format operation. Details and current
artifacts are in [p2.4-pending-ends.md](p2.4-pending-ends.md).
