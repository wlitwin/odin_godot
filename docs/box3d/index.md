# Box3D physics

Box3D provides explicitly stepped 3D physics for Odin games. Use it offline, with
Kit, or with Replay. The SDK includes low-level bodies and queries, Godot
authoring nodes and shape Resources, character movement, joints, and separate
framework adapters for complete physics history.

Use [the physics concepts](concepts/index.md) alongside this section's tutorial
to understand bodies, collision, solver history, and the roles of joints and
character movement.

Learn [Odin scripting](../scripting/index.md) first. Multiplayer knowledge is
needed only for a framework integration.

## What owns the simulation

Godot nodes describe authored content or display copied poses. Adding a
`Box3DWorld3D` node does not start a solver. Your offline script, Kit Lane, or
Replay runtime must own stepping. Each world has one tick owner.

| Use | Owner | Start here |
| --- | --- | --- |
| Offline physics | Your Odin script | [Tower knockdown tutorial](quickstart.md) |
| Editor-authored collision | Detached bake and your chosen runtime | [Author a world](authoring.md) |
| Kit multiplayer | Kit Lane and `kit/physics` | [Multiplayer integration](multiplayer.md) |
| Replay multiplayer | Replay runtime and `replay/physics` | [Multiplayer integration](multiplayer.md) |

## Learn Box3D

Look up signatures and types in the [Box3D API](../api/generated/box3d.md)
and [authoring API](../api/generated/box3d/authoring.md).

| Page | What you will learn |
| --- | --- |
| [Tower knockdown](quickstart.md) | Run physics without networking and trace world creation, stepping, and node updates |
| [Physics ownership](ownership.md) | Separate source content, live solver, checkpoints, and presentation |
| [Author a world](authoring.md) | Create worlds, bodies, sensors, shape Resources, and stable keys |
| [Editor and baking](editor.md) | Install tools, bake mesh collision, save artifacts, and display debug geometry |
| [Characters and joints](motion.md) | Keep character state in history, query collision, and connect bodies |
| [Multiplayer integration](multiplayer.md) | Choose an adapter, prepare its sample, and preserve complete state |
| [Build and export](building.md) | Build and select the backend, deploy it with the SDK, and export a project |
| [Configure capacities](capacities.md) | Select body, shape, joint, asset, and byte budgets for the game |
| [Configure timing](timing.md) | Select history, prediction/repair ceilings, tick rate, and substeps |
| [API map and limits](reference.md) | Find package entry points, shape rules, identity rules, and supported bounds |
| [Support](support.md) | Check platform, determinism, and runtime restrictions |

## Choose a supported configuration

Box3D is a separate solver from Godot's built-in physics. A Godot `RigidBody3D`
does not become a Box3D body automatically. Migrate its collision and gameplay
rules explicitly, and keep node transforms as presentation when the solver owns
motion.

Rollback requires complete solver state: contact caches, constraints, pending
events, and gameplay side state as well as body poses. The framework adapters
provide this attachment. Their bounded profile and same-build, same-target
compatibility rules are described in [Support](support.md).
