# Author a Box3D world

Describe initial collision in Godot, then extract a detached definition and
construct the runtime world. This guide assumes you have run
[the offline tutorial](quickstart.md) and understand [physics ownership](ownership.md).

## Create the scene

1. Copy `addons/box3d_authoring` from the SDK into your project's `addons/` directory.
2. Add a `Box3DWorld3D` node and set an explicit `stable_key` namespace.
3. Add `Box3DBody3D` or `Box3DSensor3D` descendants. Give each body a unique
   `stable_key` within the world.
4. Assign shape Resources and set rigid poses, dimensions, materials, and filters.
5. Validate the complete definition before constructing a runtime world. The
   optional [editor tools](editor.md) report field-specific diagnostics.

These nodes describe initial content and presentation bindings. Your script or
framework still owns stepping. The [authored samples](multiplayer.md) provide
complete scenes and runtime setup to adapt.

## Choose shapes

| Resource | Authoring rule |
| --- | --- |
| Box | Positive half extents; an offset or rotated box can bake to its exact convex hull |
| Sphere | Positive radius; uniform positive scale |
| Capsule | Explicit local endpoints and positive radius; uniform positive scale |
| Convex hull | 4–256 points |
| Triangle mesh | Static, non-sensor collision; bounded vertices and indices |
| Heightfield | Row-major Z then X, explicit positive spacing; bakes to a static mesh |

Body and world transforms are rigid. Shear, reflection, invalid dimensions, and
unsupported scaling are errors. Meshes and heightfields require sensor events
disabled. Unsupported geometry is rejected rather than approximated silently.

## Keep identity stable

Use explicit keys for worlds, bodies, shapes, characters, and joints. Renaming a
presentation node or reordering Resources must not change the logical object ID.
Duplicate keys, conflicting reused Resource keys, unresolved references, and
identity collisions fail validation.

Content identity includes geometry, poses, materials, filters, and flags. Editing
content can change compatibility while an unchanged logical key retains its
meaning. Identical baked geometry can share a native catalog asset even when
several authored Resources refer to it.

## Extract and build

This excerpt shows extraction and construction. `world_object` is the authored
Godot World object, `allocator` must outlive the returned owners, and `profile_id`
selects the runtime profile:

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

The extractor copies scene data. The builder creates a native world, trusted
catalog, and local logical-ID mappings. A failed candidate is cleaned up before
publication; check diagnostics and any returned surviving owner.

For Kit, `kit/physics.authoring_attach` transfers the world only on success; the
caller retains catalog and mapping ownership. Replay uses `authoring_config`
and `authoring_checkpoint`; its complete checkpoint owns its retained image and
catalog independently. Follow [the adapter setup](multiplayer.md) for lifetimes.

## Next

Use [Editor and baking](editor.md) for mesh conversion and artifacts,
[Characters and joints](motion.md) for movement, and [API map](reference.md) for
schemas and bounds.
