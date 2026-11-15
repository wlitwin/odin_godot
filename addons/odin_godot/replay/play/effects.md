# Effect clocks and telegraphs

Use `Effect` for replayable status durations and stacks, and `Telegraph` for a
wind-up that applies gameplay on a chosen tick. `Effect` stores a game-defined
kind, stack count and remaining ticks in four value bytes. `effect_stack` refreshes an existing kind up to a supplied stack cap and
keeps the longer duration; otherwise it uses the first empty slot. It returns the
affected slot index so a game can attach frame-owned attribution alongside it.
Invalid arguments or full storage reject without mutation. `effects_tick` clears
expired slots, including a nonempty slot accidentally assigned zero remaining time.

Definitions, damage/pulse behavior, credit and reaction rules belong to the game.
Stack counts deliberately do not imply multiplicative movement or damage rules.
Scrapyard keeps four effects and four corresponding `{seat, generation}` credits
on each body; expiry clears both, and a new occupant cannot inherit old DOT credit.

`Telegraph` owns the remaining and original wind-up durations. Start it with a
duration, tick it once per simulation step, and apply the payload only when
`telegraph_tick` returns true. Cancellation clears both fields. Presentation can
use `telegraph_fraction`; a shortened wind-up therefore still starts at zero and
finishes at one. Geometry, rooting policy and the landing effect remain the caller's.

```odin
if boss.tele.left > 0 {
    if p.telegraph_tick(&boss.tele) {pound(world, boss, ctx)}
    return
}
if in_range && cooldown_ready {p.telegraph_start(&boss.tele, 48)}
```

`tests/replay_effects/run.sh` compares nine 4,096-tick stack/expiry/telegraph traces
against the original procedures compiled in isolation, with native boundary and
WASM checks. Cached results allow the repository tests to run without the sibling
Scrapyard checkout; `REPLAY_REQUIRE_BASELINE=1` requires the live comparison.
