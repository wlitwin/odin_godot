# Editor tools and baking

Use the optional Box3D editor addon to inspect authored definitions, bake mesh
collision, save detached artifacts, and display copied debug geometry. The
runtime authoring classes also work without enabling the editor plugin.

## Install the tool bridge

1. Copy `addons/box3d_authoring` into the project.
2. Use its install action to copy the packaged tools into
   `res://modules/box3d_authoring_tools`. The installer accepts identical files
   and refuses to overwrite a different existing module.
3. Run the normal Odin script/module build with the selected Box3D backend.
4. Enable `res://addons/box3d_authoring/plugin.cfg` in Godot's plugin settings.
5. Select an authored world, body, shape, character/joint setting, mesh instance,
   or artifact to inspect it.

See [Build and export](building.md) for the native environment and
[Script modules](../modules.md) for module layout.

## Bake collision from a mesh

Mesh baking requires an explicit stable shape key. It reads triangle data,
applies source transforms, converts Godot's clockwise front faces to Box3D's
counter-clockwise winding, and creates a collision shape Resource. Box3D mesh
collision is one-sided, so winding affects contacts.

The cleanup tool welds vertices within 1 mm, drops zero-area triangles, removes
buried faces between touching closed parts, and splits T-junctions. GridMap or
other multi-part builders can call `Box3DMeshCleanup.build` directly.

Skinned or blend-shape sources, non-triangle surfaces, invalid transforms, and
mesh sensors are unsupported. UVs, normals, and tangents do not define collision
identity. Check the baked outline before using it for gameplay.

## Save a detached artifact

World baking saves a `.b3authoring` envelope. It owns versioned definition bytes,
source/import metadata, and semantic bake identity. Loading checks length,
schema, integrity, references, and fields, then invokes the shared parser and
baker. It does not deserialize a native solver memory image.

Keep wide IDs exact: the tools expose them as fixed hexadecimal strings.
Converting a 64-bit ID to a JSON floating-point number can lose identity.

## Draw debug geometry

`Box3DDebugDraw3D` is off by default. Presentation can submit copied line batches
with the expected epoch, tick, revision, and source. Stale batches clear prior
drawing. The renderer owns no physics clock and does not query the live solver.

Preview limits are eight geometries, 35 bindings, one joint, 35 character
overlays, 4096 mesh vertices/triangles, and 8192 lines. A capacity error is
explicit; the tool does not publish a truncated shape or increase runtime limits.

See [the source API](https://github.com/wlitwin/odin_godot/blob/main/box3d/debugdraw/API.md)
for line generation and [the authoring API](reference.md) for artifact procedures.
