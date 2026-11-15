# Add weapons and authoritative damage

Design a weapon by separating input, a valid shot, hit adjudication, damage,
and feedback. This guide builds on a moving player from
[the movement guide](movement.md). Begin with one weapon, one target, and a
cooldown before adding ammunition types or effects.

The shooter can receive an immediate response while the authority still decides
whether the shot was allowed and what it hit. Those are distinct results, and
the game must be prepared for them to differ.

## 1. Write the shot rule

List everything that permits a shot: an active player, the correct game phase,
an equipped weapon, available ammunition or energy, and an expired cooldown.
Then list the consequences of accepting it: consume the resource, advance the
cooldown, create a projectile or query a ray, and produce an identified gameplay
result.

Put mutable values that affect repeated simulation in its history. If death
disables movement or firing, reading present-day health while replaying an older
tick can change the result. In Kit, a reliably replicated health field and a
predicted movement field have different histories. Choose that boundary with
the expected correction behavior in mind. In Replay, health, weapon state, and
cooldowns that affect the model belong in the World.

Pure damage arithmetic is useful in a replayed rule. It does not make every
container or convenience component suitable for every simulation lane. Follow
the storage restrictions in [Kit combat](../../kit/combat.md) when composing a
weapon from its helpers.

## 2. Choose the time of a hit

A hitscan weapon and a slow projectile usually need different policies:

| Weapon | Useful adjudication policy | Visible consequence |
| --- | --- | --- |
| Instant rifle | Authority may query a bounded historical view of targets | A player can be hit shortly after reaching cover locally |
| Slow grenade | Advance a projectile and collide against the relevant simulation state | Players can move away before it arrives |
| Shared physics object | Include contact dependencies in the physics simulation | Several bodies can affect the result together |

Historical hit queries favor part of the shooter's past view. They consume
history and need age limits. They do not prove what a client actually displayed,
and they cannot make both players' views of a delayed interaction simultaneous.

Decide the policy per weapon. Applying a rifle's rewind rule to a slow grenade
can make an attack hit an old target position long after the target moved away.

## 3. Implement the framework path

In Kit's ordinary field-based simulation lane, the tick computes whether the
weapon fires. Its authority `_then` consequence can adjudicate the hit and
apply accepted damage.
The paired presentation path displays the shot on its appropriate local or
watched timeline. The [Quickdraw game](https://github.com/wlitwin/odin_godot/tree/main/examples/quickdraw)
demonstrates hitscan, a predicted lobbed projectile, and their different hit
policies.

Kit's `lane_rewound_begin` and `lane_rewound_end` temporarily select historical
predicted fields for tracked entities other than the shooter. Keep the query
within that scope, pair the calls, and do not track or untrack entities inside
it. Reliably replicated fields such as health remain current. A historical
shield predicate therefore needs shield state in the history being queried.
See [Kit simulation](../../kit/sim.md) before adapting the query.

These field-rewind functions are unsupported while Kit's complete Box3D
participant is attached. That mode retains complete native solver checkpoints
and rejects the legacy rewind path. Use [Kit Box3D](../../kit/box3d.md) to design
the weapon around its supported staged state and query surface; wrapping a
native query in the ordinary field-rewind scope does not rewind the solver.

In Replay, put firing and damage in the model's step/action path. Use the
runner's configured action schedule to decide whether a discrete shot keeps a
tick deadline or is admitted at receipt time. Historical hit data and its query
policy are explicit model dependencies. Scrapyard retains hit proxies and uses
`net.query_view` to select an admitted view in
[ordnance.odin](https://github.com/wlitwin/odin_godot/blob/main/examples/replay_scrapyard/shared/game/ordnance.odin).
That example is a starting point for the game's weapon policy, rather than an
automatic rewind of arbitrary Godot nodes.

## 4. Trace one delayed shot

Suppose the shooter sees a target beside a doorway and fires. Before the request
arrives, the target's current simulation position has moved behind the wall.

The authority first checks whether the player could fire. It then checks which
historical view, if any, the selected policy permits. A valid historical pose
can establish the hit, while current health determines whether damage can still
be applied. An unavailable or inadmissible history query needs the weapon's
explicit outcome; avoid quietly inventing an older pose.

Keep the query result and the damage operation distinct in diagnostics. “The
ray missed,” “the view was too old,” and “the target was already dead” explain
different behavior. A single “shot failed” counter cannot help a developer
adjust those rules.

## 5. Add feedback after damage works

A muzzle flash, tracer, recoil animation, hit marker, and death announcement
have different costs when a prediction is wrong. Show cheap local feedback at
input or prediction time if the game accepts that tradeoff. Reserve stronger
claims, such as a confirmed kill, for a settled result.

Give gameplay effects stable identities so correction can reconcile them.
Playing audio from every execution of a simulation tick can repeat a shot
during replay. Conversely, a late joiner should learn current health without
receiving every old muzzle flash. Follow
[Presentation and effects](../concepts/presentation-and-effects.md) for that
boundary.

## Check the behavior

Hold fire through a cooldown, duplicate an action packet, fire during death,
and exhaust ammunition. Check that each accepted shot pays its cost once and
that a dead target cannot grant another killing reward.

Then add delay and jitter, move targets into cover, and test the oldest allowed
historical query. For projectiles, test collision on the final lifetime tick
and against a target removed or replaced before impact. Record the selected
query tick, action outcome, and applied damage separately.

Continue with [spawning and lifetime](spawning-and-lifetime.md) for projectiles,
or [testing and debugging](../concepts/testing-and-debugging.md) for diagnosing
disagreements between simulation and display.
