# Build responsive player movement

Use this guide to decide who computes movement, which values correction must
restore, and how Godot displays the result. Start with [two Kit players](../../kit/quickstart.md)
or the [Replay Session starter](../../replay/godot.md). The examples below describe
the decisions to make inside that working project.

A movement feature is complete when the local player responds to input, remote
players move smoothly, and an authority correction changes the simulation
without leaving collision or presentation state behind.

## 1. Choose who computes position

For trusted cooperative play, the player can supply their position. Kit's
`gd:"owner"` fields support that model; the host checks who owns the entity
before forwarding its stream. This permits the owning process to choose its
movement, including an implausible speed. Select it when the game's trust model
allows that behavior.

For authority-controlled movement, send controls such as direction and jump,
then compute position on the authority. The client can run the same movement
ahead of the reply. Kit's ordinary field-based simulation lane uses
`gd:"predict"` fields and `@(gd_tick)` procedures. Replay stores movement values
in its World and advances them through the chosen runner.

Choose this policy before tuning interpolation. Smoother display cannot change
which process is permitted to decide a position. See [Authority](../concepts/authority.md)
for the distinction between an entity owner and a trusted authority.

## 2. List the state needed for the next move

A character often needs more than position. Consider a jump that begins at
tick 80 and is corrected at tick 83:

| Value | Why correction needs it |
| --- | --- |
| Position and velocity | Determine the next integration result |
| Grounded state and movement mode | Decide whether jumping or air control is allowed |
| Jump cooldown or remaining dash ticks | Prevent the corrected input from granting a second action |
| Platform or attachment identity | Select the moving surface the character follows |
| Collision dependencies | Determine what the character can move through |

Keep values that affect later movement in the movement's restorable state.
Reading a current Godot animation flag to decide whether an earlier tick could
jump creates a dependency that history cannot reproduce.

In Kit, ordinary simulation-lane prediction covers the declared predicted
fields. Cross-entity movement needs the corresponding timeline model and world
pass; see [Kit timelines](../../kit/timelines.md). In Replay, begin with the
character and its mutable movement dependencies together in one World. Consider
its authored prediction-scope features once that boundary works.

## 3. Sample devices outside the movement step

Convert keyboard, controller, or touch input into a small control value before
simulation. A direction vector, jump edge, and aim direction usually communicate
more useful intent than a claimed final transform.

Validate the value's range and finite numbers. Also decide how diagonal input
affects speed: allowing both axes to reach one makes an unnormalized vector
longer than a single-axis vector. A gameplay rule must make that choice
consistently on prediction and authority paths.

The [Kit simulation quickstart](../../kit/quickstart-sim.md) demonstrates a
constrained two-axis input, sampling, and the fixed-tick mutation. Its movement
constant is derived from a 60 Hz lane. If you change the rate, derive movement
from the same configuration. That tuning applies to the ordinary Kit lane;
managed Box3D integration requires 60 Hz with four native substeps per tick.
In Replay, the Session adapter supplies sampled
controls to the runner; device reads stay outside the model step.

## 4. Follow a correction through the character

Suppose a client predicts three moves to the right, but the authority finds a
collision on the second move.

| Moment | Simulation | Display |
| --- | --- | --- |
| Local input | Predict the next position | Show the local response |
| Authority result arrives | Restore the accepted state at its tick | Retain any allowed visual correction offset |
| Remaining inputs replay | Recompute the later moves against corrected dependencies | Follow the rebuilt character |
| Later render frames | Continue ordinary simulation | Reduce the visual offset according to the chosen presentation policy |

Collision uses the corrected simulation position. A smoothing offset belongs to
the view. Feeding the smoothed node transform back into movement makes the next
simulation result depend on rendering frequency.

Remote characters usually display an earlier, interpolated time. A remote
character and the local predicted character can therefore be visible at
different times. Check [Clocks](../concepts/clocks.md) before using their displayed
distance as an authoritative interaction test.

## 5. Add collision with an explicit stepping owner

For a query-driven controller, run collision queries from the fixed-tick
movement rule and retain the resulting movement state. For dynamic rigid-body
movement, choose a physics integration that can restore the dependencies your
prediction model needs.

Streaming Godot body poses is a cooperative observation policy. Restoring those
poses does not restore Godot's contact solver. Box3D's managed Kit and Replay
adapters retain complete physics state and give the framework ownership of
stepping. Follow [Physics ownership](../../box3d/ownership.md) before combining
either adapter with a character or rigid body.

Kit's complete Box3D participant uses staged world/Side callbacks rather than
the ordinary generated entity tick path described above. Its supported
mutations and restrictions are in [Kit Box3D](../../kit/box3d.md). Choose that
integration explicitly when the movement depends on a restorable native solver.

## Check the behavior

Test a joined client as well as the hosting player. The host's short local path
can hide problems visible over a connection. While adding delay and loss:

- hold a direction, release it, and check the stop policy when controls are missing;
- collide with a wall during correction and check for repeated penetration;
- jump or dash near a correction boundary and check that its cost is paid once;
- teleport or respawn and check that interpolation does not draw a trip across the map;
- vary rendering frame rate while keeping the simulation rate fixed.

Begin with [Hello Sim's player](https://github.com/wlitwin/odin_godot/blob/main/examples/hello_sim/scripts/player.odin),
which separates tick mutation from node positioning. Then continue with
[spawning and lifetime](spawning-and-lifetime.md) or
[presentation and effects](../concepts/presentation-and-effects.md).
