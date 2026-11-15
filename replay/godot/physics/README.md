# Box3D presentation for Replay

Import `physicsgd "godot:replay/godot/physics"` when a view needs a copied
presentation frame from a complete Box3D checkpoint. This feature imports
`godot:replay/physics` and requires the matching native or WebAssembly backend.
Ordinary `godot:replay/godot` sessions and scene helpers have no native Box3D
link dependency.

`physics_presentation_frame(checkpoint, project, revision, source)` reads the
complete checkpoint's body cache and invokes the game's binding projection.
It returns the copied `box3d/presentation.Frame`, projection status, and Replay
status. The checkpoint's owner, realm, and native identity are checked before
the projection reads its game values. Keep the checkpoint alive throughout the
call; the returned frame owns no checkpoint or engine handle.

Use the frame with the ordinary detached physics view. The helper does not
step, restore, or change the simulation. See
[physics ownership](../../../docs/box3d/ownership.md) for the tick owner and
[presentation](../../../docs/replay/presentation.md) for effect timing.

The value-only `physics_effect_observation`, `physics_presentation_status`, and
`physics_impairment_options` helpers remain in `godot:replay/godot`.

## Importing the checkpoint reader

Code that used `replaygd.physics_presentation_frame` imports this feature and
changes that call to `physicsgd.physics_presentation_frame`. The arguments and
ownership rules are unchanged. Root Session, Party, and Room APIs keep their
existing import and names.
