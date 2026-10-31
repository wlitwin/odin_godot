# kit/combat — health, abilities, effects, projectiles

Use `kit/combat` to apply damage, check ability costs and cooldowns, maintain
timed effects, and simulate projectiles. Coop games can display a shot
immediately on the shooter's screen while the host decides damage. The package
also provides helpers for recording damage, kills, and deaths in the
[session](session.md) stat registry; the game calls them at impact and death.

The network examples here use coop replication: `Predicted_Hp` displays local
damage until an hp delta arrives, the host validates hits, and
`fire_announce` distributes projectile visuals. A [sim-lane](sim.md) game
instead schedules commands within ticks and can judge hits with
[lag comp](sim.md). Health may remain reliably replicated, as in Quickdraw;
state that must replay with a tick uses `predict` fields. Fired shots can use
predicted projectile entities or declared presentation events; see
[sim.md](sim.md).

Range/cone checks and damage arithmetic are pure and replay-safe. The
`Cooldowns` and ability bundles lack simulation-descriptor test coverage;
do not put them on the simulation lane without adding that coverage.

<a id="mental-model"></a>

## Replicated combat state and local projectiles

Declare combat state as ordinary replicated entity fields: `hp: i32`,
`cds: [4]u16`, and `fx: [4]Effect`. [kit/net](net.md) sends their changes as
deltas. The operations in `kit/combat` are deterministic, allocation-free, and
independent of Godot, so a predicted command and an authority tick apply the
same checks when given the same bytes.

In this coop pattern, projectiles are local simulations rather than replicated
entities. The shooter predicts the cast's cost and cooldown immediately. Each
peer draws its own visual with the same projectile math, while the host's
simulation validates hits and applies damage.

## Health and abilities

```odin
// Apply damage using the game's hp integer type, clamping at zero.
// `dealt` reports applied damage (0 on a corpse) for hit credit;
// `died` reports the killing blow exactly once.
hurt :: proc "contextless" (hp: ^$T, dmg: T) -> (dealt: T, died: bool)
// Restore `amount`, clamped to `maximum`. Reviving a corpse is a heal from 0
// The caller decides whether healing from 0 is allowed.
heal :: proc "contextless" (hp: ^$T, maximum: T, amount: T)
// The i32 helper over `hurt` returns only `died`. It clamps hp at zero
// and reports each death once. hit and play.Health both call `hurt`,
// so raw fields and blocks apply the same damage and death rules.
hit :: proc "contextless" (hp: ^i32, amount: i32) -> (died: bool)

Ability_Def :: struct {
	name:     string, // for ability bars / logs; kit/combat never allocates it
	cooldown: u16, // net ticks
	cost:     i32, // spent from whatever resource the game passes in
}
// Check readiness and cost, then pay and start the cooldown. Prediction
// and authority call this from inside the ability's command proc.
ability_try :: proc "contextless" (cds: []u16, slot: int, def: Ability_Def, resource: ^i32) -> bool
ability_ready :: proc "contextless" (cds: []u16, slot: int) -> bool
// The authority's per-net-tick decay (clients receive it as deltas).
abilities_tick :: proc "contextless" (cds: []u16)

// Embed the `cds: [N]u16 gd:"replicate"` field with `using cd:
// kcombat.Cooldowns(3)`. The array replicates as a flat field;
// cd_try/cd_ready/cd_tick pass `cds[:]` to the underlying helpers.
Cooldowns :: struct($N: int) {
	cds: [N]u16 `gd:"replicate"`,
}
```

Define abilities as code constants. Cavecrawl's `ROCK_ABILITY` has
`cooldown = 20`, which lasts one second at 20 Hz. A predicted cast is a command
procedure; generated policy runs it for client prediction and authority
execution. This example is from `spelunker.odin`:

```odin
@(gd_command = knet.ACTION_OWNER_PREDICTED)
spelunker_heal :: proc(self: ^Spelunker) -> bool {
	if self.hp <= 0 || self.hp >= MAX_HP {return false} // reject dead or already fully healed targets
	if !kcombat.ability_try(self.cds[:], 1, HEAL_ABILITY, &self.stamina) {return false}
	self.hp = min(self.hp + HEAL_AMOUNT, MAX_HP)
	return true
}
```

Check `ability_ready` before issuing the command, as `input.odin` does.
A locally refused prediction is still sent, so repeated input while an ability
is unavailable would send requests the host must reject. [kit/ui](ui.md)'s
ability bar renders the same `cds` and definitions.

## Blocks or low-level helpers

Start with the [`play`](play.md) blocks for entity health and named abilities:

- `play.Health` combines hp, maximum health, a damage-change notification, and
  the current health fraction.
- `play.Ability` generates a cast command on the containing entity, replicates
  cooldown configuration, and handles command acceptance and rejection.

`play.Health` calls `hurt` for its clamp, and `play.Ability` calls `cast_gate`
for its readiness check. Blocks and raw fields therefore use the same rules
for readiness and death. Both use `kcombat.Ability_Def`. The game's definition
table retains names and costs because a replicated blob cannot contain a
string and a wire command cannot carry a resource pointer. That table also
feeds [kit/ui](ui.md)'s ability bar for either blocks or slot arrays.

Use the low-level helpers for cases that need different storage or checks:

- `ability_try` checks and spends a resource when casting. Check the same
  definition row before issuing and in the authority hook.
- `Cooldowns(N)` stores slots indexed at runtime, such as castable inventory
  items that cannot be represented by named block fields.
- `hit`/`hurt` operate on hp outside an entity block, such as a transient value
  or a separate pool.

Cavecrawl and Homestead use the low-level helpers; Scrapyard uses blocks. See
[kit/net — composing verbs from embedded blocks](net.md#composing-verbs-from-embedded-blocks).

## Status effects

One buff/debuff is 4 POD bytes, embedded as a fixed array (`fx: [4]Effect`); kind 0
(`EFFECT_NONE`) is the empty slot.

```odin
Effect :: struct {
	kind:  u8,
	power: i8,
	left:  u16, // ticks remaining
}
// Refresh an effect of the same kind with the strongest power and longest
// duration, or use the first empty slot. Return false when all slots are busy.
effects_add :: proc "contextless" (fx: []Effect, kind: u8, power: i8, ticks: u16) -> bool
// The authority decrements durations each net tick and clears expired slots.
// A hand-written {kind, left = 0} row also clears immediately,
// preventing underflow into a 65535-tick duration.
effects_tick :: proc "contextless" (fx: []Effect)
effect_of :: proc "contextless" (fx: []Effect, kind: u8) -> (Effect, bool)
```

## Projectiles

The host uses the projectile math to judge damage, and peers use it to animate
local [kit/fx](fx.md) tracers. They start from the announced origin and velocity;
network transit delays when remote peers begin their visuals.

```odin
Projectile :: struct {
	pos:  [3]f32,
	vel:  [3]f32, // velocity per tick, not per second
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
// nearest to the muzzle). `from` is the position before projectile_step.
projectile_hit :: proc "contextless" (from: [3]f32, vel: [3]f32, targets: []Target) -> (best: Target, ok: bool)
```

## Cast origin and leash

Include the shooter's local cast origin in the throw command. With
owner-streamed movement, the host receives the shooter's position after a delay.
Launching from that older copy makes the authority projectile follow a different
path from the shooter's visual. The host bounds the supplied origin with
`leash`:

```odin
// leash clamps a claimed point into a disc of radius r around anchor.
leash :: proc "contextless" (claimed, anchor: [3]f32, r: f32) -> [3]f32
```

Origins within the permitted latency offset pass unchanged; larger displacements
are clamped to the allowed distance.
Call it in the command procedure, as `spelunker_throw` in `spelunker.odin`
does. During local prediction, `claimed == anchor`, so the same call leaves
the origin unchanged.

## Fire announcements

When the host accepts a cast, it broadcasts a `Fire` through the session's app
channel ([session.md](session.md)). Each peer simulates that projectile locally
for presentation. The shooter starts at cast time (zero RTT); other peers start
when the announcement arrives. The announcement and later hp delta travel the
same one-way path, aligning remote visual impacts with health changes.

```odin
Fire :: struct {
	shooter:   knet.Player_Id, // actual causer; echo suppression uses `predicted`
	origin:    [3]f32,
	vel:       [3]f32, // per tick; a no-flight kind may use it for spatial data such as radius
	ttl:       u16,
	kind:      u8,  // game-defined (which ability/visual)
	arg:       u16, // the game's payload word beside kind — an ability/status id, a variant
	                // (use arg for ids; packing them into vel.z limits the payload to 2D)
	predicted: bool, // the shooter's screen drew this at cast time; skip its echo.
	                 // false = present on every screen, including the causer's
}
fire_write :: proc(w: ^knet.Writer, f: Fire)
fire_read :: proc(r: ^knet.Reader) -> (f: Fire, ok: bool)
```

Fire announcements default to `FIRE_TAG :: 1`; the other app tags are comms 0,
xfer 2, and sim 3. Store a listener in a struct field so each session has its
own route rather than sharing package globals:

```odin
fire_announce :: proc(s: ^ksess.Session, f: Fire, tag: u8 = FIRE_TAG)   // authority only; asserts on a client
fire_announce_to :: proc(s: ^ksess.Session, peer: ksess.Peer_Id, f: Fire, tag: u8 = FIRE_TAG) // addressed
fire_listen :: proc(fr: ^Fire_Route, s: ^ksess.Session, tag: u8 = FIRE_TAG)
fire_poll :: proc(fr: ^Fire_Route) -> (f: Fire, ok: bool)
fire_route_destroy :: proc(fr: ^Fire_Route)
```

Use `fire_announce_to` to send a recent transient event to one newly joined
player. Take that player's `Peer_Id` from the roster on `Ev_Player_Joined`;
rebroadcasting would make existing peers process the event again.

`fire_poll` drops a `predicted` fire when its shooter is the receiver, because
that screen already presented it at cast time. This also drops an addressed
replay to the original caster after reconnecting with the same identity.
That is appropriate for transient one-shots, but makes fire announcements
unsuitable for persistent effects. Represent a standing zone or lingering glow
as an entity so new and returning players receive its current state in the
world snapshot. Use `fire_announce_to` only for the remaining part of a
transient effect a particular peer should see.

Only the authority may call `fire_announce`; it asserts on a client, and
receivers discard announcements from non-host authors. The listener stores
events in [`ksess.App_Queue`](session.md#the-riders-queue-appq), also used by
comms, xfer, and albums. It does not invoke game callbacks. Drain the route with
`fire_poll` each frame on the game's stack.

The authority loops its own announcement into its local route, so the same
polling code presents events on the host and clients. A `predicted` fire skips
the shooter's echo. A host-produced event with `predicted = false`, such as a
nova or reaction, appears on every screen, including the actual causer's.

```odin
// host, when the command hook confirms a cast:
kcombat.fire_announce(&self.ses, f)

// ready(), every peer:
fires: kcombat.Fire_Route   // a field on your game struct
kcombat.fire_listen(&self.fires, &self.ses)

// Each frame, poll and draw on every peer, including the host.
// A predicted fire skips its shooter; call fire_route_destroy on exit.
for {
	f, ok := kcombat.fire_poll(&self.fires)
	if !ok {break}
	// draw the rock
}
```

Raw `fire_write`/`fire_read` stay public for games that need a different envelope.

For tick-based cooldowns and [kit/ai's director](ai.md), read
`ksess.session_tick_no(s)` instead of maintaining a parallel counter that can
drift across resume and host migration. A campaign clock is different: the
game must persist it in its save blob because session ticks cover only the
session's lifetime. Cavecrawl uses its saved `host_ticks` to schedule respawns
across saves.

## Predicted hp

When your local rock visually contacts a body, the health you *display* may dip
immediately. The dip lives in a presentation overlay and cannot change
authoritative health:

```odin
Predicted_Hp :: struct {
	pending: i32, // damage shown locally but not yet confirmed by a delta
	basis:   i32, // authoritative hp at the last overlay update
	expires: f64, // overlay expiry time (seconds, caller's clock)
}
PHP_TTL :: 0.6 // seconds allowed for an authoritative hp update to arrive

php_note_hit :: proc "contextless" (ph: ^Predicted_Hp, hp_now: i32, amount: i32, now: f64)
php_display :: proc "contextless" (ph: ^Predicted_Hp, hp_now: i32, now: f64) -> i32
```

Call `php_note_hit` at visual contact and `php_display` when drawing health,
as `rock_impact` in `rocks.odin` does. When the authoritative hp drop arrives,
it consumes the overlay so the display does not subtract damage twice. If the
host judges a miss, the overlay expires and the displayed bar returns to the
authoritative value. `php_display` clamps to 1 while authoritative hp is
positive, so speculative damage cannot display a death.

<a id="auto-published-combat-stats"></a>

## Publishing combat stats

Call `combat_columns` once on the host to register the three stat columns.
At impact, call `credit_hit`; on a killing blow, call `credit_kill`. The session
then replicates and displays those recorded values.

```odin
Combat_Cols :: struct {
	damage: ksess.Stat_Col,
	kills:  ksess.Stat_Col,
	deaths: ksess.Stat_Col,
}
// Host, once at start: declare the standard combat columns (idempotent).
combat_columns :: proc(s: ^ksess.Session) -> Combat_Cols
// Host, at impact: record damage credit for a valid attacker.
credit_hit :: proc(s: ^ksess.Session, cols: Combat_Cols, attacker: knet.Player_Id, amount: i32)
// Host, on a killing blow.
credit_kill :: proc(s: ^ksess.Session, cols: Combat_Cols, attacker, victim: knet.Player_Id)
```

## Pools

`pool_tick` maintains a dynamic projectile array. It sweeps each tick's segment
before stepping, removes a projectile on hit or expiry, and updates iteration
correctly after removal. The game supplies target, hit, and expiry callbacks:

```odin
Slug :: struct { p: kcombat.Projectile, dmg: u8, shooter: knet.Player_Id }
flying: [dynamic]Slug                 // a wrapper pool (or a bare [dynamic]kcombat.Projectile)

kcombat.pool_tick(&self.flying, self, slug_targets, slug_hit, nil)   // hit-testing pool
kcombat.pool_tick(&self.lobs, self, nil, nil, lob_splash)            // fly-out-and-splash pool
```

`targets` runs separately for each projectile. If `on_hit` kills a target,
the next projectile queries the updated target list. A hit always removes the
projectile; the example pools do not support piercing. `on_expire` handles the
end of its lifetime, such as applying a lob's splash damage.

## Worked example

From `examples/cavecrawl/scripts/host.odin` (`cave_host_tick`); the full pattern (launch
on the command hook, announce the `Fire`, draw visuals per frame) is in `rocks.odin`:

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

<a id="gotchas"></a>

## Timing and validation constraints

- Cooldowns and effect durations count network ticks. Convert a duration in
  seconds to ticks for the chosen rate. Only the authority decrements these
  values; clients receive the countdown through replication.
- A cast near the end of a cooldown may be predicted differently on a client.
  The command is still sent, and the host decides acceptance.
- `Projectile.vel` is per tick. Use the position before `projectile_step` for
  hit testing, and test that segment even if the step returns false: the last
  tick still occurred.
- Carry the shooter's local cast origin and apply `leash`. The host's delayed
  position can otherwise launch the projectile along a different path.
