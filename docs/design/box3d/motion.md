# Character movement, queries and joints

P5.2 extends the shared authoring backend through separate Kit and Replay
execution adapters. The Native matrix, pure and Native-facing Odin tests, both framework transaction
and canonical-transfer cases, and actual Godot SDK fixture pass on the declared
macOS reference. Exact artifacts and limits are in the
[task report](../../../tests/box3d_motion/report.json).

## Tick ownership and character state

`Box3DCharacterMover3D` authors a capsule and its movement settings. It does not
schedule physics. Extract its configuration before simulation and store the
character position, velocity and grounded state in rollback-owned Game or Side.
Kit and Replay call the shared mover from their existing staged tick callbacks.
Presentation reads the published value and updates nodes afterward.

Movement uses the pinned engine's capsule cast, collision-plane collection,
plane solver and velocity clipping. Query filters and an explicit body exclusion
apply to the same actual execution world. No Godot query, Resource lookup,
process clock or live node reference participates in replay. Floor classification
uses a declared up vector and slope threshold. An unsupported or exhausted
query returns an error instead of publishing movement based on a partial set.

## Deterministic queries

The original raw AABB and ray queries retain their documented traversal order.
The new deterministic operations gather the complete bounded result, convert
handles to world-independent allocation keys, and apply stable ordering and tie
breaks before copying to the caller. Capacity is explicit. Stable allocation
keys are valid within the recorded world history; they do not replace durable
authored logical IDs across unrelated construction histories.

Framework helpers query the unpublished staged solver. Callers copy results
into their own value state; they never retain the borrowed execution world.
Rejected ticks, actions and commit gates preserve both character side-state and
the complete solver through the frameworks' existing transaction machinery.

## Calling from each framework

The shared runtime types are `Character_Config`, `Character_State` and
`Character_Result` in `godot:box3d`. Build-time character maps supply a copied
configuration and initial state. A mover does not create a hidden dynamic body;
its optional self-exclusion resolves an authored body reference to a local
allocation key during construction.

Inside a Kit authored tick, use the current Side and the staged helper:

```odin
side := kp.state(physics)
next, error := kp.character_step(physics, movement_config, side.character)
if error != .Ok {return}
side.character = next.state
```

Inside Replay's existing step callback:

```odin
next, error := rp.character_step(ctx.execution, movement_config, game.character)
if error != .None {return}
game.character = next.state
if rp.step(ctx.execution) != .None {return}
```

The callback supplies desired velocity in its rollback-owned state, including
any game-specific gravity or jump rule. Both adapter movement helpers use the
existing fixed 1/60 step. Kit still performs its participant solver step; Replay
still requires exactly one ordinary `rp.step`. The mover itself only reads the
world and returns a candidate value. Invalid movement poisons the unpublished
transaction even if its error is ignored.

Both adapters expose `motion_aabb`, `motion_ray`, `motion_capsule` and
`motion_capsule_cast` with copied `Motion_Hit` results and a `Motion_Filter`.
They expose `motion_joint_create` and `motion_joint_destroy` for staged commands
using body/joint allocation keys. Replay dispatches mutations through the
producer that owns the execution and its accounting. Read results only after
checking status. Capacity from a read query remains an explicit sizing result;
no partial prefix is published by the deterministic query API.

## Joint families and identity

The named authoring surfaces map to the pinned engine as follows:

| Authoring kind | Native constraint |
| --- | --- |
| Pin | Spherical point constraint with angular features disabled |
| Hinge | Revolute |
| Slider | Prismatic |
| Spherical | Spherical with its explicit angular settings |
| Distance | Distance |
| Motor | Motor |
| Weld | Weld |
| Wheel | Wheel |

Joint definitions reference explicit body keys in the same authored world.
Their own stable keys produce durable logical IDs independent of node names,
resource order and runtime handles. Baking validates references, rigid local
frames, finite settings and limit relationships before native construction.
The local runtime map contains native joint allocation keys for executing later
operations. Neither Godot object identities nor native handles enter canonical
Game state.

## Complete recovery and limits

Schema 1 keeps its earlier body/shape content identity and recovery format 2.
Use `scene_input_default(namespace, 2)` for joint/character arrays. Schema 2 uses
the same copied asset descriptor layout with a recovery-format-3 catalog. Legacy
primitive format 1 and authored format 2 retain their earlier readers. The new
format carries every supported native joint union; no solver field is omitted.
The wrapper normalizes default Distance length bounds through the engine's
setter before publishing the key, including a disabled 0..0 range. Inverted
native ranges remain invalid canonical data.


A locally created constraint is usable in networked rollback only after the
canonical codec covers its complete solver state. Every joint family requires
its actual settings, impulses, prepared solver data and native graph links to
survive validation, scratch reconstruction and exact re-encoding. Unsupported
format versions fail explicitly; legacy recovery readers keep their declared
contracts. No joint family may be silently omitted from a checkpoint.

The existing profile still permits one joint at a time, 35 bodies/shapes,
32 dynamic bodies, eight deduplicated geometry assets, H128 and prediction and
ordinary repair depth eight. Tests exercise joint families separately under that
profile. Adding authoring classes does not increase the 64 MiB tracked resource
limit or change the dependency pin and floating-point policy.

## Required validation

The task must establish Native Debug, Release and sanitizer coverage; pure
schema/identity/reference controls; actual native Odin construction and movement;
Kit and Replay rollback, rejected-publication and canonical recovery checks; and
ordinary Godot import plus Resource/scene save/reload, source destruction and
checked cleanup. Editor gizmos and export Gate C are separate tasks.
