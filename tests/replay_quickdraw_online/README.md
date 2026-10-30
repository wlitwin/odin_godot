# Quickdraw party/browser acceptance

```sh
REPLAY_QUICKDRAW_ONLINE_OUT=/absolute/fresh/output nix develop --command bash tests/replay_quickdraw_online/run.sh
```

The runner creates isolated game/service copies, builds native and WASM code, then
runs a local room service and separate Chrome processes. The browser fixture creates
a party, rejects an invalid invite, admits three players and a true observer, starts
combat, and exercises both planned handoff and SIGKILL of the exact host process.
It verifies exact combat restoration, continued hits/lobs/respawn, observer rejoin,
fresh-process host return, personal identity/name continuity, stable invites and
canonical world hashes shared by all four final peers.

The browser records real RTC traffic and buffer-target conflicts. A read-only test
bridge reports state and invokes ordinary game/menu actions; it does not replace
the simulation, invent checkpoints or authorize takeover. Invite strings and browser
profiles are private fixture state and are excluded from published evidence.

The original and successor each publish a durable Room save. An independent native
reader validates the actual database records with Quickdraw's model and checks
revision two, epoch two, combat state and names. Native Party acceptance reuses the
existing menu/chat/nonzero-score/observer/rejoin scenario through the same service
and the SQLite client store. Direct native UI/profile and file saves remain separate
regression gates.

`build_service.sh`, `build_web.sh`, `execute_web.sh`, `native.py` and `verify/` are
available separately for focused reruns. Use fresh output paths. Public TLS/TURN,
other devices/browsers and full competitive/play-feel acceptance remain additional
work; loopback WS is enabled explicitly only by the fixture.
