# slopball — co-op physics soccer on the friendslop kit

The kit's **engine-physics** exercise: everything the other examples replicate is
hand-rolled kinematics; slopball's ball is a real `RigidBody2D` and its players are real
`CharacterBody2D`s. It answers the question every Godot dev asks the kit first — *"can I
just use physics bodies?"* — with `play.Puppet` plus one ownership rule.

## The model

- **Your kicker is yours.** Each peer runs `move_and_slide` for its OWN CharacterBody2D
  and owner-streams the resulting pose; every other screen glides the body to the stream.
  Remote kickers stay solid (frozen kinematic to the solver), so crowds feel like crowds.
- **One peer simulates the ball.** `play.Puppet` wraps the RigidBody2D: the entity's
  owner runs the solver and streams pose + velocity; everyone else freezes the body and
  follows. The HOST hands the seat to the **last toucher** by plain proximity arbitration
  (`host.odin`) — granted a step *before* contact, so your kicks resolve on your own
  solver with no round trip. The handoff carries momentum.
- **Goals are host truth.** The host scores off the *streamed* pose and bumps plain
  `gd:"replicate"` fields on the ball entity — host-authoritative deltas and a client's
  owner stream sharing one entity is exactly what the field tags mean.

## Run it

Two windows on one machine (build once with `bash ../../build/build_scripts.sh .`):

```sh
SLOP_NAME=lefty  godot --path .    # Host
SLOP_NAME=righty godot --path .    # Join
```

WASD moves, Space kicks, first to `SLOP_GOALS` (default 3) takes the match. Odd seats
defend the left goal, even the right.

## The feel ledger

Seven layers of stutter hid under each other, each found by live playtest and
fixed at the right layer. The short version, for the next physics game:

1. **RigidBody2D ignores node transform writes** — live ones are stomped by the
   server sync; frozen ones vanish when the freeze lifts. Every imposed pose
   goes through `PhysicsServer2D.body_set_state` (`play.Puppet` does this).
2. **Ownership transfers must flush the freshest sample** into the fields
   before the ring resets, and **seed the fresh ring** so watcher interp flows
   through the seam instead of pausing an interp window (kit does both now).
3. **Run the session at the solver's rate** (60Hz here; `SLOP_HZ` drives both).
4. **Arbitration is feel**: grant the seat *before* contact (anticipation),
   make possession sticky, debounce moving-ball challenges, and let statues
   never claim — an idle body doesn't need the seat.
5. **Smooth corrections, never authority**: the body snaps to truth; the drawn
   skin glides in (~63ms half-life). Deliberate cuts snap outright.
6. **Predict possession**: `puppet_claim` seizes the sim the frame your screen
   sees the touch; the host confirms (seamless) or denies (smoothed snap).
7. **The last stutter wasn't netcode**: physics-tick stepping vs display
   refresh. `physics/common/physics_interpolation=true`, reset it at cuts,
   and never lerp an angle across the ±π wrap.

## The acid

- `run.sh` — solo gate (`SLOPBALL_SINGLE_OK`): the striker bot runs the whole loop
  headless. The repo's only exercise of the 2D physics *solver* under `--headless`.
- `native_run.sh` — 3-peer proof (`SLOPBALL_NATIVE_OK`): host + striker + watcher. The
  seat transfer lands on all three screens, the striker's local solver scores, and the
  three screens agree on the ball within a few pixels at the same session tick.
