# Joints and character movement

Choose a motion model from the interactions the game needs. A loose crate, a
hinged gate, and a walking player can look similar in a scene tree while needing
different state and control rules.

This page explains when to use dynamic bodies, joints, or the Box3D character
mover. [Characters, queries, and joints](../motion.md) contains the adapter
entry points once you have chosen the model.

## Decide which motion the solver may choose

| Gameplay need | Model to consider | State the game must own |
| --- | --- | --- |
| A crate tumbles when pushed | Dynamic body | Cargo status and body mapping alongside physics state |
| A gate rotates around an attachment | Dynamic body connected by a hinge | Gate rules, motor/limit decisions, and joint mapping |
| A player follows a controlled capsule path | Character mover with explicit state | Position, velocity, grounding, jump state, and timers |

A dynamic player can participate in physical impacts and constraints, while
requiring the game to handle the control consequences of those impacts. A
character mover gives the game an explicit movement result against the current
collision world. It does not create a dynamic body on the player's behalf.

Neither choice defines the whole character design. Input acceleration, jump
rules, camera behavior, animation, and accepted interactions still belong to
the game. A character capsule alone does not specify how pushing cargo should
transfer momentum.

## A joint relates two bodies

A joint constrains the relative motion of bodies. A hinge leaves a rotational
degree of freedom; a slider describes motion along an axis. Distance, spherical,
motor, weld, and wheel families express other relationships. Pin authoring uses
a spherical point constraint with angular features disabled.

The attached bodies remain separate bodies. That is useful for a pendulum or
vehicle suspension whose pieces must move relative to one another. Several
shapes on one body are a better fit when the parts must move as one rigid
object. Adding a joint between every visual component can introduce physical
degrees of freedom that the model never needed.

Joint definitions refer to both bodies and describe a local frame in each
body's space. A local anchor moves and rotates with its body. Matching the
intended attachment requires transforming the same physical relationship into
both local frames. In this integration, a hinge's axis is local Z in those
frames; a slider uses its defined local axis settings.

A gate anchored at the wrong local point can appear to orbit rather than swing
at its hinge. A rotated frame can make a motor act along an unexpected axis.
Inspect frames and body poses before increasing forces or changing solver
settings. Authoring rejects unresolved references, a body connected to itself,
and two static bodies connected by a joint.

## Let constraints produce the connected motion

A motor or spring expresses a target through a constraint with the family's
force, torque, velocity, or spring settings. Teleporting a connected body every
tick expresses an additional placement rule. When those rules disagree, the
solver must keep resolving an arrangement the game keeps moving out of place.

For a powered gate, decide whether the game requests motor behavior or
prescribes its motion. Keep the accepted target and any gameplay limits in
restorable state. A predicted “open” input may be rejected, so both the target
and the complete joint/solver state must return to the appropriate tick.

Long chains, large mass differences, contacts between connected parts, and
large lever arms influence constraint behavior and cost. `collide_connected`
is a game choice about whether the connected bodies may also form contacts.
It is useful to inspect one connection under load before adding the entire
mechanism.

All supported joint families share the selected profile's joint capacity,
which defaults to 256. Raising that count permits more constraints; it does not
establish their simulation cost. See [capacity planning](../capacities.md).

## The character mover returns values

The mover consumes a capsule, up direction, slope threshold, filter, and
`Character_State`. It queries collision, solves movement against encountered
planes, and returns candidate state and displacement. The result includes
grounding information. Your game supplies the desired velocity, including its
gravity and jump decisions, before asking for movement.

The slope threshold relates a surface normal to the character's up direction.
A floor-like surface and a steep wall therefore produce different grounding
results. Grounding is a saved value used by later game rules, rather than a
Godot node reference or a visual guess based on foot animation.

The operation has bounded slide/plane work and can fail. Check the result before
publishing candidate character state. Treat a capacity error as a failed
simulation operation that needs handling; accepting an unexamined partial
movement can make peers disagree about the character's next position.

The helper neither advances the world nor mutates another body's motion. If a
character should push a crate, define that interaction explicitly in the
simulation, for example through the game's accepted impulse rule. Moving a
character mesh into cargo does not transfer physical momentum. If you maintain
a separate physical proxy for the character, exclude it from the character's
own movement queries and define how its pose follows the saved movement state.

## Keep the character on the framework tick

Offline code can call the native character helper at the selected fixed-duration
step boundary and then advance its world according to its chosen schedule.
Kit's helper reads the staged participant world; the Lane performs the
participant's fixed physics step. Replay's helper reads its execution
attachment, and the game callback still calls `replay/physics.step` exactly once.
Choose and preserve the order in which movement and other body operations run.

Save character position, velocity, grounding, cooldowns, and jump timing in
Kit Side or Replay frame values. Rendered smoothing and animation
can use copied values at a display time. Feeding the smoothed mesh position
back into the next simulation tick changes the movement input according to
render timing.

Useful situations to reason through include stepping off a ledge, landing on a
slope, moving beside a wall, and correcting input during a jump. Ask which saved
values determine the next tick in each case, and which visible effects should
survive or be revised when the prediction changes. The
[physics rollback guide](simulation-and-rollback.md) explains that boundary.
