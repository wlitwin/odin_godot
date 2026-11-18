Box3D authoring

The SDK ships this addon beside `addons/odin_godot`. Copy both directories
into the project and enable Box3D Authoring in Project Settings → Plugins.
Use Project → Tools → Box3D: setup and status, then Install tools and build.
The same setup panel appears in the Inspector. It uses the ordinary Odin build
and reports progress, missing compiler, failures and loaded-tool readiness.

Updates replace only unchanged managed tool sources. Local changes are listed
and preserved; merge them with tool_module or build your customized sources.
Commit modules/box3d_authoring_tools/.box3d-tools.json with the module so its
installation record survives clones and cache cleanup.

 Create a Box3DWorld3D, then
Box3DBody3D/Box3DSensor3D children. New editor objects receive saved stable IDs;
runtime construction still supplies explicit stable_key values. Resource classes are
Box3DBoxShape3D, Box3DSphereShape3D, Box3DCapsuleShape3D, Box3DHullShape3D,
Box3DMeshShape3D and Box3DHeightfieldShape3D. Ordinary .tres/.tscn serialization
stores exported values/scripts. Nodes never step physics or become rollback state.

Use **Duplicate Box3D selection** in the Scene tree context menu or Inspector to
copy connected authoring objects. It remaps references to copied bodies, preserves
shared shape Resources, and supports exact undo/redo. **Duplicate shape** gives a
body-local shape copy its own Resource and ID. **Stable ID** / **New ID** updates
incoming references when rekeying a body. These controls do not need the compiled
Odin tools. Runtime data extraction does not require the editor plugin.

World `box3d_definition()` returns a detached Dictionary; `box3d_definition_json()`
returns exact Scene_Input JSON using full float precision. Invalid input returns
an empty result; `box3d_diagnostics()`/`box3d_diagnostics_json()` supplies bounded
field/code/message errors. No native handle, instance ID or scene path is an ID.
Diagnostic scene paths are not definition data. Body pose is relative to the
World; its global rigid transform is the presentation coordinate frame. Shape
local_pose and positive scale are passed to the shared baker, never discarded.
Sphere center and both capsule endpoints are explicit. Hull limit is256 points.
Mesh/heightfield require Static, non-sensor and sensor events disabled. Box3D mesh
collision is one-sided and counter-clockwise, the reverse of Godot's front faces;
Box3DEditorMeshBaker converts the winding, and Box3DMeshCleanup welds and repairs
meshes assembled from parts (see mesh_cleanup.gd). Heightfield
triangulation and every stable ID/content hash belong to the shared Odin baker.

Less common Box3D settings sit in Inspector groups and default to Box3D's own
values: World "Solver" (restitution/hit thresholds, contact stiffness, damping and
push-out speed, speed limit, restitution iterations), Body "Motion" (fast rotation
for wheels and balls, axis locks, continuous-collision safety factor, contact
recycling) and shape "Surface"/"Contacts" (rolling resistance, conveyor tangent
velocity, contact creation on add, speculative contacts). See box3d/README.md.

Same resource key on different bodies denotes the same immutable geometry;
per-instance sensor/material/filter definitions stay separate. Duplicate body or
per-body resource keys fail. Engine integer filter fields accept nonnegative
signed64 values; negative mask shortcuts are rejected rather than reinterpreted.
The Odin definitions can express their full u64 domain directly.
