# Angular correction smoothing

Use `Smoother2` and `Smoother3` to ease displayed poses toward same-tick
corrections. They retain rotational correction error as local presentation state,
alongside positional error. Read complete detached poses:

```odin
// before and after belong to the same simulation tick.
view.smooth_correct_pose(&smoother2, before2, after2)
view.smooth3_correct_pose(&smoother3, before3, after3)

// The current pose includes ordinary movement/rotation; only correction error decays.
shown2 := view.smooth_present(&smoother2, current2, render_dt)
shown3 := view.smooth3_present(&smoother3, current3, render_dt)
```

The correction calls return false on invalid inputs without changing the
smoother. Initialize by presenting a valid pose before applying corrections.
2D uses radians and the shortest signed angular difference. 3D uses x/y/z/w
quaternions, normalizes valid nonzero values and treats q and −q as equivalent.
It composes correction rotations in order; Euler-component subtraction is not
used. The error angle decays exponentially with the same half-life as position,
so splitting a render interval preserves the result within floating-point error.

Default correction cuts are 60 position units in 2D, 2.25 in 3D and π/2 radians
for angle. A discontinuity, disabled cut, or correction exceeding either bound
clears the complete pose error. Existing position-only correction calls remain
available and clear angular error on their explicit/large cuts too.
`smooth_rebase` additionally preserves the displayed 2D angle when rebasing a
whole displayed pose; its existing position cut remains 48.

A finite nonpositive half-life disables smoothing. An invalid current pose, render duration
or nonfinite half-life holds the previous shown pose and leaves state unchanged.
Correction poses/cut parameters must be finite; 3D rotations must be nonzero.
At the exactly-180-degree ambiguity a canonical quaternion sign chooses a stable
error axis, so equivalent signs follow the same visual path. Simulation values
and their checksums are never changed by these functions.

The [Godot Body2](../godot/scene/body2.md) and [Body3](../godot/scene/body3.md) adapters use
these corrections and preserve the skin's authored local offset and rotation.
Their physics publication still reads PhysicsServer. Their skin correction reads
the node transform because a frozen kinematic solver can retain its previous
transform until the next physics step after a node is placed. Reading that stale
solver transform for rendering would accumulate a correction twice or apply the
skin relative to the wrong parent transform.

[Tests and evidence](../../docs/replay/results/angular-smoothing-2026-09-08/README.md)
include native/default and optimized WASM corpus execution, a real Godot native
and browser fixture, ownership transfers and both Slopball network games. These
checks do not establish perceptual quality on every device or support arbitrary
scaled/sheared hierarchies, contacts or deterministic Godot solver rollback.
