# Frozen C5 relic saves

These three real authority checkpoints were produced before the C6 relic rule
change using the sources in `source.tar.gz`. `producer.log` records tick 100 and
the relic values. `SHA256.json` seals the original fixture artifacts. The producer
is `tests/replay_cave_relic/legacy_fixture/main.odin` and requires content C5.

- `resting.replay`: unowned relic at `(200, 150)`, version 7; party at the stairs.
- `carried.replay`: seat 1 owns the same relic before descent.
- `restart.replay`: seat 1 owns the relic at the end of floor 2, before restart.

All use the test identity `cave-relic-legacy`. Conversion must preserve the saved
complete frame and peer ledger. New behavior only applies after advancement.
