# Cavecrawl director comparison

```sh
REPLAY_CAVE_DIRECTOR_OUT=/absolute/fresh/output nix develop --command bash tests/replay_cave_director/run.sh
```

Runs Cave unit tests, the unchanged Kit director oracle, the same 262 scenarios in
WASM, current saved-fixture/fresh Godot resume, and the existing normal
and 10%-loss/duplication campaigns. Gameplay/loot/death/victory assertions remain.
The campaign observer waits for the authority's completion tick before evaluating
victory totals; the filesystem phase signal alone is not an authority observation.

`shared/run.odin` compares one director invocation per active tick, with scripted
deaths before the director as in both games. Replay deaths use actual rock damage.
Spawn and death call counts are hoisted before loops because Odin re-evaluates
range bounds. Capacity behavior has its own unit test; the oracle corpus keeps
populations within the Replay pool's bound. No original source is modified.

Current fixtures and their hashes live in `tests/replay_cave/fixtures/current`.
Original producer data remains under
`docs/replay/results/usability-legacy-2026-11-16/cavecrawl/originals`.
`current_fixtures.stage` verifies and copies each immutable input with exact
string-valued tick/frame-hash metadata. It does not run a converter.

`build.sh OUTPUT`, `campaign.py PREPARED normal|fault [LABEL]` and
`saved_fixtures.py PREPARED [LABEL]` retain preparation and driver/binary identities and
require new result directories. The aggregate gate is registered in `tests/run_all.sh`.
See the [behavior and compatibility guide](../../examples/replay_cavecrawl/director.md).
