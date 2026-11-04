# Box3D upstream reuse matrix

Source audit recorded October 30, 2026 for board `b_cdde1cdfea104035`, task
`t_44f35034af544ab3` (P0.3). This report covers inspected source, build files,
manifests, and test definitions. It does not claim that the two Godot integrations
were built or their tests passed locally. See [upstream-baseline.md](upstream-baseline.md)
for reproduced results and [snapshot-audit.md](snapshot-audit.md) for the snapshot
implementation audit.

The best initial reuse candidate is Box3D's C API plus the C snapshot shim from
`rollback-in-a-box`. Keep its network session outside the dependency boundary.
Use `box3d-godot` as the principal editor/custom-node reference and
`godot-box3d` as the stock-node/query compatibility reference. Neither Godot
integration currently supplies the ownership and transaction contract required
by both Kit and Replay.

Kit and Replay remain sibling frameworks. Replay already implements complete
gameplay resimulation and rollback; its missing integration is complete external
solver state, not another input, correction, session, or rollback runtime.

## Exact source revisions

The repositories were shallow-cloned into the phase-zero scratch workspace;
recorded revisions identify the inspected trees rather than moving branch names.

| Repository | Inspected commit | Relevant dependency boundary |
| --- | --- | --- |
| [bearlikelion/godot-box3d](https://github.com/bearlikelion/godot-box3d/tree/f073c2de2523bf12163095e920347881352dc8a9) | `f073c2de2523bf12163095e920347881352dc8a9` | Box3D gitlink `3fc20f5b453ba9e14cdf54ecafa87a2a4bcdf53c`; godot-cpp fetched at `godot-4.3-stable`. |
| [Stink-O/box3d-godot](https://github.com/Stink-O/box3d-godot/tree/72bf5f2f9a803e18949507f46dc38916be21ca1c) | `72bf5f2f9a803e18949507f46dc38916be21ca1c` | Fork includes the engine tree; godot-cpp gitlink `ba0edfed90512ec64aba51d4295a3e7e30112f86`. Godot code is under `godot/`. |
| [pdaddyo/rollback-in-a-box](https://github.com/pdaddyo/rollback-in-a-box/tree/9e1fe882a0ea4eb52e160d5754a752580b4db462) | `9e1fe882a0ea4eb52e160d5754a752580b4db462` | Setup script pins Box3D `d421e45c828f6f853a145f726f0b9425d31146eb` and godot-cpp `godot-4.5-stable`. Core can depend on Box3D alone. |
| [pdaddyo/multi-box-3d](https://github.com/pdaddyo/multi-box-3d/tree/987f4ca44d0065676f17cab35edad57fcbb63b13) | `987f4ca44d0065676f17cab35edad57fcbb63b13` | Its rollback-in-a-box gitlink is **`91e01dc75e8dfe3fbd890f21361e27b31fa2e994`**, not the current rollback repository revision above. |

The different Box3D revisions must not be combined by copying headers or C++
wrappers between projects. In particular, the private snapshot layout is bound
to its exact engine revision. P0.4 must record immutable godot-cpp SHAs behind
the tags before adopting a build dependency. The fork's in-tree engine is not
an independent upstream pin for the Odin spike.

## Runtime and API comparison

| Concern | godot-box3d | box3d-godot | rollback-in-a-box |
| --- | --- | --- | --- |
| Integration model | Implements `PhysicsServer3DExtension`; registers a selectable physics server. Stock Godot nodes retain their API. | Registers custom `Node3D`, utility, Resource, and replay classes. Separate Box3D world beside Godot physics. | Engine-neutral C/C++ simulation and network code with thin Godot and Unreal adapters; also a generated raw Godot binding. |
| Tick owner | Godot invokes server `_step`, which steps every active space. | `Box3DWorld` defaults to automatic physics processing; manual `step(delta)` exists. Optional async mode can skip a requested tick while its previous solve remains busy. | `rb::RollbackWorld::step_frame` explicitly invokes `b3World_Step` with configured fixed step/substeps; `rb::RollbackSession` can drive it. The public C API can be stepped directly without either class. |
| Solver snapshots | No snapshot/rollback API found in the integration's `src/` tree. | Recording/player support exists, but the live world API's transform interpolation snapshots are not a complete rollback-world snapshot interface. | `b3r_create/save/load/destroy`, same-context slot buffers, plus wrapper side-state; uses private Box3D snapshot machinery. See the separate audit for its omissions and restore failure behavior. |
| Shapes | Sphere, box, capsule, cylinder, convex/concave polygon, heightmap, boundary, and query-only separation-ray implementations. | Body authors sphere/capsule/hull/mesh/heightfield/compound geometry; child shapes author box, sphere, capsule, cylinder, cone. Box/cylinder/cone become hull geometry. | Raw API includes Box3D geometry families. Convenience `RollbackWorld` only creates static/dynamic boxes, spheres, and capsules; it is not the full raw API. |
| Joints | Pin, hinge, slider, and internal filter joint. ConeTwist and Generic6DOF entry points explicitly reject unsupported operations. | Nine custom joint classes: hinge, slider, distance, ball, fixed, motor, wheel, parallel, filter. Some authoring behavior creates companion constraints. | Raw generated API reaches all native joint families. `RollbackWorld` convenience class does not supply a comparable authoring surface. |
| Queries and characters | Implements direct-space and direct-body Godot APIs, motion recovery/casts, and stock `CharacterBody3D` behavior. | Custom world/body/collision query APIs and a custom kinematic capsule character node. Results commonly contain Godot objects resolved from native `userData`. | Native Box3D C queries are available; generated Godot dispatch is a separate scripting layer. No replacement for Replay's existing game query/input/presentation model. |
| Live identity | Godot RID ownership plus C++ object pointers in native body `userData`. | Nodes retain raw body/shape/joint handles; bodies, child shapes, and joints put Godot node pointers in `userData`. | Wrapper uses packed native body IDs and slot-copied side tables. Raw IDs are explicitly distinguished from game entity IDs. |

Source entry points:

- PhysicsServer registration and stepping:
  [`register_types.cpp`](https://github.com/bearlikelion/godot-box3d/blob/f073c2de2523bf12163095e920347881352dc8a9/src/register_types.cpp),
  [`Box3DPhysicsServer3D::_step`](https://github.com/bearlikelion/godot-box3d/blob/f073c2de2523bf12163095e920347881352dc8a9/src/servers/box3d_physics_server_3d.cpp#L1364),
  [`Box3DSpace3D::step`](https://github.com/bearlikelion/godot-box3d/blob/f073c2de2523bf12163095e920347881352dc8a9/src/spaces/box3d_space_3d.cpp#L77).
- Custom world scheduling and side effects:
  [`Box3DWorld::step`](https://github.com/Stink-O/box3d-godot/blob/72bf5f2f9a803e18949507f46dc38916be21ca1c/godot/src/box3d_world.cpp#L567),
  [`Box3DBody::create_body`](https://github.com/Stink-O/box3d-godot/blob/72bf5f2f9a803e18949507f46dc38916be21ca1c/godot/src/box3d_body.cpp#L313),
  [`register_types.cpp`](https://github.com/Stink-O/box3d-godot/blob/72bf5f2f9a803e18949507f46dc38916be21ca1c/godot/src/register_types.cpp).
- Neutral core:
  [`core/CMakeLists.txt`](https://github.com/pdaddyo/rollback-in-a-box/blob/9e1fe882a0ea4eb52e160d5754a752580b4db462/core/CMakeLists.txt),
  [`rollback_shim.h`](https://github.com/pdaddyo/rollback-in-a-box/blob/9e1fe882a0ea4eb52e160d5754a752580b4db462/core/include/box3d_rollback/rollback_shim.h),
  [`RollbackWorld`](https://github.com/pdaddyo/rollback-in-a-box/blob/9e1fe882a0ea4eb52e160d5754a752580b4db462/core/include/box3d_rollback/rb_world.h),
  [`IRollbackSimulation`](https://github.com/pdaddyo/rollback-in-a-box/blob/9e1fe882a0ea4eb52e160d5754a752580b4db462/core/include/box3d_rollback/rb_simulation.h).

## Authoring, resources, and presentation

`box3d-godot` is the stronger reference for custom editor UX. It registers
collider and joint gizmo plugins at editor initialization only, supplies class
documentation and node icons, and draws geometry/constraint previews.
`Box3DBody::create_baked_compound` assembles child geometry into one static
compound with geometry deduplication. The bake has meaningful limitations:
per-child filters/events no longer survive as separate solver shapes, and
child shape IDs/live mutators are unavailable for the baked representation.
Its geometry utility layer converts procedural engine geometry into owned
Godot arrays without leaking temporary native allocations. These are useful
patterns for immutable shape definitions and editor validation.

This does **not** establish the proposed durable authoring asset contract.
The inspected implementation primarily authors node properties and builds
native geometry; it is not a reusable suite of stable-ID, versioned
box/sphere/hull/mesh/heightfield Resource definitions. No
`EditorImportPlugin` or `GLTFDocumentExtension` implementation, or general
durable entity/shape ID bake, was located in `godot/src/`. Its contact-rule
Resource and recording objects serve different purposes. Odin's eventual
baker must define deterministic traversal, stable content IDs, serializer
versions, source mesh identity, scale validation, and native geometry lifetime.

Useful source references are
[`box3d_editor_gizmos.cpp`](https://github.com/Stink-O/box3d-godot/blob/72bf5f2f9a803e18949507f46dc38916be21ca1c/godot/src/box3d_editor_gizmos.cpp),
[`box3d_body.h`](https://github.com/Stink-O/box3d-godot/blob/72bf5f2f9a803e18949507f46dc38916be21ca1c/godot/src/box3d_body.h),
[`Box3DBody` bake documentation](https://github.com/Stink-O/box3d-godot/blob/72bf5f2f9a803e18949507f46dc38916be21ca1c/godot/doc_classes/Box3DBody.xml#L500),
and [`Box3DGeometry`](https://github.com/Stink-O/box3d-godot/blob/72bf5f2f9a803e18949507f46dc38916be21ca1c/godot/src/box3d_geometry.h).

`godot-box3d` instead translates stock shape resources into backend
implementations. Its shape update/lifecycle tests and motion-recovery/query
algorithms are useful compatibility references; the integration has no
separate custom authoring/import/gizmo layer in `src/`. Existing stock-node
editor behavior should not be mistaken for a rollback-aware baking pipeline.
Its [behavior differences](https://github.com/bearlikelion/godot-box3d/blob/f073c2de2523bf12163095e920347881352dc8a9/docs/behavior-differences.md)
document query-only separation rays, sensor/concave restrictions, convex query
requirements, material mixing differences, and ignored joint parameters. Carry
these cases into any later compatibility tests instead of assuming matching
method names imply matching behavior.

For runtime resimulation, neither node layer should directly become canonical
physics state. The custom world synchronizes nodes before/after stepping and
dispatches contact, sensor, joint, and body signals. Its async path deliberately
trades tick progress for smooth rendering. The PhysicsServer layer performs
Godot callbacks and caches contacts after each solve. Those policies need
separation from a fixed, exactly replayed simulation step. Reuse geometry,
gizmo, conversion, and query ideas while emitting framework events and reading
presentation copies through each sibling's own adapter.

## Coordinates and stable identity

Both bindings map vectors directly between Godot and Box3D. The custom-node
binding explicitly uses Godot's Y-up/right-handed convention; quaternion
conversion maps `(x, y, z, w)` to Box3D's vector/scalar representation. Scale
is baked into geometry rather than represented in the rigid-body transform.
The PhysicsServer implementation forces single-precision Box3D in CMake;
its conversion header assumes that choice. Both integrations expose the
process-wide length-units setting. Adopt one explicit convention and initialize
it before any world/geometry creation; do not assume independent per-world
length units. See
[`box3d_conversions.h`](https://github.com/Stink-O/box3d-godot/blob/72bf5f2f9a803e18949507f46dc38916be21ca1c/godot/src/box3d_conversions.h),
[`type_conversions.hpp`](https://github.com/bearlikelion/godot-box3d/blob/f073c2de2523bf12163095e920347881352dc8a9/src/misc/type_conversions.hpp),
and [`box3d_globals.cpp`](https://github.com/bearlikelion/godot-box3d/blob/f073c2de2523bf12163095e920347881352dc8a9/src/misc/box3d_globals.cpp).

Native body handles, RIDs, node pointers, ObjectIDs, and scene paths are runtime
references, not durable game identity. A restored solver must restore the
logical entity-to-body mapping and rebind callback/presentation references.
Snapshot-era native handle behavior does not make a handle created after the
restored tick valid, nor make a handle portable to another world or machine.
The existing shim's pointer clearing makes direct reuse of the bindings'
`userData` event routing especially unsuitable without an explicit rebind step.

## Build and export evidence

| Project | Source-defined build/export surface | What remains unverified here |
| --- | --- | --- |
| godot-box3d | CMake 3.22, C++17 wrapper, separate Box3D submodule; godot-cpp ExternalProject pinned by tag. Forces Box3D single precision. MinGW statically links runtime; Linux hides linked static symbols. GDExtension minimum 4.3, with Linux/Windows x86-64 and macOS library entries. CI defines Linux/Windows headless tests and macOS build. | No local build/test was run for this matrix. macOS runtime behavior, alternate architectures, web/mobile export and rollback integration are not established. |
| box3d-godot | `godot/SConstruct` compiles the C17 engine and C++ wrappers into one extension using godot-cpp, targets API 4.6. Manifest lists desktop, Android arm64/x86-64 and threaded release WASM. macOS workflow defines universal builds and headless checks against 4.7.1/4.6.3 and Rosetta. Web adds SIMD flags; no-thread build disables asynchronous stepping. | Source-defined packaging or a workflow is not a local passing result. The README explicitly leaves WASM determinism unverified. Export ability does not establish cross-target rollback identity. |
| rollback-in-a-box | Neutral static core needs only a Box3D CMake target and uses C17/C++17. Godot build adds godot-cpp and adapter objects. Simulation compiler flags disable FP contraction on GCC/Clang and request precise FP on MSVC. Manifest lists macOS arm64 and Linux/Windows x86-64, minimum Godot 4.5. | P0.1 owns local build/test results. No WASM/mobile adapter/export or cross-target identity is established by the inspected manifest. A fingerprint/probe is a compatibility diagnostic, not proof for every game/corpus. |

Build references:
[`godot-box3d/CMakeLists.txt`](https://github.com/bearlikelion/godot-box3d/blob/f073c2de2523bf12163095e920347881352dc8a9/CMakeLists.txt),
[`ExternalGodotCpp.cmake`](https://github.com/bearlikelion/godot-box3d/blob/f073c2de2523bf12163095e920347881352dc8a9/cmake/GodotBox3DExternalGodotCpp.cmake),
[`box3d-godot/SConstruct`](https://github.com/Stink-O/box3d-godot/blob/72bf5f2f9a803e18949507f46dc38916be21ca1c/godot/SConstruct),
[`custom-node manifest`](https://github.com/Stink-O/box3d-godot/blob/72bf5f2f9a803e18949507f46dc38916be21ca1c/godot/demo/addons/box3d/box3d.gdextension),
[`macOS workflow`](https://github.com/Stink-O/box3d-godot/blob/72bf5f2f9a803e18949507f46dc38916be21ca1c/.github/workflows/godot-macos.yml),
and [`neutral core build`](https://github.com/pdaddyo/rollback-in-a-box/blob/9e1fe882a0ea4eb52e160d5754a752580b4db462/core/CMakeLists.txt).

The Odin integration should compile one pinned engine plus its compatibility
shim, avoiding multiple Box3D copies with separate global settings/world ID
domains. A C-only snapshot target is narrower than the current neutral CMake
target, which also compiles `rb_world.cpp` and `rb_session.cpp`. Consuming the
entire Godot object target unnecessarily adds godot-cpp registration and the
upstream session. Existing Odin native/WASM build composition still needs its
own explicit link/export work and verification.

## Recommended reuse boundary

| Candidate | Initial disposition | Work before adoption |
| --- | --- | --- |
| Pinned Box3D public C headers/library | Runtime dependency candidate. | Minimal typed Odin bindings or C wrappers; ABI/layout checks, exact precision/SIMD/compiler configuration, lifecycle/query tests, and license record. |
| `core/src/rollback_shim.c` and its C header | Small compatibility-code reuse candidate, subject to P0.2/P0.4. | Isolate private-header dependency; repair/extend ownership, failure, lifetime, and hash contracts needed by the siblings. Keep an upgrade audit. |
| `rb::RollbackWorld` | Reference for fixed stepping and solver-plus-side-state save/load; optional C++ helper only if justified. | It is noncopyable, vector-owning C++, not a C/Odin value-frame API. It provides limited convenience bodies and a body-oriented diagnostic hash, not a general complete-state codec. |
| `rb::RollbackSession` and Godot reflection bridge | Keep outside the runtime dependency boundary. | Kit and Replay already own input/prediction/session/replay policy. Importing this peer session would introduce another authority and history contract. |
| Raw binding generator/API manifest | Reference/checking input. | It generates Godot Variant/GDScript dispatch, not Odin declarations. Reuse the coverage method or adapt only needed parsing after attribution review. Avoid a Godot scripting bridge in a native Odin call path. |
| Custom-node geometry, gizmos, joint/query patterns | Editor/API references; selectively port after Gate B. | Separate immutable authored definitions from runtime handles and Godot callbacks; define stable IDs and versioned baking; test against the chosen engine pin. |
| PhysicsServer motion/query/filter and stock shape lifecycle | Compatibility references. | Preserve documented behavior differences. A full stock-node backend remains a separate project; do not make it a prerequisite for the rollback spike. |
| multi-box-3d side-state and lifecycle scenarios | Behavioral/test reference. | Keep game rules outside the shared backend. Do not copy its game code until P0.4 resolves missing root licensing. Reproduce at its own gitlink before considering upgrades. |

The initial C boundary should expose world/body/shape lifecycle and explicit
step through Box3D's public API, and a narrow opaque snapshot owner through the
shim. Add bounded array query/event adapters only where direct C callbacks
would make lifetime or thread ownership ambiguous. C++ classes, `std::vector`,
Godot `Variant`/objects, and upstream session packets should not cross the
Odin boundary.

The existing snapshot owner is not yet a ready-made Replay Frame field. It
binds slots and a geometry registry to one live world/context; it supplies no
detached retain/release or import-into-another-world contract. P0.0/P0.2 must
choose how the framework owns snapshots and how staged correction, audit,
aborts, eviction, copied frames, and canonical recovery preserve complete
state. A copied slot index or hidden live-world pointer is insufficient.

For hash diagnostics, inspect actual coverage rather than relying on the word
"world": `b3r_world_hash` delegates to the engine's state hash, while
`RollbackWorld::state_hash_u64` adds frame/body mapping/render metadata.
P0.2 must identify solver and side-state omissions before this becomes the
confirmed complete-state comparison used by either adapter. Current geometry
interning also means the August issue's collision-mesh duplication warning is
historical context, not evidence that every current snapshot copies all geometry.

## multi-box-3d ownership lessons

The game embeds a rollback extension object target in its existing
GDExtension, keeping one engine and one registration context. Its own
`Box3DWorld` supplies the simulation interface and saves game side-state beside
physics: frame/spawn counters, players, body tables, entities, vehicles,
creatures/droids, wave RNG and timers. `load_state` restores those values and
rebuilds derived reverse maps. Terrain/vehicle definitions are explicitly
immutable during the match; their lifetime still outlives live/restored shapes.
Physics recording is kept outside rollback.

These boundaries are useful references for both siblings, but the game's
render table is not a prescribed canonical field for Odin. Each framework
should classify its own complete deterministic side-state and presentation
metadata. See
[`ROLLBACK_EXTENSION.md`](https://github.com/pdaddyo/multi-box-3d/blob/987f4ca44d0065676f17cab35edad57fcbb63b13/docs/ROLLBACK_EXTENSION.md),
[`SideState`](https://github.com/pdaddyo/multi-box-3d/blob/987f4ca44d0065676f17cab35edad57fcbb63b13/gdext/src/box3d_world.h),
and [`save_state/load_state`](https://github.com/pdaddyo/multi-box-3d/blob/987f4ca44d0065676f17cab35edad57fcbb63b13/gdext/src/box3d_world.cpp#L2130).

The current game pins an older rollback revision. Its documented embedding
link list includes `godot-cpp` and `box3d`; the current neutral extraction adds
a separate `box3d_rollback_neutral` target. Therefore an upgrade must review
link dependencies as well as the API and snapshots; silently advancing the
gitlink would cease to reproduce the recorded game source.

## Preliminary provenance and unresolved decisions

The inspected `godot-box3d` root LICENSE is MIT, copyright Mark Arneman;
rollback-in-a-box root LICENSE is MIT, copyright Paul Barrass. The custom-node
fork's root LICENSE names Erin Catto; its Godot source headers use contributor
MIT SPDX declarations, and its packaged addon LICENSE explicitly attributes
the extension to Stink-O and the engine to Erin Catto. Preserve all applicable
notices for any reused source and dependencies; P0.4 owns the final attribution
inventory and reuse decision.

No root LICENSE, COPYING, or NOTICE was located in the inspected
multi-box-3d tracked tree; its GodotSteam addon has a separate license that
does not establish the game code's license. Treat game source as reference
only until that gap is resolved. This report does not vendor or copy upstream
implementation code.

Source notices:
[`godot-box3d/LICENSE`](https://github.com/bearlikelion/godot-box3d/blob/f073c2de2523bf12163095e920347881352dc8a9/LICENSE),
[`rollback-in-a-box/LICENSE`](https://github.com/pdaddyo/rollback-in-a-box/blob/9e1fe882a0ea4eb52e160d5754a752580b4db462/LICENSE),
[`fork/LICENSE`](https://github.com/Stink-O/box3d-godot/blob/72bf5f2f9a803e18949507f46dc38916be21ca1c/LICENSE),
and [`packaged addon LICENSE`](https://github.com/Stink-O/box3d-godot/blob/72bf5f2f9a803e18949507f46dc38916be21ca1c/godot/demo/addons/box3d/LICENSE).

Before P0.5, combine this matrix with snapshot findings and reproduced baseline
results to select the pin and minimal reused files. Resolve detached snapshot
ownership/transactions, complete hash coverage, canonical recovery, geometry
registry lifetime/memory caps, callback rebinds, and the first desktop/CI pair.
Keep the initial spike independent of editor work and leave platform-wide
determinism claims to measured target-specific corpora.
