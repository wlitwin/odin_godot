# Quickdraw abandoned-party restore

```sh
REPLAY_QUICKDRAW_PARTY_RESTORE_OUT=/absolute/fresh/output nix develop --command bash tests/replay_quickdraw_party_restore/run.sh
```

The fixture creates three players and a true observer, starts combat and publishes
a durable save. It records a canonical hash of the published tick, stops controls,
and SIGKILLs the exact owned Chrome processes. The coordinator/service is then killed
and restarted against the same database with creation disabled.

The observer returns first using its saved credential and explicit watch preference.
The owner then rejoins in a fresh browser profile process, recovers through the
published-restore service path and must match the original saved tick/hash. Other
players return through their existing credentials and seats. The game continues
hits/lobs/respawn and named chat, publishes revision two, and all four peers compare
a common canonical world. RTC traffic, observer permissions, local/party store
separation and graphics errors retain the shared browser assertions.

`execute.py WEB_OUTPUT SERVICE_OUTPUT FRESH_OUTPUT` runs against existing isolated
builds. Private browser profiles, invitations and service databases must not be
included in published evidence. The independent native reader validates the final
stored publication through Quickdraw's real model.

This is local browser/service recovery acceptance. Public deployment, other devices,
concurrent competing restorer scenarios in this game and broader policy/fault cases
remain separate requirements in the full roadmap.
