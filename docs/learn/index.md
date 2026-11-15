# Learn by building

For a complete topic index, use the [site map](../site-map.md).

Follow a path to a working result, then read the explanations for the decisions
you now face. You can learn the scripting bridge without multiplayer, and
Box3D without either framework.

## Build your foundation

1. [Create your first Odin scene](../scripting/first-scene.md): a visible moving
   square with a property you can change in the Inspector.
2. [Understand script state and Godot objects](../onboarding/02-thinking-in-structs.md):
   learn where instance data lives and how procedures reach the engine node.
3. [Set up the development loop](../workflow.md): build, reload, and debug changes.
4. [Study a complete single-player game](../examples/index.md): follow input,
   signals, resources, and scene behavior in Survivors.

## Choose a multiplayer path

| Goal | Build | Understand |
| --- | --- | --- |
| Cooperative script entities | [Two Kit players](../kit/quickstart.md) | [State replication](../onboarding/03-state-not-messages.md) |
| Authoritative movement | [Kit prediction](../kit/quickstart-sim.md) | [Timeline models](../kit/timelines.md) |
| Restorable interactions | [Replay pickup correction](../replay/quickstart.md) | [World and history](../replay/architecture.md) |
| A Replay game in Godot | [Session starter](../replay/godot.md) | [Presentation and effects](../replay/presentation.md) |

Read [Choosing Kit or Replay](../multiplayer/index.md) before committing a new
game's state model. A framework tutorial teaches its own concepts; learning Kit
is not a prerequisite for Replay.

## Understand multiplayer before adding features

Follow [the conceptual reading path](../multiplayer/concepts/index.md) from
authority and state through ticks, prediction, and presentation. Continue with
the [feature walkthroughs](../multiplayer/recipes/index.md) for one problem in
your game: movement, a contested pickup, a weapon, spawning, joining, or a round
change.

When a prototype moves beyond localhost, use the articles on
[connections](../multiplayer/concepts/connections-and-compatibility.md),
[bandwidth](../multiplayer/concepts/bandwidth-and-relevance.md),
[scale](../multiplayer/concepts/performance-and-scale.md),
[testing](../multiplayer/concepts/testing-and-debugging.md), and
[recovery](../multiplayer/concepts/recovery-and-trust.md). These explain the
decisions behind settings you will find in the framework references.

## Add physics or a small library

- [Knock down a tower](../box3d/quickstart.md), then learn
  [who owns physics](../box3d/ownership.md) and [author collision](../box3d/authoring.md).
- [Understand a physics world](../box3d/concepts/index.md): bodies, queries,
  solver history, authored identity, joints, and character movement.
- [Run a timed sequence](../libraries/flow.md), then add
  [Godot Tween steps](../libraries/flowgd.md).
- [Publish a typed event](../events.md) for scripts inside the same library.

## Ship what you built

Use [Exporting](../exporting.md) for desktop and browser packaging. Check
[bridge distribution](../distribution.md), [Replay support](../replay/support.md),
and [Box3D support](../box3d/support.md) for the configurations your game uses.
