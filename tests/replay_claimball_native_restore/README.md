# Claimball native published-party restore

```sh
REPLAY_CLAIMBALL_NATIVE_RESTORE_OUT=/absolute/fresh/output nix develop --command bash tests/replay_claimball_native_restore/run.sh
```

Three native players and an observer use separate gameplay ports, SQLite Party
credentials and personal profiles. The service uses WSS with a generated localhost
certificate trusted through the normal CA option; the plaintext development
exception is disabled.

The host publishes a scored moving match. An independent reader checks the actual
checkpoint, then every game process and the service are SIGKILLed. The same database
reopens with creation disabled. The observer registers first without authority;
the owner restores the exact tick/digest in epoch two and other players reclaim
their seats. Prediction boundaries, new spikes/chat, a common full-world digest and
revision-two publication are verified.

`execute.py GAME_BUILD SERVICE_BUILD FRESH_OUTPUT` reuses prepared builds.
`prepare_bridge.py` adapts the read-only browser status bridge to atomic local
request/status files; game actions still use normal methods. Private requests,
status files, credentials, personal profiles, service databases and TLS keys must
not be included in published evidence. `events.json` omits invite text.
