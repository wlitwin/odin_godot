# kit/combat — health, abilities, effects, projectiles

Reach for `kit/combat` when entities need hp that goes down, abilities with cooldowns and
costs, buffs/debuffs on a clock, or projectiles that must feel instant on the shooter's
screen while only the host deals damage. It also auto-publishes damage/kill/death tallies
into the [session](session.md) stat registry.

**Lane compatibility: COOP.** The wire halves here — `Predicted_Hp` keyed to delta
confirmation, host-validated hits, `fire_announce`/tracers — are the coop lane's model in
mechanism and vocabulary. A [sim-lane](sim.md) game expresses the same ideas natively
instead: hp as a `predict` field, hits as verbs judged under [lag comp](sim.md), fired
shots as predicted spawns or declared facts (sim.md says why tracers are superseded by
projectile *entities* there). The pure math (range/cone checks, damage arithmetic) is
sim-safe anywhere. Whether the `Cooldowns`/ability bundles can ride a sim snapshot
descriptor is an OPEN question — unverified today; don't assume it.

## Mental model

Combat state is **plain replicated fields on your entity** — `hp: i32`, `cds: [4]u16`,
`fx: [4]Effect` — riding the [kit/net](net.md) delta walk. kit/combat is the *operations*
on them: deterministic, allocation-free, engine-free, because they run inside predicted
commands and host ticks — client and host execute the same gates from the same bytes.
Projectiles are **not entities**: the shooter's cast is predicted (cost and cooldown bite
instantly), everyone draws local visuals from the same sim math, and only the *host's*
sim deals damage — peer-owned visuals, host-validated hits.

## Health and abilities

```odin
// The scalar damage core — THE one corpse-guarded clamp, generic over the
// game's hp integer. `dealt` is what actually landed (0 on a corpse — hit
// credit reads it); `died` reports the killing blow exactly once.
hurt :: proc "contextless" (hp: ^$T, dmg: T) -> (dealt: T, died: bool)
// Restore `amount`, clamped to `maximum`. Reviving a corpse is a heal from 0
// — whether that is ALLOWED is policy, gated by the caller.
heal :: proc "contextless" (hp: ^$T, maximum: T, amount: T)
// The died-only i32 convenience over `hurt`: clamps at zero, no double kills,
// no negative hp. hit and play.Health both delegate to the same `hurt` — one
// death definition for raw fields and blocks alike.
hit :: proc "contextless" (hp: ^i32, amount: i32) -> (died: bool)

Ability_Def :: struct {
	name:     string, // for ability bars / logs; kit/combat never allocates it
	cooldown: u16, // net ticks
	cost:     i32, // spent from whatever resource the game passes in
}
// The whole cast gate, shared by prediction and authority: ready + affordable
// -> pay and start the cooldown. Call from inside the ability's command proc.
ability_try :: proc "contextless" (cds: []u16, slot: int, def: Ability_Def, resource: ^i32) -> bool
ability_ready :: proc "contextless" (cds: []u16, slot: int) -> bool
// The authority's per-net-tick decay (clients receive it as deltas).
abilities_tick :: proc "contextless" (cds: []u16)

// The `cds: [N]u16 gd:"replicate"` field, packaged: embed it (`using cd:
// kcombat.Cooldowns(3)`) and the array replicates like a flat field, while
// cd_try/cd_ready/cd_tick forward to `cds[:]` so you never spell the slice.
Cooldowns :: struct($N: int) {
	cds: [N]u16 `gd:"replicate"`,
}
```

Defs are code constants (cavecrawl's `ROCK_ABILITY` has `cooldown = 20` — one second at
20 Hz). The predicted cast is one command proc, zero role branches (`spelunker.odin`):

```odin
@(gd_command = "predict")
spelunker_heal :: proc(self: ^Spelunker) -> bool {
	if self.hp <= 0 || self.hp >= MAX_HP {return false} // corpses and the hale need no bandage
	if !kcombat.ability_try(self.cds[:], 1, HEAL_ABILITY, &self.stamina) {return false}
	self.hp = min(self.hp + HEAL_AMOUNT, MAX_HP)
	return true
}
```

The verb that issues it pre-gates with `ability_ready` (`input.odin`) — a refused
prediction still rides the wire, so a key held at full hp would flood the host with doomed
commands. [kit/ui](ui.md)'s ability bar renders the same `cds` and defs.

> **Which layer to use — these helpers, or the `play` blocks?** This is one instance of
> the toolkit's TWO-LAYER rule, so here is the rule itself. **`kit` is mechanism and
> vocabulary**: contextless procs, wire formats, replication machinery, descriptor tables
> — no opinions about game feel, no replicated fields of its own. The litmus: *is this
> something a block calls?* **`play` is policy and composition**: blocks — structs games
> embed, carrying `gd:"replicate"` fields and name-paired generated hooks, with defaults
> that encode a stance. The litmus: *does it hold replicated state or generate hooks?*
> **The arrow points one way, play → kit, never the reverse** — a block delegates its
> mechanism down (`play.Ability`'s gate IS `kcombat.cast_gate`, `play.Health`'s clamp IS
> `kcombat.hurt`), so the two layers cannot drift on what "ready" or "a death" means.
> Across kit's own math cores the opposite rule holds — independence over sharing
> (combat/interact/ai each keep their own vocabulary, so a game can take any subset);
> sharing is the rule *up* the stack, independence *across* it.
>
> In practice: for the common cases the blocks are the default — **`play.Health`** instead
> of a raw hp field + `hit` (max, the damage edge, and frac for free), **`play.Ability`**
> instead of a `Cooldowns` slot + a hand-written command (the cast command is *generated*
> onto the embedding entity, the cooldown knob replicates, and the applied-vs-rejected
> semantics are already right). The def type is `kcombat.Ability_Def` at every layer —
> name and cost live in the game's declared table (a string can never ride a replicated
> blob, and a wire verb can't carry your resource pointer), which is also what feeds
> [kit/ui](ui.md)'s ability bar for block and slot-array games alike. Reach for the
> low-level forms when you're outside the blocks' shape: `ability_try` when a cast
> **spends a resource** at the gate (cost is a game gate — check it where you issue, and
> in the authority's hook, against the same def row), `Cooldowns(N)`'s slot array when
> slots are **dynamic** (castable inventory items indexed at runtime, where named block
> fields can't), and `hit`/`hurt` when hp lives somewhere a block can't (a transient, an
> off-entity pool). The examples split along history: cavecrawl/homestead show the
> low-level way (they predate the blocks and double as a view of the layer underneath);
> scrapyard shows the block way. New games: start with the blocks. See
> [kit/net — composing verbs from embedded blocks](net.md#composing-verbs-from-embedded-blocks).

## Status effects

One buff/debuff is 4 POD bytes, embedded as a fixed array (`fx: [4]Effect`); kind 0
(`EFFECT_NONE`) is the empty slot.

```odin
Effect :: struct {
	kind:  u8,
	power: i8,
	left:  u16, // ticks remaining
}
// Apply an effect: an existing one of the same kind REFRESHES (strongest
// power, longest clock); otherwise the first empty slot. False = all busy.
effects_add :: proc "contextless" (fx: []Effect, kind: u8, power: i8, ticks: u16) -> bool
// The authority's per-net-tick decay; a row clears on its LAST tick, expired
// slots zero back to empty. Underflow-guarded: a hand-written {kind, left = 0}
// row clears instead of wrapping into a 65535-tick immortal effect.
effects_tick :: proc "contextless" (fx: []Effect)
effect_of :: proc "contextless" (fx: []Effect, kind: u8) -> (Effect, bool)
```

## Projectiles: one sim, two jobs

The same math runs as the host's authoritative sim (damage) and as every peer's local
visual ([kit/fx](fx.md) tracers) — what you see is what the host computes, offset only by
latency.

```odin
Projectile :: struct {
	pos:  [3]f32,
	vel:  [3]f32, // per TICK, not per second
	left: u16, // ticks to live
}
Target :: struct {
	id:     u32,
	pos:    [3]f32,
	radius: f32,
}
// Advance one tick. False = time to remove it (this tick still happened —
// hit-test the swept segment before discarding).
projectile_step :: proc "contextless" (p: ^Projectile) -> (alive: bool)
// First target the tick's travel touches (earliest along the path wins, not
// nearest to the muzzle). `from` is the position BEFORE projectile_step.
projectile_hit :: proc "contextless" (from: [3]f32, vel: [3]f32, targets: []Target) -> (best: Target, ok: bool)
```

## The cast origin, and leash

The lesson: a moving shooter's projectile must carry the **owner-true origin**. Its
position is owner-streamed, so the host's copy lags a stream behind — launching from the
lagged copy makes the authoritative rock fly a different line than the one the shooter
*saw* hit. So the throw command carries the caster's own origin, leashed:

```odin
// leash clamps a CLAIMED point into a disc of radius r around anchor.
leash :: proc "contextless" (claimed, anchor: [3]f32, r: f32) -> [3]f32
```

Honest latency offsets pass untouched; teleport-cheese gets dragged back to arm's length.
Run it in the command proc itself: on the caster's own prediction `claimed == anchor` and
it is a no-op — no role branch (`spelunker_throw` in `spelunker.odin`).

## Fire announcements: everyone draws their own rocks

When the host confirms a cast it broadcasts a `Fire` over the session's app channel
([session.md](session.md)); every peer runs the same projectile sim locally for the
visual. The shooter starts theirs at cast time (zero RTT), everyone else on the
announcement — which rides the same one-way path as the eventual hp delta, so remote
impacts and health drops coincide.

```odin
Fire :: struct {
	shooter: knet.Player_Id,
	origin:  [3]f32,
	vel:     [3]f32, // per tick
	ttl:     u16,
	kind:    u8, // game-defined (which ability/visual)
}
fire_write :: proc(w: ^knet.Writer, f: Fire)
fire_read :: proc(r: ^knet.Reader) -> (f: Fire, ok: bool)
```

The plumbing is packaged — the fire lane defaults to `FIRE_TAG :: 1`, beside its tag
siblings (comms 0, xfer 2, sim 3); give the listener a home (a struct field; no package
globals, so parallel sessions never collide), and the guards every game hand-rolled are
the kit's problem now:

```odin
fire_announce :: proc(s: ^ksess.Session, f: Fire, tag: u8 = FIRE_TAG)   // HOST-ONLY (asserts)
fire_listen :: proc(fr: ^Fire_Route, s: ^ksess.Session, tag: u8 = FIRE_TAG)
fire_poll :: proc(fr: ^Fire_Route) -> (f: Fire, ok: bool)
fire_route_destroy :: proc(fr: ^Fire_Route)
```

`fire_announce` is the AUTHORITY's half — it asserts on a client (the receiver drop
below stays the security boundary; the assert is the teaching moment: a client calling
it would broadcast frames every receiver silently discarded). The listener is EVENTS,
NOT CALLBACKS: the handler only *files*, and the game drains with `fire_poll` each frame
on its own stack — the old `on_fire` callback ran game code mid-session-pump, the one
reentrancy hole in the subsystem. What lands in the queue is exactly "someone else's
rock — draw it" (the host's own copy, your own echo, and non-host authors are all
dropped):

```odin
// host, when the command hook confirms a cast:
kcombat.fire_announce(&self.ses, f)

// ready(), every peer:
fires: kcombat.Fire_Route   // a field on your game struct
kcombat.fire_listen(&self.fires, &self.ses)

// every frame, drain and draw (fire_route_destroy on exit):
for {
	f, ok := kcombat.fire_poll(&self.fires)
	if !ok {break}
	// draw their rock
}
```

Raw `fire_write`/`fire_read` stay public for games that need a different envelope.

Tick-paced code (cooldown decay loops, [kit/ai's director](ai.md)) should read the
session's own clock, `ksess.session_tick_no(s)`, not accumulate a counter — a
hand-rolled count silently diverges across resume/migration. The exception is a
**campaign clock** a game deliberately persists in its save blob (cavecrawl's
`host_ticks` gates respawns across saves): that one must be the game's, because the
session's tick is local to the session's lifetime.

## Predicted hp: the impact you saw, before the wire agrees

When your local rock visually contacts a body, the health you *display* may dip
immediately — but the replicated hp field is never touched (that is how phantom damage
stays impossible). The dip lives in an overlay:

```odin
Predicted_Hp :: struct {
	pending: i32, // damage shown locally but not yet confirmed by a delta
	basis:   i32, // the authoritative hp when the overlay was last squared
	expires: f64, // heal-back deadline (seconds, caller's clock)
}
PHP_TTL :: 0.6 // seconds a dip may outrun truth (a generous round trip)

php_note_hit :: proc "contextless" (ph: ^Predicted_Hp, hp_now: i32, amount: i32, now: f64)
php_display :: proc "contextless" (ph: ^Predicted_Hp, hp_now: i32, now: f64) -> i32
```

`php_note_hit` at visual contact, `php_display` wherever hp renders (`rocks.odin`,
`rock_impact`). When the authoritative drop lands, the overlay is consumed — no double
dip. If the host saw a miss, the overlay expires and the bar heals back: wrong for a
heartbeat, honest forever after. Dips never kill — `php_display` clamps to 1 while real
hp is positive, so corpses appear only on truth.

## Auto-published combat stats

```odin
Combat_Cols :: struct {
	damage: ksess.Stat_Col,
	kills:  ksess.Stat_Col,
	deaths: ksess.Stat_Col,
}
// Host, once at start: declare the standard combat columns (idempotent).
combat_columns :: proc(s: ^ksess.Session) -> Combat_Cols
// Host, at the point of impact. Self-damage tallies nothing but the pain.
credit_hit :: proc(s: ^ksess.Session, cols: Combat_Cols, attacker: knet.Player_Id, amount: i32)
// Host, on a killing blow.
credit_kill :: proc(s: ^ksess.Session, cols: Combat_Cols, attacker, victim: knet.Player_Id)
```

## Pools: one tick for a whole volley

Every game that host-sims projectiles ends up with the same loop — sweep the tick's segment
before stepping, remove on hit or expiry, don't corrupt the index while removing. `pool_tick`
owns those mechanics; your callbacks own the meaning:

```odin
Slug :: struct { p: kcombat.Projectile, dmg: u8, shooter: knet.Player_Id }
flying: [dynamic]Slug                 // a wrapper pool (or a bare [dynamic]kcombat.Projectile)

kcombat.pool_tick(&self.flying, self, slug_targets, slug_hit, nil)   // hit-testing pool
kcombat.pool_tick(&self.lobs, self, nil, nil, lob_splash)            // fly-out-and-splash pool
```

`targets` is called **per projectile**, not snapshotted — an `on_hit` that kills changes the
census for the next projectile in the same pool. A hit always removes (no pool in the dogfoods
pierces); `on_expire` is the fizzle's last word — a lob's splash *is* its expiry.

## Worked example: the host's tick flies the rocks

From `examples/cavecrawl/scripts/host.odin` (`cave_host_tick`); the full pattern — launch
on the command hook, announce the `Fire`, draw visuals per frame — is `rocks.odin`:

```odin
kcombat.abilities_tick(sp.cds[:])   // per spelunker
kcombat.effects_tick(sp.fx[:])
// per flying rock:
from := fl.p.pos
alive := kcombat.projectile_step(&fl.p)
if hit, hit_ok := kcombat.projectile_hit(from, fl.p.vel, targets[:]); hit_ok {
	kcombat.credit_hit(&self.ses, self.cols, fl.shooter, ROCK_DMG)
	if kcombat.hit(&dw.hp, ROCK_DMG) { cave_slay_dweller(self, victim_id, fl.shooter) }
}
```

## Gotchas

- **Cooldowns and effect clocks count NET TICKS**, not seconds — rate-agnostic by design.
  Only the authority decays them; clients see the countdown through replication.
- A cast raced against the last ticks of a cooldown may mispredict locally — the command
  still ships, and the host's answer stands. That is the whole model.
- `Projectile.vel` is **per tick**. Hit-test with the position *before* `projectile_step`,
  and test the segment even when it returns false — that tick still happened.
- Carry the owner-true cast origin and `leash` it; the lagged host copy makes witnessed
  hits miss.
