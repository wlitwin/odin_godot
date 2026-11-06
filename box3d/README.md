# Box3D native backend

This package is the framework-independent, explicitly stepped Box3D backend
shared by the separate Kit and Replay adapters. It owns native physics resources.
Each adapter owns its game state, stable entity mappings, input history,
transactions and presentation.

The authoritative foreign boundary is `native/api.h` and the additive
`native/motion.h`, with owned snapshots and
normalized state diagnostics in `native/owned_snapshot.h` and
`native/state_dump.h`. The Odin declarations mirror that flat C API, not Box3D's
private layouts or any C++ class. Engine and shim revisions, notices and build
configuration are recorded in `dependency.json` and the native build metadata.

## Build and use

Build one pinned engine and shim archive, then give its absolute path to Odin:

```sh
nix develop --command bash build/build_box3d.sh Debug .box3d-cache
nix develop --command odin check box3d -no-entry-point \
  -define:BOX3D_LIBRARY="$(pwd)/.box3d-cache/build/Debug/libogb3.a"
nix develop --command bash tests/box3d/run.sh \
  "$(pwd)/.box3d-cache/build/Debug/libogb3.a"
```

Use `Release` for the optimized native build. Native assertions, validation and
the floating-point policy remain enabled. `BOX3D_LIBRARY` defaults to
`native/libogb3.a` relative to this package; no archive is committed. Import the
package as `godot:box3d` with the existing repository collection, or use its local
path. Linux additionally links libm. The supported initial native targets are
macOS arm64 and Linux x86-64; evidence for each target is recorded separately.

```odin
world, status := box3d.world_create(box3d.world_def_default())
if status != .Ok {return}
defer box3d.world_destroy(&world)

def := box3d.body_def_default()
def.type = .Dynamic
def.pose.position = {0, 3, 0}
body, body_status := box3d.body_create(world, def)
if body_status != .Ok {return}
_, shape_status := box3d.shape_box(body, box3d.shape_def_default(), {0.5, 0.5, 0.5})
if shape_status != .Ok {return}
if box3d.world_step_fixed(world) != .Ok {return}

snapshot, capture_status := box3d.snapshot_capture(world)
if capture_status != .Ok {return}
defer box3d.snapshot_destroy(&snapshot)
```

Use native default constructors before changing definition fields. POD flag
fields use `u32` values 0/1, body kinds use `Body_Type`, and public body/shape/
joint mutation helpers accept Odin booleans where applicable. `abi_check` compares
the ABI version and every POD field's offset, size and alignment with C.
`world_create` runs it before creation. Default constructors fail loudly on an
incompatible ABI before C can write to a POD.

Object operations return `Status`; validity queries return `(bool, Status)` and
report stale handles as `false, .Ok`. Creation returns `(typed_handle, Status)`.
Read outputs only after checking status. Native wrapper allocation failures can
return `.Out_Of_Memory`; upstream engine allocations still assert on exhaustion.

## Simulation contract

Positions use meters in a Y-up, right-handed coordinate system. Rotations use
quaternions in `(x, y, z, w)` order. Transforms are rigid; bake scale into immutable
geometry. The initial corpus uses one worker, 60 ticks per second and four
substeps. Process-wide unit settings must be initialized before creating worlds:
`set_length_units_per_meter` (default 1) scales Box3D's contact slop, speculative
distance and AABB margins, so a scene far smaller than a metre can use e.g. 0.1.
Call it before the first world, geometry or `build_fingerprint`; afterwards only the
current value is accepted. The fingerprint includes it. Kit and Replay are validated
with 1 only.
Keep engine configuration and callback identity fixed during a simulation run.

ABI 2 exposes the rest of Box3D's value settings; in each, 0 keeps Box3D's
default, so existing definitions are unchanged:

| Definition | Settings |
| --- | --- |
| `World_Def` | `restitution_threshold`, `hit_event_threshold`, `contact_hertz`, `contact_damping_ratio`, `contact_speed` (push-out speed), `maximum_linear_speed`, `isotropic_inertia_tolerance`, `restitution_iterations`, `enable_restitution_propagation` |
| `Body_Def` | `allow_fast_rotation`, `motion_locks` (`Motion_Locks` bit set), `safety_factor`, `disable_contact_recycling` |
| `Shape_Def` | `rolling_resistance`, `tangent_velocity` (conveyor), `skip_contact_creation`, `disable_speculative_contact` |

Box3D scales the world thresholds and speeds by the length unit, so a game that
sets `set_length_units_per_meter(0.1)` also shrinks the restitution threshold to
0.1 m/s and the push-out speed to 0.3 m/s; set them back explicitly if the bodies
move at ordinary speeds. Box3D caps spin at a quarter turn per step (47 rad/s at
60 Hz) unless a body sets `allow_fast_rotation`; a small ball rolling faster than
radius x 47 m/s otherwise slides. Above that cap the contact point turns with the
ball within a substep, so a fast-spinning ball rides about r(1 - cos(w h)) into
the floor (h = one substep). Rolling resistance limits a contact's angular impulse
to `rolling_resistance` x radius x normal impulse, so it only lets friction start
a roll when the mixed friction (Box3D's default is `sqrt(a * b)`) is well above
it; against a mesh the radius is the rolling shape's, against a box or hull it is
the larger of that and a quarter of the hull's inner radius. The SDK's engine
patch `rolling_resistance_limit.patch` makes that limit apply to light bodies:
upstream compared the squared impulse with an absolute `FLT_EPSILON`, which a
0.2 kg ball's impulses never exceed, so rolling resistance held its spin at zero.
Settings that only matter through callbacks or APIs
the SDK does not expose (custom filtering, pre-solve and hit events, explosions,
manual mass) are left out. Snapshots and recovery keep all of these.

All mutation, queries, capture and restore happen at settled step boundaries on
the owning thread. The package does not schedule ticks or mutate Godot scenes.
Run Odin tests with `-define:ODIN_TEST_THREADS=1`; the supplied test script does so.

Query and sensor APIs copy results into caller-owned slices and return the total
available count. `.Capacity` means the prefix that fits was copied; retry with
enough storage for a complete result. Empty slices are valid size queries.
Query order is the engine's traversal order; adapters choose any required stable
game-ID ordering after copying. Ray translation is the full displacement.
The hinge axis is local Z in both local frames.

The additive motion API supplies `query_aabb`, `query_ray_sorted`,
`query_capsule` and `query_capsule_cast`. These gather complete bounded results,
return allocation keys and sort by hit fraction and stable key/geometry ties.
An undersized output returns `.Capacity` without publishing a partial prefix.
`Motion_Filter` includes sensor selection and an explicit self body exclusion.
The existing raw query functions retain their earlier behavior.

`character_step` reads the actual world and returns explicit caller-owned
`Character_State` through `Character_Result`. It uses the pinned engine's
capsule casts and collision-plane solver; it neither mutates a body nor steps
the world. Store that value in Game/Side and call it from the existing framework
tick. The accepted time step is zero or the existing fixed 1/60. See the
[motion contract](../docs/design/box3d/motion.md) for the distinct Kit and Replay
entry points and the authored node/resource surface.

Both the sensor and convex visitor shapes must enable sensor events. This initial
API supports primitive/convex sensors and static mesh collision. Mesh sensor or
mesh visitor event flags return `.Unsupported`; the pinned engine's sensor path
cannot form a convex proxy for a mesh visitor. Geometry beyond the supported
surface needs explicit native support and
evidence before use. `Motion_Joint_Def` supports Pin, Hinge, Slider, Spherical,
Distance, Motor, Weld and Wheel. Pin maps to a spherical point constraint,
Hinge to Revolute and Slider to Prismatic. Each definition uses world-independent
body allocation keys, and creation returns a joint key. The current profile
still permits one joint at a time.

## Ownership and identity

Worlds and bodies/shapes/joints use distinct typed native handles. These are
runtime references, not durable game identities. Destroying a body also destroys
its shapes and joints. Destroying a world invalidates all its object handles.
Zero is the empty value. Destruction helpers clear the caller's owning variable
after successful destruction; ordinary copies do not create another owner.
World/body/shape/joint destruction returns `.Invalid_Handle` for an empty or
stale handle. Snapshot and geometry destruction accept an empty owner.

`Geometry` owns copied hull points or indexed mesh vertices. Mesh indices are
triangle triples. `geometry_destroy` releases the caller's lease, and any native
shape/world ownership remains valid. Native worlds conservatively retain mesh
asset leases through destroyed-shape history until world destruction; use bounded
predeclared assets. Snapshot geometry metrics describe reachable retained assets,
not every native/wrapper allocation.

Snapshots own their images and immutable geometry dependencies. Clone explicitly
when a second history entry or checkpoint needs independent ownership, and
destroy each owner once. Copying a snapshot value aliases its native owner; it
does not clone. A successful restored world retains the geometry dependencies it
needs independently of the snapshot that supplied them.

Restore clears process-local body/shape/joint user data and output event buffers.
Adapters must reconstruct their associations from rollback-owned stable mappings.
Snapshot-era handles can become valid again, and future resimulated spawns can
reuse a numerical handle. A handle's value therefore does not identify a unique
gameplay lifetime. Cross-world restore also requires native handle retargeting.
Use `body_retarget`, `shape_retarget` and `joint_retarget` with snapshot-era
handles and the destination world. `body_identity` returns native allocation
index/generation without the world slot; it still is not durable game identity.

Capture physics and deterministic game state at the same tick. A physics snapshot
alone does not include gameplay RNG, entity/body maps, timers, health, pending
commands or framework events. Stage speculative execution in a separate world;
publish physics and game state together only after all checks succeed.

## Complete state and diagnostics

The motion digest covers poses and awake velocities. It is a diagnostic only.
It cannot establish complete solver equality or justify reusing a rollback suffix.
The normalized solver dump/digest carries an explicit coverage/version contract;
its supported coverage must be checked against the native manifest. Adapters
still need to include deterministic game side-state in a complete checkpoint or
comparison. Preserve normalized bytes when diagnosing mismatches.

`world_dump`/`snapshot_dump` return `(required_bytes, Status)`. Any empty slice is
a successful size query. A nonempty undersized slice returns `.Capacity` without
writing a partial dump. `world_digests`/`snapshot_digests` return explicitly named
`complete_solver_digest` and `motion_digest` fields. Snapshot diagnostics inspect
its sealed captured resource directly. `state_version`, `state_coverage` and
`build_fingerprint` describe compatibility; the fingerprint is diagnostic only.

`snapshot_metrics` reports image used/capacity and geometry bytes/count. Clones
have independent leases on one immutable resource, so summing clone metrics can
double-count shared storage. `engine_allocation_stats` reports process-wide
engine calls/requested bytes/live/high-water bytes; it excludes wrapper mallocs
and snapshot owner/normalized-dump mallocs. Neither counter set alone measures
total backend memory.
`snapshot_storage` additionally reports retained normalized bytes, wrapper malloc
bytes and native requested bytes for the captured resource. These per-resource
figures overlap the other counters; consult the native header before totaling
them, and count shared clone storage once.
`snapshot_allocation_stats` reports successful wrapper allocations process-wide,
including temporary digest storage and branch/restore owners and leases. It uses
the same `Allocation_Stats` fields as engine counters. Caller buffers, flat-API
geometry owners and allocator overhead are excluded; these are requested-byte
counters, not process resident memory.

Owned local snapshots are exact-build implementation data. They are separate
from a portable, validated recovery/network codec. Passing the native ownership
and ABI checks does not establish Gate A, cross-target determinism, either
framework integration, or canonical transferred recovery.
