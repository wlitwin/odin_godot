# `kit/sim`: server-authoritative fixed-tick simulation

Use `kit/sim` for movement, aiming, projectiles, or shared objects whose state
must be computed by a trusted authority. Its simulation lane advances gameplay
at a fixed tick rate and retains input and state history for prediction and
correction. Clients send windows of tick-stamped inputs. The authority computes
the accepted state and sends snapshots; each owning client predicts its entities
locally and corrects its prediction when a snapshot differs.

Reliable session state such as inventory, score, chat, entity lifetime, and
saves remains on `kit/session` and `kit/net`.

The package does not import Godot. Its input, snapshot, history,
reconciliation, and lag-compensation paths run in headless tests under
`tests/kitsim`.

<a id="the-mental-model"></a>

## Replication lanes and replay

A field tag selects one of three disjoint replication lanes:

| tag | authority | wire | applied by |
| --- | --- | --- | --- |
| `replicate` | host | reliable deltas | on arrival |
| `owner` | owning peer | unreliable stream | interpolated in the past |
| `predict` | authority simulation | tick-stamped snapshots | prediction, reconciliation, and resimulation |

Identity, roster, reconnects, spawns, blobs, stats, chat, and reliable commands
remain session features. The [quickstart](quickstart.md) introduces the coop
model; the [sim quickstart](quickstart-sim.md) shows how to add simulation to
that setup. Select the simulation lane per field for fast state such as
movement and projectiles that the authority must compute. A field's lane is
the tag's first token, so each field uses exactly one lane. Choose either
`owner` or `predict`; they cannot be combined.

Simulation-lane gameplay runs in a fixed-rate step proc (60 Hz by default).
The proc derives predicted fields from their previous values, the current
input, and replayable tick data. The authority runs it for final state. The
owning client runs it ahead for immediate control response.

When authoritative state for tick T arrives, the client compares it with its
recorded prediction. If they differ, the client restores authority at T and
replays later ticks from its input history. Bit-exact cross-machine determinism
is not required because authority remains final, but replayed code must be
stable enough to avoid constant correction.

Step procs may read predicted state, declared inputs, `lane_input`, and values
derived from the tick. They must not read wall clocks, device state, current
scene-node transforms, or untracked randomness.

Input packets include a configurable window of recent samples, and newer
snapshot batches supersede older ones. If a loss burst exceeds the redundancy
window, the authority temporarily holds the player's last accepted input. The
client later reconciles to the resulting authority state.

## Defining a sim entity

Tag the entity's simulated fields with `predict` and mark its tick procedure
with `@(gd_tick)`. Script generation discovers the input struct from that
procedure's signature. Return values carry tick events to two optional
procedures paired by name: `<tick>_then` handles authority consequences and
`<tick>_fx` handles presentation. The generated thunk, which adapts the typed
procedure to the lane's raw-pointer callback, checks which role and simulation
pass may call each half.

Here `Runner` is the game's character type. Its `owner` field holds the Godot
node; the network entity owner is the player whose input drives it.

```odin
Runner :: struct {
	owner:   gd.Node2d,
	net_id:  knet.Net_Id,
	x, y:    f32 `gd:"predict,interp"`,
	vx, vy:  f32 `gd:"predict"`,
	fire_cd: u16 `gd:"predict"`, // cooldown state participates in prediction
	hp:      i32 `gd:"replicate"`, // reliable state updated independently of simulation replay
}

Runner_Input :: struct { // no tag — discovered from the tick proc's signature
	move:    [2]i8,
	buttons: u8,
}

@(gd_tick)
runner_tick :: proc(self: ^Runner, input: Runner_Input) -> (fired: bool) {
	self.vx = f32(input.move[0]) * SPEED // advance using the fixed tick interval
	self.x += self.vx
	if self.fire_cd > 0 {self.fire_cd -= 1}
	if input.buttons & FIRE != 0 && self.fire_cd == 0 {
		self.fire_cd = COOLDOWN
		fired = true // an event trigger, not a verdict — ticks can't reject
	}
	return
}

// Authority only; not called during resimulation.
@(gd_half)
runner_tick_then :: proc(g: ^Game, self: ^Runner, by: knet.Player_Id, fired: bool) {
	if fired { adjudicate_shot(g, self, by) } // lane_rewound lives here
}

// The owning player's live pass only; not called during resimulation.
@(gd_half)
runner_tick_fx :: proc(g: ^Game, self: ^Runner, fired: bool) {
	if fired { muzzle_flash(self) } // local feedback before the authority reply
}
```

Script generation emits the raw-pointer thunk, role and resimulation checks,
`runner_sim_set`, and recursive input-layout checks. Those checks compare the
canonical ABI with the target layout and reject platform-sensitive or padded
inputs. Generation also rejects invalid halves and a tick procedure whose
entity has no `predict` fields.

Supported tick signatures are `(self)`, `(self, input)`, `(self, lane)`, and
`(self, input, lane)`: a pointer parameter is the lane, and a value parameter
is the input. Both halves also accept signatures that omit the game parameter
and start with `self`.

### Presenting a tick payload on every screen

The `_fx` above runs only for the acting player's live pass. To present the
same occurrence on every screen, add `mine: bool` immediately after `self` (the
parameter name is significant):

```odin
@(gd_half)
runner_tick_fx :: proc(g: ^Game, self: ^Runner, mine: bool, fired: bool) {
	if fired {
		muzzle_flash(self)        // every screen
		if mine {kick_camera(g)}  // feedback for the local player
	}
}
```

- The actor presents it immediately with `mine = true`. Resimulation
  does not present it again.
- The authority presents payload events from other actors as they execute, with
  `mine = false`.
- Other clients receive the internal reliable `SIM_FACT` frame and present it
  when their watch clock reaches the event's tick. This keeps an effect aligned
  with the delayed entity that caused it. Occurrences are counted individually, so a batch cannot
  collapse two occurrences into one.

The actor skips the returned event because its own live pass is expected to
have presented it already. Packet loss can break that assumption: the authority
may hold the actor's previous input and produce an event that the actor's fresh
input did not produce. The actor then misses that effect. Tick payload events
are cosmetic one-shots and may be lost this way. If the actor must receive the
event even when its input is lost, produce it in an authority world pass
(`@(gd_step="authority")`). Events produced there include the entity owner
among their recipients.

### Events produced by a world pass

Use `@(gd_event)` for a presentation event discovered outside a single
entity's tick, such as contact between a player and a ball. An anchor is an
entity parameter that selects the event's presentation timeline and owner.
When that entity is tracked by the simulation lane, the event uses the lane's
watch clock, which follows received state at a delay:

```odin
// The presentation proc you write. `k` is the only entity, so it is the anchor.
@(gd_event = "audience=everyone,timing=auto")
ball_kicked_fx :: proc(g: ^Game, k: ^Kicker, mine: bool, bvx, bvy: f32) {
	kick_sound(bvx, bvy)            // scheduled on the event's display clock
	if mine {kick_camera(g)}        // feedback for the local player
}

// Scriptgen generates this helper. Call it where the sim discovers the event:
if kicked {
	ball_kicked(&g.boot, k, b.roll.vx, b.roll.vy)
}
```

The generated helper applies the same live-pass, authority, watcher, and
resimulation rules as a tick payload event. The anchor's network entity owner
determines `mine`. The anchor names a particular procedure parameter: if a game
has hundreds of `Enemy` instances, `anchor=enemy` selects the `enemy` pointer
passed to this call.

Select an anchor according to the event's parameters:

- No entity parameters means a world event. In a lane-owning game, `timing=auto`
  selects the watch clock and the authority is its local producer.
- One entity parameter is the inferred anchor.
- With two or more entity parameters, name one parameter explicitly, such as
  `@(gd_event="anchor=target,timing=auto")`.
- Use `anchor=none` only when the authority/world clock is intentional despite
  carrying entity references.

Put all typed entity parameters between the game and `mine`. They must be
lane-tracked script classes. The anchor travels in the internal event header; every other
entity reference travels as a `Net_Id` and is resolved to that peer's local
pointer before presentation. Arguments after `mine` must be wire primitives.
Scriptgen rejects ambiguous anchors, names that are not entity parameters, and
untracked entity types at build time.

Announce an anchored event before untracking or despawning its anchor. The
generated helper rejects events whose anchor no longer exists, so no peer
presents them. A predicted event that the authority never confirms may still
appear locally. Speedball's kick is the worked example. Declare presentation
events for either session or simulation clocks with `@(gd_event)` and call
them through the generated helper that accepts `^Boot`.

For a local diagnostic such as a debug print in a tick body, gate on
`ksim.lane_live(&lane)` to skip resimulation. Do not read `lane.resimming`
directly.

For a `mine`-form tick event, at least one returned value must be `bool`; the
half runs on ticks where any boolean payload is true. All returned payloads
must be wire primitives. Scriptgen reports either violation at build time. Use a plain
owner-only `_fx` (without `mine`) for continuous local presentation such as an
engine hum, or for an effect that should not appear on every screen.

The game declares input sampling and world passes with typed procedures and
attributes too. `@(gd_sample)` marks the procedure that reads hardware; it is
never called during resimulation. Scriptgen checks its input struct against
the tick's input type at build time and rejects a mismatch.

Declare field-level input validation on the input struct:

```odin
Move_Mode :: enum u8 {On_Foot, Driving}

@(gd_input)
Runner_Input :: struct {
	aim:     [2]f32 `gd:"unit"`,
	trigger: f32    `gd:"finite,range=0:1"`,
	move:    [2]i8  `gd:"range=-1:1"`,
	mode:    Move_Mode `gd:"enum"`,
	buttons: u8     `gd:"mask=0x07"`,
}
```

`range` clamps each scalar/array component. `unit` rejects non-finite vector
components and scales only magnitudes above one, preserving analog strength.
`finite`, `enum`, and `mask` reject values that have no legal authored meaning.
The generated sanitizer runs after local sampling and transactionally over
every received window before any authority buffer changes.

Each received input window must fit its size and redundancy limits. Across
windows, a seat may send at most 16 input classes in a 32 KiB `SIM_INPUT`
payload. Generated and hand-built lanes assert these aggregate limits at
registration. The authority rejects an oversized packet before creating
per-class buffers.

For cross-field or game-state rules, add `@(gd_sample="validate")` and the typed
`<sample>_validate(self, input) -> bool` hook (or name one with
`validate=PROC`). It runs after the generated field rules; returning false
rejects the complete multi-class packet.
`@(gd_step)` is the world pass, run after entity ticks. A game may declare one
of each kind: a bare `@(gd_step)` runs on every peer, including resimulation,
while `@(gd_step="authority")` runs once per real tick on the authority. Keep
the two procedures separate so the generator can apply the execution policy:

```odin
@(gd_sample = "validate")
game_sample :: proc(self: ^Game, tick: u64, input: ^Runner_Input) {
	input.move = quantize_axes()
	input.buttons = read_buttons()
}

game_sample_validate :: proc(self: ^Game, input: ^Runner_Input) -> bool {
	// Field ranges/masks are already canonical here. Keep only relationships
	// that cannot be expressed one field at a time.
	return input.trigger == 0 || input.buttons & BTN_FIRE != 0
}

@(gd_step) // everywhere, live + resim: contact for the pairs this peer simulates
game_contact :: proc(self: ^Game, tick: u64) {
	resolve_overlaps(self)
}

@(gd_step = "authority") // host alone: adjudication, respawns, the match clock
game_step :: proc(self: ^Game, tick: u64) {
	run_respawns(self, tick)
}
```

(The `tick: u64` param is optional in both slots; a pass that doesn't read
the clock declares `proc(self: ^Game)`.)

### Using an authority step without a simulation lane

A package with no `@(gd_tick)` classes has no simulation lane. In that case,
`@(gd_step = "authority")` uses the boot accumulator: scriptgen generates
`<snake>_step(self, ticks)` with the authority check, fixed-step loop, and
[same-frame edge pass](net.md#field-change-edges), called from
`<game>_net_frame`. Cavecrawl's `cave_host_tick` demonstrates this setup.
The coop loop has no absolute tick, so declare `proc(self)` and count ticks
in a `gd:"backup"` field if needed. Adding a simulation lane changes the
generated routing without changing the attribute.

For a game root with one Boot, Session, Comms, and Lane field, the generated
game-network facade connects these components. Pass a named network profile
when attaching, then override lane settings when measurements call for it:

```odin
// ready(): Boot + entities + lane in one generated call
cfg := kboot.network_profile(.Listen_Server_Action)
cfg.lane.smooth_cut = 48
game_net_attach(self, kboot.Options{/* ... */}, cfg)
```

The generated `<class>_lane_init` supplies the input size, typed procedures,
and world-pass callbacks; `boot_lane` connects the lane to Boot. Both are
public for custom game roots. The generated entity table includes each ticking
class's `Sim_Set`, allowing the factory to track and untrack its entities on
the lane. `<game>_net_frame` calls `boot_pump`, which runs `lane_frame` and
`lane_present` every frame and forwards `Ev_Owner_Changed`.

Entity thunks run in track order on every simulated tick, including replay,
using each entity owner's input. A `nil` input leaves the entity coasting;
this applies to inputless types and to remote entities whose state a client
receives from the authority. After entity ticks, the optional everywhere world
pass handles replayable cross-entity work such as contact. The authority world
pass handles accepted world outcomes such as respawns and wave scheduling.

An input class groups entities by the distinct input struct in their
`@(gd_tick)` signatures. `lane_init` registers the primary class (class 0),
and `lane_add_input_class` registers each additional class. Each packet carries
one window per class; see [Two entity kinds, two inputs](#two-entity-kinds-two-inputs).
Two entities of the same kind driven by one player share a window, so compose
their intent into one struct.

Inputs cross the wire as a memory copy of the struct, with no per-field wire
encoding. To quantize an input, declare its quantized type. Quickdraw's aim
uses a `u16` turn fraction with ~0.005° resolution, encoded when sampling and
decoded in the tick. A world pass that reads inputs uses the typed view:

```odin
input, drives := ksim.lane_input_of(&g.lane, owner, Kicker_Input)
if !drives {continue} // a pair this peer doesn't simulate
```

Tests and games without generated code can call the same procedures directly:
`lane_init`, `lane_set_sim` with a rawptr sample callback and two `Step_Proc`s
(everywhere, then authority), `lane_track` / `lane_track_set`, and explicit
`lane_frame`/`lane_present` calls. In this setup, `lane_present` is optional.
Until its first call, the `presented` latch allows received snapshots to update
watched fields directly. After that call, presentation updates those fields.
A client that omits `lane_present` therefore continues to show received state.

Reinitializing a session does not reset lane state. The app route survives,
but the tick anchor and state ledgers remain tied to the previous authority.
Call `lane_destroy` then `lane_init` to reset them. Destruction zeroes the lane;
calling `lane_init` on a live lane asserts.

## Simulation blocks in `godot:play/sim`

Embed a `godot:play/sim` block to add reusable simulated behavior to an entity.
Scriptgen includes the block's `gd:"predict"` fields in the entity's replication
descriptor and calls the block's `@(gd_tick)` after the entity's own tick.
The entity can therefore write movement intent before the block integrates it.
The import alias is `psim`:

```odin
import psim "godot:play/sim"

Kicker :: struct {
	...
	run:  psim.Mover, // momentum movement: the tick writes run.tx/ty, the block integrates
	kick: psim.Cool,  // predicted cooldown: psim.ready(&k.kick, KICK_CD) gates and re-arms
}
```

- `psim.Cool` implements a predicted cooldown with `due` / `arm` / `ready`,
  the same operations as `play.Pace`. Pace stores a deadline against a clock
  supplied by the caller; it is host-local state and is never sent. Cool counts
  down within the simulation, so the client can predict a revolver's firing
  cadence or a kick's recovery and reproduce it during replay.
- `psim.Mover` implements momentum-based 2D movement. The entity's tick writes
  its target velocity, and the block approaches that velocity. Set `accel = 1`
  to reach it immediately. Configuration such as acceleration and bounds uses
  plain, untagged fields. Set it at spawn on every peer; it is not replicated.
- `psim.Roller` integrates a shared rolling body's motion with friction, a hard
  speed ceiling, and wall bounces that reduce speed. The game implements
  gameplay outcomes. Speedball detects goals from the roller's position clamp:
  a crossing places the ball exactly on the line for one tick, allowing the
  ball's tick to detect the goal and predict its reset.

**Driving a block yourself: `gd:"manual"`.** By default, a block's tick runs
after its containing entity's tick. Call it manually when the entity must use
the integrated result immediately, such as resolving a crate overlap after
movement, or must skip integration, such as freezing a dead avatar's cooldown.
Tag the embedded field `gd:"manual"` to suppress the generated tick call,
then call the block's tick at the required point:

```odin
fire: psim.Cool `gd:"manual"`, // tick explicitly in the parent procedure

@(gd_tick)
gunner_tick :: proc(self: ^Gunner, in: Gunner_Input) -> (fired: bool) {
	if self.hp <= 0 {return} // leave the cooldown unchanged while dead
	if in.buttons & FIRE != 0 && psim.ready(&self.fire, FIRE_CD) {fired = true}
	psim.cool_tick(&self.fire) // driven here, on the alive path
}
```

The block's predicted fields remain in the descriptor and on the wire;
`manual` suppresses only the generated call. The entity can call the block
conditionally, change its ordering, or skip it. An untagged embedded field
retains the default ordering. Quickdraw's revolver freezes its cooldown while
dead by skipping that call.

Scriptgen checks blocks in the SDK's two packages. A block in `godot:play`
with predicted fields produces an error directing it to `play/sim`; a
`play/sim` block with no predicted fields produces the reverse error. These
checks do not restrict game-local blocks. They ensure that SDK blocks imported
with the `psim.` prefix contain state that participates in resimulation.

<a id="what-the-lane-does-underneath"></a>

## Lane timing, snapshots, and presentation

- **Anchoring.** A client waits to tick or send input until its first snapshot
  batch establishes the server's tick. It adopts that state and starts a couple
  of ticks ahead. Afterward, a ±2% timescale adjustment grows or shrinks the
  lead toward the target input headroom, using the batch header's input-ack
  echo. This needs no separate clock synchronization or tick jumps.
- **Snapshots use an acknowledged baseline.** The server computes deltas for
  each entity's predicted fields against the newest batch the client confirmed
  applying in full. A client acknowledges a batch only after every row applies.
  An unknown entity id, such as a spawn still in transit, is skipped by row
  length and prevents the acknowledgement from advancing. A missing baseline
  causes a per-entity full row, without a keyframe-request message.
- **Predict-self.** The client records its own entities in state-history
  ledgers and reconciles them. It watches other entities: received state updates
  them, and `lane_present` renders them on a delayed watch clock by blending
  between batches per field. This uses `Lerp_Kind`, as streams do, with the same
  clamp-and-hold rule: it never extrapolates.
- **Correction smoothing.** Reconciliation immediately sets simulation state
  to authority state and records it in the ledger. For float `interp` fields,
  `lane_present` adds a decaying render error with a 63 ms half-life, the same
  constant used by the puppet. This smooths the displayed correction. If the
  error exceeds a nonzero `smooth_cut`, it is cleared and the corrected pose appears
  immediately. Fields contain simulation values during `lane_frame` and
  presentation values after `lane_present`. Before ticking again, the lane
  restores simulation values from the ledger, so the game can continue copying
  fields to nodes after presentation.
- **Game callbacks run in the frame call.** Packet handlers store received
  bytes. The lane calls game code from `lane_frame` on the caller's stack.
- **Possession.** Forward the session's `Ev_Owner_Changed` to
  `lane_set_owner(l, id, player)` on every peer. The authority changes which
  player's input buffer drives the entity and which player's rewound queries
  exclude it. A client changes the entity between predicted and watched state,
  seeding a new prediction ledger from the freshest received state.

<a id="the-contested-object"></a>

## Predicting contested objects

With predict-self, a client watches shared fast objects such as a ball, crown,
or flag. They render in the past, and a local interaction waits for the round
trip to the authority. Mark an entity `@(gd_tick = "contested")` to have every
peer predict it. Local contact can then take effect on the client's predicted
timeline. The server still decides the accepted state. If an opponent touched
the object first on the server, the client reconciles its prediction and
smooths the displayed correction.

Contested prediction adds resimulation work on every peer and can produce
corrections when peers disagree about contact. Keep authority consequences in
`_then` so replay cannot apply them twice. Put predicted resets in the tick
itself: Speedball's ball detects a goal and handles the kickoff freeze in its
own tick, allowing each screen to reset the ball as soon as its simulation
crosses the line. The authority updates the score. Handle contact in the world
pass only for pairs whose inputs this peer has: the local player's pairs on a
client and every player's pairs on the server. A remote touch then arrives as
an authority result.

Constraints for contested prediction:

- **Contested entities must simulate their own motion.** A ball can integrate
  velocity between snapshots on every peer. An input-driven avatar without
  remote input would instead remain stationary on a client and repeatedly
  require correction.
- **Presentation follows a claim.** A claim selects the displayed pose; it
  does not grant authority over gameplay. Call `lane_claim(l, id)` each tick
  that local simulation influences the contested entity, such as during contact
  in the world pass. The entity then displays its predicted pose. Without a
  claim, it displays the watched pose, aligning a remote touch with the delayed
  avatar that caused it. Otherwise the screen would show a predicted ball
  reacting before the remote avatar reached it. Claim weight rises immediately
  and decays over ~a quarter second. This is the continuous form of net.md's
  test for whether local simulation caused the change.
- **Predict-world also predicts remote avatars.** Enable
  `Lane_Config.echo_inputs` and mark the avatars `contested` too. Batches echo
  every player's held input, allowing every peer to tick every entity and
  extrapolate remote inputs from the held values. Speedball uses this model.
  The scene shares one predicted timeline, and contested entities display their
  predicted poses without claims. Remote contacts appear beside the avatars
  making them immediately. Held inputs often differ from the next received
  inputs, so this model adds resimulation on nearly every batch, frequent small
  smoothed corrections on remote avatars, and a few echo bytes per player per
  batch. Choose it for contact-driven games. Predict-self with lag compensation
  suits games that need accurate rendered targets: Quickdraw watches targets
  without extrapolating them. The remaining claim rules apply when clients
  predict only the shared object.
- **Keep a claim while its cause persists.** After a kick, continue claiming
  while the ball moves quickly because of that touch. Release when it slows,
  when the predicted and watched timelines nearly coincide, or when an opponent
  contests it. Releasing merely because the ball is far away blends toward the
  watched pose, which trails a fast ball by speed × timeline skew. That blend
  can pull the ball backward during its flight. The `sp_step` claim block in
  `examples/claimball` demonstrates holding while fast and releasing when slow.

Compare the three soccer examples when choosing a model:
`examples/slopball` uses coop peer authority, `examples/speedball` uses
predict-world with echoed avatar inputs and no claims, and `examples/claimball`
uses predict-self with presentation claims on the contested ball. In `claimball`,
every screen predicts the ball; a local claim selects its predicted pose for
display. The onboarding's
[competitive turn](../onboarding/07-the-competitive-turn.md) compares the same
three models.

## Lag compensation

```odin
// Judge the shooter's hitscan on the authority, in _then or a world pass.
judged_at := ksim.lane_rewound_begin(&g.lane, shooter)
g.hit = trace_shot(g) // Other entities use the shooter’s historical view;
                      // the shooter’s own state remains live.
ksim.lane_rewound_end(&g.lane)
```

Write the hit test between the begin and end calls. This avoids passing a
context struct through a rawptr callback. The calls must not nest, and no code
may track or untrack entities between them. For tests or table-driven weapons,
`lane_rewound(l, shooter, user, query)` provides the same query through a
callback.

Rewind changes only the predicted fields of tracked entities other than the
shooter's own. Delta-lane fields such as hp, scores, and gear, untracked
entities, and game-side maps retain their current values. Quickdraw tests a
rewound pose but applies damage to current hp, so a player already dead cannot
absorb a new bullet. If a hit predicate needs the target's shield state at the
time the shooter saw it, that state must be in the predicted fields too.
Otherwise the predicate combines a past pose with the current shield state.

Each input packet carries the sender's snapshot acknowledgement and render
offset; the input buffer records both alongside each input. Before judging a
shot, the server verifies that its acknowledgement names a recent batch issued
to that seat and has not regressed. The client still only claims to have applied
the batch: a valid replication baseline does not prove what it displayed.

The authority limits credible acknowledgement age to
`ceil((observed RTT + 2·jitter) / tick_dt) + margin + snap_every` and limits the
reported render offset to its configured `watch_delay + snap_every`. The extra
snapshot cadence allows normal interpolation around the watch target without
accepting a client-reported stall. The sum, capped again by `rewind_max`, is
the seat's current competitive rewind envelope: the maximum credible rewind
age in ticks. `lane_rewind_envelope(l, shooter)` exposes it. Until the authority
has a pong sample for the seat, this limit is zero and queries use current state.

Within that limit, rewind uses `predict_blend` over the state ledger to
reconstruct the pair of snapshots the shooter reports blending. Using the
freshest acknowledgement instead would advance the view by the client's lead
plus transit time between sampling and adjudication. Using a single tick would
lose the interpolation needed for near-tangent shots. Quickdraw's duel
acceptance test measures this behavior: most aimable shots land at 240 ms RTT.

`rewind_max` (default ~250 ms) remains the absolute limit on how far the
server favors the shooter's past view. An older issued acknowledgement, a
reported render-clock stall, or an inflated field cannot grant the full window;
the measured connection and configured limits bound the reconstructed view.
Rewind can still let a shot hit someone just after they reach cover. A snapshot
acknowledgement cannot prove which frame the player actually saw, so the render
offset remains a bounded hint.

<a id="discrete-verbs-on-the-lane"></a>

## Scheduling and replaying commands

A Kit command requests a discrete action with arguments. Its predicate may
reject the request; an accepted request executes once. On a ticking class,
`@(gd_command)` uses the same declaration as the coop model: validate and mutate
the target, then handle accepted authority consequences in the paired `_then`
procedure. The simulation lane schedules the command within its tick pipeline:

```odin
@(gd_command = knet.ACTION_OWNER_PREDICTED)
gunner_buy :: proc(self: ^Gunner, item: u8) -> bool {
	if self.gold < price_of(item) {return false}
	self.gold -= price_of(item) // delta lane: reverted on rejection
	self.gear = item            // predicted: replayed by every resim
	return true
}

// Issue through the Boot wrapper from an input handler or bot.
// The wrapper returns the same knet.Action_Outcome type as a cooperative command.
outcome := gunner_buy_cmd(&g.boot, g.me_gun, ITEM_BOOTS)
if outcome.reason == .Rate {show_slow_down_feedback()}
```

The generated wrapper schedules the command at the client's next tick and
sends it reliably with that tick stamp. The client's simulation lead gives it
time to arrive before the server reaches the tick. If it arrives late, the
server executes it at its next tick without rewriting history.

The client executes the command once at its scheduled tick. Resimulation
reapplies its recorded predicted-field writes, avoiding a second predicate
check against gold the command already spent. On the server, commands run after
entity thunks and before the world pass. A rejection immediately unwinds the
speculative delta-lane writes; the next reconciliation removes speculative
predicted-field changes and smooths the displayed correction.

Every verb declares the same typed policy as the co-op lane. Bare
`@(gd_command)` is owner-only and non-predicted;
`knet.ACTION_OWNER_PREDICTED` opts into owner speculation,
`knet.ACTION_ANY_SEAT` opens a world interaction, and
`knet.ACTION_AUTHORITY` never crosses client ingress. Prediction requires both
an optimistic action policy and a prediction ledger: marking an entity
contested does not silently predict every verb, and choosing a predicted policy
does not make a watched entity predictable. Two commands scheduled for the
same tick run in execution order; each predicate decides whether its request
still applies, as when two players try to spike the same ball. Commands queue
per entity. A rejection unwinds delta-lane speculation in order while preserving
the effects of surviving commands. The wrapper returns the same `Action_Outcome`
as co-op: `.state` says whether the request was scheduled, `.reason` names a
local access/rate/malformed/stale refusal, `.seq` correlates the final callback,
and `.model` is `.Scheduled`.

The authority verdict reaches the ordinary generated session callbacks. A
client's `<game>_command_rejected` half receives the addressed command and an
`Action_Reject_Reason`; the host's `<game>_command_executed` half receives the
same reason for diagnostics. Predicate failure and timeout are therefore
distinct without a lane-specific event API. Scheduled timeouts use an
independent lane-frame clock, so authority loss still expires actions when the
simulation clock itself has stopped waiting for snapshots.

If the predicate needs the issuer's identity, declare `by: knet.Player_Id`
immediately after the receiver. During client speculation, the lane supplies
the local seat; on the authority it supplies the recorded issuer, the same
value passed to `_then`. This value is never sent as a command argument, so a
client cannot choose another issuer when interacting with a contested entity.
The name is reserved: a wire argument called `by` is a build error.

Replay normally reapplies a command's recorded bytes, so prefer absolute
mutations such as `gear = item`. For relative effects such as an impulse or
knockback, declare `<verb>_apply(self, <wire args>)` to implement the
predicted-field mutation. Resimulation reruns this `_apply` half with the
recorded arguments against corrected state. An additive impulse then applies
to the corrected velocity rather than restoring the old resulting velocity.
When an `_apply` half exists, the main command must not write predicted fields;
its predicate and delta-lane writes still execute once.

```odin
@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
ball_spike :: proc(self: ^Ball, px, py: f32) -> bool {
	return self.hold == 0 && in_reach(self, px, py) // verdict + (any) delta writes
}
@(gd_half)
ball_spike_apply :: proc(self: ^Ball, px, py: f32) {
	self.vx += ... // relative mutation, recomputed on each resimulation
}
```

## Predicted spawns — a fired projectile

To show a projectile immediately when the player fires, create a local
predicted entity before the authority's spawn arrives. It simulates its flight
locally and records history for correction. When the authority announces the
projectile, the factory assigns its authoritative id to the existing local
entity instead of creating a second bullet.

Declare the projectile as an inputless `@(gd_tick)` entity that integrates its
own motion, with an `entity=Bullet:id` scene. The authority spawns it in the
firing tick's `_then` half. The `_fx` half creates the local prediction only
when `mine` is true and this peer is not the authority. This check prevents a
hosting player, whose `_then` already created the bullet, from spawning it twice.
Both halves call the same helper:

```odin
@(gd_tick) // the flight: pure predicted state, `landed` routes to the splash
bullet_tick :: proc(self: ^Bullet) -> (landed: bool) { ...self.x += self.vx... }

@(gd_half)
gunner_tick_then :: proc(g: ^Game, self: ^Gunner, by: knet.Player_Id, lobbed: bool) {
	if lobbed { lob_bullet(g, self, by) } // AUTHORITY: the real spawn
}
@(gd_half)
gunner_tick_fx :: proc(g: ^Game, self: ^Gunner, mine: bool, lobbed: bool) {
	// The hosting player's authority callback already spawned the bullet.
	// Predict a local bullet only on a non-authority owner client.
	if lobbed && mine && !ksim.lane_is_authority(&g.lane) {
		lob_bullet(g, self, g.ses.me)
	}
}

lob_bullet :: proc(g: ^Game, gun: ^Gunner, owner: knet.Player_Id) {
	b, bid := bullet_spawn(&g.boot, owner) // allocate through the shared authority/prediction helper
	b.x, b.y, b.vx, b.vy, b.life = ... // the muzzle and the arc
	kboot.boot_spawn_send(&g.boot, bid) // host announces; client no-ops
}
```

Scriptgen generates `bullet_spawn` for the `entity=` declaration. For a ticking
entity it calls `kboot.boot_fire_spawn`, which creates an authoritative network
id through `session_spawn_make` on the authority and a local predicted node
under a provisional id on the client.

Born-tick gating prevents a correction for a tick before the local spawn from
restarting its flight from stale state. Such corrections can arrive throughout
the first round trip while the server runs behind the client's prediction.
When the authority's `Ev_Spawned` arrives, the factory matches it to the local
projectile and replaces its provisional id. The node and flight ledger remain
intact for later reconciliation. If the authority refuses the fire or never
spawns the projectile, the local prediction is culled and its node freed.
Splash damage is judged against current server state without rewind, because
a slow projectile is intended to be dodged.

The right-click lob in `examples/quickdraw` demonstrates this behavior. Its
native acceptance test creates the predicted bullet on the client's own tick
without waiting for a round trip.

## Two entity kinds, two inputs

One player can drive two entity kinds on the same tick, such as an avatar and
a vehicle or a duelist and a companion drone. Each kind declares its own
`@(gd_tick)` input struct, forming a separate input class. The client samples
each class once per tick and sends one window per class in a single upstream
packet. The host buffers each player's classes separately to absorb arrival
jitter. Each entity tick reads its own class, and reconciliation of one entity
leaves the other entity's state intact.

Declare a second `@(gd_sample)`, one per input type:

```odin
// two ticking kinds, two input structs
@(gd_tick) gunner_tick :: proc(self: ^Gunner, in: Gunner_Input) { ... }
@(gd_tick) drone_tick  :: proc(self: ^Drone,  in: Drone_Input)  { ... }

// two device reads on the game root — scriptgen matches each to its class by
// the struct it writes (one sample per input type; a second on the same type
// is a build error)
@(gd_sample) qd_sample    :: proc(self: ^Game, tick: u64, in: ^Gunner_Input) { ... }
@(gd_sample) drone_sample :: proc(self: ^Game, tick: u64, in: ^Drone_Input)  { ... }
```

Scriptgen assigns each distinct input type a stable wire id, sorted by name
with the primary class at 0. It records the class in each `Sim_Set` and
registers all classes in `<game>_lane_init`: `lane_init` registers the primary
and `lane_add_input_class` registers the rest. Track entities with their
generated `Sim_Set` to route input during live simulation, prediction, and
resimulation. A single-input game registers one class and retains the same
single-class wire representation.

A `Lane` keeps one history ring per class the local seat drives; the host keeps
one buffer per (player, class). A batch acknowledges the oldest of the newest
input ticks across a player's classes. This lets the client maintain enough
lead for the class furthest behind and trim every ring to that common floor.
The limit is one driven entity per class per player. Two same-kind entities
driven by one player share a window; use distinct input structs or combine
their intent in one struct.

Quickdraw's companion drone in `examples/quickdraw` demonstrates multiple
classes. Its native acceptance test predicts the drone on the client's own
tick while steering it in a different direction from the gunner, verifying
independent input routing from one seat.

## Promoting a coop game

Because the lane is selected per field, a session-replication game can migrate
one contested entity at a time. The worked comparison is
`examples/slopball` → `examples/speedball`:

1. **Keep session features in place.** Identity, roster, chat, stats, spawns,
   saves, generated helpers, and the entity factory support both models.
   Chests, inventories, and scores stay on the delta lane with their commands.
2. **Retag the contested fast state.** `owner` (movement the peer
   owned) becomes `predict`: the field's writer changes from "its
   owner's stream" to "the server's simulation, predicted locally". Keep
   `interp` on displayed floats.
3. **Move its writes into a `@(gd_tick)`.** Frame-rate mutation becomes a
   fixed-rate pure step: (predicted fields, input) → predicted fields. This
   is the main simulation rewrite, and it is where engine physics must become
   query-based kinematics (slopball's `play.Puppet` ball becomes speedball's
   forty lines of bounce arithmetic; see Simulation constraints).
4. **Declare and sample the input struct.** Mark it `@(gd_input)`, put field
   ranges/finite/unit/enum/mask rules beside the fields, and sample it in
   `@(gd_sample)`, the one place that still touches hardware.
5. **Add only game predicates by hand.** Use
   `@(gd_sample = "validate")` for cross-field or game-state invariants; the
   generated field sanitizer already runs locally and at authority admission.
6. **Sort the consequences.** Cross-entity outcomes move to `<tick>_then`
   (authority), local presentation to `<tick>_fx` (live pass). Discrete
   verbs on delta-lane state keep their `@(gd_command)`s.
7. **Remove obsolete ownership arbitration.** Logic that chose which peer
   simulates owner-streamed state may no longer apply after the authority takes
   over. Keep presentation claims where local contact needs an immediate
   displayed response.
8. **Attach the network components:** let `<game>_net_attach(self, options, cfg)`
   validate a [named network profile](profiles.md), install the
   generated lane, and migrate entities one at a time. A hybrid game is a
   supported end state. A custom shell can call `<game>_lane_init` +
   `boot_lane` directly. Command and spawn call sites
   continue using `<verb>_cmd(&boot, …)` and `<entity>_spawn(&boot, …)` in both
   models; the generated bodies choose the appropriate execution path.

After promotion, the authority derives the selected fields from admitted input
instead of accepting client-written positions. This adds fixed-tick authoring,
history, and server simulation cost. It also enables authoritative rewind
queries. Input validation and a trusted authority remain necessary; the field
tag alone is not a complete security policy. See [Timelines](timelines.md) for
model selection.

## Tuning

`Lane_Config` (zero = the default): `hz` 60 · `snap_every` 3 (20 Hz batches)
· `margin` 2 (target input headroom, ticks) · `slots` 128 (ledger depth) ·
`redundancy` 8 · `rewind_max` hz/4 · `lead_max`
max(margin + rewind_max + 2×snap_every, slots/2, 8) (the furthest
client-stamped input/verb tick accepted ahead of authority time) ·
`watch_delay` 2×snap_every ·
`smooth_halflife` 0.063 s · `smooth_cut` 0 (never cut; set it in world
units for teleport-heavy games) · `tolerance` 0 (exact reconcile; set it in
world units to leave smaller continuous held-input drift uncorrected in
predict-world) · `snapshot_budget` 0 (unlimited at the low-level;
named profiles install a measured per-recipient ceiling).

`lane_init` validates the configuration as one set: negative values are invalid;
cadence, margin, rewind, lead, and watch delay must fit the ring; redundancy cannot exceed the receiver cap; and
`watch_delay` cannot exceed 31 (the render offset rides the wire in eighths
of a tick, in one byte). `echo_inputs` with `tolerance` 0 warns once, since
that pairing resims on nearly every batch; set the tolerance in world units.
For a netgraph, use `lane.stat_reconciles` and `lane.stat_resims` to show
corrections and bursts of replay work. Host-side counters for version skew and
invalid traffic include `stat_input_drops` (input windows dropped for an
unknown class id), `stat_input_rejected` (malformed or future windows),
`stat_ack_rejected` (unissued, regressing, misaligned, or stale snapshot
claims), `stat_cmd_capped` (verbs refused by the per-player cap),
`stat_cmd_rate_dropped` (verbs refused by the shared action token bucket),
`stat_cmd_rejected` (replay/bounds/access refusals), and
`stat_echo_dropped` (predict-world rows past the u8 batch ceiling). Snapshot
telemetry is `stat_snap_full`, `stat_snap_delta`, `stat_snap_suppressed`,
`stat_snap_deferred`, `stat_snap_aoi_culled`, and `stat_snap_bytes`.
`lane_net_stats` collects these with input gaps, ack age, current command queue,
rewind depth, resimulated ticks, and measured replay seconds. Games using Boot
can read the installed lane's statistics through `kboot.boot_net_stats`.

### Snapshot AOI, budgets, and sparse recovery

Simulation snapshots reuse `session_set_interest` and `session_set_focus` to
select an area of interest (AOI) for each recipient. An entity owned by the
recipient is always eligible; other predicted entities must be in that
recipient's session AOI. When `snapshot_budget` is nonzero, the
authority sends owned entities first, then the stalest eligible rows, with
distance as the tie-break. Work that does not fit is deferred rather than
growing the packet.

Unchanged entities emit no row. The authority records that their acknowledged
value was represented at the new batch tick, and the receiver carries the same
value into its baseline history. AOI-culled and budget-deferred entities are
not marked represented. If one later re-enters after the global acknowledgement
advanced, its first row is full, so a global batch ack can never authorize a
delta against state that recipient did not receive. This is why sparse batches
do not need a keyframe-request protocol.

For lag compensation, monitor `stat_rewind_clamped`. It counts rewound queries
limited by the authority's measured-connection bounds, configured render-hint
cap, or absolute `rewind_max`. A clamp or two before timing measurements settle
is normal. A persistently increasing count can mean that the client reports an
older view than its measured connection and lane settings allow, its simulation
lead needs adjustment, or the configured ceiling is too small for the link.
Quickdraw's duel acceptance test checks this counter because a hit count alone
does not reveal shots consistently judged at the permitted rewind limit.

**Per-field reconciliation and smoothing.** Float fields can override lane
defaults through their tags, allowing a fast contested object and a precise
avatar to use different correction behavior within the same lane:

- `slack=N` (world units) overrides `tolerance`: the allowed drift before
  reconciliation. This applies only to floats. Discrete predicted state always
  reconciles exactly when any byte differs.
- `glide=N` (seconds) overrides `smooth_halflife`: the half-life of the displayed
  correction error. A larger value makes the displayed correction more gradual.
- `cut=N` (world units) overrides `smooth_cut`: the error beyond which correction
  immediately snaps the displayed pose. If any field exceeds its own cut, the
  whole pose snaps together.

`glide=`/`cut=` require a `predict,interp` float field because they control
render error; a predicted field without interpolation snaps on reconciliation.
`slack=` requires a `predict` float. Scriptgen reports an error if a tag is
used on an incompatible field.

<a id="gotchas"></a>

## Simulation constraints

- **Step procedures rerun.** Anything a step reads must be recorded in history
  or derived from the tick. Reading `knet.now_s()` introduces a value that
  changes during replay and can cause misprediction. Sample devices only in
  `game_sample`.
- **Mutate predicted fields within the tick pipeline.** A client write outside
  that pipeline is absent from replay history and will be erased by the next
  reconciliation. Use `@(gd_command)` for discrete mutations; on a ticking
  class, these commands are scheduled and replayed within the pipeline. See
  "Scheduling and replaying commands".
- **Engine physics cannot be replayed.** Predicted movement must use
  query-based kinematics. A rigid body can use the simulation lane only if its
  step procedure implements integration. Engine ray and shape casts are
  replayable only against static geometry such as walls or the arena. During
  replay, the physics server still holds current node poses. A cast against
  another moving entity's collider would therefore query the latest frame
  rather than the replayed tick. Test entity-to-entity contact in Odin using
  the tracked structs' fields, as the examples' overlap checks do.
- **Delta-lane reads can cause corrections when the value changes.** A tick may
  read delta-lane fields, but replay sees their current values and clients
  receive their changes after network transit. Around a death, Quickdraw's
  `if self.hp <= 0` gate lets the client predict a step the server refuses;
  presentation smoothing reduces the visible correction. This may be
  acceptable for rare changes. Mirror frequently changing state into a
  predicted field when it must replay with the tick.
- **Watched entities render in the past.** Their `watch_delay` works like the
  delay on owner streams. Account for the difference between their displayed
  time and the local avatar's predicted time when handling interactions.
- **Present before updating nodes.** `lane_present` writes displayed values
  into fields: interpolation for watched entities and smoothed corrections for
  predicted entities. Code that needs simulation state must run inside tick
  procedures or the Step_Proc, before `lane_present`. The ledger retains
  simulation state for access outside that pipeline.

## Implementation and test coverage

The repository currently implements the input pipeline, ledgers, snapshots,
reconciliation, lane driver, lag compensation, watched interpolation,
render-error smoothing, possession, predicted spawns, tick payloads and world events,
multiple input classes, generated authoring, and the `play/sim` blocks.

`tests/kitsim` covers convergence under loss and blackout, input-class routing,
glide versus snap behavior, and event timing. `tests/repgen` covers generated
contracts. Quickdraw and Speedball add multi-process acceptance tests for the
main competitive paths.

Implemented limits include declarative input constraints, shared traffic
budgets and authority admission checks, protocol-wide payload ceilings,
per-recipient snapshot budgets, AOI, and sparse snapshots that preserve
acknowledgement safety. Decoder and property-test corpora check protocol
handling. These mechanisms do not establish support for arbitrary scale.
Simulation event tuples are capped at 4 KiB, command arguments at the action-policy bound, input packets at 32 KiB,
and every simulation message remains inside the session's 256 KiB app-message /
1 MiB packet envelope. The benchmark-backed supported starting points are published
by `network_profile_envelope` and documented in [profiles](profiles.md); measure
your game logic and engine work before raising them.

See [net](net.md) for the wire format, descriptors, blend math, and tick
support used by this lane; [session](session.md) for identity and reliable
state; and [play](play.md) for coop components, including Puppet for
engine-driven physics and `play/sim` for replayable integration.
