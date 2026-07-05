# kit/combat — health, abilities, effects, projectiles

Reach for `kit/combat` when entities need hp that goes down, abilities with cooldowns and
costs, buffs/debuffs on a clock, or projectiles that must feel instant on the shooter's
screen while only the host deals damage. It also auto-publishes damage/kill/death tallies
into the [session](session.md) stat registry.

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
// Apply damage: clamps at zero, reports the killing blow exactly once
// (hitting a corpse is a no-op — no double kills, no negative hp).
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
// The authority's per-net-tick decay; expired slots zero back to empty.
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
