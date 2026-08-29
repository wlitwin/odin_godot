# Server authority and client prediction

The [session-replication quickstart](quickstart.md) lets each client write its
own position. This guide moves that position to Kit's simulation lane: the
authority derives movement from validated inputs, while the owning client runs
the same fixed-tick code locally for immediate response.

The completed example is `examples/hello_sim`. Its session, lobby, entity
factory, spawn flow, chat, and reconnect behavior are the same concepts used by
`examples/hello_net`. The differences are limited to the state that needs server
authority.

## What changes

The conversion has five parts:

1. mark contested fields as predicted;
2. move their mutation to a fixed-tick proc;
3. sample and validate player input;
4. attach a `ksim.Lane`; and
5. remove the old frame-rate mutation.

## 1. Change the field's replication lane

In `Player`, replace the owner-stream tags on position:

```odin
// Session replication: the entity owner writes position.
x, y: f32 `gd:"owner,interp,wire=f16"`

// Simulation lane: the authority writes position and the owner predicts it.
x, y: f32 `gd:"predict,interp"`
```

`interp` still controls presentation. For the local player, it smooths
reconciliation error after authoritative snapshots arrive. For remote players,
it interpolates between authoritative snapshots on the watched timeline.

Fields that do not need rollback can remain on the reliable delta lane. The
example's `pid` field is unchanged:

```odin
pid: u8 `gd:"replicate"`
```

## 2. Move movement to a fixed tick

Declare the input that drives a player and the deterministic step that updates
predicted state:

```odin
@(gd_input)
Player_Input :: struct {
	move: [2]i8 `gd:"range=-1:1"`,
}

STEP :: f32(160.0 / 60.0)

@(gd_tick)
player_tick :: proc(self: ^Player, input: Player_Input) {
	self.x = clamp(self.x + f32(input.move[0]) * STEP, 8, 632)
	self.y = clamp(self.y + f32(input.move[1]) * STEP, 8, 352)
}
```

The authority runs this proc to produce truth. The owning client runs it for
prediction and may run it again during reconciliation. A tick proc therefore
must use predicted fields, its input, and values derived from the tick. Do not
read wall-clock time, input devices, scene-node transforms, or untracked random
state from it.

This example assumes the default 60 Hz simulation rate. If the lane's `hz`
changes, derive movement constants from the same configured rate.

## 3. Sample input

Device access belongs in one `@(gd_sample)` proc on the game script:

```odin
@(gd_sample)
hello_sample :: proc(self: ^HelloSim, tick: u64, input: ^Player_Input) {
	_ = tick
	input^ = {}
	if gd.is_action_pressed("ui_right") {input.move[0] += 1}
	if gd.is_action_pressed("ui_left")  {input.move[0] -= 1}
	if gd.is_action_pressed("ui_down")  {input.move[1] += 1}
	if gd.is_action_pressed("ui_up")    {input.move[1] -= 1}
}
```

`@(gd_input)` turns the struct's field tags into the validator. Kit clamps the
axis after local sampling and applies the same sanitizer to every received input
before changing the authority's de-jitter buffer. The tick therefore sees the
same legal values on both sides.

Available rules are `range=min:max`, `finite`, `unit` (a `[2]..[4]f32/f64`
vector whose magnitude is clamped to one), `enum`, and `mask=bits`. Rules are
part of the generated network fingerprint, so peers with different input
languages refuse the join instead of disagreeing during play.

For a predicate involving several fields or game state, keep the generated
rules and add `@(gd_sample = "validate")` plus
`<sample>_validate(self, input) -> bool`. The generated sanitizer runs first;
returning `false` then rejects the complete multi-class packet. Use
`validate=my_validator` to name the hook explicitly.

## 4. Attach the simulation lane

Add a lane beside the existing session components:

```odin
HelloSim :: struct {
	owner: gd.Node2d,
	ses:   ksess.Session,
	comms: kcomms.Comms,
	boot:  kboot.Boot,
	lane:  ksim.Lane,

	player_scene: ^gd.Resource `gd:"entity=Player:1"`,
	me: ^Player,
}
```

That conventional field layout makes the generated facade lane-aware. One call
from `_ready` attaches Boot, installs the entity factory, initializes the lane,
and gives it to Boot:

```odin
hello_sim_net_attach(self, kboot.Options{
	title = "HELLO, SERVER AUTHORITY",
	env = "HELLO",
}, kboot.network_profile(.Listen_Server_Action))
```

Under that call, `hello_sim_lane_init` is generated from the `@(gd_tick)` and
`@(gd_sample)` declarations. It registers the input type, validator, tick
thunks, descriptors, and optional world passes. `boot_lane` makes the network
pump drive simulation and presentation each frame.

The third argument configures the session and lane together. Override fields on
the materialized profile when the game's measured needs differ:

```odin
hello_sim_net_attach(
	self,
	kboot.Options{/* ... */},
	config,
)
```

where `config` was prepared as ordinary data:

```odin
config := kboot.network_profile(.Listen_Server_Action)
config.lane.smooth_cut = 48
config.lane.rewind_max = 30
```

The generated attach validates the full pair before starting. Start with a
named profile and tune from measurements; see [Network profiles](profiles.md)
and [Simulation tuning](sim.md#tuning).

## 5. Remove frame-rate movement

Delete the code that wrote the local player's position from `_process`.
The generated network pump now samples inputs, advances fixed ticks, reconciles
snapshots, writes presentation values, and forwards declared events before the
entity's `_process` displays them:

```odin
hello_sim_process :: proc(self: ^HelloSim, delta: f64) {
	if kboot.boot_phase(&self.boot) == .Menu {return}
	_ = hello_sim_net_pump(self, delta, knet.now_s())
}
```

Spawning and reliable state do not require a second code path. The generated
factory tracks `Player` entities on the lane because their descriptor contains
`predict` fields.

## Run the example

```sh
bash build/build_scripts.sh examples/hello_sim
$GODOT --path examples/hello_sim &
HELLO_LATENCY=120 $GODOT --path examples/hello_sim
```

Host in the first window and join in the second. In the joined window:

- the local square should respond immediately because it is predicted; and
- the host's square should move smoothly on the delayed watched timeline.

The automated two-process test checks both behaviors under injected latency:

```sh
bash examples/hello_sim/run.sh
```

## Run a dedicated authority

The example also exposes a headless server role:

```sh
HELLO_ROLE=serve $GODOT --headless --path examples/hello_sim
```

`boot_serve` creates a dedicated infrastructure seat. The seat does not receive
a player entity and does not participate in host succession. `hello_sim_ready`
selects `.Dedicated_Competitive` for this role, while ordinary Host uses
`.Listen_Server_Action`; the dedicated profile also verifies that every input
class has a semantic validator. A production
server still needs deployment, discovery, monitoring, restart, and abuse-control
infrastructure; Kit does not provide a server fleet or matchmaking service.

A listen server uses the same simulation code, but the hosting player controls
the authority process. That is convenient for invited sessions, not a fair
security boundary against the host.

## What the simulation lane does not solve

- Native ENet join codes provide discovery and limited UDP hole punching, not a
  general relay. Symmetric NAT still requires WebRTC with TURN or Steam.
- Prediction hides input latency; it does not make the authority's verdict
  instantaneous. Rejected or divergent actions still reconcile.
- Godot rigid-body physics cannot be replayed by Kit. Predicted physics must use
  query-based, tick-driven integration over data stored in the simulation.
- Public servers need an encrypted transport, semantic input validation,
  application-specific rate policy, and operational controls. See
  [Session trust and admission](session.md#trust-and-admission).

Continue with [kit/sim](sim.md) for discrete commands, predicted spawns,
contested objects, world passes, facts, lag compensation, and reconciliation
tuning.
