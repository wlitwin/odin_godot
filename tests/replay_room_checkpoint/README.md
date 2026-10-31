# Shared checkpoint service acceptance

```sh
REPLAY_CHECKPOINT_OUT=/absolute/fresh/output CHECKPOINT_RESTORE=1 \
  nix develop --command bash tests/replay_room_checkpoint/run.sh
```

The original fixture covered Cave, Speedball and Scrapyard. The test publishes checkpoints,
kills/restarts the service, downloads the unchanged archive with a fresh process,
and optionally installs a granted runtime and advances it to tick 11 in epoch 2.
The low-level probe requests a fresh correlated renewal before runtime setup,
matching the high-level Room restore lifecycle.

`CHECKPOINT_GAMES` selects a space-separated subset of supported models.
The launcher also includes owner-motion Cave (`cavecrawl-owned`) alongside
those three games.
`CHECKPOINT_RESTORE_DELAY_MS=2400` adds test-only backpressure before the Restore
request reaches the service. It changes no timestamps or lease durations. The
grant then has an expired local permit even though the coordinator has just
reserved the actor; a fresh correlated renewal must precede installation. Logs report the
grant's request age/live status, renewed remaining time, and detailed failure
stage if installation or advancement fails.

The broader [renewal gate](../replay_restore_renewal/README.md) also checks denied
renewals and full native/browser Room gameplay under this delay.
