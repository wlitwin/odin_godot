# Joint authoring acceptance

Run `nix develop --command bash tests/box3d_editor/joints/run.sh` from the
repository root. This uses a real isolated editor, fresh-runtime reload, and the
shared Odin baker. No native solver library is needed for this gate.

The fixture checks named body pickers, missing/ambiguous references, nested World
scope, transformed World/body/joint parents, plain Node transform breaks,
orientation-preserving mode conversion, actual viewport B-handle drag/cancel and
undo/redo, invalid ancestry, overflow refusal, and descendant-body safeguards.
It also verifies that migrated sample scenes retain their explicit local frames.

`tests/box3d_motion/godot/run.py` separately exercises all eight joint families
through ordinary SDK extraction, source-free native construction, stepping and
cleanup with a coherent native backend.
