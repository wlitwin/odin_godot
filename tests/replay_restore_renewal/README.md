# Delayed restore grant renewal

```sh
REPLAY_RESTORE_RENEWAL_OUT=/absolute/fresh/output nix develop --command bash tests/replay_restore_renewal/run.sh
```

The gate delays a Restore request by 2,400 ms before it reaches the coordinator.
The coordinator then grants its ordinary 2,000 ms reservation. Because the client
anchors its conservative deadline to request start, that grant arrives locally
expired. A fresh correlated renewal must authorize installation in the same epoch.
No deadline, clock, lease duration or acceptance requirement is relaxed.

Coverage:

- Deterministic SQLite/Room tests reproduce the former extra-Restore behavior,
  verify renewal of the same active reservation, and reject renewal after the
  coordinator's reservation also expires. Prepared state remains owned and no
  runtime is installed from the stale permit.
- The native checkpoint fixture publishes/downloads/restores actual Cave,
  Speedball and Scrapyard models after service restart. Its delayed grant is
  expired, its renewal is live, and the saved tick-1 world advances to tick 11
  in epoch 2. The low-level fixture now follows Room's renewal-before-install
  protocol instead of consuming the expensive Restore reply directly.
- An isolated Claimball build injects backpressure only on the Restore request.
  All other control/transfer traffic uses the underlying transport unchanged.
  Full native and browser party tests kill all game processes and restart the
  service, preserve the exact saved frame, return three player identities and an
  observer, continue combat/chat, and publish revision 2. Both assert one parked
  expired grant followed by a renewed installation in epoch 2.

`build.sh WORK`, `execute.py WORK`, and `execute_web.py WORK` run the game portions
separately. The browser export uses `tests/replay_claimball_online/build_web.sh`.
Every build/run uses fresh output directories and retains prepared hashes. Test
wrappers are absent from the shipping games and library. Exclude runtime DBs,
profiles, invitations and private TLS keys when collecting receipts.

The earlier uninstrumented Scrapyard failure has the same top-level symptom, but
its exact cause remains unproven. This gate proves and fixes a specific delayed-
grant path; it does not retrospectively identify that historical failure.
