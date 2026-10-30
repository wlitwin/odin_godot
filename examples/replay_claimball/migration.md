# Claimball native host migration

Claimball can run through Replay's existing authenticated Room lifecycle. A trusted
connected player receives complete authority checkpoints and can become host after
planned handoff or owner loss. Prediction remains local-avatar-plus-ball; the
checkpoint is the complete authority world, including outsiders.

The fixed-coordinator entry point below remains useful for development.
[Party menus and browser RTC](online.md) now provide a provisioned Room path and
durable publication as well. Whole-party restore now has native WSS/browser
acceptance through that path. Public deployment, Steam and broader recovery still
require further acceptance.
Ordinary Solo/Host/Join/Watch launches with `RCB_COORD_PORT=0` keep the standalone
session path and native file-save behavior.

## Run the acceptance fixture

```sh
REPLAY_CLAIMBALL_MIGRATION_OUT=/absolute/fresh/output nix develop --command bash tests/replay_claimball_migration/run.sh
```

It builds isolated app/coordinator projects and runs three native players through
planned and abrupt-loss migration. `RCB_MIGRATION_RENDER=1` renders the players
and retains playing/recovering/recovered screenshots. The fixture owns all its
processes and kills only the original owner in the crash case.

For an already prepared build, `tests/replay_claimball_migration/execute.py` takes
`APP_OUTPUT COORDINATOR_OUTPUT FRESH_RESULTS [planned|crash ...]`.

## Configured Room contract

- `RCB_COORD_PORT` selects the local coordinator port. This initial adapter uses
  loopback and room 50, with Claimball content C3.
- `RCB_MEMBER`, `RCB_INCARNATION` and the 64-character lowercase hex `RCB_COORD_KEY`
  provide the authenticated process identity. The development fixture provisions
  members 1–3, incarnations 101–103, with fixed test credentials.
- `RCB_TOKEN` must match that member's admitted game identity. Fixture tokens are
  `migration-1`, `migration-2` and `migration-3`. `RCB_ROLE=host` boots member 1;
  members 2/3 use `client`. The coordinator determines the actual owner/endpoints.
- The fixture trusts members 1/2 to host and receive complete checkpoints. Member 3
  is a normal player without that trust. Automatic nomination selects an eligible
  connected successor from the authenticated roster.
- Hand off host is enabled for a hosting authority with a nominated successor.
  During recovery, the match stays visible with a status message. Restored clients
  keep their seats; the app clears old claims/smoothing/effects at the new epoch.
- Direct file save/resume is disabled for configured Rooms. The app does not bypass
  Room fencing or policy by reopening a standalone checkpoint.

These fixed credentials and loopback endpoints are for local development. Use a
proper admission/provider integration for deployed games. A configured Room is not
an internet discovery or NAT-traversal service.

Set `RCB_PROBE=1` for test-only prepared-checkpoint decoding and restore diagnostics.
Normal play does not perform that extra decode. `recovery_probe` reports actual
Room state and retained checkpoint equality; it does not install a test world or
grant authority. The [receipts](../../docs/replay/results/claimball-migration-2026-09-13/README.md)
state the measured rollback and scope of these native checks.
