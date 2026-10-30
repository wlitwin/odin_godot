# Choosing an authority and presentation model

Multiplayer code has to answer two separate questions:

1. Which process decides the authoritative value?
2. Which point in time should each player see?

Kit offers several answers because no single choice is best for co-op movement,
competitive hitscan, and shared physics. Select a model for each contested
entity or field; the rest of the session can continue to use reliable
replication.

## Summary

| Model | Authoritative writer | Local presentation | Remote presentation | Typical use |
| --- | --- | --- | --- | --- |
| Session replication | Host for `replicate`; entity owner for `owner` | Owner-streamed state is immediate | Owner streams are interpolated in the past | Invited co-op, player movement that the host need not verify, owner-simulated Godot physics |
| Predict self | Server simulation | The local player's state is predicted at the current tick | Other players are interpolated on a delayed watched clock | Competitive movement and aimed actions |
| Contested object | Server simulation, with a temporary local presentation claim | The claimant predicts the object while its interaction is active | Other peers watch authoritative snapshots | A ball, vehicle, carried object, or other isolated shared object |
| Predict world | Server simulation | The client predicts local and remote simulation from echoed inputs | Corrections are reconciled and visually smoothed | Games where current contact between several moving bodies must look coherent |

The first model is provided by `kit/net` and `kit/session`. The other three use
`kit/sim`. All four share the same player identities, entity factory, reliable
delta fields, chat, saves, and transports.

## Start with what players can contest

Use the least expensive model that gives the authority you need.

### No adversarial fast state

For an invited co-op game, owner streams are usually the simplest option. Each
player writes their own movement or aim; the host remains authoritative for
shared state and commands. Remote peers interpolate streamed values, so normal
packet loss does not require rollback or retransmission.

This model does not make owner-streamed values cheat-resistant. Do not use a
client's streamed position as trusted evidence in a public competitive game.

Read [kit/net](net.md), [kit/session](session.md), and the
[session-replication quickstart](quickstart.md). `examples/slopball` shows
owner-simulated Godot physics through `play.Puppet`.

### A player's movement or aim

Use predict-self when the authority must derive a player's state from inputs.
The owning client predicts at the current tick, while other entities remain on
the delayed watched clock. This keeps local controls responsive without making
every client simulate every remote player.

Aimed actions need lag compensation because the target was displayed in the
past. `lane_rewound` reconstructs the authority's recorded state for the view
associated with the shooter's input. The authority must bound that rewind and
validate all client input used by the simulation.

`examples/quickdraw` is the reference. Its native integration test compares a
rewound shot with the same shot judged against the live server state.

### One shared object

A contested object can use a presentation claim. The server remains
authoritative, but the client that initiated an interaction temporarily presents
its predicted version of the object. Other peers continue to display delayed
authoritative snapshots.

Claims are useful when round-trip delay on a kick, grab, or steering handoff is
noticeable but predicting the whole world would be excessive. A claim should be
tied to the interaction that caused it and released when that interaction ends,
not simply when the object crosses an arbitrary distance.

This model can still show mixed-time artifacts: a predicted ball may move before
a delayed remote player visibly reaches it. If contact itself is central to the
game, use predict-world instead.

### Contact among several moving bodies

Predict-world echoes players' latest inputs so that each client can advance the
contested simulation on one local timeline. This avoids the most obvious
mixed-time contact artifacts, but it increases simulation and reconciliation
work. Remote inputs are necessarily estimates until the next batch arrives, so
small corrections are normal.

Movement with inertia predicts better than movement that can change velocity
instantaneously. Simulated objects should integrate their own state between
snapshots, and contact resolution must be replay-safe.

`examples/speedball` demonstrates this model. Compare it with
[`examples/slopball`](../../examples/slopball/README.md), which implements a
similar game using owner-simulated physics.

## Hybrid games are expected

The choice is not global. A simulation-lane entity can still contain reliable
delta fields:

```odin
Player :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"predict,interp"`, // fixed-tick simulated movement
	hp:     i32 `gd:"replicate"`,      // reliable host-written state
	team:   u8 `gd:"replicate"`,
}
```

Quickdraw uses predicted movement beside reliable health and score. Chests,
inventories, chat, match state, and save data generally do not benefit from
rollback and should remain on the session layer.

The [promotion checklist](sim.md#promoting-a-coop-game) moves one entity at a
time from an owner stream to the simulation lane. A hybrid is a supported end
state, not merely an intermediate step.

## Presentation rules

These rules apply across the models:

1. **Present an effect on the same timeline as its cause.** A locally predicted
   shot should flash immediately. A remote shot should flash when the watched
   shooter reaches the corresponding tick.
2. **Treat first sight as a baseline.** A newly spawned entity should be placed
   from its received fields without replaying score flashes, damage reactions,
   or other historical edges.
3. **Judge the state that was displayed.** Lag-compensated queries should use
   validated snapshot evidence tied to the input being adjudicated. Bound its
   age with authority-observed RTT/jitter and the configured rewind window;
   treat a client-reported render offset only as a capped hint.
4. **Keep replayed code free of presentation and engine state.** A resimulated
   tick may run more than once. Audio, particles, node mutation, wall clocks,
   and non-ledgered randomness do not belong in it.
5. **Adopt truth immediately and smooth only the display.** Reconciliation must
   update simulation state before replay. Render-error smoothing can hide small
   corrections; intentional teleports should cross a configured cut threshold
   and display immediately.
6. **Resolve simulated contact from replayable data.** Query static level
   geometry if needed, but test moving entities against their simulated fields,
   not the physics server's current-frame transforms.

`kit/net` exposes edge halves for reliable replicated changes. `kit/sim` exposes
tick payloads and declared events so presentation can run once on the appropriate
clock without firing during resimulation.

## Authority is not the same as security

A server-authoritative model means the authority computes the final state. It
does not automatically make a game secure:

- A listen server is controlled by the hosting player. Use a dedicated authority
  when the host must not be able to alter outcomes.
- Input structures need semantic validators. Structural decoding alone cannot
  know that an axis is restricted to `-1`, `0`, or `1`.
- Commands need the correct generated access mode and game-specific predicate.
- Public sessions need an encrypted transport and application-specific traffic,
  moderation, logging, and deployment policies.

See [Session trust and admission](session.md#trust-and-admission) and
[Network profiles](profiles.md) for the concrete configuration and validation
attached to each trust model.

## Scale and validation status

The default co-op session cap is eight players. Unit tests cover lower-level
session behavior at 32 seats, while the shipped real-process examples exercise
smaller groups. Quickdraw and Speedball are duel-scale references. Treat those
examples as correctness demonstrations, not published capacity targets for a
production game.

Measure CPU time, bandwidth, reconciliation frequency, and engine cost using
your entity counts and network profile. `kit/ui` provides a netgraph, and the
[testing harness](testing.md) can inject latency, jitter, loss, and bandwidth
limits into multi-process scenarios.

## What Kit does not implement

Kit does not ship deterministic peer-to-peer lockstep. Lockstep can be a better
fit for a small deterministic simulation in which every participant must run
the same world and rollback the same inputs. It also requires cross-platform
determinism, has a different late-join model, and does not provide a trusted
referee by itself.

Kit's simulation lane instead gives one authority the final state. Client
prediction is allowed to be approximate because authoritative snapshots repair
divergence.

## Package compatibility

| Package | Use with the simulation lane |
| --- | --- |
| `comms`, `xfer`, `save`, `ui` | Session-level; use unchanged. |
| `items` | Inventory state normally remains on reliable deltas. Pure slot and packing helpers are usable anywhere replay-safe. |
| `interact` | Geometry helpers are replay-safe. Prompt and command examples are written for session replication. |
| `combat` | Its networked projectile and predicted-health flow targets session replication. Reuse pure geometry and policy helpers; implement sim combat with predicted fields, commands, and events. |
| `ai` | Perception and steering math can be reused. Run navigation and non-replayable decisions only in the authority pass. |
| `nav` | Do not call Godot navigation queries from a resimulated tick. Call them from authority-only logic and feed replayable results into the simulation. |
| `fx` | Presentation helpers are reusable. The tracer pool is the co-op projectile presentation path; sim projectiles are usually predicted entities. |

## Recommended reading order

1. [Session-replication quickstart](quickstart.md)
2. [Simulation quickstart](quickstart-sim.md)
3. [kit/sim reference](sim.md)
4. `examples/quickdraw` for predict-self and lag compensation
5. `examples/slopball` and `examples/speedball` as a side-by-side comparison
