# Understand a physics world

Learn what a Box3D world contains, how its motion becomes a Godot view, and what
changes when the world participates in multiplayer. These concepts apply to
the [offline tutorial](../quickstart.md) as well as the Kit and Replay adapters.

Start with a small scene you can inspect: a floor, a moving body, and one
interaction. Keep the body's simulated state and the node that displays it
distinct as you follow the reading path.

| Page | Question it answers |
| --- | --- |
| [Bodies, shapes, and motion](bodies-shapes-and-motion.md) | What has mass, what defines collision, and how prescribed movement differs from an impulse |
| [Collision, sensors, and queries](collision-and-queries.md) | When objects block one another, when they report overlap, and how a query selects results |
| [Simulation and rollback](simulation-and-rollback.md) | Who steps the world, why pose restoration is incomplete, and which history must agree |
| [Authoring and world identity](authoring-and-world-identity.md) | How editor definitions become immutable geometry, durable content IDs, and runtime objects |
| [Joints and characters](joints-and-characters.md) | When to use a constraint or explicit character movement, and where that movement state lives |

After the explanation, use [authoring](../authoring.md) and
[motion](../motion.md) for the concrete nodes and operations. The
[capacity guide](../capacities.md) explains count and storage choices, while
[performance and scale](../../multiplayer/concepts/performance-and-scale.md)
explains why activity and interactions matter alongside those limits.

For a multiplayer physics game, read
[prediction](../../multiplayer/concepts/prediction.md) and
[presentation](../../multiplayer/concepts/presentation-and-effects.md) before
connecting the world to [Kit or Replay](../multiplayer.md). A smooth displayed
transform and a restorable solver serve different parts of that game.
