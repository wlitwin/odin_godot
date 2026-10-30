# Rotation correction corpus

`nix develop --command bash tests/replay_rotation/run.sh` executes the same
numbered corpus natively and in WASM, in default and optimized builds. It checks
wrapped 2D corrections, moving truth, repeated corrections, quaternion composition,
q/−q and 180-degree ties, render subdivision, cuts, rebasing and invalid inputs.

The freestanding WASM harness supplies the standard math imports emitted by Odin
from JavaScript Math (including optimized exp2); it is not an import-free module
or a claim of bit-identical floating-point arithmetic. The corpus checks numerical
and orientation tolerances. Actual Godot native/browser adapter tests live in
`tests/replay_rotation_godot`.
