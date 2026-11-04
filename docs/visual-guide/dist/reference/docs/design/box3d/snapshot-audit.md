# Box3D snapshot and identity audit

Audited on 2026-10-30 for the **Odin Godot / Box 3D Implementation** board,
task `t_e73e0163fcf54470` (P0.2). This report applies to both Kit and Replay.
Replay already supplies full resimulation and rollback; its missing boundary is
participation of the external solver in its existing state transactions.

The current snapshot machinery is a useful implementation starting point, but
the exposed slot API is insufficient for detached Replay frames. Its motion hash
does not cover complete solver state, and restore is destructive. Those are
requirements for the adapter design, not reasons to build a second rollback
framework.

## Exact source revisions

| Source | Revision | Scope of this audit |
|---|---|---|
| [rollback-in-a-box](https://github.com/pdaddyo/rollback-in-a-box/tree/9e1fe882a0ea4eb52e160d5754a752580b4db462) | `9e1fe882a0ea4eb52e160d5754a752580b4db462` | Current engine-neutral core, C shim, wrapper and documentation |
| [Box3D](https://github.com/erincatto/box3d/tree/d421e45c828f6f853a145f726f0b9425d31146eb) | `d421e45c828f6f853a145f726f0b9425d31146eb` | Exact dependency pinned by that core's `gdext/setup_deps.sh` |
| odin_godot | `56e4ab3` | Existing Replay value/frame, correction and audit contracts |

The baseline investigation found a different game dependency chain:
`multi-box-3d@987f4ca44d0065676f17cab35edad57fcbb63b13` vendors
`rollback-in-a-box@91e01dc75e8dfe3fbd890f21361e27b31fa2e994`, which pins
`Box3D@540ea387b0c02bf714fbfdcc8fb88c039c35fe6f`. Results from that game do
not automatically establish correctness of the newer neutral core audited here.
See [upstream reproduction](upstream-baseline.md).

## API ownership and snapshot coverage

The reusable [C shim](https://github.com/pdaddyo/rollback-in-a-box/blob/9e1fe882a0ea4eb52e160d5754a752580b4db462/core/src/rollback_shim.c)
calls private Box3D recording functions. `B3RollbackCtx` owns a world ID, reusable
slot buffers, a long-lived `b3Recording` geometry registry, and a registry view
used during restore. The public Box3D step/lifecycle API alone does not supply
this snapshot contract. Pinning and testing the private ABI is necessary.

The coverage below comes from the pinned
[world serializer](https://github.com/erincatto/box3d/blob/d421e45c828f6f853a145f726f0b9425d31146eb/src/world_snapshot.c#L980),
not from assumptions about node poses:

| State | Captured behavior | Adapter consequence |
|---|---|---|
| World configuration | Gravity, contact tuning, speed thresholds, step index, inverse timestep, sleep/warm-start/continuous/speculative flags, capacity and end-event buffer index | Keep tick/substep policy and immutable host configuration compatible |
| Object allocation | All six ID pools, sparse body/shape/contact/joint arrays, generations and free lists | Restore gameplay allocation counters and mappings in the same transaction |
| Solver sets | Body simulations/states, joint simulations, contact indices and island simulations, including sleeping sets | Restoring poses alone would lose required solver state |
| Contacts | Sparse contact records, manifolds including accumulated impulses, mesh triangle caches | Useful warm-start/contact restore coverage; contact-heavy tests remain required |
| Joints | Sparse organizational records and joint solver data in sets/graph colors | Test each supported family and its motor/limit state |
| Islands/sleep | Island membership, constraint-removal counters, body sleep fields and sleeping solver sets | Test sleep/wake and split-island transitions after rewinds |
| Broadphase | Dynamic trees, nodes, moved-proxy bitsets, move array and pair hash table/probe layout | Broadphase traversal state is part of the snapshot |
| Constraint graph | Body sets, joint simulations and contact lists by color | Transient prepared SIMD/constraint buffers are omitted |
| Sensors | Hits and both overlap-history arrays with shape IDs/generations | Event output buffers are a separate omission below |
| Shapes/materials | Filters, flags, owned material arrays, sphere/capsule geometry; registry IDs for hull/mesh/heightfield/compound data | Geometry registry lifetime is part of snapshot ownership |
| Names | Name-cache entries | These contribute snapshot bytes even though they are not gameplay state |
| `userData` | Body, shape and joint pointers are written/loaded as null | Rebind host associations from stable rollback-owned identities; never depend on restored pointers |
| Host callbacks | World filter, pre-solve, friction/restitution, task callbacks and their contexts are not serialized | Keep callback identity/configuration fixed and put any mutable callback dependencies in rollback state |
| Host world wiring | World slot/generation, scheduler, workers, allocator/scratch/profiling, recording and world `userData` remain host-owned | Restore only at a settled, unlocked boundary with no concurrent step/query/registry mutation |
| Debug renderer | Shape renderer handles may be retained for matching slot/generation; vanished handles can invoke host destruction callbacks | Disable these callbacks in speculative/audit worlds or explicitly isolate their side effects |
| Event outputs | Body moves, begin/end touch arrays, contact hits and joint-event arrays are not serialized | Fold physics events into framework-owned occurrences before capture; define event-buffer reset/restoration explicitly |
| Game side-state | Entity mappings, gameplay RNG, health, timers, spawn counters, input edges and queued game events are absent | Kit and Replay must own and restore them alongside the solver |

`b3DeserializeIntoShell` also operates over populated worlds, as the shim uses it
for in-place loads. It tears down/rebuilds per-object storage while retaining
host wiring. Header validation precedes mutation, but later parsing can fail
after freeing or modifying the live world. It is **not an atomic transaction**.
The adapter must never mistake a false return for an untouched published world.

Event arrays merit a specific regression gate: the focused probe below saved a
world before stepping, advanced it, and loaded the old snapshot. The future
`bodyMoveEvents` entry remained present. Begin/hit outputs clear at the next
step, while end events are double-buffered; restoring only their buffer index
does not restore their contents. Verify destroy-before-step and sensor/contact
end events across rewinds rather than assuming the next step repairs all cases.

## Detached storage, geometry, and cross-world restores

A slot's bytes can be copied into independent storage, but those bytes are not
a self-contained portable world. They contain geometry registry IDs whose
definitions live in the context. Registry entries append as new geometry appears;
old blobs remain until context destruction. Meshes and heightfields in a restored
world point directly into registry bytes; compounds use lazily reconstructed
registry-owned live data. Hulls are cloned into the world's hull database.
Consequently **destroy the world before its context/registry**. Rebuilding a
context while a live restored mesh/heightfield/compound still borrows its data
requires particular care.

The current C shim exposes save/load by slot within one context. It supplies no
snapshot clone/export/import, retained lease, independent byte-buffer read, or
destination-world parameter. A copied integer slot number or live `rawptr` is
therefore not a detached Replay `Frame`.

The underlying internal deserializer accepts another world and a compatible
registry reader. The focused probe restored a simple hull-body snapshot into a
different live world and matched one subsequent motion step. That establishes a
narrow candidate mechanism for scratch worlds, not a general clone guarantee.
The destination retains its host world identity; application body IDs must
replace `world0` with the destination world slot while preserving snapshot-era
object index/generation. Cross-world contacts, joints, sensors, mesh assets,
callback wiring and long resimulation still need targeted proof.

Within the same world, snapshot-era handles become valid again and objects
created after capture disappear. A post-snapshot handle can subsequently become
numerically valid again when a resimulated spawn reuses that slot/generation.
The probe observed this reuse. External presentation objects must use restored
game identities and mappings, not interpret a raw handle as durable identity.

## Image compatibility and hash limitations

The snapshot is raw native struct data plus variable sections. Its header checks
magic, format version 2, a size-derived layout hash and float/double precision.
It does not establish endian independence, semantic field compatibility or all
compiler/configuration compatibility. Size-only layout hashing cannot detect
every ABI change. Keep images local to the exact supported build and validate
the dependency/configuration fingerprint separately.

Snapshot byte equality is not canonical logical equality. Live `b3Shape` images
retain their geometry-union pointer bits before the serializer writes the
separate registry reference; the union is only zeroed for free slots. Native
padding and other storage details also require normalization. The probe produced
equal motion hashes but unequal images for equivalent simple worlds. A fixed
`[N]u8` array satisfies Replay's value-type checker without resolving these
ownership or canonicalization issues.

The pinned
[`b3HashWorldState`](https://github.com/erincatto/box3d/blob/d421e45c828f6f853a145f726f0b9425d31146eb/src/recording.c#L1235)
hashes live body positions/orientations and awake linear/angular velocities.
It does **not** hash gravity/configuration, contacts or warm-start impulses,
shape definitions/materials, joint settings/impulses, ID pools, sleeping timers,
sensor histories or gameplay state. The neutral wrapper adds its frame number,
normalized body index/generation table and convenience rendering metadata.
Neither function is a complete solver-state digest. The probe changed gravity
without changing the upstream hash.

Matching motion hashes remain a useful observation, but cannot establish the
original plan's complete confirmed-state equivalence. Before treating hash
agreement as a correctness gate, implement a documented canonical digest over
all simulation-affecting state plus game side-state. Exclude pointers, host world
indices and presentation data; normalize geometry identity independently of
registry insertion order. The binary's small simulation fingerprint can reject
some incompatible builds, but its 90-frame motion probe is not a proof of every
world or cross-platform determinism.

## Allocation and static-geometry costs

[Issue #134](https://github.com/erincatto/box3d/issues/134) remains open when
checked. Its August maintainer reply identifies collision-mesh duplication as
an obstacle to a public snapshot API. The audited revision already interns
geometry outside each slot; retain the issue's concern as historical context,
then measure the current implementation rather than repeating the older
blanket cost assumption.

Interning reduces retained duplicated bytes, but the pinned
[`b3RecInternHull/Mesh/HeightField/Compound`](https://github.com/erincatto/box3d/blob/d421e45c828f6f853a145f726f0b9425d31146eb/src/recording.c#L1190)
still allocates, copies and hashes a geometry blob on each call. Deduplication
compares its bytes and frees the temporary duplicate. The warmed single-hull
probe observed **one Box3D allocation per save**, despite reuse of the slot
buffer. Do not interpret buffer reuse as an allocation-free snapshot path.
Restore also rebuilds various arrays/materials/manifolds/trees and allocates
shape-handle scratch. Benchmark allocation count and bytes as well as wall time.

The geometry registry is append-only, including geometry first encountered on
speculative branches. A bounded slot count alone does not bound its retained
memory. Measure registry bytes/high-water marks, unique geometry spawn/churn,
slot capacity, save/load allocations, and game-side history separately. Define
an asset lifetime/cap or safe registry compaction policy before production.

## Requirements for the framework adapters

Kit can extend its existing correction lane, but must include complete external
solver and side-state restore. Replay must preserve the guarantees already
provided by [its timeline](../../../replay/timeline.odin) and
[correction operations](../../../replay/correction.odin):

1. Frames and saved checkpoints retain complete detached state. A `World`
   snapshot token is sufficient only if ownership, export and lifetime are
   explicitly part of the frame contract; `ctx.user` alone does not provide this.
2. Stage suffix resimulation separately from published state. Failed steps,
   rejected commit gates, rejected actions and audit runs leave published solver
   state, mappings and occurrences unchanged. The destructive upstream loader
   needs scratch-world staging or an equally explicit rollback-on-failure design.
3. Atomicity includes intermediate action predicates: Replay can restore a
   copied `State` after an action returns false, so an action that mutated an
   external solver needs the corresponding subtransaction or a deferred command
   policy. Whole-tick save/load alone does not cover this case.
4. An audit may execute a complete suffix but must restore/retain the published
   head. `rewind`, checkpoint reset, frame-copy resume, history wrap and destruction
   need matching solver ownership operations too.
5. `correct_reusing` must compare the complete predecessor state. A slot index or
   narrow motion hash cannot justify reusing a record. Disable this optional
   optimization for the first adapter unless complete equivalence is established.
6. Deliver physics callbacks/events through framework-owned deterministic inputs
   and occurrences. Keep Godot presentation and debug callbacks outside scratch
   execution. Rebind any required host pointers after load.
7. Local opaque images and canonical recovery are different contracts. Do not
   send these raw images as general late-join/migration data, or claim P2P
   support by hiding floating solver data inside integer byte-array schemas.

These are design requirements inferred from the audited sources. P0.5 must
select and document the representation and transaction implementation; this
audit does not change either framework's runtime.

## Focused native probe

This audit built Box3D and the current neutral core in an isolated scratch
project. It did not run the upstream Godot/game suite; those results belong to
the separate baseline report. Environment: macOS 15.8 arm64, Apple Clang 16.0.0,
CMake 3.31.3, Unix Makefiles, Debug, default NEON SIMD, single worker,
`-ffp-contract=off`, float precision. `BOX3D_VALIDATE` was not defined in this
subdirectory build; normal Debug assertions were active.

Observed results, both probe processes exiting 0:

```text
motion_hash_ignores_gravity=1
warmed_hull_save_box3d_allocations=1
body_user_data_cleared=1 snapshot_bytes=6341 post_restore_future_move_events=1
future_handle_invalid_after_restore=1 same_handle_reused_on_respawn=1
equal_motion_hashes_unequal_snapshot_bytes=1 image_bytes=6341 registry_entries=1
internal_cross_world_import_with_shared_registry=1 retargeted_handle_valid=1 one_step_motion_hash_matches=1
snapshot_audit_probe: PASS
```

A separate malformed-image process additionally observed:

```text
truncated_load_returns_false_after_mutating_gravity=1
corrupt_probe: PASS (isolated process exits without destroying the damaged world)
```

The malformed image used a valid header with a 112-byte truncated body. An
exploratory attempt to destroy that partly restored world asserted in the ID
pool. The final corrupt-image probe deliberately exits its isolated process
without normal teardown. These images must stay trusted/local, and a failed
parse must not be installed into the published world. This probe is a narrow
boundary check, not a memory-safety or fuzzing campaign.

Scratch evidence for this run:
`/var/folders/f5/n795h3hd5nxbqwzvt3t6bpcw0000gp/T/box3d-phase0-qu5lt6zn/snapshot/`
contains the pinned clones, `audit_probe.c`, `CMakeLists.txt`, `configure.log`,
`build.log`, `probe.log`, and `corrupt-probe.log`. The complete probe and build
recipe follow so the finding does not depend on retaining temporary files.

Gate A still needs contact/joint/sensor/lifecycle corpus coverage, complete
logical digest checks, long/random rewinds, 100/500-body timing/memory results,
and evidence for each supported compiler/target. Neither the source audit nor
this one-body probe satisfies Gate A.

### Reproduce the focused probe

In a fresh scratch directory, fetch the exact revisions and save the two code
blocks below as `CMakeLists.txt` and `audit_probe.c`:

```sh
git clone https://github.com/erincatto/box3d.git box3d
git -C box3d checkout --detach d421e45c828f6f853a145f726f0b9425d31146eb
git clone https://github.com/pdaddyo/rollback-in-a-box.git rollback-in-a-box
git -C rollback-in-a-box checkout --detach 9e1fe882a0ea4eb52e160d5754a752580b4db462
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --target snapshot_audit_probe -j 6
./build/snapshot_audit_probe
./build/snapshot_audit_probe corrupt
```

The corrupt case is deliberately a separate process. Check both exit statuses.
No Godot or godot-cpp build is required for this probe.

```cmake
cmake_minimum_required(VERSION 3.22)
project(snapshot_audit_probe LANGUAGES C CXX)
add_compile_options(-ffp-contract=off)
add_subdirectory(box3d)
add_subdirectory(rollback-in-a-box/core neutral)
add_executable(snapshot_audit_probe audit_probe.c)
target_include_directories(snapshot_audit_probe PRIVATE box3d/src)
target_link_libraries(snapshot_audit_probe PRIVATE box3d_rollback_neutral)
set_property(TARGET snapshot_audit_probe PROPERTY C_STANDARD 17)
```

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>
#include "box3d/box3d.h"
#include "rollback_shim.h"
#include "physics_world.h"
#include "recording.h"
#include "recording_replay.h"
#include "world_snapshot.h"

#define CHECK(condition) do { if (!(condition)) { fprintf(stderr, "CHECK failed: %s:%d: %s\n", __FILE__, __LINE__, #condition); exit(1); } } while (0)

static _Atomic unsigned long allocation_calls;
static void *count_alloc(int32_t size, int32_t alignment) {
    void *p = NULL;
    CHECK(posix_memalign(&p, (size_t)alignment, (size_t)size) == 0);
    atomic_fetch_add(&allocation_calls, 1);
    return p;
}
static void count_free(void *p) { free(p); }

static b3BodyId add_body(b3WorldId world, float y) {
    b3BodyDef body_def = b3DefaultBodyDef();
    body_def.type = b3_dynamicBody;
    body_def.position = (b3Vec3){0, y, 0};
    b3BodyId body = b3CreateBody(world, &body_def);
    b3ShapeDef shape_def = b3DefaultShapeDef();
    b3BoxHull hull = b3MakeBoxHull(0.5f, 0.5f, 0.5f);
    b3CreateHullShape(body, &shape_def, &hull.base);
    return body;
}

int main(int argc, char **argv) {
    (void)argv;
    b3SetAllocator(count_alloc, count_free);
    setvbuf(stdout, NULL, _IONBF, 0);
    b3r_install_exit_on_assert();
    b3WorldDef def = b3DefaultWorldDef();
    def.workerCount = 1;
    b3WorldId a = b3CreateWorld(&def);
    b3BodyId body_a = add_body(a, 4.0f);
    B3RollbackCtx *ctx = b3r_create(a, 3);
    CHECK(ctx != NULL);
    b3World *world_a = b3GetWorldFromId(a);

    uint64_t hash = b3r_world_hash(a);
    b3World_SetGravity(a, (b3Vec3){0, -99, 0});
    CHECK(hash == b3r_world_hash(a));
    printf("motion_hash_ignores_gravity=1\n");
    b3World_SetGravity(a, def.gravity);

    b3Body_SetUserData(body_a, (void*)0x1234);
    int snapshot_bytes = b3r_save(ctx, 0);
    CHECK(snapshot_bytes > 0);
    unsigned long before_save_allocs = atomic_load(&allocation_calls);
    CHECK(b3r_save(ctx, 0) == snapshot_bytes);
    printf("warmed_hull_save_box3d_allocations=%lu\n", atomic_load(&allocation_calls) - before_save_allocs);
    CHECK(world_a->bodyMoveEvents.count == 0);
    b3World_Step(a, 1.0f/60.0f, 4);
    int future_move_events = world_a->bodyMoveEvents.count;
    CHECK(future_move_events > 0);
    CHECK(b3r_load(ctx, 0));
    CHECK(b3Body_GetUserData(body_a) == NULL);
    CHECK(world_a->bodyMoveEvents.count == future_move_events);
    printf("body_user_data_cleared=1 snapshot_bytes=%d post_restore_future_move_events=%d\n", snapshot_bytes, future_move_events);

    b3BodyId future_body = add_body(a, 8.0f);
    CHECK(b3r_load(ctx, 0));
    CHECK(!b3Body_IsValid(future_body));
    b3BodyId replacement = add_body(a, 20.0f);
    CHECK(b3StoreBodyId(future_body) == b3StoreBodyId(replacement));
    printf("future_handle_invalid_after_restore=1 same_handle_reused_on_respawn=1\n");
    CHECK(b3r_load(ctx, 0));

    b3WorldId b = b3CreateWorld(&def);
    add_body(b, 4.0f);
    b3Recording *rec_a = b3CreateRecording(0);
    b3Recording *rec_b = b3CreateRecording(0);
    b3RecBuffer image_a = {0}, image_b = {0};
    b3SerializeWorld(world_a, &image_a, rec_a);
    b3SerializeWorld(b3GetWorldFromId(b), &image_b, rec_b);
    CHECK(b3r_world_hash(a) == b3r_world_hash(b));
    CHECK(image_a.size == image_b.size);
    CHECK(memcmp(image_a.data, image_b.data, image_a.size) != 0);
    printf("equal_motion_hashes_unequal_snapshot_bytes=1 image_bytes=%d registry_entries=%d\n", image_a.size, rec_a->registry.count);

    b3RegistrySlot *slots = calloc((size_t)rec_a->registry.count, sizeof(*slots));
    for (int i = 0; i < rec_a->registry.count; i++) {
        slots[i].kind = rec_a->registry.entries[i].kind;
        slots[i].byteCount = rec_a->registry.entries[i].byteCount;
        slots[i].bytes = rec_a->registry.entries[i].bytes;
    }
    b3RecReader reader = {0};
    reader.ok = true;
    reader.replayWorldId = b;
    reader.slots = slots;
    reader.slotCount = rec_a->registry.count;
    CHECK(b3DeserializeIntoShell(image_a.data, image_a.size, b3GetWorldFromId(b), &reader));
    CHECK(b3r_world_hash(a) == b3r_world_hash(b));
    b3BodyId retargeted = body_a;
    retargeted.world0 = b.index1 - 1;
    CHECK(b3Body_IsValid(retargeted));
    b3World_Step(a, 1.0f/60.0f, 4);
    b3World_Step(b, 1.0f/60.0f, 4);
    CHECK(b3r_world_hash(a) == b3r_world_hash(b));
    printf("internal_cross_world_import_with_shared_registry=1 retargeted_handle_valid=1 one_step_motion_hash_matches=1\n");

    if (argc > 1) {
    b3WorldId damaged = b3CreateWorld(&def);
    b3World_SetGravity(damaged, (b3Vec3){0, -77, 0});
    b3RecReader damaged_reader = reader;
    damaged_reader.replayWorldId = damaged;
    CHECK(!b3DeserializeIntoShell(image_a.data, 112, b3GetWorldFromId(damaged), &damaged_reader));
    CHECK(b3GetWorldFromId(damaged)->gravity.y == def.gravity.y);
    printf("truncated_load_returns_false_after_mutating_gravity=1\n");

    puts("corrupt_probe: PASS (isolated process exits without destroying the damaged world)");
    _Exit(0);
    }
    b3DestroyWorld(b);
    b3DestroyWorld(a);
    b3r_destroy(ctx);
    b3RecBufFree(&image_a);
    b3RecBufFree(&image_b);
    b3DestroyRecording(rec_a);
    b3DestroyRecording(rec_b);
    free(slots);
    puts("snapshot_audit_probe: PASS");
    return 0;
}
```
