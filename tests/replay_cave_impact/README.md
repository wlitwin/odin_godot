# Cavecrawl dweller impacts and compatibility

```sh
REPLAY_CAVE_IMPACT_OUT=/absolute/fresh/output nix develop --command bash tests/replay_cave_impact/run.sh
```

The pure cases check projectile/target identity, nonlethal/lethal ordering,
detached positions, slot reuse, correction and atomic event-capacity failure.
Genuine C8/O2 checkpoints and recordings were captured before changing the reducer;
their producer and hashes are in `fixtures`. They contain a flying rock about to
hit a 70-HP dweller and one pending Door command. Conversion preserves the frame
and all shared ledgers; fresh native Godot and WASM resumes produce the new impact.
Explicit historical models reproduce old recordings; current models fail the
ordered-event comparison when deliberately substituted.

The existing native converters exercise all 18 saved fixtures across C1–C8/O1–O2,
including existing-destination and corruption preservation. Full C9 normal/faulted
and O3 campaigns retain gameplay/world-hash checks and require at least 24 dweller
impacts alongside player hits and deaths. Read-only authority history proves the
accepted heal's exact 25-HP gain after same-tick damage, five stamina cost and
60-tick cooldown. This handles live bites between the revive and heal phases;
host/client must also observe the resulting health with an active cooldown.

The renderer fixture creates view-only generations without changing World. It
verifies an active older-generation cue cannot flash a replacement node, along
with cancellation and confirmation behavior. Native rendering and Chrome cover
particles. The current-content Chrome owner migration/save matrix and typed
checkpoint service restore both current profiles.

Component runners may be used separately; keep build/runtime inputs unchanged
while their processes are live. These checks do not establish render-rate rock
tracer parity, arbitrary navigation equivalence or public deployment readiness.
