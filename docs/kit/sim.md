# `kit/sim`: server-authoritative fixed-tick simulation

`kit/sim` adds an authority-run simulation lane to the normal Kit session. A
client sends tick-stamped input windows; the authority advances final state and
sends snapshots; the owning client predicts the same ticks and reconciles when
its result differs.

Use the simulation lane for movement, aiming, projectiles, or shared objects
whose state should be computed by a trusted authority. Reliable session state
such as inventory, score, chat, entity lifetime, and saves remains on
`kit/session` and `kit/net`.

The package does not import Godot. Its input, snapshot, history,
reconciliation, and lag-compensation paths run in headless tests under
`tests/kitsim`.

## The mental model

A field tag selects one of three disjoint replication lanes:

| tag | authority | wire | applied by |
| --- | --- | --- | --- |
| `replicate` | host | reliable deltas | on arrival |
| `owner` | owning peer | unreliable stream | interpolated in the past |
| `predict` | authority simulation | tick-stamped snapshots | prediction, reconciliation, and resimulation |

Identity, roster, reconnects, spawns, blobs, stats, chat, and reliable commands
remain session features. The
[quickstart](quickstart.md) is the fast route into the coop model, and the
[sim quickstart](quickstart-sim.md) is the fast route here (a coop hello
promoted in a small set of changes). Only contested fast state (movement,
projectiles) opts into the sim lane, per field. A field's lane is the tag's
first token, so a field lives on exactly one lane: `owner` and `predict`
are alternatives, not flags you combine.

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

Tag the state, declare the input struct by using it, mark the step, and
return facts. The name-paired halves consume those facts, and the generated
thunk holds every role gate:

```odin
Runner :: struct {
	owner:   gd.Node2d,
	net_id:  knet.Net_Id,
	x, y:    f32 `gd:"predict,interp"`,
	vx, vy:  f32 `gd:"predict"`,
	fire_cd: u16 `gd:"predict"`, // even the trigger is predicted state
	hp:      i32 `gd:"replicate"`, // delta lane: never resimmed, wire-fresh
}

Runner_Input :: struct { // no tag — discovered from the tick proc's signature
	move:    [2]i8,
	buttons: u8,
}

@(gd_tick)
runner_tick :: proc(self: ^Runner, input: Runner_Input) -> (fired: bool) {
	self.vx = f32(input.move[0]) * SPEED // single-player-looking, fixed dt implicit
	self.x += self.vx
	if self.fire_cd > 0 {self.fire_cd -= 1}
	if input.buttons & FIRE != 0 && self.fire_cd == 0 {
		self.fire_cd = COOLDOWN
		fired = true // a FACT, not a verdict — ticks can't reject
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
	if fired { muzzle_flash(self) } // answers the click NOW, at any latency
}
```

Script generation emits the raw-pointer thunk, role and resimulation checks,
`runner_sim_set`, and recursive canonical-ABI plus target-layout checks for the
input struct. It rejects invalid halves, platform-sensitive or padded inputs,
and a tick proc whose entity has no `predict` fields.
Tick shapes are `(self)`, `(self, input)`, `(self, lane)`, and
`(self, input, lane)`: a pointer param is the lane, and a value param is
the input. Both halves also accept game-less (self-first) shapes.

### Presenting a fact on every screen

The `_fx` above runs only for the acting player's live pass. To present the
same fact on every screen, add `mine: bool` immediately after `self` (the
parameter name is significant):

```odin
@(gd_half)
runner_tick_fx :: proc(g: ^Game, self: ^Runner, mine: bool, fired: bool) {
	if fired {
		muzzle_flash(self)        // every screen
		if mine {kick_camera(g)}  // flavor, not a role branch
	}
}
```

- The actor presents the fact immediately with `mine = true`. Resimulation
  does not present it again.
- The authority presents facts from other actors as they execute, with
  `mine = false`.
- Other clients receive a reliable `SIM_FACT` and present it when their watch
  clock reaches the fact's tick. This keeps an effect aligned with the delayed
  entity that caused it. Facts are counted individually, so a batch cannot
  collapse two occurrences into one.

The `mine = true` skip **assumes the actor's own live pass fired the same fact
from the same input**, which holds true unless the actor's input for that
tick was lost: the authority then held their last input, its everywhere pass
fired the fact from the extrapolation, and the actor, running its own fresh
input, may not have. Skipped, they miss that one-shot. Facts are cosmetic
one-shots, and loss is allowed to drop them. If the actor **must** see a fact
regardless of loss, fire it from an **authority** world pass
(`@(gd_step="authority")`) instead of the entity tick: an authority-minted
fact includes the owner by construction.

### Cues produced by a world pass

Use `@(gd_event)` for a presentation event discovered outside a single
entity's tick, such as contact between a player and a ball. A sim-tracked
anchor lowers the declaration onto this lane's existing fact/watch clock:

```odin
// The presentation proc you write. `k` is the only entity, so it is the anchor.
@(gd_event = "audience=everyone,timing=auto")
ball_kicked_fx :: proc(g: ^Game, k: ^Kicker, mine: bool, bvx, bvy: f32) {
	kick_sound(bvx, bvy)            // every screen, at its right time
	if mine {kick_camera(g)}        // flavor, not a role branch
}

// Scriptgen generates this helper. Call it where the sim discovers the event:
if kicked {
	ball_kicked(&g.boot, k, b.roll.vx, b.roll.vy)
}
```

The generated helper applies the same live-pass, authority, watcher, and
resimulation rules as a tick fact. The anchor chooses the entity timeline used
for presentation and the owner used to derive `mine`; it is a particular proc
parameter, not a class or category. If a game has hundreds of `Enemy`
instances, `anchor=enemy` means "use the `enemy` pointer passed to this call."

Anchor selection is intentionally small:

- No entity parameters means a world cue. The authority is its local producer.
- One entity parameter is the inferred anchor.
- With two or more entity parameters, name one parameter explicitly, such as
  `@(gd_event="anchor=target,timing=auto")`.
- Use `anchor=none` only when the authority/world clock is intentional despite
  carrying entity references.

Put all typed entity parameters between the game and `mine`. They must be
lane-tracked script classes. The anchor travels in the fact header; every other
entity reference travels as a `Net_Id` and is resolved to that peer's local
pointer before presentation. Arguments after `mine` must be wire primitives.
Scriptgen rejects ambiguous anchors, names that are not entity parameters, and
untracked entity types at build time.

Announce an anchored cue before untracking or despawning its anchor; otherwise
the generated corpse gate rejects it and no peer presents it. A predicted cue
that the authority never confirms may still appear locally. Speedball's kick is
the worked example. `@(gd_cue)` and `@(gd_fact)` remain source-compatible
sim-only spellings with their older `^Lane` announcement door; new
cross-model presentation uses `@(gd_event)` and `^Boot`.

For the rare inline probe that should not be a fact at all (a debug print in
a tick body), gate on `ksim.lane_live(&lane)`: it reflects the live pass, not
a resim replay. Never read `lane.resimming` raw.

For a `mine`-form tick fact, at least one returned value must be `bool`; the
half runs on ticks where any boolean fact is true. All returned facts must be
wire primitives. Scriptgen reports either violation at build time. Use a plain
owner-only `_fx` (without `mine`) for continuous local presentation such as an
engine hum, or for an effect that should not appear on every screen.

The game's own halves (the device read and the world pass) are typed and
attributed the same way. `@(gd_sample)` marks the one place that touches
hardware (never called during a resim); scriptgen pins its input struct to the
ticks' at build time, so sampling into the wrong struct cannot compile.

Put the ordinary admission rules on the input itself:

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

Admission is bounded at both levels: each window keeps its size/redundancy
limits, and a seat may send at most 16 input classes in a 32 KiB `SIM_INPUT`
payload. Generated and hand-built lanes assert the same aggregate envelope at
registration, and the authority rejects an oversized packet before creating
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

In a package with no
`@(gd_tick)` classes there is no lane, so `@(gd_step = "authority")` routes
through the boot accumulator instead: scriptgen generates
`<snake>_step(self, ticks)`: the role gate, the fixed-step loop, and the
[same-frame edge pass](net.md#field-change-edges)
in one proc the game calls with `boot_pump`'s ticks
(cavecrawl's `cave_host_tick` is the worked example; there is no absolute
tick in the coop loop, so this form is `proc(self)`; count ticks in your
own `gd:"backup"` field). One declaration, two routings: promoting the game
to the sim lane re-routes it without touching the attribute.

For a conventional shell with one Boot, Session, Comms, and Lane field, the
generated game-network facade owns this wiring too. Pass a named complete-stack
profile while attaching, then override its lane fields when measurements call
for it:

```odin
// ready(): Boot + entities + lane in one generated call
cfg := kboot.network_profile(.Listen_Server_Action)
cfg.lane.smooth_cut = 48
game_net_attach(self, kboot.Options{/* ... */}, cfg)
```

Underneath, `<class>_lane_init` carries the input size, typed procs, and each
pass wired to its slot; `boot_lane` makes Boot drive everything. Both remain
public for a custom shell. The generated entity table
carries each ticking class's `Sim_Set`, so the factory tracks and untracks
entities on the lane itself; `boot_pump` runs `lane_frame` + `lane_present`
every frame and forwards `Ev_Owner_Changed`.

Entity thunks run every simulated tick, live and replay identically, in
track order, each fed its owner's input (`nil` coasts: an inputless entity
type, or a remote player on a client whose truth is already inbound). The two
optional world passes run after entity ticks: the everywhere pass for pure-sim
cross-entity work (contact), the authority pass for genuinely WORLD-shaped
authority work (respawn queues, wave directors). One input **class** exists
per distinct `@(gd_tick)` input TYPE: `lane_init` registers the primary
(class 0) and `lane_add_input_class` registers each extra, and the wire ships
one window per class per packet (see [Two entity kinds, two inputs](#two-entity-kinds-two-inputs)
below). Two driven entities of the SAME kind still share a window; compose that
intent into the one struct. Quantize by declaring the quantized type: what the
struct holds is what crosses the wire (quickdraw's aim is a `u16` turn
fraction, ~0.005° resolution, with a two-line codec pair at the sample/tick
boundary; there is no per-field wire machinery on inputs; the blob memcpys).
A world pass that reads inputs takes the typed view:

```odin
input, drives := ksim.lane_input_of(&g.lane, owner, Kicker_Input)
if !drives {continue} // a pair this peer doesn't simulate
```

For hand-driven setups (tests, generated-code-free games) `lane_init` +
`lane_set_sim` (rawptr sample + the two `Step_Proc`s, everywhere then
authority) + `lane_track` / `lane_track_set` + explicit
`lane_frame`/`lane_present` calls remain fully supported; the generated
wiring and the thunks are sugar over exactly that. `lane_present` is
genuinely optional there: until the first call, the `presented` latch keeps
ingest painting watched truth directly (a hand-driven client that never
presents never freezes its watched entities); after it, watched fields
belong to the presenter.

One lifecycle rule either way: lane state does not reset with a session
re-init. The app route survives, but the anchor and ledgers do not follow a
fresh authority. To reset, call `lane_destroy` then `lane_init` (destroy
zeroes the lane); `lane_init` on a live lane asserts.

## Simulation blocks in `godot:play/sim`

Blocks compose on this lane the way `godot:play`'s compose on the coop one:
embed a field and the entity gains the block's predicted state (its
`gd:"predict"` fields flatten into the descriptor) AND its
`@(gd_tick)` step, hoisted to run after the entity's own tick: the entity
writes intent, and blocks integrate. The alias is `psim`:

```odin
import psim "godot:play/sim"

Kicker :: struct {
	...
	run:  psim.Mover, // momentum movement: the tick writes run.tx/ty, the block integrates
	kick: psim.Cool,  // predicted cooldown: psim.ready(&k.kick, KICK_CD) gates and re-arms
}
```

- **`psim.Cool`**: the predicted cooldown, the sim-lane counterpart to
  `play.Pace`, with the same three verbs (`due` / `arm` / `ready`) on the other
  timeline. Pace holds a deadline against a clock you pass in (host scratch,
  never on the wire); Cool counts itself down inside the sim, so a revolver's
  cadence or a kick's recovery answers the click at any latency and replays
  exactly.
- **`psim.Mover`**: momentum 2D movement. Intent-through-fields: the entity's
  tick writes the velocity it wants every tick and the block approaches it;
  `accel = 1` collapses the approach to an exact snap for twitch games. Config
  (accel, bounds) is fixed, not replicated state: plain untagged fields,
  stamped at spawn on every peer, never on the wire.
- **`psim.Roller`**: the contested rolling body, with self-simulating
  friction, a hard speed ceiling, and energy-eating wall bounce. The game
  keeps the consequences: speedball's ball detects goals off the roller's
  clamp (a crossing lands exactly on the line for one tick) and predicts its
  own reset.

**Driving a block yourself: `gd:"manual"`.** Auto-hoist runs a block's tick
after the wielder's (intent, then integrate); this is the right default until
the wielder must act on the integrated result (a crate pushout after the move) or
skip the step entirely (a dead avatar that must not count its cooldown down).
Tag the embed `gd:"manual"` and scriptgen stops auto-calling that block's
tick; the wielder drives it, wherever and however often it likes:

```odin
fire: psim.Cool `gd:"manual"`, // I'll tick it myself

@(gd_tick)
gunner_tick :: proc(self: ^Gunner, in: Gunner_Input) -> (fired: bool) {
	if self.hp <= 0 {return} // dead: never tick it — the cooldown just freezes
	if in.buttons & FIRE != 0 && psim.ready(&self.fire, FIRE_CD) {fired = true}
	psim.cool_tick(&self.fire) // driven here, on the alive path
}
```

The predict fields still flatten into the descriptor; `manual` suppresses only
the auto-CALL, never the wire. It is the escape hatch for bespoke ordering (any
order, conditional, or not at all); an untagged embed stays auto-hoisted, so
the plain embed-and-integrate case is untouched. quickdraw's revolver is the
worked example: its dead-man freeze is one skipped call.

The namespaces police themselves: embed a predict-tagged block from the
root `godot:play` shelf and scriptgen errors it toward `play/sim`; embed a
`play/sim` block that carries no predict fields and it errors back.
Game-local blocks compose however they like; the lint is the shelf's
contract, so `psim.` at a call site always means this state resims.

## What the lane does underneath

- **Anchoring.** A client neither ticks nor sends until the first batch
  names the server's tick, then adopts the truth outright and starts a
  couple of ticks ahead. From there the clock only BENDS: a ±2% timescale
  nudge (beneath perception) grows or shrinks the lead toward the target
  headroom, fed by the batch header's input-ack echo. There is no clock sync
  dependency, no tick jumps, and no pops.
- **Snapshots delta against an ACK, not a guess.** The server deltas every
  entity's predict set against the newest batch the client confirmed
  applying in full; a client only acks a batch when every row landed. An
  unknown id (spawn in flight) skips by length and stalls the ack; a missing
  baseline falls back to a per-entity full row. This is self-healing in both
  directions, with no keyframe-request message.
- **Predict-self.** Your own entities are ledgered and reconciled; everyone
  else's are *watched*: truth applies as it arrives, and `lane_present`
  renders them on a delayed watch clock, blending bracketing batches per field
  (`Lerp_Kind`, the same as streams, and the same clamp-and-hold rule: never
  extrapolate).
- **Authority snaps, the eye glides.** When a reconcile corrects your
  avatar, the sim state snaps to truth (the ledger records it), but
  `lane_present` draws sim plus a decaying error (63 ms half-life, the puppet
  constant) on float `interp` fields, so a correction is a lean, not a
  teleport. Past `smooth_cut` the error zeroes and the snap shows, because
  smoothing a cut looks worse than the cut. This is free for the game:
  fields hold sim truth during `lane_frame` and presentation truth after
  `lane_present`; the lane re-seeds sim state from the ledger before
  ticking, so dressing nodes from fields keeps working unchanged.
- **Events, not callbacks.** Packet handlers only file bytes; every call
  into game code happens inside `lane_frame` on your stack.
- **Possession is one call.** `lane_set_owner(l, id, player)` on every peer
  (forward the session's `Ev_Owner_Changed`): the authority flips whose
  input buffer drives the entity (and whom rewound queries spare); a client
  swaps the entity between predicted and watched, seeding the new ledger
  from the freshest received truth.

## The contested object

Predict-self leaves shared fast objects (the ball, the crown, the flag)
watched, which means rendered in the past and touchable only after a round
trip. `@(gd_tick = "contested")` is the middle path (the Rocket League
model): **every peer predicts this entity**, so contact with it resolves on
each screen's own timeline instantly. The server's simulation stays the only
truth; a wrong guess (the opponent you render in the past touched it first)
reconciles and glides like any other mispredict. You opt into the costs per
entity: resim CPU on every peer, and exactly that mispredict class. Design the
tick so consequences that must not double-fire stay in `_then` (authority),
but keep RESETS in the tick itself where they predict: speedball's goal
detection and kickoff freeze live in the ball's own tick, so every screen
snaps the ball home the instant its simulation crosses the line, while the
score lands authority-side. Contact belongs in the world pass, applied only to
the pairs this peer HAS INPUTS for: yours on your screen, everyone's on the
server; a remote touch reaches you as the server's word, never as a local
guess.

Rules that keep the pattern honest:

- **Contested entities must be SELF-SIMULATING.** A ball integrates its own
  motion, which is what makes every peer's between-batch prediction good. An
  input-driven avatar would coast frozen client-side and fight corrections
  forever.
- **Presentation follows the CLAIM.** A contested entity's sim runs on your
  predicted timeline, but its PRESENTATION is claim-weighted: call
  `lane_claim(l, id)` every tick YOUR sim influences it (the world pass's
  contact block), and the entity draws from your predicted pose, instantly
  and legitimately front-running the server. Unclaimed, it draws the WATCHED
  view, so a remote touch moves it beside the remote avatar that made it
  instead of a whole lead early (the mixed-timelines artifact you will
  otherwise ship: predicted ball, past-rendered players, one screen). The
  claim rises instantly and decays over ~a quarter second, matching net.md's
  "did MY simulation cause this?" boolean, asked continuously.
- **Or go all the way: PREDICT-WORLD** (`Lane_Config.echo_inputs`, the
  Rocket League model: what speedball ships). Batches echo every player's
  held input; mark the AVATARS `contested` too, and every peer ticks every
  entity (remote ones extrapolated with held inputs), so the whole scene
  lives on ONE predicted timeline. No claim dance at all (contested
  presentation is simply the predicted pose), remote touches play out beside
  the avatars making them, immediately. The price is resim on nearly every
  batch (held inputs drift: small, constant, glided corrections on remote
  avatars instead of delayed-but-accurate ones) and a few echo bytes per
  player per batch. Pick per game: predict-world for contact-driven games,
  predict-self + lag comp where accurate rendered targets matter (quickdraw
  keeps hitscan honest by NOT extrapolating its targets). The claim-mode
  rules below serve games that predict only the object.
- **The claim follows the CAUSE, and releases when the cause ends.** Your
  kick's whole FLIGHT is your simulation's consequence: keep claiming while
  the ball is fast from your touch, and release when it SLOWS (the two
  timelines nearly coincide, so the handback is invisible) or when an
  opponent contests it. Releasing on mere distance pulls your own kick
  backward mid-flight: the fade target is the watched view, sitting
  speed × timeline-skew behind a fast ball, and blending across that gap
  cancels its forward motion on your screen. `examples/claimball`'s `sp_step`
  claim block (hold while fast, release on slow) is the reference.

The soccer game ships three times, one per model, so read them against each
other to choose: `examples/slopball` (coop, peer-authoritative),
`examples/speedball` (predict-world: every avatar echoed, no claim), and
`examples/claimball`
(predict-self + the claim dance above). `claimball` is the worked claim-mode
example: a contested ball predicted on every screen, presented from whoever's sim
is driving it. The onboarding's
[competitive turn](../onboarding/07-the-competitive-turn.md) walks the same three.

## Lag compensation

```odin
// HOST, judging a hitscan from `shooter` (inside a _then or the world pass):
judged_at := ksim.lane_rewound_begin(&g.lane, shooter)
g.hit = trace_shot(g) // every OTHER entity is wound back to what the
                      // shooter's screen showed; the shooter's own stay live
ksim.lane_rewound_end(&g.lane)
```

Write the hit test inline between begin and end, with no context struct across a
rawptr. The pair must not nest, and nothing may track/untrack entities in
between. `lane_rewound(l, shooter, user, query)` is the same judgment as a
callback, for the places a proc value reads better (tests, table-driven
weapons).

**Scope, precisely:** the rewind winds back the PREDICT-SET fields of every
tracked entity except the shooter's own, and nothing else. Delta-lane fields
(hp, scores, gear), untracked entities, and any game-side maps read LIVE
inside the block. That is usually what you want (quickdraw judges a rewound
pose but applies damage to live hp, since a dead man's past body shouldn't
eat a new bullet), but it means a predicate like "was the target shielded when
the shooter saw them" must keep its shield in the predict set, or it reads
today's shield against yesterday's pose.

The rewind view is **issued-snapshot-anchored and interpolated**: every input arrives
in a packet that also carries the sender's snapshot ack and its render
offset, and the buffer tags each input with both, so when the server
executes the input that pulled the trigger, it first verifies that the ack
names a recent, non-regressing batch actually issued to that seat. Applying
the batch remains a client claim, so validity as a replication baseline does
not automatically make it visibility evidence. The authority caps credible
ack age at
`ceil((observed RTT + 2·jitter) / tick_dt) + margin + snap_every` and caps the
reported render offset at its own configured `watch_delay + snap_every`. That
extra cadence admits the normal interpolation phase around the watch target,
not a client-reported stall. Their sum, capped again by `rewind_max`, is the
seat's current competitive rewind envelope.
`lane_rewind_envelope(l, shooter)` exposes that derived limit in ticks. Before
the authority has a pong sample for the seat the envelope is zero and queries
judge live.

Within that envelope the rewound scope BLENDS the claimed bracket pair
the shooter's screen blended (`predict_blend` over the truth ledger), not
the shooter's freshest ack (which advances a whole lead-plus-transit
between sampling and adjudication), and not a quantized single tick (which
costs near-tangent shots against the watch clock's interpolation).
quickdraw's duel acceptance test measures the result: most aimable shots
land at 240 ms RTT. `rewind_max` (default ~250 ms) is still the absolute
favor-the-shooter ceiling. The client cannot earn that whole window merely by
replaying an older issued ack, reporting a stalled render clock, or inflating a
field: the observed-link envelope pins the reconstructed view to the newest
credible floor. The cost of any favor remains the classic one: occasionally
you are hit just after reaching cover. No ordinary snapshot acknowledgement
can prove which frame a player actually looked at; the render offset is a
bounded hint, not proof.

## Discrete verbs on the lane

A verb is everything an input bit is not: it carries arguments, it can be
REJECTED, and it fires once. On a ticking class, `@(gd_command)` keeps the
exact coop authoring shape (predicate-then-mutate, name-paired `_then` on
the authority) but executes INSIDE the tick pipeline:

```odin
@(gd_command = knet.ACTION_OWNER_PREDICTED)
gunner_buy :: proc(self: ^Gunner, item: u8) -> bool {
	if self.gold < price_of(item) {return false}
	self.gold -= price_of(item) // delta lane: reverted on rejection
	self.gear = item            // predicted: replayed by every resim
	return true
}

// anywhere with the boot in reach (a key edge, a bot) — the same handle and
// the same knet.Action_Outcome as a coop verb, so promoting a class never
// touches an issue site:
outcome := gunner_buy_cmd(&g.boot, g.me_gun, ITEM_BOOTS)
if outcome.reason == .Rate {show_slow_down_feedback()}
```

The generated wrapper schedules the verb at your next tick and ships it
tick-stamped on the reliable channel; the client's lead exists precisely
so it arrives before the server simulates that tick (a lag spike executes
at the server's next tick instead; history is never rewritten). Your screen
runs the verb ONCE at that tick; resims re-apply its predicted-field
footprint rather than re-running it (a replayed predicate would read the
gold it already spent). The server executes at the stamped tick (verbs run
after entity thunks, before the world pass) and answers with a verdict: a
rejection unwinds the delta-lane writes on the spot and the next reconcile
scrubs the predicted ones, the same glide as any mispredict.

Every verb declares the same typed policy as the co-op lane. Bare
`@(gd_command)` is owner-only and non-predicted;
`knet.ACTION_OWNER_PREDICTED` opts into owner speculation,
`knet.ACTION_ANY_SEAT` opens a world interaction, and
`knet.ACTION_AUTHORITY` never crosses client ingress. Prediction requires both
an optimistic action policy and a prediction ledger: marking an entity
contested does not silently predict every verb, and choosing a predicted policy
does not make a watched entity predictable. Two same-tick verbs run in
execution order with the predicate arbitrating (a spike on the ball is the
shape). Bursts are
fine: verbs QUEUE per entity, and a rejection unwinds the delta-lane
speculation chain in order without disturbing the survivors. The wrapper
returns the same `Action_Outcome` as co-op: `.state` says whether it scheduled,
`.reason` names a local access/rate/malformed/stale refusal, `.seq` correlates
the final callback, and `.model` is `.Scheduled`.

The authority verdict reaches the ordinary generated session callbacks. A
client's `<game>_command_rejected` half receives the addressed command and an
`Action_Reject_Reason`; the host's `<game>_command_executed` half receives the
same reason for diagnostics. Predicate failure and timeout are therefore
distinct without a lane-specific event API. Scheduled timeouts use an
independent lane-frame clock, so authority loss still expires actions when the
simulation clock itself has stopped waiting for snapshots.

When the predicate needs WHO, declare the issuer: `by: knet.Player_Id`
right after the receiver, and the lane fills it with the seat that issued
it: you speculating, the ledgered seat on the authority, the same value the
`_then` gets. It never rides the wire, so on a contested entity a verb can
arbitrate on whose touch it is without a claimable argument (the name is
reserved: a wire arg called `by` is a build error).

Replays re-apply what a verb WROTE (recorded bytes), not what it meant, so
prefer absolute mutations (`gear = item`) in the verb itself. When the
effect is genuinely relative (an impulse, a knockback), give the verb an
**`_apply` half**: `<verb>_apply(self, <wire args>)` holds the
predicted-field effect, and resims RE-RUN it with the ledgered args against
corrected state, exact where the byte patch can't be. With an apply half,
the verb keeps its hands off predicted fields: the predicate and the
delta-lane writes stay execute-once.

```odin
@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
ball_spike :: proc(self: ^Ball, px, py: f32) -> bool {
	return self.hold == 0 && in_reach(self, px, py) // verdict + (any) delta writes
}
@(gd_half)
ball_spike_apply :: proc(self: ^Ball, px, py: f32) {
	self.vx += ... // RELATIVE — re-run by every resim, never re-pinned
}
```

## Predicted spawns — a fired projectile

A verb mutates an entity that already exists; a **projectile** is a NEW one,
and it has to leave your muzzle the instant you fire, before the authority's
real bullet is even on the wire. That's a client-PREDICTED spawn: a local
entity, flying its own arc, born-gated and reconciled like your avatar, that
the authority's spawn REKEYS a round trip later (never a second bullet).

The projectile is an ordinary `@(gd_tick)` entity (inputless: it self-
integrates, like the ball) with an `entity=Bullet:id` scene. The fire is one
call in the tick's name-paired halves, with no role branch needed, because
`_then` is always the authority and `_fx` always the owner's client:

```odin
@(gd_tick) // the flight: pure predicted state, `landed` routes to the splash
bullet_tick :: proc(self: ^Bullet) -> (landed: bool) { ...self.x += self.vx... }

@(gd_half)
gunner_tick_then :: proc(g: ^Game, self: ^Gunner, by: knet.Player_Id, lobbed: bool) {
	if lobbed { lob_bullet(g, self, by) } // AUTHORITY: the real spawn
}
@(gd_half)
gunner_tick_fx :: proc(g: ^Game, self: ^Gunner, mine: bool, lobbed: bool) {
	// A HOSTING player is authority AND owner — the _then above already
	// spawned their real bullet; only a pure client predicts one.
	if lobbed && mine && !ksim.lane_is_authority(&g.lane) {
		lob_bullet(g, self, g.ses.me)
	}
}

lob_bullet :: proc(g: ^Game, gun: ^Gunner, owner: knet.Player_Id) {
	b, bid := bullet_spawn(&g.boot, owner) // typed, role-routed — no const, no cast
	b.x, b.y, b.vx, b.vy, b.life = ... // the muzzle and the arc
	kboot.boot_spawn_send(&g.boot, bid) // host announces; client no-ops
}
```

The generated `bullet_spawn` (every `entity=` tag gets one) rides
`kboot.boot_fire_spawn` underneath, which routes: the authority gets a real
net id (`session_spawn_make`), this client a local predicted node under a
provisional id. **Born-tick gating** keeps the reconciles that land before the
spawn (the whole first round trip, the server running a transit behind) from
re-flying it from stale state; when the authority's `Ev_Spawned` arrives the
factory **matches** it to the projectile you predicted and rekeys it: the
same node, its flight ledger intact, reconciled from there. A refused fire
(or one the authority never spawns) is culled and its node freed. Splash
adjudicates server-side on truth, not a rewind, because a slow shot is meant
to be dodged.
`examples/quickdraw`'s lob (right-click) is the worked example; its native
acceptance test lands the predicted bullet on the client's own tick, no round
trip.

## Two entity kinds, two inputs

One player can drive two DIFFERENT entity kinds on the same tick: a walker and
a turret, an avatar and a vehicle, a duelist and a companion drone. Each kind
declares its own `@(gd_tick)` input struct, and each is an input **class**: the
client samples one per tick, ships one window per class on the single upstream
packet, and the host de-jitters each into its own per-player buffer. An entity's
tick reads only its own class, so the two timelines never cross, and a reconcile
of one leaves the other untouched.

The authoring is just a second `@(gd_sample)`, one per input type:

```odin
// two ticking kinds, two input structs
@(gd_tick) gunner_tick :: proc(self: ^Gunner, in: Gunner_Input) { ... }
@(gd_tick) drone_tick  :: proc(self: ^Drone,  in: Drone_Input)  { ... }

// two device reads on the game root — scriptgen matches each to its class by
// the struct it writes (one sample per input TYPE; a second on the same type
// is a build error)
@(gd_sample) qd_sample    :: proc(self: ^Game, tick: u64, in: ^Gunner_Input) { ... }
@(gd_sample) drone_sample :: proc(self: ^Game, tick: u64, in: ^Drone_Input)  { ... }
```

scriptgen assigns each distinct input type a stable wire id (sorted by name; the
primary is 0), stamps each `Sim_Set` with its class, and grows `<game>_lane_init`
to register them all: `lane_init` carries the primary, `lane_add_input_class`
the rest. Nothing else changes: track each entity with its generated `Sim_Set`
as before, and the right input reaches the right tick everywhere (live, predict,
resim). A single-input game registers exactly one class and is byte-for-byte the
single-class wire.

Underneath: a `Lane` holds one ring per class the seat drives and the host holds
one buffer per (player, class); the batch's input ack is the MIN newest across a
player's classes, so the client leads enough for its most-starved input and
trims every ring by that floor. There is one limit: **one driven entity
per class per player**. Two entities of the *same* kind driven by one player
would share a window (give them distinct input structs, or compose their intent
into one). `examples/quickdraw`'s drone (a companion each duelist steers beside
their gunner) is the worked example; its native acceptance test predicts the
drone on the client's own tick and shows it sweeping its own steer while the
gunner strafes the other way, demonstrating the two input classes running
orthogonally from one seat.

## Promoting a coop game

Because the lane is selected per field, a session-replication game can migrate
one contested entity at a time. The worked comparison is
`examples/slopball` → `examples/speedball`:

1. **Touch nothing session-shaped.** Identity, roster, chat, stats, spawns,
   saves, the doors, the factory: all of it rides both models unchanged.
   Chests, inventories, scores stay on the delta lane with their verbs.
2. **Retag the contested fast state.** `owner` (movement the peer
   owned) becomes `predict`: the field's writer changes from "its
   owner's stream" to "the server's simulation, predicted locally". Keep
   `interp` on displayed floats.
3. **Move its writes into a `@(gd_tick)`.** Frame-rate mutation becomes a
   fixed-rate pure step: (predicted fields, input) → predicted fields. This
   is the one honest rewrite, and it is where engine physics must become
   query-based kinematics (slopball's `play.Puppet` ball becomes speedball's
   forty lines of bounce arithmetic; see Gotchas).
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
   over. Keep presentation claims only where they are still needed for feel.
8. **Wire once:** let `<game>_net_attach(self, options, cfg)` validate a
   [named network profile](profiles.md), install the
   generated lane, and migrate entities one at a time. A hybrid game is a
   supported end state. A custom shell can call `<game>_lane_init` +
   `boot_lane` directly. Command and spawn call sites
   retain their shape: `<verb>_cmd(&boot, …)`
   and `<entity>_spawn(&boot, …)` keep their exact shape on both models;
   the generated bodies re-route.

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
world units so continuous held-input drift under the line rides uncorrected,
predict-world's anti-churn) · `snapshot_budget` 0 (unlimited at the low-level;
named profiles install a measured per-recipient ceiling). `lane_init` validates the configuration as one
set: negative values are invalid; cadence, margin, rewind, lead, and watch
delay must fit the ring; redundancy cannot exceed the receiver cap; and
`watch_delay` cannot exceed 31 (the render offset rides the wire in eighths
of a tick, in one byte). `echo_inputs` with `tolerance` 0 warns once, since
that pairing resims on nearly every batch; set the tolerance in world units.
Running tallies for a netgraph:
`lane.stat_reconciles`, `lane.stat_resims` (a resim burst is a latency
event worth drawing), and the host-side skew/abuse counters:
`stat_input_drops` (input windows dropped for an unknown class id: the
version-skew shape), `stat_input_rejected` (malformed or future windows),
`stat_ack_rejected` (unissued, regressing, misaligned, or stale snapshot
claims), `stat_cmd_capped` (verbs refused by the per-player cap),
`stat_cmd_rate_dropped` (verbs refused by the shared action token bucket),
`stat_cmd_rejected` (replay/bounds/access refusals), and
`stat_echo_dropped` (predict-world rows past the u8 batch ceiling). Snapshot
telemetry is `stat_snap_full`, `stat_snap_delta`, `stat_snap_suppressed`,
`stat_snap_deferred`, `stat_snap_aoi_culled`, and `stat_snap_bytes`.
`lane_net_stats` collects these with input gaps, ack age, current command queue,
rewind depth, resimulated ticks, and measured replay seconds. Normal booted
games do not copy any of them: `kboot.boot_net_stats` reads the installed lane.

### Snapshot AOI, budgets, and sparse recovery

Simulation snapshots reuse `session_set_interest` and `session_set_focus`.
An entity owned by the recipient is always eligible; other predicted entities
must be in that recipient's session AOI. When `snapshot_budget` is nonzero, the
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

`stat_rewind_clamped` is the one to watch if you run lag comp: it counts
rewound queries adjusted by the authority's observed-link envelope, configured
render-hint cap, or absolute `rewind_max`. A clamp or two while the clock is
cold is normal; a count that keeps moving means the client keeps claiming an
older view than its measured link and lane configuration substantiate, its
lead is mispaced, or the configured ceiling is too small for the link served.
quickdraw's duel acceptance test asserts on exactly this number, because the
hit count alone does not catch a client silently judging its shots at the
floor.

**Per-field reconcile + glide knobs.** The lane values are defaults; a single
float field can override each on its tag, so a fast contested object and a
precise avatar share ONE lane with different behavior:

- `slack=N` (world units) overrides `tolerance`: the drift this field rides
  before a reconcile (float-only: discrete predicted state always reconciles
  exactly, a differing byte is a real event).
- `glide=N` (seconds) overrides `smooth_halflife`: how slowly a correction on
  this field glides back (a slower glide reads smoother).
- `cut=N` (world units) overrides `smooth_cut`: the error past which this
  field is a teleport and SNAPS. The snap stays entity-coherent: any field over
  its own cut snaps the whole pose (smoothing a cut looks worse than the cut).

`glide=`/`cut=` are render-error knobs and need a `predict,interp` float field
(a non-interp predicted field snaps on reconcile, nothing to glide); `slack=`
needs a `predict` float. scriptgen rejects each on the wrong field, spelled out.

## Gotchas

- **Step procs re-run.** Anything a step reads must be ledgered or derived
  from the tick; `knet.now_s()` in a step proc is a mispredict source.
  Sample devices in `game_sample` only.
- **Predicted fields are the resim's property.** Don't mutate them outside
  the tick pipeline on a client: the next reconcile will erase your write
  (that is its job). Discrete mutations go through `@(gd_command)` verbs,
  which on a ticking class are tick-scheduled and replayed by construction
  (see "Discrete verbs on the lane").
- **Engine physics can't re-step.** Predicted movement must be query-based
  kinematics; a rigid body can be sim-lane state only if you own its
  integration in the step proc. This is the same line every Godot rollback
  system draws. And be precise about what a cast may TOUCH: an engine
  ray/shape cast is re-runnable only against STATIC geometry (walls, the
  arena), because a replay queries the physics server's CURRENT node poses:
  a cast that can hit another entity's collider reads the latest frame,
  not the replayed tick, and mispredicts every time bodies move. Entity-vs-
  entity tests belong in Odin against the tracked structs' own fields (the
  examples' overlap checks are all field math for exactly this reason).
- **Reading delta-lane fields in a tick is legal, and a mispredict source
  at their change edges.** A replay sees the field's CURRENT value, not the
  value it held at the replayed tick, and a client learns the change a
  transit late (quickdraw's `if self.hp <= 0` gate predicts a step the
  server refused around every death; the glide eats the pop). Fine when
  the edge is rare; mirror the fact into a predicted field when it's hot.
- **Watched entities render in the past** (`watch_delay`), just like owner
  streams: the two-timelines discipline changes shape, but it doesn't vanish.
  Your own avatar is the one thing that never waits.
- **Present after frame, dress after present.** `lane_present` writes
  PRESENTATION values into the fields (watched interp, own-avatar glide);
  anything that reads sim truth from fields must run inside the tick procs
  or the Step_Proc, not after `lane_present`. The ledger is always the sim
  truth if you need it out-of-band.

## Implementation and test coverage

The repository currently implements the input pipeline, ledgers, snapshots,
reconciliation, lane driver, lag compensation, watched interpolation,
render-error smoothing, possession, predicted spawns, tick and world facts,
multiple input classes, generated authoring, and the `play/sim` blocks.

`tests/kitsim` covers convergence under loss and blackout, input-class routing,
glide versus snap behavior, and fact timing. `tests/repgen` covers generated
contracts. Quickdraw and Speedball add multi-process acceptance tests for the
main competitive paths.

This is not a claim of arbitrary scale. Declarative input constraints, unified
traffic budgets and authority ingress, protocol-wide payload ceilings,
decoder/property corpora, per-recipient snapshot budgets, AOI, and ack-safe
sparse snapshots are implemented. Facts are capped at
4 KiB, command arguments at the action-policy bound, input packets at 32 KiB,
and every sim rider remains inside the session's 256 KiB app-message / 1 MiB
packet envelope. The benchmark-backed supported starting points are published
by `network_profile_envelope` and documented in [profiles](profiles.md); measure
your game logic and engine work before raising them.

See also: [net](net.md) (whose shared substrate layer of wire, descriptors,
blend math, and tick this lane is built on), [session](session.md)
(identity and everything reliable), [play](play.md) (the coop shelf:
Puppet is that model's physics answer, `play/sim` is this one's).
