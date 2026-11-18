# Editor identity acceptance

Run `nix develop --command bash tests/box3d_editor/identity/run.sh` from the
repository root. The runner preserves an isolated project and its logs.

The real editor creates objects, saves/reloads their generated IDs, duplicates
connected selections, rekeys references, copies shape slots, and exercises
undo/redo across plugin disable/re-enable. It verifies shared and local-to-scene
Resources, instanced and inherited scene overrides, Inspector controls, collision
rejection, unowned-child refusal, standalone components, and external Resource
saving. A separate runtime process reloads the saved results.

The shared Odin baker then consumes the actual before/after editor definitions.
It checks resolved body references, unique logical IDs, unchanged original IDs,
and one geometry asset for the equivalent sphere shapes. No native Box3D solver
library or compiled editor bridge is required for this gate.

For the editor/persistence checks alone, run `python3
tests/box3d_editor/identity/run.py`. Set `GODOT` to the target editor executable;
the macOS runner copies the complete app into an isolated editor environment.
