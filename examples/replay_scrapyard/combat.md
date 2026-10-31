# Scrapyard combat contract

This page records the combat-rule comparison and its measured test scope.
Resource counts and world sizes below describe that revision. Use
[run rules](run.md), [profiles](profiles.md), and [saves](saves.md) for current
progression, persistence, and saved-content guidance.

The compared implementation loads seven GunDef resources and their projectile
subresources, six MobDef resources, eight status resources, eight ordered combo
resources, and six ability resources through Godot. It validates numeric
bounds before narrowing them,
then copies names and numbers into a value-owned catalog. Resource references are
released at the boundary. Sorted filenames retain the original last-file override
rule. IDs must be dense within 16 guns/eight mob definitions; gaps fail validation.

The authority's catalog lives in the complete world and therefore travels in
snapshots, late-join baselines and authority checkpoints. `tools/stock.py` generates
the matching native test catalog; `--check` detects stale generated data. The
Godot tests require equality between the runtime resource catalog and that stock
catalog. This is gameplay-data transfer; arbitrary mod assets/abilities and full
mod compatibility remain separate work.

All seven stock weapons and six stock enemy types are enabled. Interactive play uses the [run loop](run.md). With `RSY_RUN=0`, the default isolated
yard starts eight melee enemies. `RSY_ENCOUNTER=mixed` cycles scuttlers, hulks, spitters
and poppers; `RSY_ENCOUNTER=boss RSY_MOBS=1` starts a Titan. The enemy test harness
uses a 36-HP Titan override; ordinary play retains the authored 600 HP unless
`RSY_BOSS_HP` is set. `RSY_ENCOUNTER=barrels` uses an authored line of two barrels
and a hulk for chain testing. `RSY_MOBS=0` retains the empty arena scenario.
Player abilities use reliable predicted actions; [abilities.md](abilities.md)
describes their delivery. Waves/floors, wipe/revive, and shops are included.
These combat checks do not establish durable profile/bank persistence; see
[profiles](profiles.md) for that separate lifecycle.

Every gun mechanism, next-pull tick, shot, enemy action/reap timer, damage/kill
counter and scrap pile belongs to the world. Stable pool generations govern entity
lifetime. A projectile sweeps against current living targets and cover before
movement. Each subsequent projectile sees deaths caused by earlier projectiles.
Damage clamps at remaining health; an ordinary kill drops three scrap exactly once.
Drops attract inside 52 pixels and credit on contact inside 14 pixels.

Capacity is explicit: 64 enemy bodies, 128 projectiles and 128 scrap piles. Ballistic/grenade
pulls defer at a full projectile pool without spending ammo or advancing the jam sequence.
A full drop pool merges into the nearest existing pile that can hold the amount;
stable slot order breaks ties. Arithmetic exhaustion aborts the candidate tick.
Feedback aggregates hit damage, kills, received damage, pickups, healing and blasts
once per player/kind/tick; exact target state remains in the world. Together with shots,
jams, dashes and roster events this fits the runner's 32-gameplay-event limit.

Rendering reads observed enemy/drop state, predicted local shots and observed
remote shots. Original runner/zombie strips and scrap geometry are retained.
Weapon names/regions and enemy scale come from the received catalog. Beams and
blast rings are bounded value-owned visuals, so correction/checkpoint restoration
preserves their lifetime. At saturation the oldest visual is replaced and a counter
records the eviction; gameplay damage is retained. The automated driver generates ordinary player controls; it does not mutate the world.

Rails use a 32-frame history of compact collision proxies (position, generation,
active flag). This history is part of the complete world and its authority archive.
Godot binds inputs to the exact quantized view bracket drawn on screen. The runner
validates snapshot proofs and age before the game reads history. Queries never
move live bodies: they judge old proxies and apply wounds/heals to matching current
lifetimes. A recycled slot, dead/disconnected friend or absent historical frame
cannot become a live fallback target. Expired/unavailable queries consume the pull,
record their outcome and deal no damage/healing. The lance pierces all matching
mobs; the mender hits the first living friend, including a full-health blocker, and
cannot heal itself or revive a dead player.

Grenades run the original carom law at one tick per simulation step. They detonate
at fuse-out or within 22 pixels of a live mob; the 72-pixel blast damages mobs and
spares the crew. The base blast damage is stamped from the firing definition; the shooter’s
current run damage boost applies at detonation, matching the original.

Statuses use four stack/duration slots per body with corresponding generation-aware
credits. Slot order selects the first present status that reacts; filename order
selects the first row for that pair. Detonate wounds mobs and crew in radius,
Transmute re-enters the same target, and Spread re-enters every in-range target.
Depth four bounds cycles; a 65,536-operation tick budget aborts an over-budget
candidate through Replay's ordinary transaction. A dense 64-target stock spread is
tested within that budget. Full effect slots refuse the new landing, while a capped
refresh retains the longest duration and updates credit to the latest applier.

Effects decay before testing pulses. Pulses use remaining-time modulo cadence,
matching the original (surge's first pulse is after 15 ticks, not 45). Expiry clears
its credit slot. DOT damage to mobs credits only the same seat incarnation; a new
occupant cannot inherit it. Negative DOT heals runners, not mobs. Movement and
outgoing runner damage use the row multipliers; stacks scale DOT, not multipliers.
Dash bypasses movement modifiers. Taken-damage scaling applies to mobs, as in the
original `damage_mob`; `hurt_runner` did not apply it. Mender/grenade status-dealt
scaling retains their original exceptions. Ability wounds use the caster’s dealt multiplier; run boost and part modifiers are described in [run.md](run.md). Pulse iteration also retains the original runner-upkeep ordering.

Spitters have a 90-tick arrival grace, maintain range, spiral around blocked sight
lines and fire 60-tick projectiles on a 150-tick cadence. Poppers burst at close
range, hurt the crew and leave no loot when they self-detonate. Titans preserve
wind-up duration, cooldown/add clocks, enrage and maximum health; a pair of adds is
reserved together and retries at capacity. Only members present at the beginning of the enemy pass run AI during that
tick. Boss death cancels its wind-up, produces five
scrap piles and awards three in-world cores to each connected runner. Bank/profile
persistence and complete floor progression are not established by that payout.

Barrels are stationary, shootable props excluded from crowd separation. Death
chains damage/status payloads through the same reaction rules, with no prop kill/loot
award. Corpses remain allocated until their saved reap tick, so recursion cannot
invalidate a borrowed body pointer. Status washes, spit discs, barrel art and the
Titan's wind-up ring are driven from the observed value state. Enemy-owned visuals
use the observed clock for spectators as well as players.

Comparison boundaries:

- The reusable gun FSM matches the original executable oracle. Trigger cadence is
  `cooldown + 1` at 60 Hz, with reload dwell carried in saved state. The original
  owner-local wall pacer and owner-streamed movement have different timing/trust
  semantics. Replay launches from the tick's simulated muzzle, without a claimed
  owner position or muzzle leash. Jam salt uses seat/floor, versus registry ID/floor.
- Enemy move speed, wall-follow, bite range/cadence, soft separation, clamped damage,
  payout and pickup-attraction formulas follow the selected original rules. Stable slot/seat
  ordering replaces map iteration. Spawn flavor derives from seed/floor instead of
  host wall time; no exact spawn trace equivalence is claimed.
- Cover blocks at exact first contact, including segment endpoints. The original
  shortens flight TTL to `integer(contact + 1)`; crossing-tick behavior differs.
- The original rails estimate rewind from RTT/interpolation; Replay uses validated
  view stamps. Beam judgment geometry matches the original, while exact cover clipping
  retains the contact-boundary difference above. A normal network test proves current
  application of historical client queries, not identical timing to the old pacer.
- Grenade motion/beam geometry match isolated original test corpora. Replay grenades advance in saved ticks rather than the original per-render-frame host/view copies.
  Beam/boom visuals last nine/17 ticks instead of 0.14/0.28 wall-clock seconds.
- Corpses reap after 42 saved ticks. The original schedules a presentation callback
  after 0.7 seconds. Full attack animations, audio and visual/feel parity remain work.

Native checks cover the content codec, capacity/conservation, cover occlusion,
corpse recensus, rollback of death/payout/pickup, tiny aim values and tick exhaustion,
and complete checkpoint continuation during active combat. The recorded expanded world measured 52,380 canonical bytes and 18,397 scalar
fields; this is not a bandwidth,
CPU or scaling benchmark. Real-process evidence is recorded separately in the
Replay progress/results ledger.
