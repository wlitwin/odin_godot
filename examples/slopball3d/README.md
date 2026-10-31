<a id="slopball3d--co-op-physics-soccer-third-dimension-on"></a>

# slopball3d — cooperative 3D physics soccer with Kit

Use this Kit example to replicate 3D Godot physics bodies. The ball is a
`RigidBody3D` that arcs, bounces and tumbles; players are `CharacterBody3D` capsules.
`play.Puppet3` lets the ball's entity owner simulate it and stream its pose and
momentum, while other peers freeze their solver and display the received state.

<a id="what-3d-actually-changed"></a>

## 3D physics and rotation

The 3D version uses the same Session, streams, deltas, commands, chat, and
lobby APIs. A kicker streams position as one `pos: [3]f32` field. Its physics
and rotation use these rules:

- `play.Puppet3` streams `rot: gd.Quaternion` with the `.Quat` interpolation
  kind, using nlerp with hemisphere correction. The 2D puppet uses snapped
  angles; directly interpolating their scalar values across ±π would take
  the long arc.
- Ownership transfer seeds angular velocity as well as linear velocity,
  preserving the ball's tumble and rolling motion.
- Impose poses through `PhysicsServer3D.body_set_state`, as for the 2D
  version, because solver synchronization can replace direct node transforms.
- Ownership arbitration uses ground-plane XZ distance, anticipates contact,
  retains possession, and gates claims on input. `puppet3_claim` predicts
  possession locally; render-error smoothing and physics interpolation apply
  only to presentation and reset at cuts. Kicks add a y impulse for loft.

See the [2D ownership and timing guide](../slopball/README.md) for the shared
session and presentation rules.

## Run it

From `examples/slopball3d`, build once with `bash ../../build/build_scripts.sh .`,
then open two windows on one machine:

```sh
SLOP3_NAME=lefty  godot --path .    # Host
SLOP3_NAME=righty godot --path .    # Join
```

WASD moves on the pitch plane, Space kicks (lofted), first to `SLOP3_GOALS` (default 3)
takes the match. Odd seats defend the left goal, even the right.

## Automated tests

- `run.sh` — solo gate (`SLOPBALL3D_SINGLE_OK`): the striker bot runs the whole loop
  headless, exercising the 3D physics *solver* under `--headless`.
- `native_run.sh` — 3-peer integration test (`SLOPBALL3D_NATIVE_OK`): host + striker + watcher.
  The seat transfers to the striker client, its local solver (gravity, tumble) scores,
  and the three screens agree on the ball within centimeters at the same session tick.
