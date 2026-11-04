Box3D authoring schema1

Copy this directory into a Godot project's addons directory and enable the
standard editor plugin if desired. Create Box3DWorld3D with explicit stable_key
(namespace), then Box3DBody3D/Box3DSensor3D children. Resource classes are
Box3DBoxShape3D, Box3DSphereShape3D, Box3DCapsuleShape3D, Box3DHullShape3D,
Box3DMeshShape3D and Box3DHeightfieldShape3D. Ordinary .tres/.tscn serialization
stores exported values/scripts. Nodes never step physics or become rollback state.

World `box3d_definition()` returns a detached Dictionary; `box3d_definition_json()`
returns exact Scene_Input JSON using full float precision. Invalid input returns
an empty result; `box3d_diagnostics()`/`box3d_diagnostics_json()` supplies bounded
field/code/message errors. No native handle, instance ID or scene path is an ID.
Diagnostic scene paths are not definition data. Body pose is relative to the
World; its global rigid transform is the presentation coordinate frame. Shape
local_pose and positive scale are passed to the shared baker, never discarded.
Sphere center and both capsule endpoints are explicit. Hull limit is256 points.
Mesh/heightfield require Static, non-sensor and sensor events disabled. Heightfield
triangulation and every stable ID/content hash belong to the shared Odin baker.

Same resource key on different bodies denotes the same immutable geometry;
per-instance sensor/material/filter definitions stay separate. Duplicate body or
per-body resource keys fail. Engine integer filter fields accept nonnegative
signed64 values; negative mask shortcuts are rejected rather than reinterpreted.
The Odin definitions can express their full u64 domain directly.
