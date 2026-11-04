P5.3 actual SDK/editor fixture

run.py requires --out NEW --native-library CURRENT --godot --odin plus
--kit-frame-json and --replay-frame-json from Root's actual public CP frame_json
outputs. It copies these verbatim, installs p's unchanged module source once at
res://modules/box3d_authoring_tools, then standard build/import/editor/runtime.
No Core/scriptgen bypass or Native build. Actual input hashes are retained.

Editor checks actual registered Inspector/Gizmo callbacks, all authored shapes
plus explicit joint/capsule preview, validation/property edit, artifact import,
disable/reenable. Runtime checks actual ArrayMesh surfaces/indices/affine transform
and flags, Resource metadata roundtrip, shared canonical owning artifact after
source destruction, corrupt rejection, actual Kit/Replay detached frame drawing,
defaultOFF/stale behavior and unchanged actual Native allocation totals. Headless
geometry/callback checks are not a manual pixel/usability claim. Root separately
owns pure/native/framework proofs and final card acceptance.

The current reference run passes build/import/editor/runtime with strict logs.
It additionally constructs and steps the exact source-free imported ArrayMesh
artifact through Native, with checked Meter/world/catalog cleanup. See
[report.json](../report.json) for current inputs, prior failures and scope.
