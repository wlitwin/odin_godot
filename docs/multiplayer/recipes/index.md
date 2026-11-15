# Build a multiplayer feature

These walkthroughs help you design one feature inside a working Kit or Replay
project. Each follows the state changes, input, presentation, and failure cases
that the game must handle. Use your framework's
[Kit tutorial](../../kit/quickstart.md) or
[Replay tutorial](../../replay/quickstart.md) for the initial running setup.

If authority, ticks, or prediction are new terms, begin with
[multiplayer concepts](../concepts/index.md). Each walkthrough then keeps the
framework paths distinct and links to the APIs and example code for that path.

| Feature | Decisions you will work through |
| --- | --- |
| [Player movement](movement.md) | Input ownership, authoritative movement, prediction, collision dependencies, and display |
| [Pickups and inventories](pickups-and-inventories.md) | Competing requests, conserved items, accepted consequences, and tentative feedback |
| [Weapons and damage](weapons-and-damage.md) | Shot identity, validation, historical aim, projectiles, and authoritative health |
| [Spawning and lifetime](spawning-and-lifetime.md) | Stable identity, generations, membership changes, despawn, and view cleanup |
| [Joining and reconnecting](joining-and-reconnecting.md) | Readiness, returning identity, baselines, pending actions, and host loss |
| [Scenes and rounds](scenes-and-rounds.md) | Simulation phases, content readiness, round identities, and stale work |

Begin with one interaction and a small number of players. Make its accepted
result observable before adding effects, then introduce delay and a competing
action. This gives the examples a purpose: the relevant files demonstrate a
decision you have already made for your game.

Use [the example map](../../examples/index.md) to find the small runnable
projects and the hosted Dockyard and Scrapyard games. For deployment concerns,
continue with [connections](../concepts/connections-and-compatibility.md),
[scale](../concepts/performance-and-scale.md), and
[testing](../concepts/testing-and-debugging.md).
