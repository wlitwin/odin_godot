# Box3D editor, bake artifacts and debug drawing

P5.3 builds tools around the shared authoring contract. It does not introduce a
physics scheduler, a network protocol or a second rollback runtime. The declared
macOS reference passes 18 standalone checks and the actual SDK editor/runtime
fixture. Exact artifacts and limits are in the
[task report](../../../tests/box3d_editor/report.json).

## Editor and runtime boundaries

The optional addon uses normal Godot inspector and 3D gizmo plugins. Authoring
nodes and Resources retain their explicit stable keys and rigid-transform rules.
Previews and validation warnings do not become canonical Game/Side. Property
editing and plugin enable/disable must use normal editor ownership and cleanup.

Mesh conversion reads actual Mesh/ArrayMesh arrays once, validates triangle and
index data, copies geometry and records version/source metadata. Shared baking
still owns canonical geometry, IDs, deduplication and native limits. A preview
must not silently discard unsupported surfaces, invalid transforms, sensor flags
or capacity overflow.

## Detached artifacts

Bake artifacts are versioned owning authoring data. They must preserve the
shared semantic bake identity, source/import metadata and exact integer IDs.
Godot-facing payloads keep wide IDs opaque or hexadecimal; JSON floats cannot
be used to roundtrip arbitrary u64 identities. Loaders bound input length and
validate schema, version, integrity, references and field values before publishing
an owner. Source nodes, Resources and files can disappear after successful load.

The ordinary SDK supports reusable tool scripts under `res://modules/<name>`.
If the editor bridge needs one, install it once per project and build it through
the existing module workflow. A missing tool bridge should be an actionable
setup state. It does not justify a Core loader workaround or per-scene simulation
code. Runtime import/bake goes through the same shared implementation.

## Copied debug geometry

Debug drawing is optional and defaults off at runtime. Its source is immutable
authored geometry plus copied public presentation/checkpoint values. Kit and
Replay retain their separate presentation readers and feed one common line data
contract. A draw operation never queries a live solver or reads a Godot Resource
during resimulation.

Line generation is bounded and validates inputs before output publication.
Epoch, tick and revision remain explicit so stale drawing can be rejected or
cleared. Drawing owns no tick or wall clock and never changes input, admission,
effects or canonical state. The existing Native-free and Godot-free value
presentation package keeps that boundary.

## Evidence scope

Completion requires pure artifact/geometry/integrity/ownership controls, real
Mesh and Resource/scene roundtrips, source-free construction, ordinary SDK import,
actual editor plugin registration and teardown, and drawing from copied Kit and
Replay values with no Native allocation or canonical mutation. Headless component
checks do not establish a manual pixel/usability review. Export Gate C remains a
separate task.

## Shared artifact API

`godot:box3d/authoring` exposes `artifact_create`, `artifact_load` and
`artifact_destroy`. The owning envelope retains exact definition bytes and
source/import metadata, the semantic baked identity and the shared bake source
fingerprint. Loading validates the bounded versioned envelope and invokes the
same parser/baker again. It does not deserialize native solver layouts.

```odin
artifact, problem := a.artifact_create(definition_bytes,
    a.import_metadata(source_uri, source_revision), allocator)
if problem.error != .None {return}
defer a.artifact_destroy(&artifact)

loaded, load_problem := a.artifact_load(artifact.encoded, allocator)
if load_problem.error != .None {return}
defer a.artifact_destroy(&loaded)
// loaded owns an independent immutable scene; use the ordinary a.build path.
```

The reusable `AuthoringTools` tool module exposes exactly three editor methods:
`inspect_definition_json`, `bake_definition_json` and
`inspect_artifact_base64`. Inspection reports wide IDs as fixed hexadecimal
strings. Its preview is explicitly an authored **shape** outline, without a
runtime frame or invented stamp. Joint/character gizmos use their separately
identified authored inputs. Preview failure and capacity are reported explicitly.

## Debug data bridge

`box3d/debugdraw.generate` consumes a copied presentation Frame, copied geometry
bindings and an exact expected epoch/tick/revision/source. Generation is pure,
allocation-free and all-or-failure. `authoring.debug_scene_create` copies the
geometry and local maps so they can outlive the bake, native world and source
framework; current character overlays must come from actual Game/Side values.
`authoring.debug_preview` uses the same outline helpers for authored shapes.

`godot:box3d/godot/debugdraw.frame_json` copies a successful line batch into an
owning JSON payload for the optional renderer. Epoch, tick and revision are
16-character lowercase hexadecimal strings. Endpoints and per-line colors are
bounded finite arrays. Delete returned bytes with the same allocator. This
serialization helper calls no Godot or Native API.

## Project setup and editor workflow

Copy the `box3d_authoring` addon into the project. Use its install action once to
copy the packaged tools source into `res://modules/box3d_authoring_tools`, then
run the normal Odin script/module build. The installer accepts identical existing
files and refuses to overwrite a different project module. Enable the standard
`res://addons/box3d_authoring/plugin.cfg` editor plugin after the build.

Select an authored World/body/shape, character/joint setting, MeshInstance or
bake artifact to use its Inspector panel. The normal exported property editors
remain active. Validation/inspection uses the shared tool module and reports
field diagnostics and hexadecimal identities. World baking saves the checked
owning artifact; Mesh baking requires an explicit stable shape key and bakes the
actual surface triangles into a Mesh shape Resource. Source affine transforms are
baked. Godot's clockwise front faces become Box3D's counter-clockwise ones (Box3D
mesh collision is one-sided), with reflections accounted for. `Box3DMeshCleanup`
then welds vertices within 1 mm, drops zero-area triangles, removes buried faces
(back-to-back caps where closed parts touch, a part's base hidden inside another)
and splits T-junctions, so every interior edge is shared by exactly two triangles
and Box3D can smooth contacts across it. Projects assembling meshes from several
parts, such as a GridMap, can call `Box3DMeshCleanup.build` themselves.
Skinned/blend-shape sources, non-triangle surfaces, invalid transforms and
unsupported mesh sensor flags report errors. Render-only UV/normal/tangent data
is not collision identity.

The registered artifact importer handles `.b3authoring` envelopes, waits for real
filesystem reimport completion and saves a normal Resource carrying the
`Box3DBakeArtifact` script. Its declared loader type is the native `Resource`;
the loaded instance still has to satisfy the expected script class and strict
shared artifact validation. Derived addon classes name their registered parent
classes so the editor has a valid native-base/icon fallback.

The optional `Box3DDebugDraw3D` consumes explicit detached line batches. Enable
it in presentation code and call `submit_frame_json(payload, expected_stamp)`;
its default is off, and stale batches clear prior drawing. Rendering uses an
ImmediateMesh and does not schedule physics or query a solver. Preview limits
are eight geometries, 35 bindings, one joint, 35 character overlays, 4096 mesh
vertices/triangles and 8192 lines. Preview Capacity is explicit and never raises
simulation limits or publishes a truncated shape.

The SDK fixture observed registered Inspector and gizmo callbacks, actual edited
Resource property changes, artifact reimport and plugin disable/reenable. It also
built and stepped the exact imported ArrayMesh artifact after source destruction,
then rendered actual detached Kit and Replay batches without changing Native
allocation totals. These are headless API/geometry checks; a manual pixel and
usability review is outside this result. Export Gate C remains open.
