# Player abilities

Select two abilities in staging. Q sends a world point and E sends a direction
through reliable `Action.Cast` requests with an explicit slot and aim convention.
The tick reducer validates the player, slot, catalog ID, and cooldown, then applies
the cast to World. Client prediction runs the same reducer. Rejection restores
both candidate state and feedback; a full lob/zone pool rejects the cast before
starting its cooldown. The authority derives the cast origin from its simulated
movement, so the request needs no claimed caster position.

All six stock resources load through Godot into the saved catalog: slime lob,
igniter cone, frostwave nova, battlecry buff, salvefield zone and sparkjar lob.
The native generator reads the same files, and Godot gates compare the catalogs.
There are 16 ability rows (zero reserved), 64 lobs and 32 standing zones in this
profile. The original games and their resources remain unchanged.

The five delivery families preserve the selected original rules:

- Lob clamps its target to range, starts up to 14 pixels from the caster and uses
  the integer flight duration. At expiry it delivers status to living mobs in its
  radius. The shared damage column is unused by the original lob judge and remains
  unused here. A target less than one pixel away spends cooldown but creates no lob.
- Cone checks range and half-angle against mobs. Nova checks a caster-centered
  radius. Both apply scaled direct damage first, then status to survivors. Secondary
  reactions can hurt the crew even though those primary deliveries target mobs.
- Buff selects self or the nearest living friend according to the row, with self
  fallback. Stable seat order resolves equal-distance candidates.
- Zone clamps its placement to range and records the cast's scaled damage. It pulses
  damage/status onto mobs and crew, including its caster. Its remaining lifetime
  decrements before the modulo pulse test; expiry removes it without a final pulse.

Cooldowns, cast identities/counters, lobs, zones, credit and status consequences
are saved values. Correction can remove the complete cast, and authority archives
resume flight and pulse timers. `emit_fold` combines shared per-tick feedback from
the ordinary simulation and later actions; rejecting an action also restores any
earlier event it modified.

Own lobs/cones use predicted presentation. Nova/buff flashes and zones use observed
state, matching the original presentation policy. Zones are ordinary observed
entities, so a late spectator receives the existing patch and its remaining time.
[Glob discs](globs.md) restore the original shapes, payload colors and pulse.
Flights follow the original straight path without an arc or trail.
[Area discs and buff bursts](areas.md) provide nova/reaction fills, constant
standing-zone fill, and once-only wearer bursts. [Cast paths](cast_paths.md)
provide local/remote cone tongues and recorded spread bolts. Launch/contact
feedback, audio listening, and feel remain review work.

The original's owner-streamed origins and frame timing differ from this fixed-tick,
server-authoritative version. Requests execute after the tick's ordinary simulation;
new lobs/zones first advance on the following tick. Enemy/status/zone processing
order is explicit, and stable pool/seat order replaces the original map iteration.
Accepted empty casts, hostile reactions and remaining-clock pulse phase
are intentional rules, not transport retries or silent live-world query fallbacks.

`abilities_run.sh` uses declared stationary targets and initially wounded crew,
then drives normal actions from three players. A spectator joins during the standing
zone. The gate exercises all six resources, freeze/shatter/spread/surge reactions,
generation-aware credit, regeneration, eleven zone pulses and expiry. It compares
the complete world at a shared authoritative tick. These controlled encounters do
not establish full original-game parity, profile persistence or run progression.

`storm_run.sh` assigns slime/frost to one player character (called a runner)
and spark/ignite to another, verifying that the second receives credit for
shatter damage and later shock damage.
It also burns/douses both targets and explicitly observes the support runner's
friendly surge. Observation receipts delay each test's next consuming action until
all participants have seen its prerequisite; ordinary gameplay does not use those
barriers. [Recorded storm/surge results](../../docs/replay/results/scrapyard-storm-2026-09-06/README.md)
include network faults, exact world comparisons and the fixture's differences from
the original acts.
