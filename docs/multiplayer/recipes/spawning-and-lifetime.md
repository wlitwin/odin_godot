# Spawn entities with stable lifetimes

Give a new projectile, enemy, or pickup an identity that remains meaningful
across delayed messages, correction, and removal. This guide assumes the
[Kit quickstart](../../kit/quickstart.md) or [Replay quickstart](../../replay/quickstart.md)
and extends their existing entity setup.

Start with one projectile that lives for a fixed number of simulation ticks.
Its gameplay lifetime and its Godot node lifetime need separate owners: the
simulation decides whether it exists, and presentation decides which node
currently displays it.

## 1. Define identity before creating the node

A node pointer identifies an object in one process. It cannot identify a
projectile on another machine or survive freeing that node. A pool slot alone
is also insufficient: after a projectile disappears, a new one may reuse it.

Use an entity identity with the lifetime information required by the framework.
Kit gives network entities IDs and generates typed references for tracking
them across callbacks. Replay's `Pool` and `Handle` pair a slot with a
generation, which changes as the slot is reused.

Consider a delayed collision involving projectile A:

| Moment | Slot | Lifetime | Meaning |
| --- | --- | --- | --- |
| A is created | 7 | First occupant | A valid projectile |
| A expires | 7 | First occupant ends | References to A must stop resolving |
| B is created | 7 | New occupant | A different projectile |
| A's delayed message arrives | 7 | First occupant | It must not operate on B |

Keep the complete identity in pending requests, effects, and view maps. Showing
the right mesh at a reused index does not make an old request valid.

## 2. Create complete initial state

Before announcing an entity, initialize the values another peer needs to
understand it: type, owner or source, position, motion, remaining lifetime,
and any content ID used to select its visuals or behavior.

In ordinary Kit field-based games, declare the entity scene with an explicit
stable `entity=Type:id` tag.
The generated factory connects wire identity to the correct script and scene.
Use the generated spawn helper, initialize its fields, then announce it through
`boot_spawn_send`. [Kit Boot](../../kit/boot.md) describes the generated hooks.

The `_spawned` hook runs before received spawn fields are applied. Use it for
bookkeeping that needs the identity. The `_born` hook sees initialized fields
and is the appropriate place for a first visible position or tint. Otherwise,
a node added during a process pass can briefly appear at its scene's default
transform.

In Replay, create a value in the World's pool from the model step or action.
Store allocation metadata in the World alongside its values. Check insertion
failure and define its gameplay consequence: refusing a shot, choosing a
bounded replacement policy, or aborting a candidate are different rules.
Presentation reads current membership and creates the corresponding node.

## 3. Choose whether creation is predicted

An authority-created enemy can appear when accepted state reaches the viewer.
A locally fired projectile may need immediate feedback. Prediction introduces
a provisional lifetime that must later match or yield to the accepted result.

Kit supports predicted ticking projectile entities. The acting client creates
its prediction, while the authority creates the accepted entity through its
authority consequence. The factory matches the accepted spawn to the local
prediction and assigns its authoritative ID. Use the documented generated
path rather than creating a second unrelated node when the spawn arrives.
Follow [Kit simulation](../../kit/sim.md) and Quickdraw's
[bullet](https://github.com/wlitwin/odin_godot/blob/main/examples/quickdraw/scripts/bullet.odin).

This generated scene-spawn and entity-tick path is unsupported while Kit's
complete Box3D participant is attached. In that mode, game membership,
generations, and body-key mappings live in typed `Side`, alongside the retained
native world. Supported spawn/despawn mutations happen inside the staged
native/game state, and scene presentation follows committed state. Keep game
generations separate from native allocation keys. Follow
[Kit Box3D](../../kit/box3d.md) before adding dynamic physics entities.

For the hosting player, the authority may already have created the projectile.
Guard the local prediction path accordingly; otherwise one input produces two
bullets on the host. A refused or unmatched prediction also needs removal.

Replay prediction can create a pool member in the predicted World. Correction
can remove it or recreate it through the same model code. The view should
reconcile identity and lifetime from the corrected frame, including any
associated occurrence changes. It must not preserve a projectile solely
because a Godot node is still visible.

## 4. End the lifetime in simulation

Advance a projectile's remaining life in simulation ticks. Decide the order
between movement, collision, and expiry. If the last tick includes movement,
test that final swept segment before removing the projectile.

Keep iteration correct when removal changes membership. A generational pool
lets a removed slot become inactive without granting its old handle access to
a replacement. Code holding a borrowed pointer into a frame or pool must finish
using it within that valid access; do not retain it across correction or
replacement of the frame.

For Kit entity maps, remove bookkeeping in the generated `_freed` hook while
the struct and node are still available. Across frames, prefer generated typed
references and resolve them when needed. A stored raw entity pointer can
outlive the entity it once described.

## 5. Reconcile effects and late join

A projectile's identity can also identify its trail and impact. Include its
lifetime when assigning effect identities so a reused slot cannot attach a
new shot to an old effect.

A late joiner needs current projectile membership and state. It generally
does not need every historical spawn sound. Treat a durable entity and a
one-shot announcement separately; read
[Presentation and effects](../concepts/presentation-and-effects.md).

## Check the behavior

Create and remove more entities than the pool has slots over time. Send an
operation naming an old lifetime after its slot is reused. Correct to a tick
before a predicted spawn, then replay past its creation again. Test both
accepted and refused local shots, including the hosting player.

Join while projectiles are already flying and disconnect while a spawn is
pending. Verify that each visible object corresponds to a current gameplay
identity, and that departed objects release their nodes, trails, callbacks,
and local lookup entries.

Continue with [joining and reconnecting](joining-and-reconnecting.md) to make
these identities survive a screen rebuilding its view of the game.
