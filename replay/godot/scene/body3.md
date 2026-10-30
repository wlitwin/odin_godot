# Owner-streamed 3D bodies

`Body3` uses the same owner-state and producer-driver protocol as Body2. It borrows
a RigidBody3D or CharacterBody3D and optional skin; keep it outside frame state.

```odin
body3_attach(&adapter, physics_body, .Rigid, skin)
body3_sync(&adapter, authority_owned_state, my_owner_id, epoch,
           authority_tick, may_publish, render_delta, optional_observed_state)
sample, error := body3_sample(&adapter, engine_physics_frame)
```

The authority state controls permission. Observation interpolation is allowed only
within the same key, revision and discontinuity. Rigid observers freeze in kinematic
mode; character controllers call move_and_slide only while `body3_simulating` permits
it. Preparation, provisional local possession, publication gating, cuts, suspension
and epoch recovery follow [Body2](body2.md).

Pose3 uses world position, an x/y/z/w unit quaternion, linear and angular velocity,
and sleeping state. Global transforms and both velocities are written to PhysicsServer
after the new solver wakes. The current authored global scale is retained. Reads
come from PhysicsServer; temporary Variants are released. Interpolated orientations
use normalized quaternion interpolation with hemisphere selection, so q and -q do
not produce a false rotation. Position and angular skin correction use a 63 ms
half-life, retaining the authored offset and local quaternion. The visual-only
skin is a direct child of the body. Rendering follows the node transform when a
frozen kinematic PhysicsServer update is still pending; publication remains a
solver read. Observer jumps of at least 0.15 position units or 0.12 radians trigger
correction; 2.25-unit or π/2-radian corrections cut. Body-local placement and
quaternion composition keep the skin separate from physics.

`body3_suspend` stops solving/publication without changing the cached observation
clock. A restored earlier tick is valid in a new epoch. `body3_destroy` clears the
adapter; scene nodes remain caller-owned. This restores accepted pose/momentum,
not contacts, joint solver caches or deterministic engine execution.

The separate [Slopball3D port](../../../examples/replay_slopball3d/README.md) has solver,
network and Room migration gates. General scaled-hierarchy rendering, jointed bodies,
moving ownership contests and human visual/feel review need further coverage.
