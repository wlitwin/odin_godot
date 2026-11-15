# Characters, queries, and joints

Use copied value state for character movement and stable authored keys for
body connections. This guide assumes [world authoring](authoring.md). Motion
definitions use authoring schema 2.

## Character movement

The shared runtime types are `Character_Config`, `Character_State`, and
`Character_Result` in `godot:box3d`. The mover queries the current collision
world and returns candidate state. It does not create a hidden dynamic body or
own a tick scheduler.

Keep position, velocity, grounding, and game-specific jump or gravity state in
the framework's restorable state. Supply desired velocity there, and check the
movement result before using it.

Kit code inside an authored tick uses the staged physics provider:

```odin
import kp "godot:kit/physics"

side := kp.state(physics)
next, error := kp.character_step(physics, movement_config, side.character)
if error != .Ok {return}
side.character = next.state
```

Replay's step uses its existing execution attachment:

```odin
import rp "godot:replay/physics"

next, error := rp.character_step(ctx.execution, movement_config, game.character)
if error != .None {return}
game.character = next.state
if rp.step(ctx.execution) != .None {return}
```

These are callback excerpts, with the provider, configuration, and game state
supplied by the adapter setup. The movement helper reads the staged world;
Kit still performs its participant step and Replay still requires exactly one
`rp.step`. Both use the fixed 1/60-second contract.

## Queries

Both adapters expose `motion_aabb`, `motion_ray`, `motion_capsule`, and
`motion_capsule_cast`, using `Motion_Filter` and copied `Motion_Hit` results.
Results are ordered deterministically and use world-independent allocation keys.
Check status and capacity before reading results; failed reads do not publish a
partial prefix.

Allocation keys identify runtime history. Use authored logical IDs for durable
references across unrelated world constructions. Do not retain the borrowed
execution world after a callback.

## Joints

| Authored family | Native constraint |
| --- | --- |
| Pin | Spherical point, angular features disabled |
| Hinge | Revolute |
| Slider | Prismatic |
| Spherical | Spherical with explicit angular settings |
| Distance | Distance |
| Motor | Motor |
| Weld | Weld |
| Wheel | Wheel |

Joint definitions have stable keys and reference explicit body keys in the same
world. Baking validates references, rigid local frames, finite settings, and
limit relationships. Runtime mutations use `motion_joint_create` and
`motion_joint_destroy` within the staged adapter operation.

Available joint families do not increase the active runtime profile's joint
capacity. Check [Support](support.md) and the
[authoring API](https://github.com/wlitwin/odin_godot/blob/main/box3d/authoring/API.md)
before choosing a configuration.
