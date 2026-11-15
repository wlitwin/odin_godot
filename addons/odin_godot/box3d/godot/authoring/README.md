Godot authoring extraction (schema1)

Install `addons/box3d_authoring` into the project's `addons/` directory. The
standard GDScript classes/resources work without a custom Core or scriptgen
extension. The optional editor plugin refreshes configuration warnings.

`extract(world: gd.Object, allocator) -> (ba.Baked_Scene, Diagnostic)` invokes
`box3d_definition_json` on the live World once on the calling engine thread, then
uses `box3d/authoring.parse_and_bake`. All Variant/String temporaries are released.
The returned immutable owning bake has no engine references. Destroy source
nodes/resources freely after extraction; pass the bake to existing Kit/Replay
adapters and destroy it with `ba.destroy`. Never call extraction during replay.
`extract_json` instead returns detached bytes owned by the supplied allocator.
Call `diagnostic_destroy` on any returned diagnostic; invalid-authoring JSON
contains the editor's exact field paths. Native construction is a separate API.
