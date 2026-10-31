# slopball — co-op physics soccer with Kit

Use this Kit example to replicate Godot physics bodies: the ball uses
`RigidBody2D` and the players use `CharacterBody2D`. `play.Puppet` connects the
ball's solver state to Kit's owner stream. The entity owner—the player permitted
to write its owner-controlled fields—simulates the ball and sends its pose and
velocity to the other peers.

<a id="the-model"></a>

## Ownership and scoring

Each peer runs `move_and_slide` for its own CharacterBody2D and streams the
resulting pose. Other peers interpolate that pose while keeping remote
kickers solid and fixed relative to their local solver.

One peer at a time simulates the RigidBody2D ball through `play.Puppet`. Its
entity owner streams pose and velocity; other peers freeze their solver and
follow the stream. The host's proximity arbitration in `host.odin` transfers
ownership to the last toucher, anticipating contact by one step so that the
receiving player's local solver can resolve the kick before a round trip.
The transfer includes momentum.

The host judges goals from the streamed pose and updates `gd:"replicate"`
fields on the ball. An entity can therefore combine authority-written score
with owner-streamed motion, with each field selecting its policy.

## Run it

From `examples/slopball`, build once with `bash ../../build/build_scripts.sh .`,
then open two windows on one machine:

```sh
SLOP_NAME=lefty  godot --path .    # Host
SLOP_NAME=righty godot --path .    # Join
```

WASD moves, Space kicks, first to `SLOP_GOALS` (default 3) takes the match. Odd seats
defend the left goal, even the right.

<a id="the-feel-ledger"></a>

## Solver and presentation timing

The example uses these rules to manage ownership changes and display frames:

1. Write imposed poses through `PhysicsServer2D.body_set_state`, as
   `play.Puppet` does. Solver synchronization can overwrite direct node
   transforms on a live RigidBody2D, and unfreezing can discard transforms
   written while frozen.
2. Flush the latest sample into the fields before resetting the interpolation
   ring, then seed the new ring. Kit performs both operations so observers
   can continue interpolating across an ownership change.
3. Run the session at the solver's rate: 60Hz here, controlled by `SLOP_HZ`.
4. Grant ownership before contact, retain possession across small gaps, and
   debounce challenges from a moving ball. Idle bodies do not claim it.
5. Apply accepted corrections to the physics body immediately, then smooth
   only the drawn skin with a ~63ms half-life. Explicit cuts snap the skin too.
6. `puppet_claim` predicts possession when the local screen sees contact. The
   host confirms or denies that claim; a denial produces a smoothed correction.
7. Enable `physics/common/physics_interpolation=true` to interpolate between
   physics ticks and display frames, and reset it at cuts. Do not linearly
   interpolate an angle across the ±π wrap.

## Automated tests

- `run.sh` — solo gate (`SLOPBALL_SINGLE_OK`): the striker bot runs the whole loop
  headless, exercising the 2D physics *solver* under `--headless`.
- `native_run.sh` — 3-peer integration test (`SLOPBALL_NATIVE_OK`): host + striker + watcher. The
  seat transfer lands on all three screens, the striker's local solver scores, and the
  three screens agree on the ball within a few pixels at the same session tick.
