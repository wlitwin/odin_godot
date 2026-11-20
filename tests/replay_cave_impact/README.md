# Cavecrawl dweller impacts and compatibility

```sh
REPLAY_CAVE_IMPACT_OUT=/absolute/fresh/output nix develop --command bash tests/replay_cave_impact/run.sh
```

The model tests check projectile/target identity, nonlethal/lethal ordering,
detached positions, slot reuse, correction and atomic event-capacity failure.
Current fixtures contain a flying rock approaching a 70-HP dweller and one
pending Door command. Exact current checkpoint roundtrips retain the frame and
ledgers; native Godot and WASM resumes apply one impact and settle the pending
command once. `capture/main.odin` creates new current-model recordings from those
checkpoints. Native/WASM verification rejects an altered expected event even
when the recorded Worlds and inputs remain unchanged.

Historical checkpoint/recording bytes and migration receipts remain under
`docs/replay/results/usability-legacy-2026-11-16/cavecrawl`; no historical reducer
or converter is used by the active gate.

The server-motion and owner-motion campaigns retain gameplay/world-hash checks and require at least 24 dweller
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
