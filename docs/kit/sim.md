# kit/sim — the server-authority resim companion

`kit/sim` is the OTHER netcode model, built as a companion to the friendslop
toolkit rather than a replacement: **one authority (the server), inputs-only
up, tick-stamped snapshots down, rollback + resimulation on clients.** It is
for the games the coop model deliberately isn't — contested, cheat-resistant,
twitch-fair. Movement no longer trusts the client's position; the server
simulates everything from inputs, and your shots are judged where **you**
saw the target (lag compensation).

Like kit/net it is engine-free — every piece runs headless in
`tests/kitsim`, including a two-session convergence acid over an in-memory
wire. The design and its history live in the project knowledge doc
`server-authority-resim-companion`.

## The mental model

**A third lane, not a new world.** A field's tag picks its authority lane,
and the lanes are disjoint at the mask level (`diff_mask` skips the other
two):

| tag | authority | wire | applied by |
| --- | --- | --- | --- |
| `replicate` | host | reliable deltas | on arrival |
| `replicate,owner` | owning peer | unreliable stream | interpolated in the past |
| `replicate,predict` | server sim | tick-stamped snapshots | rollback + resim |

Everything the session gives you — identity, roster, reconnect, spawns,
blobs, stats, chat, the command loop for discrete verbs — keeps working
unchanged. Only the contested fast state (movement, projectiles) opts into
the sim lane, per field. `owner` and `predict` on one field is a build
error: a field has one writer.

**The tick IS the simulation.** Unlike the coop model (gameplay at frame
rate, the net tick paces the wire), sim-lane gameplay lives in a fixed-rate
step proc (default 60 Hz) that is a pure function of predicted fields +
inputs. The server runs it authoritatively; clients run the SAME proc
speculatively, a few ticks ahead of the server, so their own avatar answers
the stick instantly.

**Mispredictions self-heal; determinism is NOT required.** When
authoritative state for tick T arrives, the client memcmps it against what
it predicted at T. Equal (the overwhelmingly common case): nothing happens —
steady state costs a memcmp. Different: the predicted set rewinds to truth
and the step proc replays T+1..now from the input ledger. The server's word
is always final, so approximate re-execution suffices — no fixed-point math,
no cross-machine float anxiety. The one honest rule: **step procs may touch
predicted fields, `lane_input`, and per-tick derivables — never wall clocks,
node state, or un-ledgered randomness.**

**The loss story is redundancy, nothing retransmits.** Every input packet
carries the last ~8 unacked inputs; every snapshot batch supersedes the one
before it. A genuinely lost input (a burst longer than the window) means the
server briefly holds the player's last input and the client reconciles the
difference away — degradation, not desync.

## Write the entity, not the netcode

Tag the state, declare the input struct by USING it, mark the step — and
return FACTS. The name-paired halves consume them, and the generated thunk
holds every role gate:

```odin
Runner :: struct {
	owner:   gd.Node2d,
	net_id:  knet.Net_Id,
	x, y:    f32 `gd:"replicate,predict,interp"`,
	vx, vy:  f32 `gd:"replicate,predict"`,
	fire_cd: u16 `gd:"replicate,predict"`, // even the trigger is predicted state
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

// AUTHORITY only (never resims): the cross-entity consequence.
runner_tick_then :: proc(g: ^Game, self: ^Runner, by: knet.Player_Id, fired: bool) {
	if fired { adjudicate_shot(g, self, by) } // lane_rewound lives here
}

// THIS PLAYER's live pass only (never a resim replay): presentation.
runner_tick_fx :: proc(g: ^Game, self: ^Runner, fired: bool) {
	if fired { muzzle_flash(self) } // answers the click NOW, at any latency
}
```

scriptgen emits the rawptr thunk (with the `is_host` / `mine` / `resimming`
gates you never write), `runner_sim_set`, POD-asserts the input struct, and
refuses mispaired halves or a tick without `predict` fields at build time.
Tick shapes: `(self)`, `(self, input)`, `(self, lane)`, `(self, input, lane)`
— a pointer param is the lane, a value param is the input; both halves also
accept game-less (self-first) shapes.

The game's own half — the device read and the world pass — is typed and
attributed the same way. `@(gd_sample)` marks the ONE place that touches
hardware (never called during a resim); scriptgen pins its input struct to
the ticks' at build time, so sampling into the wrong struct can't compile.
`@(gd_step)` is the world pass, AFTER entity ticks. There are two slots, and
a class may fill one of each: a bare `@(gd_step)` runs EVERYWHERE (live and in
every resim, on every peer — pure-sim contact), and `@(gd_step="authority")`
runs on the HOST alone, once per real tick (the authority never resims). A
game needing both keeps them SEPARATE instead of folding `if is_host` into one
pass — the last role gate a world pass used to open with, held by the lane:

```odin
@(gd_sample)
game_sample :: proc(self: ^Game, tick: u64, input: ^Runner_Input) {
	input.move = quantize_axes()
	input.buttons = read_buttons()
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

The wiring left to the game, ALL of it — `<class>_lane_init` is generated,
carrying the input size, the typed procs, and each pass wired to its slot:

```odin
// ready(), beside boot_attach + boot_entities:
game_lane_init(self, &self.lane, &self.ses) // cfg = ksim.Lane_Config{...} to tune
kboot.boot_lane(&self.boot, &self.lane)
```

`boot_lane` makes the boot drive everything: the generated entity table
carries each ticking class's `Sim_Set`, so the factory tracks and untracks
entities on the lane itself; `boot_pump` runs `lane_frame` + `lane_present`
every frame and forwards `Ev_Owner_Changed`.

Entity thunks run every simulated tick — live and replay identically, in
track order — each fed its owner's input (`nil` coasts: an inputless entity
type, or a remote player on a client whose truth is already inbound). The two
optional world passes run AFTER entity ticks: the everywhere pass for pure-sim
cross-entity work (contact), the authority pass for genuinely WORLD-shaped
authority work (respawn queues, wave directors). One
input TYPE per lane, by design — the wire ships one input blob per player
per tick; compose per-entity intent into the one struct. Quantize by
DECLARING the quantized type — what the struct holds is what crosses the
wire (quickdraw's aim is a `u16` turn fraction, ~0.005° resolution, with a
two-line codec pair at the sample/tick boundary; there is no per-field wire
machinery on inputs, on purpose — the blob memcpys). A world pass that
reads inputs takes the typed view:

```odin
input, drives := ksim.lane_input_of(&g.lane, owner, Kicker_Input)
if !drives {continue} // a pair this peer doesn't simulate
```

For hand-driven setups (tests, generated-code-free games) `lane_init` +
`lane_set_sim` (rawptr sample + the two `Step_Proc`s, everywhere then
authority) + `lane_track` / `lane_track_set` + explicit
`lane_frame`/`lane_present` calls remain fully supported — the generated
wiring and the thunks are sugar over exactly that.

## The predicted shelf — godot:play/sim

Blocks compose on this lane the way `godot:play`'s compose on the coop one:
embed a field and the entity gains the block's predicted state (its
`gd:"replicate,predict"` fields flatten into the descriptor) AND its
`@(gd_tick)` step, hoisted to run after the entity's own tick — the entity
writes intent, blocks integrate. The shelf ships the shapes the showcase
games kept hand-rolling; the blessed alias is `psim`:

```odin
import psim "godot:play/sim"

Kicker :: struct {
	...
	run:  psim.Mover, // momentum movement: the tick writes run.tx/ty, the block integrates
	kick: psim.Cool,  // predicted cooldown: psim.ready(&k.kick, KICK_CD) gates and re-arms
}
```

- **`psim.Cool`** — the predicted cooldown, and play.Pace's TWIN NOUN: the
  same three verbs (`due` / `arm` / `ready`), the other timeline. Pace holds
  a deadline against a clock you pass in (host scratch, never on the wire);
  Cool counts itself down inside the sim, so a revolver's cadence or a
  kick's recovery answers the click at any latency and replays exactly.
- **`psim.Mover`** — momentum 2D movement (law #4: inertia is the
  extrapolation smoother). Intent-through-fields: the entity's tick writes
  the velocity it WANTS every tick and the block approaches it — `accel = 1`
  collapses the approach to an exact snap for twitch games. Config (accel,
  bounds) is law, not state: plain untagged fields, stamped at spawn on
  every peer, never on the wire.
- **`psim.Roller`** — the contested rolling body, laws #5 and #6 packaged:
  self-simulating friction, a hard speed ceiling, and energy-eating wall
  bounce. The game keeps the consequences — speedball's ball detects goals
  off the roller's clamp (a crossing lands exactly ON the line for one
  tick) and predicts its own reset.

The namespaces police themselves: embed a predict-tagged block from the
root `godot:play` shelf and scriptgen errors it toward `play/sim`; embed a
`play/sim` block that carries no predict fields and it errors back.
Game-local blocks compose however they like — the lint is the SHELF's
contract, so `psim.` at a call site always means "this state resims".

## What the lane does underneath

- **Anchoring.** A client neither ticks nor sends until the first batch
  names the server's tick, then adopts the truth outright and starts a
  couple of ticks ahead. From there the clock only BENDS: a ±2% timescale
  nudge (beneath perception) grows or shrinks the lead toward the target
  headroom, fed by the batch header's input-ack echo. No clock sync
  dependency, no tick jumps, no pops.
- **Snapshots delta against an ACK, not a guess.** The server deltas every
  entity's predict set against the newest batch the client confirmed
  applying in full; a client only acks a batch when every row landed. An
  unknown id (spawn in flight) skips by length and stalls the ack; a missing
  baseline falls back to a per-entity full row. Self-healing in both
  directions with no keyframe-request message.
- **Predict-self by construction.** Your own entities are ledgered and
  reconciled; everyone else's are *watched* — truth applies as it arrives,
  and `lane_present` renders them on a delayed watch clock, blending
  bracketing batches per field (`Lerp_Kind`, same as streams — and the same
  clamp-and-hold rule: never extrapolate).
- **Authority snaps, the eye glides.** When a reconcile corrects your
  avatar, the SIM state snaps to truth (the ledger records it), but
  `lane_present` draws sim + a decaying error (63 ms half-life, the puppet
  constant) on float `interp` fields, so a correction is a lean, not a
  teleport. Past `smooth_cut` the error zeroes and the snap shows —
  smoothing a deliberate cut looks worse than the cut. This costs the game
  NOTHING: fields hold sim truth during `lane_frame` and presentation truth
  after `lane_present`; the lane re-seeds sim state from the ledger before
  ticking, so dressing nodes from fields keeps working unchanged.
- **Events, not callbacks.** Packet handlers only file bytes; every call
  into game code happens inside `lane_frame` on your stack.
- **Possession is one call.** `lane_set_owner(l, id, player)` on every peer
  (forward the session's `Ev_Owner_Changed`): the authority flips whose
  input buffer drives the entity (and whom rewound queries spare); a client
  swaps the entity between predicted and watched, seeding the new ledger
  from the freshest received truth.

## The contested object

Predict-self leaves shared fast objects — the ball, the crown, the flag —
watched, which means rendered in the past and touchable only after a round
trip. `@(gd_tick = "contested")` is the middle path (the Rocket League
model): **every peer predicts this entity**, so contact with it resolves on
each screen's own timeline instantly. The server's simulation stays the only
truth; a wrong guess (the opponent you render in the past touched it first)
reconciles and glides like any other mispredict. The costs are honest and
you opt into them per entity: resim CPU on every peer, and exactly that
mispredict class. Design the tick so consequences that must not double-fire
stay in `_then` (authority) — but keep RESETS in the tick itself where they
predict: speedball's goal detection and kickoff freeze live in the ball's
own tick, so every screen snaps the ball home the instant its simulation
crosses the line, while the score lands authority-side. Contact belongs in
the world pass, applied only to the pairs this peer HAS INPUTS for — yours
on your screen, everyone's on the server; a remote touch reaches you as the
server's word, never as a local guess.

Two rules keep the pattern honest:

- **Contested entities must be SELF-SIMULATING** — a ball integrates its own
  motion, which is what makes every peer's between-batch prediction good. An
  input-driven avatar would coast frozen client-side and fight corrections
  forever.
- **Presentation follows the CLAIM.** A contested entity's sim runs on your
  predicted timeline, but its PRESENTATION is claim-weighted: call
  `lane_claim(l, id)` every tick YOUR sim influences it (the world pass's
  contact block), and the entity draws from your predicted pose — instantly,
  legitimately front-running the server. Unclaimed, it draws the WATCHED
  view, so a remote touch moves it beside the remote avatar that made it
  instead of a whole lead early (the mixed-timelines artifact you will
  otherwise ship: predicted ball, past-rendered players, one screen). The
  claim rises instantly, decays over ~a quarter second — net.md's "did MY
  simulation cause this?" boolean, asked continuously.
- **Or go all the way: PREDICT-WORLD** (`Lane_Config.echo_inputs`, the
  Rocket League model — what speedball ships). Batches echo every player's
  held input; mark the AVATARS `contested` too and every peer ticks every
  entity — remote ones extrapolated with held inputs — so the whole scene
  lives on ONE predicted timeline. No claim dance at all (contested
  presentation is simply the predicted pose), remote touches play out beside
  the avatars making them, immediately. The price: resim on nearly every
  batch (held inputs drift — small, constant, glided corrections on remote
  avatars instead of delayed-but-accurate ones) and a few echo bytes per
  player per batch. Pick per game: predict-world for contact-driven games,
  predict-self + lag comp where accurate rendered targets matter (quickdraw
  keeps hitscan honest by NOT extrapolating its targets). The claim-mode
  rules below serve games that predict only the object.
- **The claim follows the CAUSE, and releases when the cause ends.** Your
  kick's whole FLIGHT is your simulation's consequence — keep claiming while
  the ball is fast from your touch, and release when it SLOWS (the two
  timelines nearly coincide, so the handback is invisible) or when an
  opponent contests it. Releasing on mere distance pulls your own kick
  backward mid-flight: the fade target is the watched view, sitting
  speed × timeline-skew behind a fast ball, and blending across that gap
  cancels its forward motion on your screen (speedball shipped this bug for
  one playtest; its claim-retention block is the reference).

See `examples/speedball` (and read it
against `examples/slopball` — the same game on the coop model — to choose).

## Lag compensation

```odin
// HOST, judging a hitscan from `shooter` (inside a _then or the world pass):
judged_at := ksim.lane_rewound_begin(&g.lane, shooter)
g.hit = trace_shot(g) // every OTHER entity is wound back to what the
                      // shooter's screen showed; the shooter's own stay live
ksim.lane_rewound_end(&g.lane)
```

Write the hit test inline between begin and end — no context struct across a
rawptr. The pair must not nest, and nothing may track/untrack entities in
between. `lane_rewound(l, shooter, user, query)` is the same judgment as a
callback, for the places a proc value reads better (tests, table-driven
weapons).

The rewind view is **fact-anchored and interpolated**: every input arrives
in a packet that also carries the sender's snapshot ack and its render
offset, and the buffer tags each input with both — so when the server
executes the input that pulled the trigger, it knows which batch the
shooter held at aim time (a fact: it is literally their delta baseline) and
where inside it their watch clock was drawing (a claim, clamped inside the
window the ack proves). The rewound scope then BLENDS the same bracket pair
the shooter's screen blended (`predict_blend` over the truth ledger) — not
the shooter's freshest ack (which advances a whole lead-plus-transit
between sampling and adjudication), and not a quantized single tick (which
cost near-tangent shots against the watch clock's interpolation).
Quickdraw's duel acid caught both live, and measures the result: most
aimable shots land at 240 ms RTT. Clamped to `rewind_max` (default
~250 ms) — the favor-the-shooter ceiling; past it a laggy shooter aims at
the live world like everyone else. The cost of the favor is the classic one:
occasionally you are hit just after reaching cover. That is the trade this
model makes; the coop model makes the opposite one.

## Discrete verbs on the lane

A verb is everything an input bit isn't: it carries arguments, it can be
REJECTED, and it fires once. On a ticking class, `@(gd_command)` keeps the
exact coop authoring shape — predicate-then-mutate, name-paired `_then` on
the authority — but executes INSIDE the tick pipeline, because the coop
loop's optimistic-apply/revert and the lane's rewind/replay must never
share a baseline:

```odin
@(gd_command)
gunner_buy :: proc(self: ^Gunner, item: u8) -> bool {
	if self.gold < price_of(item) {return false}
	self.gold -= price_of(item) // delta lane: reverted on rejection
	self.gear = item            // predicted: replayed by every resim
	return true
}

// anywhere with the lane in reach (a key edge, a bot):
gunner_buy_cmd(&g.lane, g.me_gun, ITEM_BOOTS)
```

The generated wrapper schedules the verb at your next tick and ships it
tick-stamped on the reliable channel — the client's lead exists precisely
so it arrives before the server simulates that tick (a lag spike executes
at the server's next tick instead; history is never rewritten). Your screen
runs the verb ONCE at that tick; resims re-apply its predicted-field
footprint rather than re-running it (a replayed predicate would read the
gold it already spent). The server executes at the stamped tick — verbs run
after entity thunks, before the world pass — and answers with a verdict: a
rejection unwinds the delta-lane writes on the spot and the next reconcile
scrubs the predicted ones, the same glide as any mispredict.

You may command entities you OWN — and CONTESTED ones, which live on your
prediction ledger by construction: a spike on the ball speculates exactly
like a touch does, any seat may issue it, and two same-tick verbs run in
execution order with the predicate arbitrating (speedball's spike is the
worked example). Watched entities can't speculate — command them from the
authority, or promote them to contested. Bursts are fine: verbs QUEUE per
entity, and a rejection unwinds the delta-lane speculation chain in order
without disturbing the survivors. The wrapper returns whether it SCHEDULED
— the verdict is state (watch the fields, or the authority's `_then`).

Replays re-apply what a verb WROTE (recorded bytes), not what it meant — so
prefer absolute mutations (`gear = item`) in the verb itself. When the
effect is genuinely relative (an impulse, a knockback), give the verb an
**`_apply` half**: `<verb>_apply(self, <wire args>)` holds the
predicted-field effect, and resims RE-RUN it with the ledgered args against
corrected state — exact where the byte patch can't be. With an apply half,
the verb keeps its hands off predicted fields: the predicate and the
delta-lane writes stay execute-once.

```odin
@(gd_command)
ball_spike :: proc(self: ^Ball, px, py: f32) -> bool {
	return self.hold == 0 && in_reach(self, px, py) // verdict + (any) delta writes
}
ball_spike_apply :: proc(self: ^Ball, px, py: f32) {
	self.vx += ... // RELATIVE — re-run by every resim, never re-pinned
}
```

## Predicted spawns — a fired projectile

A verb mutates an entity that already exists; a **projectile** is a NEW one,
and it has to leave your muzzle the instant you fire — before the authority's
real bullet is even on the wire. That's a client-PREDICTED spawn: a local
entity, flying its own arc, born-gated and reconciled like your avatar, that
the authority's spawn REKEYS a round trip later (never a second bullet).

The projectile is an ordinary `@(gd_tick)` entity (inputless — it self-
integrates, like the ball) with an `entity=Bullet:id` scene. The fire is one
call in the tick's name-paired halves — no role branch, because `_then` is
always the authority and `_fx` always the owner's client:

```odin
@(gd_tick) // the flight: pure predicted state, `landed` routes to the splash
bullet_tick :: proc(self: ^Bullet) -> (landed: bool) { ...self.x += self.vx... }

gunner_tick_then :: proc(g: ^Game, self: ^Gunner, by: knet.Player_Id, lobbed: bool) {
	if lobbed { lob_bullet(g, self, by) } // AUTHORITY: the real spawn
}
gunner_tick_fx :: proc(g: ^Game, self: ^Gunner, lobbed: bool) {
	if lobbed { lob_bullet(g, self, g.ses.me) } // this CLIENT: the predicted one
}

lob_bullet :: proc(g: ^Game, gun: ^Gunner, owner: knet.Player_Id) {
	bp, bid := kboot.boot_fire_spawn(&g.boot, BULLET_TYPE, owner) // routes host/client
	b := cast(^Bullet)bp
	b.x, b.y, b.vx, b.vy, b.life = ... // the muzzle and the arc
	kboot.boot_fire_spawn_send(&g.boot, bid) // host announces; client no-ops
}
```

`boot_fire_spawn` routes: the authority gets a real net id
(`session_spawn_make`), this client a local predicted node under a provisional
id. Underneath: **born-tick gating** keeps the reconciles that land before the
spawn (the whole first round trip, the server running a transit behind) from
re-flying it from stale state; when the authority's `Ev_Spawned` arrives the
factory **matches** it to the projectile you predicted and rekeys — the same
node, its flight ledger intact, reconciled from there. A refused fire (or one
the authority never spawns) is culled and its node freed. Splash adjudicates
SERVER-SIDE on truth, not a rewind — a slow shot is meant to be dodged.
`examples/quickdraw`'s lob (right-click) is the worked proof; its native acid
lands the predicted bullet on the client's own tick, no round trip.

## Two entity kinds, two inputs

One player can drive two DIFFERENT entity kinds on the same tick — a walker and
a turret, an avatar and a vehicle, a duelist and a companion drone. Each kind
declares its own `@(gd_tick)` input struct, and each is an input **class**: the
client samples one per tick, ships one window per class on the single upstream
packet, and the host de-jitters each into its own per-player buffer. An entity's
tick reads only its own class — the two timelines never cross, and a reconcile
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
to register them all — `lane_init` carries the primary, `lane_add_input_class`
the rest. Nothing else changes: track each entity with its generated `Sim_Set`
as before, and the right input reaches the right tick everywhere (live, predict,
resim). A single-input game registers exactly one class and is byte-for-byte the
old wire.

Underneath: a `Lane` holds one ring per class the seat drives and the host holds
one buffer per (player, class); the batch's input ack is the MIN newest across a
player's classes, so the client leads enough for its most-starved input and
trims every ring by that floor. The one deliberate limit: **one driven entity
per class per player** — two entities of the *same* kind driven by one player
would share a window (give them distinct input structs, or compose their intent
into one). `examples/quickdraw`'s drone (a companion each duelist steers beside
their gunner) is the worked proof; its native acid predicts the drone on the
client's own tick and shows it sweeping its own steer while the gunner strafes
the other way — the two input classes, orthogonal, from one seat.

## Promoting a coop game

Because `predict` is a lane per FIELD, a friendslop game that grows
competitive ambitions migrates incrementally — no rewrite, no fork. The
worked diff is `examples/slopball` → `examples/speedball` (the same soccer
game on the two models); the checklist, per contested entity:

1. **Touch nothing session-shaped.** Identity, roster, chat, stats, spawns,
   saves, the doors, the factory — all of it rides both models unchanged.
   Chests, inventories, scores stay on the delta lane with their verbs.
2. **Retag the contested fast state.** `replicate,owner` (movement the peer
   owned) becomes `replicate,predict` — the field's writer changes from "its
   owner's stream" to "the server's simulation, predicted locally". Keep
   `interp` on drawn floats. The retag is the whole wire migration.
3. **Move its writes into a `@(gd_tick)`.** Frame-rate mutation becomes a
   fixed-rate pure step: (predicted fields, input) → predicted fields. This
   is the one honest rewrite — and where engine physics must become
   query-based kinematics (slopball's `play.Puppet` ball became speedball's
   forty lines of bounce arithmetic; see Gotchas).
4. **Compose the input struct** from what the entity used to read off the
   devices per frame, and sample it in `@(gd_sample)` — the one place that
   still touches hardware.
5. **Sort the consequences.** Cross-entity outcomes move to `<tick>_then`
   (authority), local presentation to `<tick>_fx` (live pass). Discrete
   verbs on delta-lane state keep their `@(gd_command)`s.
6. **Delete the authority workarounds.** Whatever arbitrated "who simulates
   this" on the coop model goes whole — speedball's diff deletes slopball's
   entire seat-grant machinery (host.odin's proximity arbitration): the
   server simulates everything, and `contested` + `lane_claim` answer the
   feel questions the seat used to.
7. **Wire once:** `<game>_lane_init(self, &self.lane, &self.ses, cfg)` +
   `kboot.boot_lane(&self.boot, &self.lane)`, and cross entities off one at
   a time — a hybrid game is a supported end state, not a transition.

What you buy: positions are no longer client-trusted (the cheat-resistance
motive), and lag-compensated hit validation becomes available. What you pay:
the fixed-tick authoring contract for exactly the entities you promote, and
a server that simulates them. [Timelines](timelines.md) is the model-choice
guide if you are deciding rather than migrating.

## Tuning

`Lane_Config` (zero = the default): `hz` 60 · `snap_every` 3 (20 Hz batches)
· `margin` 2 (target input headroom, ticks) · `slots` 128 (ledger depth) ·
`redundancy` 8 · `rewind_max` hz/4 · `watch_delay` 2×snap_every ·
`smooth_halflife` 0.063 s · `smooth_cut` 0 (never cut; set it in world
units for teleport-heavy games) · `tolerance` 0 (exact reconcile; set it in
world units so continuous held-input drift under the line rides uncorrected —
predict-world's anti-churn). Running tallies for a netgraph:
`lane.stat_reconciles`, `lane.stat_resims` (a resim burst is a latency
event worth drawing).

**Per-field reconcile + glide knobs.** The lane values are defaults; a single
float field can override each on its tag, so a fast contested object and a
precise avatar share ONE lane with different behavior:

- `slack=N` (world units) overrides `tolerance` — the drift this field rides
  before a reconcile (float-only: discrete predicted state always reconciles
  exactly, a differing byte is a real event).
- `glide=N` (seconds) overrides `smooth_halflife` — how slowly a correction on
  this field glides back (a slower glide reads smoother).
- `cut=N` (world units) overrides `smooth_cut` — the error past which this
  field is a teleport and SNAPS. The snap stays entity-coherent: any field over
  its own cut snaps the whole pose (smoothing a cut looks worse than the cut).

`glide=`/`cut=` are render-error knobs and need a `predict,interp` float field
(a non-interp predicted field snaps on reconcile, nothing to glide); `slack=`
needs a `predict` float. scriptgen rejects each on the wrong field, spelled out.

## Gotchas

- **Step procs re-run.** Anything a step reads must be ledgered or derived
  from the tick — `knet.now_s()` in a step proc is a mispredict factory.
  Sample devices in `game_sample` only.
- **Predicted fields are the resim's property.** Don't mutate them outside
  the tick pipeline on a client — the next reconcile will erase your write
  (that is its job). Discrete mutations go through `@(gd_command)` verbs,
  which on a ticking class are tick-scheduled and replayed by construction
  (see "Discrete verbs on the lane").
- **Engine physics can't re-step.** Predicted movement must be query-based
  kinematics (ray/shape casts are stateless and re-runnable); a rigid body
  can be sim-lane state only if you own its integration in the step proc.
  This is the same line every Godot rollback system draws.
- **Reading delta-lane fields in a tick is legal — and a mispredict source
  at their change edges.** A replay sees the field's CURRENT value, not the
  value it held at the replayed tick, and a client learns the change a
  transit late (quickdraw's `if self.hp <= 0` gate predicts a step the
  server refused around every death — the glide eats the pop). Fine when
  the edge is rare; mirror the fact into a predicted field when it's hot.
- **Watched entities render in the past** (`watch_delay`), just like owner
  streams — the two-timelines discipline mutates, it doesn't vanish. Your
  own avatar is the one thing that never waits.
- **Present after frame, dress after present.** `lane_present` writes
  PRESENTATION values into the fields (watched interp, own-avatar glide);
  anything that reads sim truth from fields must run inside the tick procs
  or the Step_Proc, not after `lane_present`. The ledger is always the sim
  truth if you need it out-of-band.

## Status and what's next

The runtime and the authoring surface are complete and proven headless:
input pipeline (single- or multi-class), ledgers, snapshots, reconcile, lane
driver, lag comp, watched interp, render-error smoothing, possession, predicted
spawns, the `@(gd_tick)`/`@(gd_sample)`/`predict` codegen, tick composition
through embedded blocks (the `play/sim` shelf above), and two worked example
games (quickdraw, speedball) with native duel acids — the kitsim tests
(including loss-and-blackout convergence acids, the per-class routing
fingerprint, and the glide-vs-snap assertion) plus the repgen contract pins
hold all of it.

See also: [net](net.md) (the shared descriptor core), [session](session.md)
(identity and everything reliable), [play](play.md) (the coop shelf —
Puppet is that model's physics answer, `play/sim` is this one's).
