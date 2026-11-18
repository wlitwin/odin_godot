# Editor tools and baking

Use the optional Box3D editor addon to inspect authored definitions, bake mesh
collision, save detached artifacts, and display copied debug geometry. The
runtime authoring classes also work without enabling the editor plugin.

## Set up the editor tools

The SDK includes `addons/box3d_authoring` beside `addons/odin_godot`. Copy both
from the release into your project's `addons` directory, then enable **Box3D
Authoring** in **Project Settings → Plugins**. A source checkout supplies the
same frontend under `addons/box3d_authoring`.

Choose **Project → Tools → Box3D: setup and status**, or select a Box3D object
and use its Inspector setup panel. **Install tools and build** creates the tool
module and runs the normal Odin build. The panel reports missing compiler,
build progress, build failure, and readiness. It only reports ready when the
loaded tool implementation matches the installed source. No main `scripts/`
package is required for editor-only authoring.

**Validate physics** shows a short result and body/shape/joint counts. Errors
identify the offending fields. **Technical details** expands the full result,
including IDs and hashes, when you need them.

To update the SDK, close Godot and replace its two addon directories, then
reopen. **Update tools and build** updates unchanged installed tool sources.
The installation record lives beside the module, so it survives clearing
`.godot` or cloning the project. Identical existing sources are adopted safely.
Locally edited or deleted sources are preserved and listed for review; merge
with `addons/box3d_authoring/tool_module` to accept the new version. **Build
project tools** remains available for deliberate local customizations. Keep
the installation record in version control with the module.

Artifacts waiting for tools are retried when the tools become ready. Shape
previews also refresh after a successful build without reopening the scene.

Editor validation, previews and baking do not require a native solver backend.
Games that simulate Box3D still select one through [Build and export](building.md).
See [Script modules](../modules.md) for module layout.

## Create and duplicate authoring objects

New Worlds, bodies, sensors, joints, characters, and shape Resources receive a
stable ID when created in the editor. Godot saves it in the scene or Resource.
Renaming, reordering, or reparenting a node keeps its ID. Loaded IDs are preserved;
runtime code that constructs authoring data still supplies explicit keys.

Select objects in the Scene tree and choose **Duplicate Box3D selection** from
the right-click menu, the Inspector, or **Project > Tools > Box3D: duplicate
selection**. Include connected bodies and their joints or characters in the same
selection. The copies get new identities, and their internal body references
follow the copied bodies. References to bodies outside the selection keep their
original targets. A whole-World copy gets a new namespace and retains its local
keys. Godot's generic Duplicate command copies stored IDs unchanged; use the
Box3D action for these authoring graphs.

Body copies keep shared shape Resources. Shapes marked **Local To Scene** retain
private copies, with sharing preserved inside the copied World graph. To copy a
shape within one body, use **Duplicate shape** in that body's Inspector. This
creates a separate Resource and ID for the new slot. Equivalent geometry still
deduplicates in the shared baker.

The **Stable ID** field and **New ID** button perform an explicit rekey. A body's
incoming joint and character references update in the same undo action, within
its World or standalone component scene. Colliding or ambiguous IDs are refused
before anything changes. IDs are stored separately from ordinary Inspector
parameters so native reset/paste cannot bypass this reference update.

Undo restores the exact IDs, references, Resource assignments, and hierarchy;
redo reuses the same generated identities. Instanced and inherited scenes retain
their overrides when saved. Enable **Editable Children** before editing internal
instance IDs, or edit the source scene. The scene root itself cannot be duplicated;
instance it beneath a parent scene to copy the whole World. Unowned authoring
children must become part of the saved scene before duplication.

These identity controls work before the Odin tool module is built. The tool
bridge is needed for shared baking and geometry previews.

## Keep editing through validation errors

The viewport keeps complete, valid shape outlines visible when another shape,
body, joint, or character is invalid. Missing or duplicate IDs do not hide usable
geometry. Red outlines and crosses identify authoring errors; amber crosses
identify unavailable tools or preview limits. Select the affected object and use
its configuration warning or **Validate physics** for details.

Preview availability and authoring validity are separate. An invalid shape is
omitted individually; an ambiguous joint endpoint never selects an arbitrary
body. Invalid coordinate frames are reported instead of drawing geometry at a
replacement identity transform. Fixing an edit restores the normal preview, and
undo/redo refreshes it immediately.

The shared preview kernel publishes complete fragments within the selected line
budget. An oversized fragment cannot erase a smaller valid one. An incomplete
preview does not change scene data, IDs, or physics allocation state, and it
cannot be used as a bake artifact. **Bake**, artifact loading, and runtime
construction retain their strict validation requirements.

## Pick bodies and place joint anchors

Add the desired joint node below a World and select **Body A** and **Body B**
from the Inspector's name/path pickers. Nested Worlds are separate scopes.
Missing or duplicate IDs remain visible as unresolved choices; the picker never
silently chooses a different body. Character self-exclusion uses the same picker.

New joints use **Viewport anchors**. Move or rotate the joint node with Godot's
normal 3D tools to place anchor A and its axes. Drag the **Anchor B** handle to
separate the endpoints, or edit **Anchor B Offset** for its relative position and
orientation. **Place anchors at body origins** is useful for separated endpoints.
It leaves distance target/rest-length settings unchanged.

The tool derives the body-local frames used by physics. Rotated and translated
parents are supported, including plain `Node` groups that stop Godot's transform
inheritance. Moving a body changes its local frame while a separately placed
joint stays fixed; parenting the joint under that body makes it follow the body.

**Body-local frames (advanced)** exposes the explicit frame transforms and A/B
position handles. In this mode the joint node's transform is only an editor
marker. Switching modes preserves both anchors, including independent endpoint
rotations, in one undo action. If repositioning the marker would also move a
referenced child body, keep body-local mode or move the joint outside that body's
transform ancestry first. Invalid or overflowing conversions are refused.

## Bake collision from a mesh

**Create collision shape…** supplies a generated shape ID that you can override.
It reads triangle data,
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

**Bake physics world…** saves a `.b3authoring` envelope. The source revision
label is optional. It owns versioned definition bytes,
source/import metadata, and semantic bake identity. Loading checks length,
schema, integrity, references, and fields, then invokes the shared parser and
baker. It does not deserialize a native solver memory image.

Keep wide IDs exact: the tools expose them as fixed hexadecimal strings.
Converting a 64-bit ID to a JSON floating-point number can lose identity.

## Draw debug geometry

`Box3DDebugDraw3D` is off by default. Presentation can submit copied line batches
with the expected epoch, tick, revision, and source. Stale batches clear prior
drawing. The renderer owns no physics clock and does not query the live solver.

Preview capacities follow the selected [capacity profile](capacities.md): catalog
geometries, shape bindings, joints, character overlays, and line output share its
corresponding bounds. Per-geometry limits remain 4096 mesh vertices/triangles.
A capacity error is explicit; the tool does not publish a truncated shape.

See [the source API](https://github.com/wlitwin/odin_godot/blob/main/box3d/debugdraw/API.md)
for line generation and [the authoring API](reference.md) for artifact procedures.
