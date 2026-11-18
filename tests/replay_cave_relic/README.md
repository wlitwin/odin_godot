# Cavecrawl relic acceptance

Check relic placement, carrier identity and version across descent and restart.
The suite preserves migrated saved values, then tests subsequent
transitions under the current rules.

```sh
REPLAY_CAVE_RELIC_OUT=/absolute/fresh/output nix develop --command bash tests/replay_cave_relic/run.sh
```

Runs Cave model tests and WASM checking, an isolated Godot build, all fifteen current
saved-fixture resumes, three retained-frame transition checks, and normal/
faulted three-process campaigns. The read-only `floor_value` probe exists only in
the prepared test project. Production simulation and public restart commands are
used without state edits.

The three retained cases use current checkpoints under
`tests/replay_cave/fixtures/current`: resting, carried and restart. Original data
and migration receipts remain historical evidence under
`docs/replay/results/usability-legacy-2026-11-16/cavecrawl`.

Resume must preserve complete saved frames and peer ledgers exactly. Godot
then checks the first descent frame at tick 101 for resting position or carried
attachment and unchanged version. The restart case first advances carrying under
the current rules, sends the public restart action, and checks the first new-run frame releases
the relic at the prior frame's position with one version increment.

The original source contract and remaining authority/death/disconnect differences
are described in the [behavior guide](../../examples/replay_cavecrawl/relic.md).
