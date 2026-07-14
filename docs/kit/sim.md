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

Tag the state, declare the input struct by USING it, mark the step:

```odin
Runner :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"replicate,predict,interp"`,
	vx, vy: f32 `gd:"replicate,predict"`,
	hp:     i32 `gd:"replicate"`, // delta lane: never resimmed, wire-fresh
}

Runner_Input :: struct { // no tag — discovered from the tick proc's signature
	move:    [2]i8,
	buttons: u8,
}

@(gd_tick)
runner_tick :: proc(self: ^Runner, input: Runner_Input, lane: ^ksim.Lane) {
	self.vx = f32(input.move[0]) * SPEED // single-player-looking, fixed dt implicit
	self.x += self.vx
}
```

scriptgen emits the rawptr thunk and `runner_sim_set`, POD-asserts the input
struct (it crosses the wire raw), and refuses a tick with a return value or
without `predict` fields at build time. Accepted shapes: `(self)`,
`(self, input)`, `(self, lane)`, `(self, input, lane)` — a pointer param is
the lane, a value param is the input. The wiring left to the game:

```odin
// beside your session wiring, once:
ksim.lane_init(&self.lane, &self.ses, size_of(Runner_Input))
ksim.lane_set_sim(&self.lane, self, game_sample, nil) // step proc optional now

// where sim entities are born on this peer (factory / Ev_Spawned):
ksim.lane_track_set(&self.lane, id, runner, &runner_sim_set, owner)

// once per frame, beside session_tick:
ksim.lane_frame(&self.lane, delta)   // drive: tick, predict, send, reconcile
ksim.lane_present(&self.lane, delta) // then smooth watched avatars (clients)
```

`game_sample` reads the device into your input struct — the one place that
touches hardware, never called during a resim:

```odin
game_sample :: proc(user: rawptr, tick: u64, dst: rawptr) {
	in := cast(^Runner_Input)dst
	in.move = quantize_axes()
	in.buttons = read_buttons()
}
```

Entity thunks run every simulated tick — live and replay identically, in
track order — each fed its owner's input (`nil` coasts: an inputless entity
type, or a remote player on a client whose truth is already inbound). The
optional `Step_Proc` runs AFTER entity ticks as the world pass: cross-entity
work like spawning a predicted projectile or resolving a contested pickup.
One input TYPE per lane, by design — the wire ships one input blob per
player per tick; compose per-entity intent into the one struct.

For hand-driven setups (tests, generated-code-free games) `lane_track` +
a Step_Proc that loops entities via `lane_input` remains fully supported —
the thunks are sugar over exactly that.

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

## Lag compensation

```odin
// HOST, inside game_step, validating a hitscan from `shooter`:
judged_at := ksim.lane_rewound(&g.lane, shooter, g, proc(user: rawptr) {
	g := cast(^Game)user
	g.hit = trace_shot(g) // every OTHER entity is wound back to what the
	                      // shooter's screen showed; the shooter's own stay live
})
```

The rewind tick is **derived, never trusted**: every input arrives in a
packet that also carries the sender's snapshot ack, and the buffer tags each
input with the ack it TRAVELED WITH — so when the server executes the input
that pulled the trigger, it knows exactly which batch the shooter held at
aim time (a fact: it is literally their delta baseline), and their screen
draws watched entities `watch_delay` ticks behind that. Rewind =
`view_tag − watch_delay`: the world as DRAWN at the moment of aiming, not
the shooter's freshest ack (which advances a whole lead-plus-transit between
sampling and adjudication — quickdraw's acid caught that one live). Clamped to `rewind_max` (default
~250 ms) — the favor-the-shooter ceiling; past it a laggy shooter aims at
the live world like everyone else. The cost of the favor is the classic one:
occasionally you are hit just after reaching cover. That is the trade this
model makes; the coop model makes the opposite one.

## Tuning

`Lane_Config` (zero = the default): `hz` 60 · `snap_every` 3 (20 Hz batches)
· `margin` 2 (target input headroom, ticks) · `slots` 128 (ledger depth) ·
`redundancy` 8 · `rewind_max` hz/4 · `watch_delay` 2×snap_every ·
`smooth_halflife` 0.063 s · `smooth_cut` 0 (never cut; set it in world
units for teleport-heavy games). Running tallies for a netgraph:
`lane.stat_reconciles`, `lane.stat_resims` (a resim burst is a latency
event worth drawing).

## Gotchas

- **Step procs re-run.** Anything a step reads must be ledgered or derived
  from the tick — `knet.now_s()` in a step proc is a mispredict factory.
  Sample devices in `game_sample` only.
- **Predicted fields are the resim's property.** Don't mutate them outside
  the step proc on a client — the next reconcile will erase your write (that
  is its job). Server-side discrete mutations of predicted state belong in
  the step (tick-scheduled), not in `@(gd_command)` procs — commands keep
  owning the delta-lane fields.
- **Engine physics can't re-step.** Predicted movement must be query-based
  kinematics (ray/shape casts are stateless and re-runnable); a rigid body
  can be sim-lane state only if you own its integration in the step proc.
  This is the same line every Godot rollback system draws.
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
input pipeline, ledgers, snapshots, reconcile, lane driver, lag comp,
watched interp, render-error smoothing, possession, and the
`@(gd_tick)`/`predict` codegen — 26 kitsim tests (including
loss-and-blackout convergence acids and the glide-vs-snap assertion) plus
the repgen contract pins. Still to come: `@(gd_tick)` composition through
embedded blocks (a `play`-style block contributing fields AND its tick
step), commands-as-tick-inputs for entities that mix lanes, and a worked
example game.

See also: [net](net.md) (the shared descriptor core), [session](session.md)
(identity and everything reliable), [play](play.md) (Puppet — the coop
model's physics answer, and where sim-lane smoothing will land).
