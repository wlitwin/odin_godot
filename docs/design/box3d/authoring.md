# Box3D authoring contract

P5.1 builds on the [bounded Gate B reference](gate-b.md). The authoring surface
serves one shared Box3D backend through separate Kit and Replay entry points.
The P5.1 surface has Native Debug/Release/sanitizer, Odin and actual Godot SDK
validation. Final author/export Gate C remains separate.

## Scene data and simulation ownership

`Box3DWorld3D`, `Box3DBody3D` and `Box3DSensor3D` describe initial content and
presentation bindings. They do not step a native world automatically. Kit's
Lane and Replay's Timeline remain the only tick owners. Scene nodes, Resources,
instance IDs, native handles and process-local ownership tokens never enter
canonical game state.

Before play, extract a detached definition from the scene and validate the
whole candidate. Bake copied, immutable, versioned values in deterministic
order. Native construction and each framework's attachment/checkpoint operation
must either succeed completely or release the partial candidate. Source nodes
and Resources can then be destroyed without invalidating owned bake data,
geometry or recovery catalogs. Live owners still require their documented
framework teardown.

## Identity and changes

Authored worlds, bodies and shape Resources have explicit stable keys. Durable
IDs derive from a versioned namespace/key rule, not child order, array slots or
native allocation order. Reordering unchanged content or saving/reloading it
must preserve IDs. Duplicate keys, ID collisions and unresolved references are
errors before publication; do not repair them by order-dependent probing.
Content identity includes semantic geometry, poses, materials, filters and
flags. Editing content changes compatibility identity while preserving the
meaning of unchanged explicit keys. Logical authored IDs are64-bit values;
Native catalog IDs are32-bit content-derived geometry IDs. Identical geometry
shares one Native asset while retaining separate logical Resource identities.
The exact schema1 fields are in
[API.md](../../../box3d/authoring/API.md).

## Shapes and transforms

The surface includes box, sphere, capsule, convex hull, triangle mesh and
heightfield Resources. A heightfield may bake to a deterministic triangle mesh.
An offset or rotated box may bake to its exact convex vertices using the
existing hull backend. Neither conversion permits dropping an authored
transform or silently substituting different collision geometry.

Validate finite values, dimensions, unit rigid poses, scale policy, hull points,
triangle indices and heightfield dimensions/counts with a field-specific error.
Triangle meshes are currently static-only and cannot be sensors in the native
binding; these combinations must be rejected explicitly. Do not approximate
unsupported nonuniform analytic-shape scaling without a declared contract.

The existing bounded runtime profile is unchanged: at most35 bodies/shapes,
147 contacts, one hinge, eight catalog assets, H128, prediction/ordinary repair8
and64MiB tracked resource admission. Authoring validation must reject content
that cannot fit; a new surface does not increase those limits.

## Recovery and adapters

The legacy primitive catalog retains recovery format1. Authored catalogs use
the copied trusted V2 descriptor and recovery format2 for primitive, Hull and
Mesh assets; heightfields bake to Mesh. Canonical bytes contain trusted asset
references, never arbitrary geometry pointers. Full Mesh cache/manifold
validation, native reconstruction/reencoding and failed-read atomicity remain
required. The C/Odin V2 descriptor is72 bytes/align8 on supported64-bit targets,
with actual C layout queries rather than assumed offsets.

Shared native construction owns the resulting world, trusted catalog and local
stable-ID mapping. Kit consumes the world through its existing participant and
network wrapper. Replay captures it through its existing complete checkpoint,
provider and codec. Each adapter preserves its existing allocator, ownership,
atomicity and tick contracts. Asset data is copied/retained before play; replay
callbacks do not query the Godot scene or a mutable Resource.

## Required evidence

Completion needs stable-ID/order/collision/invalid-definition controls, actual
construction and lifetime tests for every shape kind and sensors, complete
canonical export/import and failed-read cleanup, both framework integrations,
and actual Godot import plus `.tres`/`.tscn` save/reload and diagnostics. Ordinary
SDK/module builds must preserve one verified shared Native image and natural
cleanup. Gizmos/importer UX, characters/joints and the final author/export Gate C
remain later P5 work.

## Using the surface

Copy `addons/box3d_authoring` into a project's `addons/` directory. The optional
editor plugin refreshes configuration warnings; the ordinary script classes
and exported Resources do not need a custom Core extension. Add a
`Box3DWorld3D`, give it an explicit `stable_key` namespace, and place
`Box3DBody3D`/`Box3DSensor3D` descendants beneath it. Give each body a unique key
and assign its shape Resources. Presentation node names are not durable IDs.

Resources expose `stable_key`, `local_pose`, positive `scale`, material/filter
flags and their shape parameters. Capsule `centers_a`/`centers_b` are actual
endpoints; heightfields are row-major Z then X with explicit grid spacing.
Mesh/heightfield are Static, non-sensor and have sensor events disabled. The
eight-asset limit counts deduplicated Native geometry, not logical Resource
keys. Validation of that count belongs to the shared bake.

Call the Godot extractor once while the source is live:

```odin
import a "godot:box3d/authoring"
import ga "godot:box3d/godot/authoring"

scene, diagnostic := ga.extract(world_object, allocator)
defer ga.diagnostic_destroy(&diagnostic)
if diagnostic.error != .None {return}
defer a.destroy(&scene)

built, problem := a.build(&scene, profile_id)
defer a.built_destroy(&built)
if problem.error != .None {return}
```

The allocator must outlive its owning bake/maps; use the actual SDK context
allocator for retained SDK owners. Destruction is checked and retryable when a
real owner drop declines. An ordinary failed bake returns an empty output;
failed build cleanup returns a surviving owner only when an actual drop
declines, with an explicit diagnostic. Assignment aliases ownership.

For Kit, call `kit/physics.authoring_attach` with the built candidate, existing
Instance/Lane, copied Side, tracked field declarations and ordinary ownership
Config. Only the world transfers on success. The caller still owns the catalog
and local maps. Use that catalog with the existing `network_attach`, then match
network/provider/Lane teardown before releasing remaining authoring storage.

For Replay, `replay/physics.authoring_config` derives the value Config from the
bake. `authoring_checkpoint` captures the borrowed built world with the trusted
catalog through the existing provider. The checkpoint independently owns its
image/catalog; use the same Config/catalog with `network_codec_init` and the
normal Server/Client/Timeline or Godot Session APIs. No authoring object is a
second tick owner. Copy only logical/native-independent keys into Game, not
the local maps' live native handles.

The World can be detached from SceneTree during extraction. Relative poses
come from local ancestry; scale/shear/reflection or top-level links are rejected
without discarding them. Diagnostic paths use relative presentation names and
remain available off-tree. Destroying source nodes/Resources after extraction
does not invalidate copied bake data or subsequent Native construction.
