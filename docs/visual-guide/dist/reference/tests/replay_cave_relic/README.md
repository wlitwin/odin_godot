# Cavecrawl relic acceptance

Check relic placement, carrier identity and version across descent and restart.
The suite preserves old saved values through conversion, then tests subsequent
transitions under the current rules.

```sh
REPLAY_CAVE_RELIC_OUT=/absolute/fresh/output nix develop --command bash tests/replay_cave_relic/run.sh
```

Runs 33 Cave tests and WASM checking, an isolated Godot build, all fifteen C1–C7
conversion/resume fixtures, three retained-frame transition checks, and normal/
faulted three-process campaigns. The read-only `floor_value` probe exists only in
the prepared test project. Production simulation and public restart commands are
used without state edits.

The three C5 archives were produced before changing the rules: a resting relic
before descent, a carried relic before descent, and a carried relic before restart.
Their producer log, hashes and frozen source live in
`tests/replay_cave/fixtures/content5`. The producer intentionally requires C5;
regeneration needs those archived sources in a temporary collection overlay.

Conversion must preserve complete saved frames and peer ledgers exactly. Godot
then checks the first descent frame at tick 101 for resting position or carried
attachment and unchanged version. The restart case first advances carrying under
C6, sends the public restart action, and checks the first new-run frame releases
the relic at the prior frame's position with one version increment.

The original source contract and remaining authority/death/disconnect differences
are described in the [behavior guide](../../examples/replay_cavecrawl/relic.md).
