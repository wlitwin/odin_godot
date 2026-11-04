# Box3D: shared native backend, separate Kit and Replay adapters

Accepted on 2026-10-30 for the Phase 1 feasibility spike.
Task `t_363c0341bb2646e6` (P0.5), board `b_cdde1cdfea104035`.
Acceptance of this architecture funds the native spike; Gate A determines whether
the measured correctness and costs justify framework integration.

Kit and Replay will share one explicitly stepped Box3D backend. Each keeps its
existing simulation and networking runtime. Replay already supplies full
resimulation and rollback; its adapter must make the external solver part of
those existing transactions and complete checkpoints.

## Evidence behind the decision

The parallel Phase 0 investigations produced:

- [Architecture boundaries](architecture-options.md): existing Kit correction
  points, Replay value/staging/action/audit requirements, and storage alternatives.
- [Reproduced upstream baselines](upstream-baseline.md): both Debug builds,
  standalone 14/14 headless suites, game 10/10 suites plus real two-process UDP,
  and a separate 101-body native restore/resimulation smoke test passed on macOS
  arm64. The game and standalone core use different exact engine revisions.
- [Snapshot audit](snapshot-audit.md): solver coverage, omitted event outputs,
  user-data clearing, numerical handle reuse, geometry lifetime/allocation,
  destructive restore and incomplete hash coverage, backed by focused C probes.
- [Reuse matrix](reuse-matrix.md): the C API/shim is the useful initial boundary;
  Godot node layers are later references and the upstream session stays separate.
- [Dependency and attribution record](dependencies.md): selected source pins,
  embedded notices, allowed reuse boundary and upgrade ownership.

These results reproduce useful upstream behavior. They do not satisfy Gate A:
the upstream hash covers body motion, not all future-affecting solver state.

## Decisions

### Build a narrow C/Odin backend

Use Box3D `d421e45c828f6f853a145f726f0b9425d31146eb` and the isolated C shim
from rollback-in-a-box `9e1fe882a0ea4eb52e160d5754a752580b4db462` as the starting
source. Preserve the notices and local patch provenance in the dependency record.
The initial linked boundary is **Box3D + `rollback_shim.c`/header**, not the
existing `box3d_rollback_neutral` target, which also compiles C++ world/session
code. Do not add godot-cpp or upstream network-session code to this runtime.

Place the framework-independent Odin API in `box3d/`, native compatibility code
in `box3d/native/`, and the reproducible native build driver in
`build/build_box3d.sh`. One engine instance owns its global settings and world-ID
domain. Use public C lifecycle/shape/query/step functions where their ABI is
straightforward; keep private snapshot/registry access inside the C shim.
Add layout, precision and enum checks at the foreign boundary.

The backend owns native worlds, snapshot resources, geometry dependencies and
native handle translation. The adapters own framework entity IDs, their
entity/body maps, callbacks and Godot presentation associations. The backend does
not need a dependency on Kit, Replay or Godot objects.

### Make snapshot ownership explicit

Extend the shim to support an owned snapshot image plus retained geometry
dependencies, with explicit clone/release, compatibility and destination-world
operations. A copied slot number, raw pointer, or bytes without their registry
dependencies is not an owned snapshot. Prototype separate scratch execution
worlds for staged revisions; the simple audited hull import is only the first
piece of evidence for this direction.

Published state must survive failed load, failed step and rejected publication.
The current destructive loader must only mutate disposable/staged execution
state until success. Isolation alone does not make failed imports safe to
destroy: the audited loader can leave a partial candidate outside its destructor's
invariants. Require non-mutating full validation before import or an explicitly
safe partial-load cleanup/reset path, and prove that cleanup in the native
tests. If safe scratch import and failure cleanup cannot be established for the
supported corpus, Gate A is a pivot/stop decision; do not weaken the framework's
transaction guarantees to make the spike pass.

The spike uses predeclared immutable geometry definitions. Dynamic body
spawn/despawn is required; arbitrary speculative creation of unbounded unique
geometry is not. Measure registry retention and temporary interning allocations
separately from bounded snapshot slots. Later dynamic geometry needs explicit
resource caps/lifetime or a proven registry compaction policy.

### Preserve Replay's complete-state contract

Choose managed solver snapshot participation with an **explicitly owned complete
physics checkpoint** as the integration direction. Keep current value-only
Replay users' behavior intact. Physics-enabled reads/branches/checkpoints must
carry both the typed game frame and its owned solver state; an ordinary game
`Frame(State)` alone must not be presented as a complete physics checkpoint.
Any new complete-checkpoint/export APIs need a documented ownership and
clone/release contract. The network and recovery composition must use those
complete APIs rather than accidentally archiving only game fields.

Implementation belongs in a focused Replay adapter, proposed `replay/physics/`,
with the minimal explicit history/transaction hooks required in Replay's existing
timeline and runners. It is not a second timeline implementation. State/output
read helpers must make the distinction between game values and complete physics
checkpoints visible. Final function signatures and module instantiation details
belong to P2.1 after the native snapshot ownership proof.

Include every relevant boundary: advance, corrected inputs, authoritative state
correction, rewind/reset, ring eviction, audit, saved-frame branch/resume,
rejected commit gates, and nested rejected actions. For the first adapter,
disable `correct_reusing` until complete solver predecessor equivalence is
implemented. Choose either solver savepoints for actions or deterministic,
value-owned deferred physics commands with an explicitly tested tick order;
whole-tick restoration alone is insufficient for action rejection.

A bounded inline byte array may be used as a small local experiment, but is not
the selected general checkpoint representation. Normalizing pointers would
still leave geometry-registry ownership and canonical recovery unresolved, and
maximum-sized arrays multiply whole-frame/staging copies and schema costs.

### Extend Kit at the complete-world correction boundary

The Kit adapter pairs complete solver snapshots with deterministic side-state
at the lane's tick boundary. Apply gameplay/entity/scheduled commands, step the
solver at one specified point, derive gameplay events and authority outcomes,
then capture the coherent state before transmission. Presentation remains a
consumer of copied poses.

Add complete-world mismatch and history handling around Kit's existing
correction path. Field-equal poses do not justify skipping a solver correction,
and missing solver history cannot fall back to the live world. Shared bodies
require coherent accepted/predicted input history and a complete authority
correction/recovery representation. Keep this mode distinct from engine-physics
owner streaming and recipient-filtered pose replication.

### Keep network policy and recovery explicit

The first slice is server-authoritative in both frameworks. Reuse each runner's
existing accepted-input, prediction, validation, correction and effect machinery;
implement only missing shared-physics history/state participation. Do not import
the upstream peer session or weaken Replay's separate integer-schema P2P policy.

Local snapshots are exact-build implementation data. Canonical network/recovery
state must describe complete solver state and versioned immutable assets through
an explicit, validated codec. Extend each framework's checkpoint/recovery
contract for that attachment; do not hide it in an unrelated policy field.
Replay's current checkpoint/schema limits require measured sizing and explicit
versioned changes if the physics representation exceeds them.

Exact canonical solver recovery is required evidence for transferred authority
corrections and late join/resync. Two processes can establish same-build
agreement from identical initial construction and accepted input history before
that transfer codec exists; report that narrower result explicitly. Pose-only
re-seeding may be evaluated as an explicitly different approximation, not
substituted for this rollback contract. The portable codec is a Phase 3
deliverable; Phase 1's local image/ownership proof does not claim it already exists.

## Initial configuration and target pair

| Setting | Initial spike choice |
| --- | --- |
| Development target | macOS arm64, actual compiler and Odin versions recorded per run |
| Second target | Linux x86-64 CI, pinned source/toolchain/configuration recorded independently |
| Execution | One worker, settled step boundaries, explicit fixed 60 Hz and four substeps |
| Coordinates | Y up, right handed, meters; rigid transforms exclude scale, which is baked into shape definitions |
| Precision | Single-precision Box3D; fixed-width quantized input fields, stable creation/application order |
| Floating-point build | No fast-math/reassociation, FP contraction disabled throughout engine and shim; record SIMD mode, compiler/flags and source fingerprint |
| Configurations | Debug with assertions and explicit `BOX3D_VALIDATE=ON`; optimized build with the same simulation policy |
| Initial history | 128 retained ticks plus separately budgeted staging/checkpoint resources; a test configuration, not a production memory budget |

Initialize process-wide unit settings before creating worlds. Keep configuration,
callback identity and immutable assets constant during a run. The actual upstream
reproduction used default arm64 NEON and Debug; Linux, optimized and disabled-SIMD
configurations have not been established by those tests. Agreement is measured
within each build first; cross-target agreement requires its own evidence.

## Gate A correctness and benchmark procedure

1. Build from recorded pins into an isolated output/cache directory, checking
   dependency identity and compile-time ABI constraints. Record OS/CPU, compiler,
   Odin version, precision/SIMD, validation, flags, tick/substep and content IDs.
2. Use independent baseline and replay worlds with 100 and 500 dynamic bodies
   plus explicit static geometry. Execute at least four recorded input/RNG seeds
   for 2,400 ticks each. Include stacks/contacts, sleep/wake, sensors, spawn and
   destruction, stable-ID mapping and at least one hinge/motor joint. Include
   hull, mesh/heightfield and registry reuse/churn cases in ownership coverage.
3. Repeatedly choose seeded rewind depths 1–30 ticks within retained history.
   Restore the complete physics/game-state pair and replay the recorded suffix.
   Compare every replayed tick with the independent baseline, not only its final
   pose. Include more than one branch at the same tick and history wrap.
4. Implement a versioned normalized state dump/digest covering all
   future-affecting serialized solver fields and deterministic side-state. Exclude
   pointers, host-world indices, profiling/rendering and unused registry history;
   identify reachable immutable geometry by content. Cover configuration,
   allocation/generations/free-list order, bodies, contacts/impulses, joints,
   islands/sleep, broadphase/solver ordering and sensor histories. The digest
   coverage list must be auditable against the pinned serializer. Retain
   normalized bytes/field differences for a mismatch, not only a hash value.
5. Add mutation controls: changing gravity, contact impulses, joint settings,
   sleep state or allocation order must change the appropriate complete-state
   comparison even when current body poses remain equal. The upstream motion
   hash stays a separate diagnostic and cannot satisfy this gate.
6. Exercise same-world and scratch-world restore, callbacks/user-data rebinding,
   body-handle reuse, output-event clearing, corrupt/truncated/incompatible
   images and rejected/aborted scratch execution. Verify the published world is
   unchanged on every failed candidate. Verify that a failed scratch candidate
   itself can be cleaned up safely, including after late/truncated input and
   injected resource failures; ordinary destruction of an invalid partially
   loaded world is not an established cleanup path.
7. Time warmed saves, restores, normal steps and complete rewind/replay operations
   with a monotonic clock outside simulation. Separate cold/setup behavior from
   samples. Report p50, p95 and maximum, sample counts, snapshot used/capacity
   bytes, registry retained/high-water bytes, temporary allocations and staging
   memory. Report CPU/hardware and body/contact/joint counts for each result.
8. Repeat in Debug and optimized builds on both initial native targets. Record
   each result independently. A missing target, incomplete digest, unsupported
   restore case or unbounded registry behavior is a named gap, not a passing
   result inferred from another configuration.

Store machine-readable run metadata and per-case results with the runner, with
separate `motion_digest` and `complete_digest` fields and a coverage/version ID.
The report includes correctness counts, first mismatch details, rollback depth,
timing quantiles and memory/allocation totals. Do not publish arbitrary production
latency/memory thresholds before measuring this curve. Gate A records measured
candidate budgets and an explicit proceed, pivot or stop conclusion; proceeding
requires correct complete restore and credible budgets for the chosen slice.

Two-process impairment, canonical transfer and both adapter transactions remain
Phase 2–4 gates. Local Gate A success is not a claim that those already pass.

## Next task scopes

The native spike can proceed while the framework adapters remain untouched:

| Card | Planned edit scope and result |
| --- | --- |
| P1.1 | `box3d/dependency.json`, `box3d/native/` build/shim/notices, `build/build_box3d.sh`, native CI workflow, required cache ignores/toolchain entries and distribution attribution. Build the isolated pinned C engine/shim on the two initial targets. |
| P1.2 | `box3d/` Odin lifecycle/shape/query/step/snapshot ABI plus the necessary native snapshot boundary extensions. Explicit resource ownership and status results; no framework adapters. |
| P1.3 | `tests/box3d/` and required backend fixes: complete-state comparison, restore/identity/event/geometry/transaction controls and the lifecycle corpus. |
| P1.4 | `tests/box3d_bench/` plus measurement report: reproducible seeded runs, separate correctness and performance data, all snapshot/registry/staging costs. |
| P1.5 | `docs/design/box3d/gate-a.md`: measured evidence, unresolved gaps, budgets and proceed/pivot/stop. |

P2.1 defines final provider signatures after this proof; P2.2 and P2.3 own Kit
and Replay adapters separately. Later authoring/compatibility work follows the
two-process Gate B. The dependency owner and upgrade procedure are recorded in
[dependencies.md](dependencies.md).
