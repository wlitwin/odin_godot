# Live recent-fact encoding comparison

Build the three-profile Cavecrawl fixture, then run six owner-profile pairs with
the same binary. Each repetition alternates which encoding runs first. Both modes
retain compact observations, 20 Hz networking, the same quiet-world gameplay and
five-second backups. Only `Session_Options.disable_compact_recent_facts` differs.
The diagnostic packet meter is disabled during timing measurements.

```sh
nix develop --command bash tests/replay_cave_comparison/build.sh /absolute/fresh/build
nix develop --command python3 tests/replay_recent_facts_codec/cohort.py /absolute/fresh/build /absolute/fresh/results
```

The report records application bytes and inclusive game callback wall time, not
total network traffic or process CPU. Run without concurrent builds or game tests.
All gameplay, gem-conservation, command-confirmation and backup checks must pass
for both modes. This quiet local scenario is not a stress or full-parity gate.

Codec/admission cases live in `tests/replay_net/recent_facts_compact_test.odin`;
recipient projection is covered by `tests/replay_interest`. The frozen old/new-peer
matrix in `tests/replay_observation_compat` also checks recent-fact format selection.
