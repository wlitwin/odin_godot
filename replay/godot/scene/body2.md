# Owner-streamed Godot bodies

`Body2` borrows a scene body and optional skin node. It supports RigidBody2D and
CharacterBody2D. Its driver and visual smoothing live outside simulation state.

```odin
body2_attach(&adapter, physics_body, .Rigid, skin)
body2_sync(&adapter, authority_owned_state, my_owner_id, epoch,
           authority_tick, may_publish, render_delta, optional_observer_state)
sample, error := body2_sample(&adapter, engine_physics_frame)
```

The ownership argument must come from authority state, not client prediction.
`session_authority_state` supplies the appropriate frame. Connection/fencing/game
eligibility is a separate `may_publish` decision. Optional observed history may
interpolate a remote pose only within the same object/revision/discontinuity scope.
Observers freeze rigid bodies in kinematic mode; remote character bodies remain
solid but their local controller must not call move_and_slide. `body2_simulating`
answers whether a controller may operate the local solver.

Transforms are written through PhysicsServer and the node's global transform;
linear/angular velocity and sleeping state cross reseeds. Freeze is lifted before
seeding a new solver, avoiding Godot restoring an obsolete pose when it wakes.
Temporary Variants are destroyed. Samples read PhysicsServer state and reuse the
last immutable observation between physics frames, so differing render/network
rates do not erase the newest observation. Character samples use real velocity.

Preparing an authority-issued offer can run a speculative solver while the old
owner remains accepted. `body2_preview` can start a local-only possession preview
earlier; it publishes nothing until an authority offer exists. Matching preparation
can retain the preview, while denial, cuts, lost eligibility and timeout revert it.
There may be overlapping speculative solvers. Exactly one revision is accepted by
the owner-state reducer at a time.

Node reseeds are immediate; a frozen kinematic PhysicsServer transform may settle
on the next physics step. Skin rendering therefore reads the visible parent node,
while publication reads the solver. Small position/angular corrections decay on
the skin with a 63 ms half-life; explicit cuts reset both errors and do not glide.
The visual-only skin is a direct child with a captured authored offset/rotation.
Observer jumps of at least six position units or 0.12 radians trigger correction;
90-unit or π/2-radian corrections cut. Scene
geometry/scale is authored separately from the streamed pose. The adapter does not
serialize solver contact caches, joints, or arbitrary engine state. Reconstructing
pose and velocity is a cooperative recovery boundary, not deterministic solver replay.
The current skin-offset correction assumes unit global body scale; scaled hierarchy
visual correction needs separate validation. The physics pose uses global transforms.

`body2_destroy` only clears the adapter; the caller owns and frees the nodes.
When a current authority frame is unavailable, call `body2_suspend` to stop solving
and publication while retaining the previous observation clock. Do not tag a cached
old-world pose with the new session epoch: a recovered checkpoint may have an earlier
tick. Resume with the actual authority frame so the driver can rebase its scope and
seed the complete recovered pose and velocities.
For 3D, [Body3](body3.md) applies the same owner protocol to quaternion poses and
linear/angular velocity; a separate Replay Slopball3D port exercises it.
