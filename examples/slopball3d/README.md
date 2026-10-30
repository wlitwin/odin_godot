# slopball3d — co-op physics soccer, third dimension on

Use this Kit example to replicate 3D Godot physics bodies. The ball is a
`RigidBody3D` that arcs, bounces and tumbles; players are `CharacterBody3D` capsules.
`play.Puppet3` lets the ball's entity owner simulate it and stream its pose and
momentum, while other peers freeze their solver and display the received state.

## What 3D actually changed

The 3D version reuses Kit's session and replication APIs, with these physics and
rotation choices:

- **The wire core changed nothing.** Session, streams, deltas, commands, chat, lobby:
  all dimension-free. A kicker streams its pose as one `pos: [3]f32` field.
- **Rotation uses a quaternion.** The 2D puppet must snap its angle
  (a componentwise lerp sweeps the long way around the ±π wrap); the stream layer's
  `.Quat` kind nlerps hemisphere-safely, so `rot: gd.Quaternion` on `play.Puppet3`
  interps correctly and watchers see the tumble turn smoothly.
- **Angular velocity crosses the seam.** A 3D ball's tumble is its rolling contact —
  `play.Puppet3` streams it and seeds it at the handoff alongside linear velocity.
- **The engine trap is identical.** RigidBody3D ignores node transform writes exactly
  like its 2D sibling; every imposed pose goes through `PhysicsServer3D.body_set_state`.
- **The whole feel ledger transferred verbatim** (see slopball's README): seat
  anticipation, sticky possession, intent gating, render-error smoothing, predicted
  possession (`puppet3_claim`), physics interpolation + cut resets. The arbitration
  runs on ground-plane (XZ) distances; kicks loft with a y impulse.

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
