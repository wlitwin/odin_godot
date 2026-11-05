# Shared Box3D contract for Kit and Replay

P2.1 contract, 2026-10-30. The [Gate A decision](gate-a.md) admits a bounded,
same-build/same-target alpha implementation and test slice. It does not admit
mixed-target physics or arbitrary scenes with the same body count. Kit and
Replay keep their own simulation, history, input, networking and event machinery.
Their existing default/value-only core packages must remain native-free.

## Identity and the C/Odin boundary

`Body`, `Shape` and `Joint` are existing world-bound native handles. New
`Body_Key`, `Shape_Key` and `Joint_Key` are distinct pointer-free `u64` allocation
keys: low 32 bits are native `index1`, high 32 bits are native generation. Index1
must be positive and fit signed 32; generation must fit unsigned 16. Zero and
noncanonical encodings are invalid. They exclude the host world slot, and are
not game entity IDs, asset IDs, network IDs or permanent spawn identities.
After rewind a future spawn can reuse the same numerical key. Each complete
framework image therefore carries its deterministic entity-to-key map and
creation/generation counters in its typed game side-state.

Authoritative declarations are `box3d/native/api.h` and `owned_snapshot.h`.
Odin convenience names are:

```odin
body_key(Body) -> (Body_Key, Status)
shape_key(Shape) -> (Shape_Key, Status)
shape_key_from_handle(Shape) -> (Shape_Key, Status) // structural copied event ID
joint_key(Joint) -> (Joint_Key, Status)
body_resolve(World, Body_Key) -> (Body, Status)
shape_resolve(World, Shape_Key) -> (Shape, Status)
joint_resolve(World, Joint_Key) -> (Joint, Status)
world_counters(World) -> (World_Counters, Status)
snapshot_body_state(^Snapshot, Body_Key) -> (Body_State, Status)
snapshot_body_states(^Snapshot, []Body_State) -> (required: u32, Status)
```

Checked key creation requires a currently valid source handle. The explicit
`shape_key_from_handle` decoder only checks structural encoding, for copied
sensor-end IDs after shape/world destruction; it establishes no liveness and
retains the original index/generation. Checked destination resolution remains
mandatory before execution. Resolution validates the
current destination world and its live object generation. Malformed keys return
`Invalid_Argument`; absent/stale keys return `Invalid_Handle`. Output PODs stay
untouched on native failure. `World_Counters` contains `body_count`,
`shape_count`, `contact_count`, `joint_count`, `island_count`, `tree_height`.
The first five count live native allocations, including static bodies/shapes and
non-touching contact records. `tree_height` is the maximum dynamic/kinematic
height, excluding the static tree.

`Body_State` contains key, rigid pose, linear/angular velocity, mass, body type,
and u32 `is_awake`/`is_enabled` flags. Sleeping velocity is zero as in the native
public getter. An immutable sorted cache is built during capture and shared by
explicit clones. It survives source world destruction and never creates a
scratch world per rendered body. Single-key lookup is logarithmic and performs
no allocation, stepping, destructive import or full-image serialization. Bulk
reads query size with an empty slice; insufficient capacity returns `Capacity`
without partial writes. The cache has a native hard bound of 65,536 live bodies;
alpha admission remains limited to 35 total. Capture rejects an over-bound cache
and releases partial resources. Cache bytes are included in snapshot storage and
wrapper allocation accounting. Normalized complete solver bytes now use dump v3,
coverage `ogb3-d421e45c-solver-v3`; the cache is a derived read representation,
not a replacement for the complete image.

## Owned images and staged execution

A native `Snapshot` (owned-resource contract version 2) owns its detached
exact-build image, retained immutable geometry, complete normalized bytes/digest,
read cache, and ordered pending sensor/contact end queues. Plain assignment
aliases ownership; use `snapshot_clone` for a second owner and destroy each owner
exactly once. Restored worlds independently retain geometry until replacement
or destruction. Images are trusted local resources, not portable/network wire
snapshots. Compatibility, seal and structural validation precede staged native
import. Existing admitted failure paths preserve the destination; upstream
allocator exhaustion and impossible post-validation loader failures remain fatal
invariants, not recoverable OOM/partial-import claims.

The shared Odin execution helpers, in `box3d/snapshot.odin`, are:

```odin
stage_open(^Snapshot) -> (World_Stage, Status)
stage_world(^World_Stage) -> (World, Status) // borrowed execution handle
stage_swap(^World, ^World_Stage) -> Status
stage_discard(^World_Stage) -> Status
```

A `World_Stage` owns one disposable world. Open creates a default shell, restores
the supplied image, and closes the shell on failure. It does not consume the
image. Swap validates distinct live worlds, swaps only their owning handles,
and leaves the retired published world owned by the stage. It allocates and
steps nothing. The adapter publishes its typed game state, history and events
with this selection at one infallible commit boundary, then discards the retired
stage. Discard clears the owner and is harmless on an empty stage. Open
transiently needs two spare native world slots (execution shell plus the
internal import candidate); a retained stage consumes one. In-place restore
needs one spare slot. Staging and restore return `Capacity` when unavailable
and preserve publication.
Backends never invoke irreversible presentation callbacks during speculative
execution. Native userData and completed output arrays clear on restore; the current
end-event buffer is a future-delivery queue and is restored, not cleared. IDs
are rebuilt for the destination world, including retired shape generations and
the full 32-bit contact generation. The next step exposes these ends once;
completed same-tick observations remain adapter-owned. Adapters rebind
needed associations before executing, using restored game maps rather than
old world handles. Host callback configuration stays fixed and nonreentrant.

## Bounded alpha observations and admission

The shared helpers include `alpha_memory_check(additional_owned_bytes=0,
reserved_bytes=0)` for detached images without an execution/provider (zero world
counts in its observation), `alpha_observe(World, additional_owned_bytes=0)` and
`alpha_check(World, Alpha_Request)`, each returning `(Alpha_Observation, Status)`.
`Alpha_Request` has `initial_dynamic_bodies`, `history_frames`, `prediction_ticks`,
`correction_ticks`, `additional_owned_bytes`, `reserved_bytes`, `normal_work_ns`,
and `correction_work_ns`. `alpha_request_default()` initializes H=128 and the
32-initial-body declaration; callers supply actual ages, elapsed work for observation and all
external owned/reserved bytes. During initialization the provider verifies the
initial dynamic count against the first snapshot body states (filter `.type`),
then retains that initial count in immutable configuration/checkpoint metadata.
It must not trust an unchecked declaration or compare later spawned dynamics
against the initial count. Fixed limits are:

| Alpha target | Shared check or observation |
| --- | --- |
| Initial dynamics 32; total bodies 35, shapes 35, contacts 147, joints 1 | Initial declaration and actual world counters before/after each staged operation |
| H=128, fixed 60 Hz/four substeps, single caller | Exact history size and shared `world_step_fixed`; adapters reject incompatible tick configuration |
| Prediction/ordinary synchronous correction at most the configured window (default 30, ceiling `net.PHYSICS_WINDOW` 32; originally 8) | Explicit ages; older repair returns hold/resync without truncation or live-world fallback |
| Normal physics core work 4 ms; eligible correction work 4 ms | Caller-supplied monotonic elapsed ns and over-target observation; integrated acceptance-test ceilings, never wall-clock runtime rejection |
| Requested live resources plus reserved staging at most 64 MiB | Process-global engine live + snapshot-wrapper live + additional game/history/adapter bytes + explicit future reservation |

`Alpha_Observation` retains actual counters, engine and wrapper allocation stats,
external owned bytes, summed live bytes, supplied elapsed work and
`normal_over_target`/`correction_over_target` flags. `alpha_check` does not reject
otherwise valid input for elapsed wall time. Simulation transitions must not
depend on OS scheduling; the integrated acceptance runner separately evaluates
these observed timing ceilings. Native totals include all worlds in
this one engine domain; wrapper totals include cache, images, clones, leases and
temporary digest buffers. Snapshot storage reports shared resources once; clones
must not multiply resource storage. Allocator rounding/headers, Odin allocator
metadata and runtime/RSS overhead are measured separately. Counter high-water
values are component peaks, not one exact simultaneous peak; providers record
staged/branch/savepoint peaks separately from published history.

Providers must preflight with a measured upper reservation before capture/open
or a command that can allocate, then check actual counts/resources after every
staged step, capture, branch and nested savepoint. A failing post-check destroys
the candidate and preserves the published pair. This helper is admission and
observation, not an allocator-level native hard cap: no untested promise of
recoverable engine OOM or arbitrary temporary allocation is implied. Integrated
P2 tests must demonstrate sufficient reservations and measured overhead/staging
inside the 64 MiB target. An insufficient reservation or out-of-envelope peak is
an explicit rejection/resync condition and a failed alpha test.

Asset/fixture identity is explicit immutable provider configuration and complete
checkpoint metadata. The initial provider trusts a nonzero predeclared content
ID and permits only its bounded authored geometry/commands. The ID must match
on clone/open/correction/branch/resume; it is not certified by matching body
counts or the small native build fingerprint. Complete normalized state also
includes reachable geometry content. Different assets/topology require new
measurement even within these numerical limits.

## Kit transaction and lifetime

Kit core exposes opaque provider callbacks without importing Box3D. Its optional
physics provider pairs the existing lane's game fields and deterministic typed
Side (keys/maps/RNG/commands) with an owned solver image at every retained tick.
No missing physics frame may use the live world. Tick order is deterministic
accepted input and game/entity/scheduled commands, exactly one fixed solver step,
copied physics observations and deterministic game events, authority processing,
then complete capture/admission. Presentation consumes copied historical poses
and is outside replay execution.

Correction opens disposable execution from the complete predecessor image,
restores the matching game/Side state, binds it for existing tick execution,
and stages the required suffix and events in the existing correction path.
Failure, stale image, insufficient history, age/resource rejection or a
rejected publication discards all candidate images/execution and leaves published
solver/game/history/events unchanged. An exact repeat of an already confirmed
complete image/Side/fields/identity is an idempotent acknowledgment with no
solver steps, even when the head has advanced; it does not admit an older
required rewind. An unconfirmed repair older than the configured window still rejects.
Pose equality or a motion hash alone cannot establish that no-op. Commit infallibly selects the accepted
execution and game/Side/history together; only afterward release retired images
and execution. Eviction, rewind, reset, branch reads and destruction release each
image once. H=128 committed images and a bounded correction suffix (at most nine
images including predecessor) are separate owned resources, not a second lane.

## Replay transaction and lifetime

Replay core remains value-only by default and exposes an optional explicit
backend-neutral participant table. Concrete Box3D participation lives under
`replay/physics`, never hidden mutable `ctx.user`. A complete physics checkpoint
owns both typed game frame/Side and native image; ordinary value frames and game
state reads are not advertised as complete solver checkpoints.

Advance/revision/correction/audit/rewind/reset/ring eviction/branch-resume and
checkpoint destruction all participate in existing Replay transactions. Each
staged tick runs the same ordered accepted commands, one fixed step, deterministic
observations/events, complete capture and admission. Rejected ticks/commit gates
and audits preserve publication. Nested action rejection needs a solver savepoint
or a tested value-owned deferred-command ordering policy; whole-tick restore is
insufficient. `correct_reusing` is disabled for physics participation until
complete predecessor equivalence is implemented. Default integer-schema P2P
policy stays unchanged.

The concrete provider may use disposable execution handles and infallible
pointer selection matching Replay's current staging. Image clone/release remain
self-contained; participant read poses uses the snapshot cache. Game maps use
keys and resolve against current execution, so switching worlds does not rewrite
typed historical game state. Partial game-only checkpoint/network export cannot
silently drop solver state. Canonical transfer, late join and cross-build/target
recovery require a later explicit complete-state codec.

## One loaded backend domain in actual Godot modules

Standalone tests may link the static archive into one executable. Actual SDK
core and separately built or hot-reloaded gameplay modules must call one loaded
native `ogb3` DSO, shared by both adapters. Package the exact DSO with matching
headers/build manifest; use loader-relative rpath/install names for the selected
platform rather than another statically embedded engine per module. Keep that
DSO loaded until all worlds, images, geometry, leases and module associations are
released. Reset/hot reload first stops calls, unbinds associations and releases
module-owned resources; runtime-owned complete checkpoints retain explicit owners
or are invalidated through an explicit complete reset. Numeric keys/fingerprints
do not prove common DSO ownership. Cross-module create/read/clone/restore/release,
loaded-domain identity and reload tests belong to actual build/export integration;
standalone provider tests do not establish that production boundary.


The selected deployment layout is `addons/odin_godot/bin/<platform>/` with the
SDK library, gameplay module and one native physics DSO in that directory:

| Platform | Backend artifact and loader policy |
| --- | --- |
| macOS | `libogb3.dylib`, install name `@rpath/libogb3.dylib`; both consumer modules use `@loader_path` in LC_RPATH |
| Linux | `libogb3.so`, matching SONAME; both consumers use `$ORIGIN` RUNPATH |
| Windows | `ogb3.dll` with one SDK-controlled absolute load from that platform directory; avoid independent per-script copies or ambient PATH resolution |

The consumer build must choose this shared artifact through `BOX3D_LIBRARY` and
must not also embed the static archive. Module reset must reject calls and
release images/worlds before backend unload; retained runtime checkpoints keep
explicit ownership independent of script callbacks. Packaging, loader metadata,
one-loaded-image inspection and actual two-module/reload execution remain
required build/export integration evidence. This document defines that concrete
policy; the current standalone archive tests do not implement or certify it.

## Concrete backend-neutral callback boundaries

Kit's `kit/sim.World_Provider` carries explicit `capture(user, execution)`,
`open(user, image)`, `step(user, execution, tick)` and `admit(user, execution,
World_Admission)` calls. `bind` and `publish` only select execution and are
infallible. `clone(image)`, `release(image)`, `equal(left,right)` and
`admit_detached(additional,reserved)` must remain usable after the originating
Lane/provider instance is destroyed. `World_Checkpoint` owns its copied game
fields, typed Side/image identity, clone/release/equality callbacks and detached
admission, rather than a pointer back to a live Lane. The optional
`kit/physics` implementation supplies these operations through shared Box3D
helpers; `kit/sim` and ordinary Kit callers do not import the native package.

Replay's `replay.External` carries immutable `identity` and complete contract
identity, self-contained image `clone/release/open`, execution `close/capture`,
complete `equal`, and phase-aware `preflight/admit` callbacks. Optional
`reserve/unreserve` charge value/history/event metadata to the same resource
budget; `clock` produces diagnostics outside simulation. `Step.execution` is a
scoped borrowed capability, with stale-scope rejection and exactly one solver
step claim where required. Its savepoints participate in existing nested action
rollback. `Complete_Checkpoint(State,Event)` owns the typed frame, epoch,
occurrences and explicit image; `current_values` remains a game-only view.
Provider configuration and image metadata include exact build/target/content
contract identity. The optional `replay/physics` provider implements this table;
value-only `replay` and its default P2P/schema policy do not link Box3D.

Detached checkpoint callbacks and type information can be monomorphized into a
producer gameplay module. Keeping only the backend DSO loaded is insufficient
if a retained typed checkpoint still refers to that module's callbacks. Pin the
producer module until those owners are released, move the typed implementation
into a runtime-owned module, or require an explicit complete reset before its
unload. Never invoke clone/release/read through unloaded module code. This is a
required part of the later actual-module reload tests.


## Logical version evolution and runtime agreement

Historical Gate A and P2.1 artifacts use normalized v2 and remain historical;
none of their timing or digest results is relabeled as v3. P2.4 exposed a missing
future input: destruction after a fixed step appends sensor/contact ends to
`endEventArrayIndex`, and the next step delivers that queue. The pinned upstream
image serializes the buffer index but omits its contents. Owned-resource v2 now
retains these supplements and dump v3 appends ordered queue counts and local
allocation keys, including full 32-bit contact generations. World slots and
contact padding are excluded; count, order and generation affect comparison.
Completed opposite-buffer ends and other completed outputs remain outside the
native logical image and must be copied by adapters when same-tick reads require
them. See [pending-end support](../../../tests/box3d_native/p2.4-pending-ends.md).

`abi_check` verifies the actual native `state_version()` against compiled
`STATE_DUMP_VERSION`, in addition to POD ABI/layout checks. World/stage creation,
complete snapshot operations and admission reject an ABI-compatible v2 archive
with `Incompatible` before using it as v3. Version diagnostics and cleanup remain
available. The resource version is an internal opaque tag checked by native
snapshot validation, not a public runtime getter. The independent
`tests/box3d/version_mismatch` program verifies rejection before world use with
zero native or wrapper allocations when linked to a retained v2 archive. A
matching POD ABI version1 alone is never complete-state compatibility.
