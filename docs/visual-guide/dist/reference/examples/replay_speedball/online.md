# Speedball party menus

Set `RSB_ROOM_SERVICE` to use the shared Replay Party helper and
[room service](../replay_room_service/README.md). The native/browser menu then offers Create
Party, Join Party, a Watch only choice, Rejoin Recent and Copy Invite. The creator
can also copy its invite during play. Without that setting, the existing direct
address and native save/resume menus remain available. Solo remains available in
party mode; file selection/resume controls use the direct menu configuration.

The service URL is deployment configuration, not a hard-coded public service.
A local development setup can use:

```sh
mkdir -p .replay-room-data
REPLAY_ROOM_CONTENT=0x5253504545444234 \
REPLAY_ROOM_DB="$PWD/.replay-room-data/speedball.sqlite3" \
REPLAY_ROOM_CREATE_DB=1 REPLAY_ROOM_LOCAL_DEVELOPMENT=1 \
nix develop --command bash examples/replay_room_service/run.sh

RSB_ROOM_SERVICE=ws://127.0.0.1:49740 RSB_ROOM_LOCAL=1 \
nix develop --command bash examples/replay_speedball/play.sh
```

Omit database creation on subsequent service starts. Give each local player a
separate `RSB_PROFILE`, `RSB_ROOMS_DB` and `RSB_PORT`. Native storage currently uses
the optional Darwin/Linux SQLite adapter. The game test uses verified WSS with a
private CA; plain WS requires the explicit loopback development setting.

| Setting | Meaning |
| --- | --- |
| `RSB_ROOM_SERVICE` | Provisioning and Room control URL |
| `RSB_ROOM_LOCAL=1` | Explicit loopback WS development mode |
| `RSB_ROOM_CA` | Optional native CA certificate for private verified WSS |
| `RSB_ROOMS_DB` | Room credentials and recent selection; default `user://speedball_rooms.sqlite3` |
| `RSB_ROOM_ADDRESS` | Advertised native gameplay address; default `127.0.0.1` |
| `RSB_PORT` | This member's advertised gameplay port; default `49480` |
| `RSB_PROFILE` | Separate personal identity/name profile |

The service needs reachable gameplay endpoints for native ENet. Local tests do not
prove Internet/NAT traversal. The shared helper also accepts ICE/relay configuration,
and the browser test verifies local RTC gameplay. Public deployment and
TURN-only routing remain separate Speedball acceptance work.

Create Party durably enrolls a creator and produces a repeatable invite. Join Party
validates the pasted invite, enrolls the member and durably stores its credential
before opening Room. Rejoin Recent reads that stored credential; the returned
process receives a newer incarnation and retains its game seat. The personal
identity/name profile remains separate from the room's network token. A failed
invitation does not create a local game; competing start actions are blocked while
enrollment is active.

Invites grant trusted co-op membership with `SEATS - 1` uses. The menu explicitly
says invited friends can host and keep the match running. This grants access to
complete authority checkpoints when selected as a successor. It is not a competitive
untrusted-player preset. Ordinary player invitations remain a library capability;
this game menu currently issues the trusted co-op variant.

Watch only applies to Join Party and Rejoin Recent. Invited observers occupy seat
0, create no player, and receive no checkpoints. They remain observers through
migration and can leave/rejoin in that mode. Observer chat uses the existing
`Observer` label. The choice is a gameplay role, not a reduction of the credential's
underlying trusted membership; the driver selects successors from connected player
seats. Create Party starts a player host regardless of the watch choice.

Room's normal lease/roster checks, automatic successor selection, prepared
checkpoints and migration UI apply. Native acceptance saves a moving scored pitch,
performs planned handoff or abrupt owner loss, then returns the old host in a fresh
process using Rejoin Recent. It requires a stable invite/seat, an increased
incarnation, observer leave/rejoin, new spikes/chat and matching canonical worlds.

```sh
nix develop --command bash examples/replay_speedball/online_run.sh
RSB_PARTY_RENDER=1 RSB_PARTY_MODES=planned \
  nix develop --command bash examples/replay_speedball/online_run.sh
```

`RSB_PARTY_OUT` selects a fresh artifact directory. Private databases, identity
files, TLS keys and invite text belong in local scratch storage, not published test
results. See [receipts, captures and limits](../../docs/replay/results/speedball-party-2026-09-08/README.md).

Steam integration, invite rotation/revocation UI,
public deployment and wider visual/playtest/comparison coverage remain. The original
Speedball and sibling Scrapyard projects stay independently runnable.


The [browser party gate](online_web_run.sh) exports the same game and uses lower-case
query parameters such as `room_service` / `room_local` instead of native environment
variables. It persists personal identity/name and room credentials in separate
IndexedDB namespaces, and verifies them after closing/reopening a browser process.
Gameplay uses WebRTC while the configured service provides enrollment, control and
signaling. The local gate exercises planned handoff, browser-host loss, true
observers, rejoin, new actions/chat and matching worlds. See
[browser evidence](../../docs/replay/results/speedball-browser-2026-09-08/README.md)
for measured limits. Browser solo checkpoints use the separate
[save-slot flow](README.md#browser-solo-save-slots); public relay deployment remains open.

## Saved party recovery

The online host can use **Save** or F5 to publish the match to the room service.
Saving is asynchronous: the UI shows progress, a confirmed stored tick, or an
uncertain result that can be retried. Followers and observers cannot publish.
`RSB_ROOM_CHECKPOINT_MS` (browser `room_checkpoint_ms`) opts into automatic saving;
zero keeps saves manual and supported intervals are 1–120 seconds.

**Rejoin recent party** joins a live host when one exists. If the party is abandoned,
Room loads the stored match, obtains a newer authority epoch and resumes it with
the returning player's stable seat/profile. Missing, incompatible or too-old saves
show a recovery error and retry option. A stored save does not bypass the room's
rollback policy or create a replacement match silently.

The recovery fixture saves a scored first round, exits the game and kills/restarts
the service, then uses the actual rejoin menu in a fresh process. It checks the
saved score, winner, round and kick count plus personal profile identity, admits a
new guest, plays round 2, verifies chat and publishes again. A separate reader
validates the continued stored match and names.

```sh
nix develop --command bash examples/replay_speedball/party_restore_run.sh
nix develop --command bash examples/replay_speedball/party_restore_web_run.sh
```

Native uses verified TLS; the browser fixture uses explicit loopback development
WS and real RTC. These checkpoints remain distinct from direct file saves and
browser solo slots. See [Room restoration](../../replay/godot/room_restore.md).

The recovery notice uses the shared [backup-status observation](../../replay/godot/room_backup.md).
It distinguishes an approved backup from preparation, stale progress or uncertain
control; a prior host change does not imply the next backup is ready.
