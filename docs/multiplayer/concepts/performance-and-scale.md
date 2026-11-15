# Plan simulation and network scale

Object count is a starting point for a performance question. This page explains
how activity, interactions, correction, and history turn that count into CPU,
memory, and network work. Use it when a prototype grows or when choosing a
capacity profile.

A yard with a thousand untouched doors has a different workload from a thousand
moving bodies in a pile. Adding players also changes the number of recipients,
inputs, interactions, and possible corrections. A capacity that admits the data
does not specify the cost of running that scene.

## Separate the budgets

| Budget | Work to include |
| --- | --- |
| Ordinary simulation | Active game systems, movement, AI, queries, contacts, constraints |
| Correction | Decode, restore, repeated steps, validation, event reconciliation, publication |
| Presentation | Godot nodes, meshes, animation, UI, effects, render interpolation |
| Memory | Current state, retained frames, input/events, native solver images, transfer staging |
| Network | Per-recipient state, inputs/actions, baselines, acknowledgements, recovery |

At 60 simulation ticks per second, each tick represents about 16.7 ms. The
application still needs time for rendering and other work, and a rendered frame
can need more than one simulation step. Scheduling regular ticks close to that
whole interval leaves little room to catch up.

For correction, include the number of steps that may need repeating. An
illustrative eight-tick repair with a 1 ms simulation step already includes
about 8 ms of simulation before decoding, restoring, or reconciling effects.
Measure the complete operation as well as its individual steps.

## Make activity explicit

An intact door can store its state until an interaction opens it. A scheduled
spawn can store a due tick. A cooldown can store a completion tick if the game's
rules support that representation. These designs can avoid separate callbacks
that do identical work for every object on every frame.

Keep the result replayable. A cooldown represented by a wall-clock deadline
changes with machine time and cannot be reconstructed from a historical frame.
A tick deadline inside simulation state can be restored with that frame.

Store shared immutable definitions once and use stable references to them.
Keep mutable values required for future decisions in the selected restorable
state. Moving mutable data out of history to reduce memory can make correction
incorrect if the next tick still reads it.

The frameworks have different work boundaries. Kit's ordinary entity and field
model lets a game select which state enters its simulation lane. Replay's World
and authored prediction group determine what a correction must reconstruct.
Choose that boundary from gameplay dependencies before optimizing its size;
[prediction](prediction.md) explains why an interaction can enlarge it.

## Account for history and temporary work

For copied value frames, retained memory grows roughly with the number of
stored frames multiplied by their footprint, plus inputs, events, and metadata.
Storage sharing and adapter ownership can change the physical total. A
serialized checkpoint's byte length is therefore insufficient as a measurement
of retained process memory.

Complete physics adds solver data such as contacts, constraints, and cached
state. A current world, retained snapshots, and a staged correction can coexist.
Transfer buffers and game-owned queues may coexist with them too. Measure steady
play, correction, join, and teardown rather than treating a low idle allocation
as the maximum.

Box3D uses a shared [build capacity profile](../../box3d/capacities.md). Counts,
wire sizes, and memory allowance are related but independently bounded. A larger
body limit can still meet a contact, shape, transfer, or memory limit first.
Its memory allowance is accounted quota rather than a startup preallocation.

## Scale the expensive relationships

Contacts and queries depend on spatial relationships and geometry, not only
body count. A sleeping, separated scene and a dense moving pile stress different
parts of a solver. Joint chains, repeated wide queries, and many sensor overlaps
also deserve separate scenes.

Network sending depends on recipients as well as changing objects. Reducing
simulation work does not remove the cost of encoding and sending state to each
peer. [Bandwidth and relevance](bandwidth-and-relevance.md) describes how to
measure that side and the correctness rules for filtering.

Godot rendering is another separate relationship: one simulated object can have
several meshes, labels, particles, and UI bindings. A slow rendered scene can
coexist with a healthy simulation. Profile those owners separately before
changing prediction or snapshot policy.

## Establish a workload you can reproduce

Choose a representative scene and a demanding interaction: clustered cargo,
simultaneous pickups, several new players joining, or a late input that forces
a substantial correction. Record counts and activity together, including
contacts, events, changed state, recipient count, and repaired ticks.

Inspect slower operations and allocation peaks as well as averages. Compare
the same build, scene, and accepted input history when evaluating a change.
Then vary one source of work so the result explains a cause. Merely increasing
every limit can move a failure into a larger queue or a longer correction.

Use [Kit profiles](../../kit/profiles.md), [Replay support](../../replay/support.md),
and [Box3D support](../../box3d/support.md) for the current bounds of the selected
configuration. Continue with [testing and debugging](testing-and-debugging.md)
to distinguish overload from an incorrect simulation.
