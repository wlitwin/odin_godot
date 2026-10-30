# The run loop

A run advances through waves, floor-clear shopping, a shared departure gate and
wipe recovery. The director is the saved-state scheduler that announces waves,
spawns enemies and tracks completion/rest deadlines.

`RSY_WAVE_BASE=0` supports an empty wave for parity with the original arena modes.
An empty single-wave floor clears once without inventing a death or rest interval;
both connected players receive the normal clear award. Content `0x5253435241503048`
introduced the [authority-only rewind history](authority-history.md) retained by
this model. Use the [save guide](saves.md) for current content and explicit
conversion of older runs.

Interactive play enables the run loop by default. Existing combat fixtures set
`RSY_RUN=0` to keep their isolated encounters. The full run uses the original
three-wave formulas, depth-based roster, every-third-floor horde and every-fourth-
floor Titan. The boss takes precedence on a floor divisible by both. Five attempted
barrel placements use the original floor-based scatter/cover exclusion rules.

The director announces before spawning, admits one enemy per tick, and waits for
directed deaths and the authored rest. Capacity refusal creates no phantom live
enemy. The final wave's rest precedes completion, as in the original director.
Floor clear requires both director completion and no living non-prop enemies.
It awards one in-world core to each connected runner exactly once.

On Clear, the [counter](shop.md) offers nine clickable cards. Keys 1–4 buy damage,
fire rate, speed or healing. Keys 5–8 buy belt, plate, catalyst or magnet with cores,
matching the original game; 9 swaps to the next iron for free. The price and all predicates
execute in the reducer. Active iron is separate from the claimed starting loadout.
Plate raises maximum HP to 14, belt shaves three cadence ticks, catalyst extends
mob status durations by half, and magnet adds 28 pixels of pickup reach. Temporary
boosts and part modifiers use the same rules in prediction and authority.

Every connected runner must be alive on the east gate to start its three-second
departure. Stepping off cancels it. Departure clears floor-owned mobs, projectiles,
zones, drops, flashes and query history; pool generations remain monotonic. Runners
warp to the next-floor entry, retaining health, boosts, parts, cores and active gun
state. Their warp counters prevent interpolation/smoothing across the teleport.
Disconnected bodies are reaped on the turn; reconnect before a turn retains the
body, while entry after reaping creates a fresh standing body from its claim.

A wipe means every connected runner is down. After 150 saved ticks, the run counter
advances and the crew returns to floor one. Scrap, temporary boosts, statuses and
ability cooldowns reset; parts, cores and the current iron remain. Guns refill and
the fresh wave observes the post-reset rest. These are in-world values. [Local co-op profiles](profiles.md) now persist confirmed
cores, parts and staging choices separately; they are not a secure competitive bank.

Hold F near a downed friend to revive. The authority checks living reviver, connected
target, range and 120 ticks of held input; release or retarget resets progress.
Completion restores four HP once. This deliberately differs from the original's
owner-authored progress/claim, where the host rechecked geometry but trusted the
claimed duration. Held controls follow the runner's normal missing-input policy.

Comparison limits remain explicit: spawn angle uses saved tick time instead of
host wall time, target/iteration order is stable, departure/wipe/revive run on ticks,
and all moves are server-authoritative. Numeric overflow is rejected rather than
wrapping. Catalyst duration arithmetic uses a wider intermediate. Purchases are
predicted transactions instead of the original host-only consequence. Full original
UI/audio/feel parity remain evaluation work; the [editor workbench](workbench.md)
and [shop cards](shop.md) have dedicated acceptance gates.

`run_loop.sh` uses short declared waves/rest to exercise two clears, shopping,
departure cancellation, a horde-floor wipe and reset. `revive_run.sh` lets an actual
enemy down a teammate, interrupts one hold, completes a second and compares the
whole world across host/client/observer. Native tests additionally cover horde/boss
precedence, ghost reaping, all parts and an authority checkpoint during departure.

The [gauntlet gate](../../docs/replay/results/gauntlet-finale-2026-09-06/README.md)
uses base four and all three five-second rests. It checks saved deadlines, thirteen
spawns and one clear award per player, then compares a world at or after every
participant's completion receipt. Its controlled team/support setup differs from
the original solo act. It now continues into the original two-barrel chain finale
through [admitted development actions](development.md), requiring two blasts from
one shot and no extra clear awards. Original solo/difficulty/feel parity and a
matched performance comparison remain separate requirements.
