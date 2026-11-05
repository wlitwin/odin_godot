# Moving a Godot physics scene to an authored Box3D world

Box3D is an explicitly stepped backend shared by Kit and Replay. It is not a
replacement `PhysicsServer3D` registration, and changing a project physics-server
setting does not convert an existing scene. The authored nodes describe initial
content. Each framework owns simulation ticks, history, input and recovery.

## Map scene content deliberately

| Existing Godot content | Authored Box3D counterpart | Required decision |
| --- | --- | --- |
| A group of physics bodies | `Box3DWorld3D` | Give the world an explicit namespace key and choose Kit or Replay as tick owner. |
| `RigidBody3D` | `Box3DBody3D` with Dynamic type | Move impulses and other mutations into staged tick callbacks. |
| Static collision | Static `Box3DBody3D` | Assign immutable shape Resources before play. |
| `CollisionShape3D` | Box/sphere/capsule/hull/mesh/heightfield Resource | Supply an explicit shape key; bake supported shape scale and local pose. |
| `Area3D` overlap logic | `Box3DSensor3D` or sensor flags | Capture actual sensor observations at the tick boundary and route effects after publication. |
| `CharacterBody3D` | `Box3DCharacterMover3D` configuration plus value state | Store position, velocity and grounding in Game/Side and supply desired velocity each fixed tick. |
| Godot joint nodes | The corresponding named Box3D joint node | Use body stable-key references and explicit rigid local frames. |
| PhysicsServer/direct-space queries | Staged deterministic motion query helpers | Read copied keyed results from the same execution world as the tick. |

Presentation node names and child order are not identity. Give every body,
resource, joint and character an explicit stable key. Keep those keys when
renaming display nodes. Duplicate or conflicting keys are errors; do not repair
them by assigning insertion-order IDs. Changing semantic geometry or simulation
settings changes content compatibility identity.

## Replace automatic callbacks with the existing tick model

Sample device input into the framework's control value. The authored callback
then applies accepted/predicted controls, runs character queries/movement against
the staged world and performs the framework's ordinary solver step. Kit's
participant performs its step; Replay requires its existing `physics.step`
operation exactly once. Do not also step in `_physics_process`, a visual node,
an Inspector tool or a renderer.

Keep gameplay timers, RNG, body/joint allocation-key maps, character values and
query-dependent decisions in rollback-owned Game or Side. Live Nodes, Resources,
native handles, process-local Owner tokens and pointers do not belong there.
Presentation consumes a copied published checkpoint/frame and updates visual
proxies afterward. A pose change on a proxy does not change the solver.

Kit and Replay remain distinct. Kit attaches the complete solver/Side participant
to its Lane and uses its World protocol. Replay's existing Timeline, complete
checkpoint provider, revisions and event journal already own resimulation and
rollback. Do not introduce a second timeline, correction loop or network stack.

## Preserve complete checkpoints and owner lifetime

A copied transform, ordinary value-only Replay `Frame`, motion digest or native
handle is not a complete physics checkpoint. Use the framework's explicit complete
capture/view/clone/destroy and canonical codec operations. Recovery compares
solver, Game, Side, observations and occurrences together. A pose-only reseed
must not be presented as equivalent recovery.

Extract and validate a detached bake before play. Shared construction returns a
world, trusted asset catalog and local logical-ID/allocation-key maps. Transfer or
borrow the world exactly as the selected adapter documents. Keep catalog and
allocator owners alive for every checkpoint, codec and callback that retains them.
SDK code uses real Meter and code/data leases; a raw pointer or a code pin alone
does not own callback data. Check every teardown result before discarding an owner.

Source scene nodes and Resources may be destroyed after successful copying. A
versioned owning artifact can reload through the same shared parser/baker. Exact
source, import version, content identity and shared-bake fingerprint are checked
before native publication. Hashes establish identity and corruption checks, not
publisher authentication.

## Supported behavior and explicit boundaries

Triangle meshes and heightfields are static, non-sensor geometry with sensor
events disabled. Hulls are convex point clouds. Heightfields bake to triangle
meshes; transformed boxes can bake to exact hull vertices. Body and World
transforms are rigid. Do not rely on cancelling body scales, shear, reflections
in a body pose or top-level ancestry to silently disappear. The mesh import tool
can explicitly bake a nonsingular affine source transform into geometry. It
converts Godot's clockwise triangles to Box3D's counter-clockwise ones and welds
and repairs the mesh so a fast body does not pop at seams between parts; see the
[editor workflow](editor.md).

Pin uses a spherical point constraint, Hinge a Revolute constraint and Slider a
Prismatic constraint. The remaining named types use their matching native
families. The current profile permits one joint at a time, not an arbitrary
constraint graph. It also retains 35 bodies/shapes, 32 dynamic bodies, eight
deduplicated geometry assets, H128, prediction/ordinary repair depth eight and the
64 MiB tracked admission limit. Debug preview has its own smaller output limits;
preview Capacity does not change simulation capacity.

Raw native query traversal order is not a durable gameplay ordering. Use the
complete sorted motion queries when ordering affects decisions, and check
Capacity before consuming results. Native allocation keys identify recorded
history; durable authored logical IDs remain separate.

Do not access a live solver during render interpolation or resolve a Godot
Resource during resimulation. Arbitrary runtime geometry edits, unsupported
callback changes, cross-domain handles and private clock/head setters are not
fallbacks for a rejected operation. Return the named error and preserve the last
published state.

Kit exposes its current public World Reset request. Replay's public Godot facade
does not expose a manual Resync command in this version. Its sample reports that
capability as unsupported while using the existing automatic canonical recovery
path. A disabled UI action must not silently mutate private client phase.

## Diagnosing a migration

| Reported field/status | Meaning and next action |
| --- | --- |
| `Key`, `Duplicate`, `Collision`, `Reference` | Fix explicit keys and same-world references before construction. |
| `Pose`, `Scale`, `Nonfinite`, `Dimension` | Inspect the named field; do not clamp or drop authored content implicitly. |
| `Unsupported` | Choose a supported geometry/body/flag/capability combination. |
| `Capacity`, resource/budget error | Reduce the scene or requested bounded output; do not raise runtime caps to hide it. |
| Artifact version/hash/shared-bake mismatch | Reimport from the declared source using the current shared baker. |
| Missing complete history or attachment | Use the existing framework recovery path; do not substitute the live world. |
| Declined owner teardown | Retain the surviving owner and finish the documented release order. |

The current functional evidence is a bounded same-build/same-target desktop
reference. Cross-target determinism, exported platform coverage, performance and
long-run resource behavior have their own checks. See the separate
[Kit and Replay samples](samples.md), [authoring API](authoring.md),
[motion contract](motion.md) and [editor workflow](editor.md).
