# Native Quickdraw published restore

```sh
REPLAY_QUICKDRAW_NATIVE_RESTORE_OUT=/absolute/fresh/output nix develop --command bash tests/replay_quickdraw_native_restore/run.sh
```

The fixture uses separate native Godot processes and gameplay ports, individual
SQLite credential stores/personal profiles, and a local WSS service. It generates a
short-lived localhost certificate and supplies it through the normal trusted-CA
option. It does not use the loopback-WS development exception.

Three players and an observer join through the real menu/Party paths. The authority
publishes during combat, then every game process and the service are SIGKILLed.
The service reopens the existing database. Fresh clients load their saved credentials:
the observer registers first, the owner restores the published tick/hash in a new
epoch, and other players reclaim their seats. Combat/chat continue, the authority
publishes revision two and all peers compare one canonical retained world.

`execute.py GAME_BUILD SERVICE_BUILD FRESH_OUTPUT` runs against existing isolated
builds. `prepare_bridge.py` adapts the read-only browser status bridge to atomic local
request/status files; game actions still use the ordinary menu/control methods.
Private request/status files, identity/profile files, databases and TLS keys must not
be included in published evidence. `events.json` removes invite text from status.
An independent native reader validates the final database publication.
