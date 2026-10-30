# Cavecrawl floor-state acceptance

```sh
REPLAY_CAVE_FLOOR_OUT=/absolute/fresh/output nix develop --command bash tests/replay_cave_floor/run.sh
```

Runs Cave tests, an isolated game build, all fifteen C1–C7 conversion/resume fixtures,
actual Godot descent/restart checks, and normal/faulted full campaigns. Test-only
`floor_value` reads retained authority frames; it does not set gameplay values.
The transition cases resume genuine C4 fixture archives under the new content,
then exercise ordinary descent and the public restart action.

The legacy producer requires C4. Its actual files, log and frozen model source
archive are retained in `tests/replay_cave/fixtures/content4`. Regenerate only
against that archived model in a temporary collection overlay. Existing saved
injury/timers/ledger remain intact through conversion, including already-reset
post-descent values which cannot be retrospectively reconstructed.

The original host descent/restart and owner position-edge procedures provide the
source contract. Pure tests verify tick decay/regeneration, active-effect retention,
reserved respawn progress and complete world/event equality after input revision.
The existing shared checkpoint-service and browser social/handoff gates validate
C5 deployment compatibility separately. See the [behavior guide](../../examples/replay_cavecrawl/floor-state.md).
