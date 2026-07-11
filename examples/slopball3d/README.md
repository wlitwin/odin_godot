# slopball3d — co-op physics soccer, third dimension on

The kit's **3D** exercise: the same engine-physics contract slopball proved in 2D,
with gravity turned on. The ball is a real `RigidBody3D` — it arcs off lofted kicks,
bounces, and tumbles — and the players are `CharacterBody3D` capsules. It answers the
kit's second-most-asked question — *"does any of this work in 3D?"* — with
`play.Puppet3` and, mostly, *"it already did."*

## What 3D actually changed

Very little — that is the point of the example:

- **The wire core changed nothing.** Session, streams, deltas, commands, chat, lobby:
  all dimension-free. A kicker streams its pose as one `pos: [3]f32` field.
- **Rotation became a quaternion — and got BETTER.** The 2D puppet must snap its angle
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

Two windows on one machine (build once with `bash ../../build/build_scripts.sh .`):

```sh
SLOP3_NAME=lefty  godot --path .    # Host
SLOP3_NAME=righty godot --path .    # Join
```

WASD moves on the pitch plane, Space kicks (lofted), first to `SLOP3_GOALS` (default 3)
takes the match. Odd seats defend the left goal, even the right.

## The acid

- `run.sh` — solo gate (`SLOPBALL3D_SINGLE_OK`): the striker bot runs the whole loop
  headless. The repo's only exercise of the 3D physics *solver* under `--headless`.
- `native_run.sh` — 3-peer proof (`SLOPBALL3D_NATIVE_OK`): host + striker + watcher.
  The seat transfers to the striker client, its local solver (gravity, tumble) scores,
  and the three screens agree on the ball within centimeters at the same session tick.
