# Delta codec tests

Run `nix develop --command bash tests/replay_delta/run.sh` from the repository root.
The gate covers sparse/dense byte differences, malformed and truncated runs,
transactional output, randomized roundtrips, and bounded cache ownership/eviction.
`tests/replay_net` additionally exercises real Hello state, acknowledgement trust,
missing-baseline recovery, and outbound rate budgets through the network runner.
