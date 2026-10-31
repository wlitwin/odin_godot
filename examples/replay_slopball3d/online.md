# Slopball3D Parties and browser play

Configure a Replay Room service to expose Create party, Join party, Watch only,
Copy invite and Rejoin recent in the 3D game. Native and browser builds use the
same Party/Room adapters. Without a service, native direct Host/Join/Watch remain
available; Solo uses a local session.

Use separate terminals for the local service and game:

```sh
mkdir -m 700 -p .replay-slopball3d-data
REPLAY_ROOM_CONTENT=0x52534c4f50334434 REPLAY_ROOM_CHECKPOINT_MODEL=slopball3d \
REPLAY_ROOM_DB="$PWD/.replay-slopball3d-data/rooms.sqlite3" \
REPLAY_ROOM_CREATE_DB=1 REPLAY_ROOM_LOCAL_DEVELOPMENT=1 \
nix develop --command bash examples/replay_room_service/run.sh
```

```sh
RS3_ROOM_SERVICE=ws://127.0.0.1:49740 RS3_ROOM_LOCAL=1 \
nix develop --command bash examples/replay_slopball3d/play.sh
```

Omit database creation when reopening an existing service. A service selects one
content ID; use separate service ports/databases for different games.

Create a party and share its invite. Other players paste it and Join, selecting
Watch only for an observer. The first connected player starts the match. WASD moves
on XZ, Space kicks with loft, Enter opens chat and Tab shows the scoreboard.

Native launch options use `RS3_*`. Browser URL parameters use the lowercase suffix,
including `room_service`, `room_local`, `name`, `port` and `latency`. Browser
multiplayer uses RTC and a configured Party service. The profile loads before
connection controls become available.

## Profiles, authority and saves

Personal identity/name preferences use `replay-slopball3d`; Party credentials use
`replay-slopball3d-rooms`. Native Party data defaults to `user://slopball3d_rooms.sqlite3`,
overridden by `RS3_ROOMS_DB`. Browser identity/name/credentials use the shared
IndexedDB adapters. Rejoin uses the stored Party credential and a new process
incarnation, preserving the member independently of personal preferences.

Invites admit up to three trusted peers who may host. Watch only selects seat zero,
disables succession-checkpoint acceptance, and keeps the observer's ball solver
frozen. Handoff is available when the authority has an eligible successor.

Migration restores the approved complete checkpoint under a newer epoch. Body3
seeds the owner solver from saved position, quaternion orientation and linear/angular
velocity. Fresh observations use the new ownership scope. An abrupt host loss may
roll back to the approved backup. Godot contact caches and joints are not serialized.

Save/F5 in a Party publishes through the service and reports a committed receipt.
`RS3_ROOM_CHECKPOINT_MS` optionally requests automatic publication. A later save
replaces the room's published progress. This is separate from native direct file
Save/Resume and does not create browser-local game-save slots. Browser-local Solo saves are described in the [session guide](session-ui.md#browser-local-checkpoints).

`RS3_ROOM_ADDRESS`/`RS3_PORT` describe native gameplay reachability (default 49580).
`RS3_ROOM_CA` supplies a native trusted certificate; `RS3_ICE_JSON` and
`RS3_ROOM_RELAY` configure the existing RTC/relay adapters. The explicit
`RS3_ROOM_LOCAL=1` exception permits WS only on literal loopback addresses. Public
browser deployment requires the normal secure service/origin and reachable ICE setup.

The operator-selected `slopball3d` backend validates D4 (`0x52534c4f50334434`)
checkpoints. Client requests cannot choose validation code. The integration changes
no game model, schema, physics material, collision shape, camera or mesh geometry.

## Verification

```sh
REPLAY_SLOPBALL3D_ONLINE_OUT=/absolute/fresh/output \
  nix develop --command bash tests/replay_slopball3d_online/run.sh
```

The fixture exercises native Party UI and four-browser planned/crash migration,
checking complete spinning backups, solver pose/momentum, new kicks/goals, observer
rejoin, fresh old-host return, retained/new named chat, common world digests,
service publication, RTC traffic, graphics errors and control layout. `RS3_PROBE=1`
enables the checkpoint diagnostics used by the fixture. Public/Steam deployment,
broader hardware/failure sequences and human gameplay comparison remain roadmap work.

See [recorded results and limitations](../../docs/replay/results/slopball3d-online-2026-09-14/README.md).

## Reopening a saved party

Rejoin recent can restore the service's published progress after every game process
and the service stop. Keep the service database and returning members' credentials;
restart the service with database creation disabled. Either the original creator
or another trusted saved player can restore. In Watch mode, an observer may register first but
does not start an authority runtime. Other players return to their saved seats, and
the original creator can rejoin after a different member has restored the party.

The new authority installs the exact published world under a newer epoch. Body3
seeds from the saved position, quaternion, linear velocity and angular velocity
before new scoped observations commit. The UI reports restored progress and known
rolled-back ticks. Continuing play can publish a replacement checkpoint. Progress
after publication and cosmetic chat history can be lost after total process loss;
solver contact caches and joints are not serialized.

The [native WSS test](../../tests/replay_slopball3d_native_restore/README.md) and
[browser RTC test](../../tests/replay_slopball3d_party_restore/README.md) test both
returning-host choices, independently decode source and replacement publications,
and compare the actual first solver seed before requiring another kick and goal.

See [the expanded recovery matrix and its limits](../../docs/replay/results/owner-streamed-party-restore-2026-09-14/README.md).

The recovery notice uses the shared [backup-status observation](../../replay/godot/room_backup.md).
It distinguishes an approved backup from preparation, stale progress or uncertain
control; a prior host change does not imply the next backup is ready.
