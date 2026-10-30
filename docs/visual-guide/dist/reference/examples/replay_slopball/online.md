# Slopball Parties and browser play

Configure `RSL_ROOM_SERVICE` to expose **Create party**, **Join party**, **Watch
only**, **Copy invite** and **Rejoin recent**. These controls use Replay's shared
Party/Room adapters on native Godot and in the browser. Solo uses a local session.
Without a service, native Host/Join/Watch retain their direct connection flow.

For a local service and native game, use separate terminals:

```sh
mkdir -m 700 -p .replay-slopball-data
REPLAY_ROOM_CONTENT=0x52534c4f50423234 REPLAY_ROOM_CHECKPOINT_MODEL=slopball \
REPLAY_ROOM_DB="$PWD/.replay-slopball-data/rooms.sqlite3" \
REPLAY_ROOM_CREATE_DB=1 REPLAY_ROOM_LOCAL_DEVELOPMENT=1 \
nix develop --command bash examples/replay_room_service/run.sh
```

```sh
RSL_ROOM_SERVICE=ws://127.0.0.1:49740 RSL_ROOM_LOCAL=1 \
nix develop --command bash examples/replay_slopball/play.sh
```

Omit `REPLAY_ROOM_CREATE_DB=1` when reopening an existing service database. Choose
Create party and share the invite. Other players paste it and choose Join party;
Watch only joins as an observer. The first connected player starts the match.

Native launch settings use `RSL_*` environment variables. Browser settings use
the lowercase suffix as URL query parameters, for example `room_service`,
`room_local`, `name`, `port` and `latency`. Browser multiplayer requires the
configured service and uses WebRTC. Profile loading completes before admission.
The test runner below prepares and exports a separate Web build.

## Identity and authority

Personal identity/name preferences use the `replay-slopball` namespace; Party
credentials use `replay-slopball-rooms`. Native Party storage defaults to
`user://slopball_rooms.sqlite3`, overridden by `RSL_ROOMS_DB`. Browser records
use the shared IndexedDB adapters. Credentials are distinct from game state.
Rejoin recent uses a stored credential, preserving the member while obtaining a
new process incarnation. Personal name and identity survive a browser restart.

The invite admits up to three trusted peers who may host. Watch only selects
seat zero and disables succession-checkpoint acceptance in that session. Observers
keep their ball solver frozen and cannot submit player actions. Handoff becomes
available when the authority has an eligible successor.

Migration restores the approved checkpoint under a newer epoch. The Body2 adapter
seeds the new owner's actual solver from the saved pose and momentum before new
scoped observations can commit. It does not serialize Godot contact caches.
An abrupt loss can roll back recent progress to the approved backup.

## Connection and save settings

- `RSL_ROOM_ADDRESS` and `RSL_PORT` describe native gameplay reachability; default
  gameplay port is 49570. The grant supplies the Room connection information.
- `RSL_ROOM_LOCAL=1` permits the shared literal-loopback WS development exception.
  Secure deployments use the service's normal WSS configuration. `RSL_ROOM_CA`
  supplies a native trusted certificate when needed.
- `RSL_ICE_JSON` and `RSL_ROOM_RELAY` configure existing RTC/relay adapters.
- Save/F5 in a Party publishes through the service, reporting a committed receipt.
  `RSL_ROOM_CHECKPOINT_MS` optionally requests automatic publication. A later
  successful save replaces that room's published progress.
- Party publication is separate from native file saves and browser-local storage.
  Standalone native Save/Resume keeps its matching-profile policy. Browser-local
  Solo saves are described in the [session guide](session-ui.md#browser-local-checkpoints).

The operator-selected `slopball` service backend validates complete B24
(`0x52534c4f50423234`) checkpoints. Client requests cannot choose validation code.
This integration does not change the model or checkpoint schema.

## Verification

```sh
REPLAY_SLOPBALL_ONLINE_OUT=/absolute/fresh/output \
  nix develop --command bash tests/replay_slopball_online/run.sh
```

The fixture covers native Party UI and four-browser planned/crash migration,
including exact recovery, moving solver seeding, continued kicks/goals, observer
rejoin, fresh host return, named chat, common world digests and durable publication.
It checks actual RTC traffic and rejects WebGL errors. `RSL_PROBE=1` enables the
extra checkpoint diagnostics used by the browser fixture.

Static pitch, kicker and ball geometry uses authored immutable meshes to avoid
Polygon2D redraw buffer conflicts in the pinned Web renderer. Geometry and physics
remain the same. Public deployment, broader network/OS/hardware testing, repeated
failures, Steam and human play comparison remain roadmap work.

See [recorded results and limitations](../../docs/replay/results/slopball-online-2026-09-14/README.md).

## Reopening a saved party

After every game process has stopped, Rejoin recent can reopen the service's
published progress under a new authority epoch. Keep the service database and the
returning members' Party credentials. The service can restart with database creation
disabled. An observer may register first but cannot create an authority runtime;
a returning trusted player restores the publication and players reclaim their saved seats.

The saved world includes ownership scopes, accepted body observations, movement
baselines, pose, linear/angular velocity, score and names. The first eligible local
solver receives that saved pose/momentum before publishing in the new epoch. The
UI reports restored progress and known rolled-back ticks. New play can publish a
replacement save. Progress after the publication can be lost, and cosmetic chat
history is not guaranteed after every process disappears.

Native WSS/ENet and browser RTC shutdown/restart fixtures are available in
[the native gate](../../tests/replay_slopball_native_restore/README.md) and
[the browser gate](../../tests/replay_slopball_party_restore/README.md). They compare
the saved world and actual first solver seed independently, then require another
kick/goal, returning named players/observer, new chat and renewed publication.

See [shutdown-recovery results and limitations](../../docs/replay/results/slopball-party-restore-2026-09-14/README.md).

The restore gates also cover a trusted player in seat two restoring before the
creator returns. The creator subsequently reclaims seat one; the new authority can
continue play and publish a replacement checkpoint under its own identity.

See [the expanded recovery matrix and its limits](../../docs/replay/results/owner-streamed-party-restore-2026-09-14/README.md).

The recovery notice uses the shared [backup-status observation](../../replay/godot/room_backup.md).
It distinguishes an approved backup from preparation, stale progress or uncertain
control; a prior host change does not imply the next backup is ready.
