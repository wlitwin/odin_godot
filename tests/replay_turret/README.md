# Shared turret acceptance

Run `nix develop --command bash tests/replay_turret/run.sh` from the repository
root. `REPLAY_TURRET_OUT` optionally selects a fresh absolute output directory;
otherwise the suite retains an isolated temporary project and logs. It builds
native Godot scripts and checks the full scripts package for WASM, runs seven
pure tests and a native/WASM takeover corpus, exercises the authored workbench,
then runs host/client/spectator and three-member occupied host-crash scenarios.

The real-peer fixture uses 120 ms configured latency, admits normal ability and
mount/release actions, rejects an occupied claim, hands remaining ammo to another
player, and requires empty-turret cleanup plus matching complete world hashes.
Spectators remove the turret view when their observed clock reaches the final
shot; that shot clears occupancy on the authority. The crash fixture waits for a backup that contains
the occupied turret before killing only its own original host process.

`fixtures/content50.checkpoint` is a genuine tick-12 content-50/J checkpoint,
captured before live types changed (local reservation token bytes start with 77).
The conversion test decodes it with frozen types and verifies all mapped state,
an empty turret pool and zero new definition fields. Do not regenerate it with
current codecs. The frozen catalog/action source and schemas live under
`examples/replay_scrapyard/shared/revisions/content50`.

See [feature documentation](../../examples/replay_scrapyard/shared-turret.md)
and [recorded evidence](../../docs/replay/turret-progress.md).
