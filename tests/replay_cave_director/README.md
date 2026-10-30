# Cavecrawl director comparison

```sh
REPLAY_CAVE_DIRECTOR_OUT=/absolute/fresh/output nix develop --command bash tests/replay_cave_director/run.sh
```

Runs Cave unit tests, the unchanged Kit director oracle, the same 262 scenarios in
WASM, explicit old-save conversions/fresh Godot resume, and the existing normal
and 10%-loss/duplication campaigns. Gameplay/loot/death/victory assertions remain.
The campaign observer waits for the authority's completion tick before evaluating
victory totals; the filesystem phase signal alone is not an authority observation.

`shared/run.odin` compares one director invocation per active tick, with scripted
deaths before the director as in both games. Replay deaths use actual rock damage.
Spawn and death call counts are hoisted before loops because Odin re-evaluates
range bounds. Capacity behavior has its own unit test; the oracle corpus keeps
populations within the Replay pool's bound. No original source is modified.

`legacy_fixture` requires the pre-change C3 model. Its captured sources and four
actual outputs are in `tests/replay_cave/fixtures/content3`. To regenerate, unpack
that model archive into a temporary `godot` collection overlay while linking the
other current source directories, then build the producer against that overlay.
Do not regenerate it against C4 or relabel newer files as historical fixtures.

`build.sh OUTPUT`, `campaign.py PREPARED normal|fault [LABEL]` and
`upgrade.py PREPARED [LABEL]` retain preparation and driver/binary identities and
require new result directories. The aggregate gate is registered in `tests/run_all.sh`.
See the [behavior and compatibility guide](../../examples/replay_cavecrawl/director.md).
