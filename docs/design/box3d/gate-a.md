# Box3D Gate A evidence and decision

**Decision: PROCEED to P2 implementation and testing of a bounded, same-build,
same-target desktop alpha.** This accepts shared-backend feasibility for the
measured small workload; it does not declare an operational alpha, enforced
resource limits or a production real-time guarantee. Larger workloads and
mixed-target physics remain outside this go decision and require a performance
or compatibility pivot before expansion.

Recorded 2026-10-30 for task `t_f5949e23c07a4100`, board
`b_cdde1cdfea104035`, worker `box3d-gate-a`. The
[accepted architecture](decision.md) remains authoritative. P1.4
`t_979cf60bfd7241f0` is done; its persistent report is
`r_a269646bddd647f6`. The finalized
[measurement report](gate-a-measurements.md) contains all per-case timings,
memory, workload counts, reproduction details and artifact hashes.

I independently reparsed all 34 raw logs and checked summaries, raw-log hashes
and native manifests. All 34 workload reference profiles reproduce their
corresponding final complete solver and game digests, including the final Linux
profiles. The persistent P1.4 report contains matching summaries/counts, source
texts/hashes, native manifests and verification metadata. The local raw artifact
roots are temporary working evidence; preserve them for future raw-sample audits
rather than assuming temporary directories are durable storage.

The P2 implementation/test targets are 32 initial dynamic bodies/35 peak total
bodies, H=128, an eight-tick prediction/ordinary synchronous repair window,
4 ms normal and 4 ms correction timed-work ceilings, and a 64 MiB accounted
resource allowance with separately accounted overhead. They retain the measured
normalized-cache/capture costs. These targets are **proposed limits for P2 to
implement, enforce and validate**, not features already supplied by this backend.
The detailed measured basis and failure/pivot conditions below are part of the
decision. No unconditional 100/500-body or 30-tick-in-one-frame budget is accepted.

**Acceptance reviewed.** The required matrix is 32 cases: macOS arm64 and
Linux x86-64, each Debug/Release, 100/500 initial dynamic bodies and seeds
`1`, `7`, `1234`, `3221344269` (`0xC001D00D`). Each case requires 2,400 forward
ticks, H=128 retained frames, fixed 60 Hz/four substeps, seeded depths 1–30,
history wrap and alternate branches. Passing requires exact normalized solver
bytes plus the fixture's deterministic game side-state at every forward and
replayed tick. Equal final poses or upstream motion hashes do not satisfy this.
Credible measured memory and correction costs for a specifically bounded slice
are also required; successful correctness alone does not establish a production
60 Hz or memory budget.

The decision is justified by complete within-build comparisons and ownership
controls, followed by a directly measured small slice with plausible headroom.
The required large matrix supplies correctness stress coverage, not large-scene
latency approval. A pivot is required before expanding body/contact/asset or
history budgets if capture/storage and correction costs remain outside the
chosen envelope. Any future correctness mismatch, unsupported necessary restore
case or unsafe admitted-failure cleanup stops alpha publication until repaired;
Kit/Replay transaction guarantees must not be weakened to retain this go result.

**Build and evidence identity.** The current candidate uses the
[dependency manifest](../../../box3d/dependency.json): Box3D
`d421e45c828f6f853a145f726f0b9425d31146eb` plus the unchanged isolated C shim from
rollback-in-a-box `9e1fe882a0ea4eb52e160d5754a752580b4db462`. It links the C engine,
local flat ABI and owned snapshot/dump modules, with no upstream C++ session or
Godot dependency. Base/archive/tree, copied-shim and local patch/result hashes
are recorded; pristine source and the separately derived patched tree are
verified before builds.

Three explicit source patches are part of this candidate: block-allocator
unaligned free-list access, packed compound geometry alignment, and broadphase
tree maintenance when destruction removes the last buffered move. The first two
were exposed by unsuppressed sanitizers. The third was reproduced in a
500-body **forward-only baseline with no snapshot operations** at tick 1760,
then reduced to public operations on three boxes. Dynamic and kinematic
regressions pass after the narrow fix. Historical two-patch or dump-v1 evidence
must not be merged with the final three-patch, dump-v2 corpus. The detailed
[support report](../../../tests/box3d_native/p1.4-support.md) retains the failure,
fix, provenance and regression evidence.

| Target/configuration | Observed native support | Measurement scope |
| --- | --- | --- |
| macOS 15.8 arm64, Apple M3, Apple Clang 16, Debug/Release | Final native CTest 3/3 in each; static/shared link and exactly 64 declared `ogb3_` exports checked; no C++/Godot linkage | Physical host; NEON width 4; all 16 required cases passed and independently reviewed |
| Linux x86-64, Debian bookworm, Clang 14.0.6, Debug/Release | Final native CTest 3/3 in each; same export/link checks | Target binaries executed under Podman/Rosetta on the Apple M3; SSE2 width 4; all 16 required cases passed and independently reviewed |
| Odin dev-2026-04 | Native/Odin lifecycle 5/5; final Linux Debug and Release each pass 5/5, with logs in the persistent P1.4 report | Separate from the long benchmark; not Godot module/export/runtime parity |
| GitHub macOS/Linux native and Linux sanitizer jobs | Workflow implemented; remote jobs not observed | Configuration is not an observed CI execution |

The Linux benchmark used Odin `dev-2026-04-nightly:a896fb2`, glibc 2.36 and four
reported logical CPUs in the emulated container. Host/load metadata is retained
for each matrix; Linux load averages were approximately 0.35/0.46/0.34 at start
and 1.00/0.99/0.77 at end. These do not make its timing a bare-metal Linux budget.

All four native builds retain assertions, `BOX3D_VALIDATE`, single precision,
`-fno-fast-math` and `-ffp-contract=off`. One worker and fixed immutable host
configuration are prerequisites. Runtime/source/compiler manifests are required
for each benchmark binary; cross-build or cross-target bit agreement is not
inferred. Linux emulated wall-time is an observation of that execution context,
not native Linux hardware throughput. Disabled-SIMD behavior is unmeasured here.

**Required shared native DSO domain in Godot.** Later GDExtension and gameplay
modules, including both framework adapters, must route their `ogb3_` calls to
one loaded native shared-library instance per process. Engine globals, world-ID
allocation, allocator/global unit configuration, snapshot resources/leases and
fingerprint state must belong to that same domain. Independently embedding the
static archive into multiple Godot modules is not an accepted integration path:
equal numeric handles or equal build fingerprints do not prove common ownership.

The standalone static executables and one-DSO native smoke prove their own
single-image linkage; they **do not establish a shared domain across Godot
modules**. Before operational alpha acceptance, P2 must load two actual modules,
create resources through one and read/step/clone/restore/release them through the
other, verify one loaded backend/domain and coherent allocation/world ownership,
and exercise module teardown/reload lifetime. The shared DSO must remain loaded
until all worlds, snapshots, geometry leases and host associations are released.
Calls remain serialized on the backend's single caller; this does not merge
Kit and Replay's separate simulation/network runtimes. Budgeting concurrent
independent published worlds requires additional measurements.

**Correctness and ownership review.**
[Dump v2](../../../box3d/native/state_dump.c) emits typed scalar fields with
active-union dispatch. Its declared coverage is `ogb3-d421e45c-solver-v2`:
configuration, ordered ID pools/free lists and generations, live bodies/shapes,
contacts/manifolds and warm-start/cache data, joint settings/impulses, solver
sets, islands/sleep, sensor histories, tree/free-node structure, moved proxies,
pair-set/probe layout and constraint ordering. Reachable immutable geometry is
traversed by content. Host addresses/world slots, padding, free-slot payload,
inactive union storage, diagnostic names/profiling and output buffers are
excluded. The v2 material control proves inactive inline material is ignored and
active material changes are detected. Other native controls detect gravity,
contact-impulse, motor, sleep and allocation/free-list changes with equal poses.
This is a reviewed exact-source coverage contract, not an independently verified
portable codec or a proof for arbitrary future engine revisions.

[Owned resources](../../../box3d/native/owned_snapshot.c) retain the native image,
normalized image and a per-capture reachable geometry registry. Clones share the
resource, while imported worlds retain separate leases. Different captures own
separate registries; bounded history therefore does not imply shared geometry
cost between captures. Source destruction, last-owner release before destination
stepping, hull/mesh/heightfield/compound ownership and teardown to zero native and
owned-wrapper requested bytes are covered by the
[native lifecycle suite](../../../tests/box3d_native/README.md).

Restore stages in a fresh shell before swapping simulation storage. The pinned
world's manifold allocators move with their heap mutex pointer; destination host
identity/callback/task/user-data wiring stays destination-owned. Old geometry
leases outlive old-world teardown. User-data associations must be rebound from
restored game identities, and raw handles can recur after replayed allocation.
Both event-output end buffers and body-move linkage are cleared. Host callbacks
must not reenter this backend; the flat ABI exposes no callback setters.

The accepted image boundary is a sealed opaque resource from this exact build.
Version/fingerprint/seal and structural checks reject changed or truncated input
before invoking the destructive loader. Tests cover seven truncations, eight
corruptions, incompatible versions, wrapper allocation failures and failures
before shell creation, after shell creation and after complete import but before
publication. They do not establish safe destruction of a damaged partially
loaded upstream world: such bytes never enter that loader. Native allocator OOM
or an unexpected sealed-image loader invariant remains fatal. That limit must
stay explicit in adapter design; untrusted recovery needs a different validated
codec and fallible failure/cleanup contract.

The fingerprint is prewarmed before public world/geometry creation. At 128
public worlds capture succeeds without another probe, restore returns `Capacity`
without changing the destination, and freeing a scratch slot permits restore.
An unprimed foreign/full native domain returns fingerprint zero/capture
`Capacity` without allocator takeover. Zero is never a compatibility token.

**Benchmark review.** The [runner](../../../tests/box3d_bench/README.md) uses an
independent forward-only reference and a candidate. Each tick compares actual
normalized solver bytes and a side-state digest containing tick/RNG, input
fields, spawn/despawn counters, entity generations/local body mappings, sensor
observation totals and query-count totals. This fixture does not compare
arbitrary application effects or general per-entity event payloads. Each fourth
rewind exercises a distinct branch, detached clone/restore, then the next step in
an independently restored oracle world before replaying the original suffix.

The [strict parser](../../../tests/box3d_bench/verify.py) rejects missing,
duplicate or malformed records, incomplete completion, incorrect corpus/coverage,
rewind endpoints, comparison/branch counts, phase/sample counts and inconsistent
allocation/memory accounting. At 2,400 ticks a case must have 75 rewinds, 19
alternate branches, 38 branch comparisons and `2,401 + sum(depths)` ordinary
comparisons. Parsing validates recorded accounting; source review and executed
work remain separate evidence. Raw logs, mismatch artifacts, binary/archive and
manifest hashes must be retained.

**Completed required correctness matrix.** Both 16-case summaries independently
pass the strict parser and all requested scenario checks. Combined totals are
114,368 ordinary solver-byte/side-state comparisons, 37,536 replayed ticks,
2,400 rewinds, 608 alternate branches and 1,216 branch-oracle comparisons, with
zero within-build mismatches. Every case covers rewind endpoints 1 and 30 and
history wrap. The 32-body supplement adds 7,274 ordinary comparisons, 2,472
replayed ticks, 150 rewinds and 76 branch comparisons with zero mismatches; it
does not replace any required 100/500-body case.

**Cross-target evidence is different.** Matching macOS/Linux cases have different
final solver digests in all 16 pairs; final game-side digests agree in all 16.
This agrees with the coordinator's `corpus-comparison.json` and the reviewed
case summaries. It is not a localized root-cause diagnosis, proof that the
remaining discrepancy is harmless metadata, or evidence of exact cross-target
physics. Same-build restore/replay is established within each case. Mixed-target
P2P, authority corrections, late join and resync need explicit codec,
normalization and continued-simulation measurement contracts; a representation
codec alone cannot establish numerical/convergence agreement.

**Completed macOS measurements.** All 16
required macOS cases passed the v2 parser and exact solver-bytes/side-state
comparisons. Totals are 57,184 ordinary comparisons, 18,768 replayed ticks,
1,200 rewinds, 304 alternate branches and 608 branch-oracle comparisons, with
zero mismatches. Every case covers depth endpoints 1 and 30 and history wrap.
The retained `bench-gate-a-macos-final/summary.json` and per-case logs preserve
all measurements and identities; artifact paths/hashes and persistent report
identity are recorded in the finalized [measurement report](gate-a-measurements.md).

Each seed has the following observed counts in each of the four macOS
configuration/load groups. Each case has 75 rewinds and 38 branch comparisons.

| Seed | Ordinary comparisons per case | Replayed ticks per case |
| --- | ---: | ---: |
| 1 | 3,643 | 1,242 |
| 7 | 3,631 | 1,230 |
| 1234 | 3,453 | 1,052 |
| 3221344269 | 3,569 | 1,168 |

Timing cells below are **p50 / p95 / maximum in ms**, rounded to three decimal
places. Step/save use the 2,273 steady-state samples after history fill in each
case; restore uses 75 ordinary rewind samples, excluding its separately reported
branch phase; replay uses 75 suffix samples. These are individual case quantiles,
not pooled quantiles. Cold/fill/replay/branch measurements, normalized-dump and
whole diagnostic rewind costs remain in the raw results and must not be mixed
into these steady operational figures.

| Configuration | Initial dynamic bodies | Seed | Steady step | Steady save | Rewind restore | Replay suffix |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Debug | 100 | 1 | 0.329 / 0.668 / 3.939 | 2.032 / 2.365 / 27.418 | 0.470 / 0.507 / 0.668 | 47.577 / 78.582 / 103.445 |
| Debug | 100 | 7 | 0.347 / 0.694 / 12.572 | 2.066 / 2.525 / 8.888 | 0.485 / 0.533 / 0.631 | 47.403 / 81.826 / 104.364 |
| Debug | 100 | 1234 | 0.334 / 0.664 / 1.598 | 2.039 / 2.337 / 5.200 | 0.470 / 0.536 / 0.613 | 29.485 / 77.708 / 100.151 |
| Debug | 100 | 3221344269 | 0.346 / 0.686 / 2.227 | 2.069 / 2.593 / 7.998 | 0.480 / 0.671 / 0.994 | 37.775 / 78.320 / 102.447 |
| Debug | 500 | 1 | 2.817 / 3.784 / 17.179 | 11.302 / 14.102 / 35.782 | 2.554 / 3.874 / 4.718 | 268.039 / 455.569 / 544.033 |
| Debug | 500 | 7 | 2.623 / 3.491 / 9.433 | 11.511 / 12.918 / 58.309 | 2.568 / 3.016 / 3.542 | 257.389 / 433.442 / 579.869 |
| Debug | 500 | 1234 | 2.756 / 3.852 / 5.762 | 11.611 / 12.995 / 24.710 | 2.605 / 3.267 / 4.999 | 184.805 / 460.104 / 563.117 |
| Debug | 500 | 3221344269 | 2.801 / 3.629 / 11.287 | 11.442 / 12.577 / 25.971 | 2.558 / 3.493 / 3.896 | 216.978 / 444.941 / 565.852 |
| Release | 100 | 1 | 0.064 / 0.085 / 0.669 | 1.335 / 1.591 / 7.586 | 0.417 / 0.482 / 0.764 | 25.426 / 44.560 / 47.485 |
| Release | 100 | 7 | 0.062 / 0.079 / 0.280 | 1.328 / 1.546 / 3.799 | 0.413 / 0.471 / 0.884 | 26.084 / 43.881 / 46.975 |
| Release | 100 | 1234 | 0.061 / 0.080 / 0.306 | 1.327 / 1.672 / 5.540 | 0.414 / 0.545 / 0.852 | 16.860 / 42.479 / 53.498 |
| Release | 100 | 3221344269 | 0.059 / 0.077 / 0.104 | 1.321 / 1.563 / 3.175 | 0.403 / 0.458 / 0.469 | 20.372 / 42.481 / 45.156 |
| Release | 500 | 1 | 0.370 / 0.516 / 2.514 | 7.243 / 8.292 / 27.372 | 2.201 / 3.459 / 5.605 | 137.000 / 233.140 / 243.356 |
| Release | 500 | 7 | 0.415 / 0.615 / 9.023 | 7.599 / 10.294 / 29.413 | 2.369 / 3.308 / 4.948 | 154.245 / 277.655 / 314.299 |
| Release | 500 | 1234 | 0.408 / 0.576 / 5.216 | 7.476 / 9.349 / 22.477 | 2.264 / 2.960 / 5.916 | 97.648 / 248.247 / 259.356 |
| Release | 500 | 3221344269 | 0.407 / 0.600 / 2.590 | 7.309 / 10.005 / 26.046 | 2.306 / 3.173 / 4.689 | 117.951 / 244.006 / 349.830 |

For the 100-body Release slice, separate steady step p95 values are
0.077–0.085 ms and save p95 values are 1.546–1.672 ms. This leaves plausible
normal-tick headroom on this host, but the measured replay suffix alone has
p95 42.479–44.560 ms and maximum 53.498 ms, before initial restore and other
application work. It does **not** fit an unconditional 16.667 ms deep-rewind
budget. Separate component quantiles cannot be added and described as a measured
combined p95. The observed load averages were approximately 6.77/6.18/5.61 at
start and 6.47/5.40/5.26 at end on the eight-logical-CPU Apple M3; tail costs are
observations under that workload, not isolated hardware guarantees.

The 500-body Release stress slice has save p95 8.292–10.294 ms, maximum save
29.413 ms, replay p95 233.140–277.655 ms and maximum replay 349.830 ms.
Passing its correctness matrix does not approve a 500-body real-time slice.
The directly measured 32-initial-body Release supplement is reviewed below.
Constructor body counts exclude two static bodies and a transient extra sphere;
the proposed alpha is bounded by actual live bodies and workload, not a label of
32 total bodies.

**Completed Linux measurements.** The following p50/p95/maximum cells use the
same phases and counts as the macOS table (2,273 steady step/save samples and
75 ordinary restore/replay samples per case). All values are ms. These are
executed Linux x86-64 observations under Podman/Rosetta, not native Linux
hardware acceptance budgets.

| Configuration | Initial dynamic bodies | Seed | Steady step | Steady save | Rewind restore | Replay suffix |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Debug | 100 | 1 | 0.782 / 1.363 / 5.141 | 2.093 / 2.456 / 9.062 | 0.531 / 0.948 / 1.698 | 57.730 / 102.755 / 154.553 |
| Debug | 100 | 7 | 0.804 / 1.410 / 12.292 | 2.135 / 2.700 / 46.188 | 0.552 / 0.888 / 3.996 | 58.657 / 105.283 / 246.910 |
| Debug | 100 | 1234 | 0.803 / 1.392 / 6.926 | 2.139 / 2.577 / 33.105 | 0.542 / 0.707 / 2.738 | 36.675 / 97.398 / 151.594 |
| Debug | 100 | 3221344269 | 0.840 / 1.400 / 11.572 | 2.184 / 2.434 / 26.539 | 0.558 / 0.663 / 4.025 | 49.426 / 98.902 / 168.512 |
| Debug | 500 | 1 | 5.079 / 6.372 / 11.031 | 11.830 / 13.211 / 35.312 | 2.735 / 3.348 / 4.271 | 309.332 / 528.611 / 734.361 |
| Debug | 500 | 7 | 4.741 / 6.147 / 12.463 | 11.882 / 13.195 / 19.616 | 2.705 / 3.739 / 5.264 | 298.072 / 515.066 / 743.671 |
| Debug | 500 | 1234 | 4.902 / 6.428 / 11.626 | 11.479 / 13.175 / 28.405 | 2.658 / 3.430 / 3.881 | 199.569 / 514.860 / 735.732 |
| Debug | 500 | 3221344269 | 5.268 / 6.901 / 16.835 | 12.282 / 16.398 / 54.471 | 2.930 / 5.719 / 8.670 | 257.599 / 566.224 / 709.717 |
| Release | 100 | 1 | 0.105 / 0.137 / 0.953 | 1.302 / 1.422 / 3.016 | 0.450 / 0.570 / 1.911 | 25.921 / 43.748 / 51.332 |
| Release | 100 | 7 | 0.117 / 0.300 / 2.176 | 1.352 / 2.311 / 4.811 | 0.490 / 1.223 / 2.701 | 28.987 / 55.333 / 82.764 |
| Release | 100 | 1234 | 0.107 / 0.154 / 3.845 | 1.313 / 1.487 / 5.145 | 0.457 / 0.527 / 1.939 | 16.847 / 44.633 / 67.453 |
| Release | 100 | 3221344269 | 0.109 / 0.144 / 2.256 | 1.312 / 1.471 / 6.398 | 0.457 / 0.551 / 1.959 | 21.172 / 43.776 / 61.429 |
| Release | 500 | 1 | 0.636 / 0.919 / 8.925 | 7.153 / 8.374 / 74.379 | 2.323 / 2.833 / 3.817 | 137.384 / 249.300 / 301.313 |
| Release | 500 | 7 | 0.563 / 0.875 / 3.289 | 7.082 / 8.247 / 21.656 | 2.312 / 2.779 / 4.125 | 137.453 / 248.683 / 281.491 |
| Release | 500 | 1234 | 0.588 / 0.935 / 5.715 | 7.186 / 9.072 / 27.657 | 2.337 / 3.044 / 5.402 | 93.653 / 245.871 / 291.642 |
| Release | 500 | 3221344269 | 0.591 / 0.862 / 3.644 | 7.159 / 8.153 / 22.598 | 2.340 / 3.575 / 11.876 | 114.351 / 242.563 / 310.840 |

**Measured smaller alpha candidate.** On macOS Release, seeds 1 and 7 each ran
2,400 ticks with the same fixture, H=128, depth-1–30 rewinds, exact solver-byte
checks, side state and branch oracle. Counter-only reference replays use the
same native archive and shared fixture source and match both final digests.
Their observed peak is 35 bodies/35 shapes (32 initial dynamics, two statics and
one extra sphere), 147 live contact records, one hinge and 32 islands. The contact
counter includes non-touching allocated contact records. Counts cover accepted
reference trajectories; speculative branch-oracle peaks are not separately
profiled. No arbitrary geometry or contact topology is accepted merely because
it has the same body count.

| 32-initial-body Release seed | Steady step p50/p95/max | Steady save p50/p95/max | Restore p50/p95/max | Replay p50/p95/max |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.014 / 0.017 / 0.040 ms | 0.332 / 0.357 / 2.531 ms | 0.108 / 0.130 / 0.262 ms | 6.101 / 10.340 / 11.161 ms |
| 7 | 0.014 / 0.017 / 0.177 ms | 0.335 / 0.360 / 3.127 ms | 0.105 / 0.132 / 0.153 ms | 6.431 / 10.798 / 14.927 ms |

I paired each raw ordinary restore sample with the same rewind's replay sample,
then grouped those **sums of measured timed segments** by actual depth. This is
not a sum of marginal p95 values or a fitted body/depth scaling model. Over all
75 depths per seed, restore-plus-suffix p95 is 10.457/10.920 ms and maxima are
11.281/15.068 ms. At depths at most eight, there are 24/27 actual samples, p95
2.703/2.815 ms and maxima 3.003/2.825 ms. Normal forward step-plus-save paired
segments have 2,400 samples per seed, p95 0.376/0.381 ms and maxima
2.546/3.139 ms. Segment sums exclude other application work, comparison and
accounting instrumentation; they are not full integrated-frame wall times.
The two-seed supplement supports a cautious prototype envelope, not a broad
latency percentile guarantee for new games or hardware.

| P2 alpha implementation/test target | Measured basis and required interpretation |
| --- | --- |
| One active published physics world plus disposable staging; 32 initial dynamic/35 total live bodies, at most 35 shapes, one hinge, one convex sensor and this bounded predeclared asset fixture; target no more than 147 published contact records | Reference profiles peak at 147 contacts. P2 must instrument speculative peaks and reject/hold out-of-envelope candidates before publication. Different assets or contact topology require remeasurement, even below the body cap |
| H=128 at 60 Hz/four substeps, single worker | Approximately 2.13 s retained history; no credit for smaller unmeasured history or omitted normalization caches |
| Prediction and ordinary synchronous repair age at most eight ticks (133.3 ms) | Based on 51 observed depth-at-most-eight paired samples across two seeds. Depths 9–30 remain correctness coverage, not an ordinary synchronous latency budget. Older required repair must stop/hold publication and use an explicitly implemented complete-state recovery policy; no live-world or pose fallback |
| P2 timed-work targets: 4 ms normal physics step/capture and 4 ms for an eligible correction | Above observed 3.139/3.003 ms segment maxima and leaves about 8.67 ms of a 16.67 ms frame for omitted adapter/game/render work. These are candidate acceptance ceilings for integrated tests, not proved hard deadlines or additive quantiles |
| P2 accounted-resource target: 64 MiB for history/live-engine/staging in this single active workload, plus separately accounted allocator/runtime/RSS overhead | Current candidate history components sum to about 31.5 MiB; whole-test engine+wrapper component high-water sum is about 31.9 MiB before external game/history metadata. This allowance retains eager normalized caches and provides explicit staging headroom, but integrated transaction ownership must demonstrate the reservation is sufficient |

These limits are implementation/test targets chosen after measurement. They are not enforced
by today's backend, do not admit concurrent independent full published histories
without accounting, and do not approve arbitrary 35-body worlds. Adapter
transactions, deadline/overflow behavior and the complete-state recovery policy
must be tested before exposing the alpha as an operational networking mode.
If those tests cannot stay within this envelope without weakening Kit/Replay
transactions, pivot capture/storage or scope before expanding it.

**Memory and timing interpretation.** The current backend eagerly retains a
normalized image inside each owned snapshot. Its bytes and capture time count
against the **implemented backend** even though a future design might make
comparison storage optional. No proposed removal or shared immutable-asset
optimization is credited as a measured saving.

| Reported quantity | Interpretation |
| --- | --- |
| `native_history_requested_peak` | Retained owned-history engine requests: image/registry/dedup/mutex storage, including applicable live geometry; use as a backend history component |
| `wrapper_history_peak` | Retained snapshot-owner/resource/slot/normalized storage; normalized cache is a subset, not another amount to add |
| `snapshot_used_peak`, `snapshot_capacity_peak`, `geometry_bytes_sum_peak` | Resource breakdowns already represented above; do not add again |
| `side_history_bytes`, `history_metadata_bytes` | Candidate game-frame and history-container storage, separately required |
| `baseline_dump_bytes_peak`, `reference_metadata_bytes` | Independent-reference verification storage, including its copied game data; not deployment solver history |
| Engine/wrapper live and high-water counters | Whole test-process requested allocation domains, including additional reference/oracle worlds, leases and staging; not a one-world production peak or RSS |
| `fixed_simulation_bytes` | Fixed storage for three simulation descriptors; a verification-inclusive figure, not measured total native world memory |

Across the completed macOS matrix, the 100-body retained native history peaks
are 65.65–66.35 MiB and wrapper history is 37.68 MiB, including 37.66 MiB
normalized cache. The reference dump ring separately reaches 37.66 MiB.
The 500-body native history peaks are 402.25–433.19 MiB and wrapper history
202.04–202.10 MiB, including 202.01–202.07 MiB normalized cache; its independent
reference dump ring is another 202.01–202.07 MiB. Geometry bytes summed over
retained snapshots peak at only 0.133 MiB for this fixed-asset fixture: geometry
blob retention alone is not the dominant current cost.

Candidate game history is 0.832 MiB in either load because the fixture uses
fixed 520-entry game arrays; candidate history metadata is another 10 KiB.
The corresponding component-maxima envelopes are approximately 105 MiB for the
100-body history and 605–636 MiB for the 500-body history, before deployed live
worlds, correction staging and other runtime overhead. These are **not measured
simultaneous peaks or RSS budgets**. Additional published/staged histories in an
adapter cannot be assumed free; clone sharing and suffix retention need their own
accounting. Allocator rounding/headers, flat geometry-wrapper bookkeeping,
general runtime/stack and Odin allocation overhead remain outside requested
byte figures. The bounded alpha implementation target retains the current
normalized-cache/capture costs and separately reserve deployment/staging
headroom; a proposed optimization supplies no measured credit.


For the directly measured 32-body supplement, native history peaks at
20.85 MiB and wrapper history at 9.785–9.786 MiB, including 9.760–9.761 MiB
normalized cache. Candidate game/history metadata adds 0.842 MiB, giving a
31.48 MiB component-maxima history envelope. The independent reference dump
ring is a separate 9.760–9.761 MiB plus 0.837 MiB reference metadata, not
additional deployment history. Engine and wrapper process high waters are
21.993–21.998 MiB and 9.861–9.862 MiB respectively, inclusive of the benchmark's
extra worlds/resources; they remain separate, non-simultaneous maxima. The
64 MiB candidate reservation above is a proposed tracked-resource allowance with
headroom, not an observed RSS peak or a promised allocator-level hard cap.

Normal `step` excludes gameplay commands and output/query processing. `save`
includes owned capture, replaced-owner release and game-frame copy, while metric
queries/scans are outside it. `restore` includes its native scratch work.
`replay` sums suffix advancement and measured saves, excluding comparison and
accounting/printing overhead. `checked_rewind` includes diagnostic comparisons
and optional oracle branch work; it is not a production correction estimate.
P2 budget enforcement must distinguish these measures and include explicit staging
headroom, rather than equating a single normal step with a correction.
`ALLOCATIONS.save_calls`, `restore_calls` and `step_calls` are engine allocation
requests accumulated inside the measured operations, not numbers of API
invocations. Additional oracle operations and wrapper allocations remain in their
separate/global accounting domains.

**P2 acceptance conditions and expansion limits.**

- The complete required matrix and 32-body supplement pass and P1.4 is closed.
  Across all 34 cases there are 121,642 ordinary complete-state comparisons,
  40,008 replayed ticks, 2,550 rewinds, 646 alternate branches and 1,292 branch
  comparisons, with zero within-build mismatches. Final workload profiles match
  complete solver/game digests in all 34 cases. On both required targets, peak
  bodies/shapes are 103/503, contacts 819/4,675 and joints one for the 100/500
  fixtures; the supplement peaks at 35/35/147/one. These count accepted reference
  trajectories, not independently profiled speculative branch peaks or new
  timing samples.
- Implement and test the stated body/contact/asset, H, prediction/repair,
  timed-work and tracked-memory targets before advertising an alpha mode.
  Measure actual integrated frame time, action/commit staging, high-water
  resources and allocator/runtime/RSS overhead. The native benchmark replaces
  history during replay; it does not prove transactional suffix reservation in
  either framework. If admission/enforcement and complete-state recovery cannot
  stay within the targets, pivot capture/storage, scheduling or workload scope.
- Establish one shared native DSO domain across actual Godot modules, including
  reload/teardown and ownership tests. Standalone static linkage is insufficient.
- The performance allowance is based on physical macOS/M3 same-build evidence.
  Linux native-hardware throughput remains unmeasured. All 16 matched
  macOS/Linux final solver digest pairs differ while side digests agree; no
  cause is inferred. Mixed-target corrections/P2P and portable recovery require
  explicit codec and continued-simulation agreement contracts, not a promise
  that canonical encoding alone fixes the boundary.
- Bounded predeclared assets and tested geometry lifetimes are supported.
  Arbitrary unique speculative geometry churn, general resource caps and
  recoverable native allocation exhaustion are not established. Native OOM and
  unexpected sealed-loader invariants remain fatal; no damaged partial loader
  is claimed safely recovered. Treat the 64 MiB figure as a P2 validation target,
  not a current allocator-level limit or RSS guarantee.
- Kit and Replay remain distinct adapters over one backend. Replay complete
  physics checkpoints/branches must own solver plus game state, while value-only
  callers retain their existing behavior. Test advance, corrected inputs,
  authoritative correction, rejected/nested actions, rejected publication,
  audit/reset/rewind, saved-frame branches, eviction and destruction. Disable
  `correct_reusing` until complete predecessor equivalence is established.
- Preserve server-authoritative policy and fixed callback/process configuration.
  Two-process impairment, canonical transfer, mixed-target correction/P2P,
  editor/scene authoring, presentation and editor/export/runtime parity remain
  later gates. This decision funds their bounded implementation work; it does
  not certify that they exist.

Gate A therefore proceeds to the bounded P2 alpha work above. Expansion to
100/500-body real-time deep correction, arbitrary assets or mixed-target exact
physics requires a new measured decision; it is not authorized by the stress
matrix's correctness result.
