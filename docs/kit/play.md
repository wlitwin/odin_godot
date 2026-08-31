# `godot:play`: reusable gameplay blocks

`godot:play` contains small gameplay components and presentation helpers used by
the Kit examples. Networked blocks are embedded in an entity struct. Script
generation flattens their tagged fields into the entity descriptor and hoists
their commands onto the entity's generated command table.

The package provides policy and reusable state, not complete game features. A
weapon block can decide whether a trigger pull fires; the game still decides
what projectile to spawn, what it may hit, and how the result affects the world.

## Networked blocks

| Block | Replication model | Responsibility |
| --- | --- | --- |
| `play.Gun` | Reliable host state with an optimistic command | Magazine, reload, jam, and clear state. `Gun_Def` supplies configuration. |
| `play.Ability` | Reliable host state with an optimistic command | Cooldown-gated casts. The game supplies resource cost and effect policy. |
| `play.Channel` | Owner stream plus a host command | Hold progress and target for revive, capture, hack, or cast-bar interactions. The host must validate the final claim. |
| `play.Health` | Reliable host state | Hit points, maximum hit points, damage, heal, and death-transition helpers. It declares no player command. |
| `play.Telegraph` | Reliable host state | A tick-based wind-up and landing test for warnings, traps, and enemy attacks. |
| `play.Puppet` | Owner stream | A `RigidBody2D` simulated by one peer and displayed by all others. |
| `play.Puppet3` | Owner stream | The corresponding `RigidBody3D` block, including quaternion rotation and angular velocity. |

Example composition:

```odin
Runner :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	health: play.Health,
	weapon: play.Gun,
	lob:    play.Ability,
}
```

This contributes the blocks' replicated fields to `Runner` and generates
commands such as `runner_weapon_fire_cmd` and `runner_lob_cast_cmd`. See
[Composing commands from embedded blocks](net.md#composing-verbs-from-embedded-blocks)
for naming and override rules.

Use generated replicated-field edge halves for presentation:

```odin
@(gd_half)
runner_health_hp_edge :: proc(
	game: ^Game,
	self: ^Runner,
	old_hp, new_hp: i32,
) {
	if new_hp < old_hp {show_damage(game, self, old_hp - new_hp)}
	if old_hp > 0 && new_hp == 0 {show_death(game, self)}
}
```

Initial state and full resynchronization establish a baseline without replaying
historical edges.

Cross-entity consequences remain in game code. For example,
`runner_weapon_fire_then` checks `self.weapon.fired`, validates or leashes the
client-provided origin, and spawns the authoritative projectile. The block does
not know the entity's position or the rules of the target world.

## Simulation-lane blocks

Predicted blocks live in `godot:play/sim`, conventionally imported as `psim`:

| Block | Responsibility |
| --- | --- |
| `psim.Cool` | Replayable tick cooldown with `due`, `arm`, and `ready` helpers. |
| `psim.Mover` | Tick-driven 2D movement with acceleration and bounds. |
| `psim.Roller` | Self-integrating rolling body with friction, speed cap, and wall bounce. |

Their fields use `gd:"predict"` and their ticks compose with the embedding
entity's tick. Do not mix a root `play` network block and a `play/sim` block
without checking which replication lane its fields select. The complete
contract is in [Simulation blocks](sim.md#simulation-blocks-in-godotplaysim).

## Local helpers

The package also includes state and procedures that do not cross the wire:

| API | Use |
| --- | --- |
| `actions_install` | Idempotently install keyboard and mouse actions from `Key_Row` and `Mouse_Row` tables. |
| `decay`, `ramp`, `advance`, `hold`, `pulse`, `pulse01` | Small frame-animation helpers over `f32` values. |
| `show`, `follow`, `fill`, `depth` | Update simple 2D world markers. |
| `every`, `latch` | Frame cadence and rising-edge helpers. |
| `Pace(T)`, `Deadlines(K, T)` with `due`, `arm`, `ready` | Re-armable deadlines over a caller-selected clock. |
| `Edge(T)` with `see`, `sync` | Detect changes in derived or local state that has no generated replicated-field edge. |
| `Trail`, `trail_note`, `trail_read` | Authority-side position history for game-owned state. For streamed session entities, prefer `session_rewound`. |

`Edge(T)` is not needed for a directly replicated field. Use it for a value
derived from several fields or for local persistence state, and call `sync`
after a full resynchronization when that jump should become the new baseline.

`Pace` stores a deadline. It is suitable for authority scratch or local
presentation cadence; simulation-lane cooldowns should use `psim.Cool` so their
state participates in replay.

## Owner-simulated physics with `play.Puppet`

Godot's rigid-body solver cannot be rewound by Kit. A `Puppet` instead assigns
one peer to simulate a shared `RigidBody2D`. That peer publishes pose and
velocity through owner-streamed fields. Every other peer freezes the body in
kinematic mode and moves it along the interpolated stream.

This model is useful for a co-op ball, crate, vehicle, or physics prop when one
simulator at a time is acceptable. It is not server-authoritative rollback
physics: contacts are decided on the current owner's machine, and remote views
are delayed by interpolation.

### Declare and attach the block

```odin
Ball :: struct {
	owner:  gd.Rigid_Body2d,
	net_id: knet.Net_Id,
	puppet: play.Puppet,
}

ball_ready :: proc(self: ^Ball) {
	play.puppet_attach(&self.puppet, self.owner, 0, 0)
}

ball_process :: proc(self: ^Ball, delta: f64) {
	play.puppet_frame(&self.puppet, f32(delta))
}
```

Pass an optional visual child to `puppet_attach` when you want render-error
smoothing. The rigid body moves immediately to authoritative state, while the
visual child decays a small correction over time.

### Initialize received state

Call `puppet_born` from the typed born hook after spawn fields have arrived, then
select whether this peer currently owns the body:

```odin
@(gd_half)
ball_born :: proc(
	game: ^Game,
	self: ^Ball,
	id: knet.Net_Id,
	owner: knet.Player_Id,
) {
	_ = id
	play.puppet_born(&self.puppet)
	play.puppet_seat(&self.puppet, owner == game.ses.me)
}
```

`puppet_born` places the physics body from its replicated fields during the
spawn frame. This avoids displaying the scene's default transform before its
first `_process` callback.

When `Ev_Owner_Changed` names this entity, call `puppet_seat` with whether the
new owner is the local player. The new simulator is seeded from streamed pose
and velocity so momentum crosses the handoff. Remote peers cut to the new
ownership baseline before continuing interpolation.

### Transfer and predict ownership

The authority changes ownership with `session_set_owner`. The game decides the
policy: last toucher, current carrier, current driver, or a permanent host
owner.

`puppet_claim` allows a client to begin simulating provisionally while it waits
for an ownership command. If the authority grants ownership, the provisional
flight continues. If the claim is denied or times out, the body freezes and the
visual correction returns it to the actual owner's stream. Treat the claim as
presentation prediction, not authority.

`puppet_place` performs a reset or teleport. Pair it with the entity kind's
generated teleport door—such as `ball_teleport(&game.boot, ball)`—so remote
interpolation cuts instead of blending through the discontinuity.
`puppet_shove` applies an impulse on the current simulator.

## `play.Puppet3`

`Puppet3` applies the same ownership model to `RigidBody3D`. It streams position,
quaternion rotation, linear velocity, and angular velocity. Its procedures use
the `puppet3_*` prefix.

See `examples/slopball` for the 2D integration and `examples/slopball3d` for the
3D version. For state that must be simulated by a trusted authority and replayed
on clients, use query-based integration with [kit/sim](sim.md) instead of a
Godot rigid body.
