# Claimball Parties and browser play

Set `RCB_ROOM_SERVICE` to a provisioned Replay Room service to expose **Create
party**, **Join party**, **Watch only**, **Copy invite** and **Rejoin recent**.
The same controls work in native Godot and the browser. Standalone native sessions
remain available when no service is configured; Solo uses its local session.

Native configuration uses `RCB_*` environment variables. Browser configuration
uses the lowercase suffix as a URL query: `room_service`, `room_local`, `name`,
`port`, `latency`, and so on. This is the existing launch-parameter adapter.
Browser profiles load before connection controls become available. Browser
multiplayer uses the configured Party service and WebRTC transport.

## Identity and admission

Personal reconnect identity and display name use the `replay-claimball` profile
namespace. Party credentials use `replay-claimball-rooms`, separately from that
personal identity. Native Party records default to
`user://claimball_rooms.sqlite3` (`RCB_ROOMS_DB` overrides it). Browser identity,
name and Party records use the existing IndexedDB adapters. Explicit test tokens,
bots and `RCB_PERSIST=0` retain their documented profile bypass behavior.

The creator invites up to three trusted peers. An invite explicitly permits friends
to host and keep the match running. Watch only selects seat zero and disables
checkpoint acceptance for that session. Observers cannot issue player actions;
the fixture verifies their role before and after migration/rejoin. Invite admission
and later credential-based rejoin remain distinct operations.

## Connections and saves

- `RCB_ROOM_LOCAL=1` enables the existing literal-loopback development exception.
  Production services use their normal secure URL and admission configuration.
- `RCB_ROOM_ADDRESS` and `RCB_PORT` describe native gameplay reachability. The
  provisioned grant supplies the actual Room identity and connection information.
- `RCB_ROOM_CA` can supply a native trusted certificate. `RCB_ICE_JSON` and
  `RCB_ROOM_RELAY` feed the existing RTC/relay credential adapters.
- The first connected player starts the match. Handoff is available to an authority
  with an eligible successor. Claims/smoothing/effects reset at an epoch change;
  clients still predict one avatar plus the ball.
- **Save · F5** in a provisioned Party publishes through the service. The authority
  gets a publication receipt; later successful publication replaces that room's
  saved progress. `RCB_ROOM_CHECKPOINT_MS` optionally requests the supported cadence.
  Party publication does not create a browser-local game-save slot.
- Standalone native file saves still use the matching host profile. Browser Solo
  uses named local checkpoint slots, described in the session guide.

The Room service supports operator-selected checkpoint model `claimball` with
content C3 (`0x52434c41494d4233`). Requests cannot choose executable validation code.
The backend validates and persists complete authority checkpoints, including the
roster and ball/player state. No game schema changed for the Party integration.

## Acceptance and limits

```sh
REPLAY_CLAIMBALL_ONLINE_OUT=/absolute/fresh/output nix develop --command bash tests/replay_claimball_online/run.sh
```

Local native Party UI, four-browser planned handoff and owner-SIGKILL paths are
covered. The browser fixture checks real RTC traffic, complete moving checkpoint
restore, new spikes, retained/new chat, observer rejoin, fresh host return with
retained personal profile/invite, one-avatar prediction, common authoritative
worlds, and service publication before/after migration. An independent reader
validates the persisted C3 checkpoints.

An initial browser run ended with `Fenced` before handoff. The diagnostic planned
and crash runs pass, but the original cause remains unestablished; this is retained
as an open issue. No clock, lease, fault or recovery limit was relaxed. See the
[full receipts](../../docs/replay/results/claimball-online-2026-09-13/README.md).
Native WSS and browser whole-party restoration have separate acceptance
[receipts](../../docs/replay/results/claimball-party-restore-2026-09-13/README.md).
Public deployment, broader network/OS/hardware testing, consecutive failures, Steam
and human parity remain further work. `RCB_PROBE=1`
enables extra local checkpoint diagnostics and is used by the browser fixture.

## Reopening a saved Party

After all game processes have stopped, **Rejoin recent** can restore the service's
published checkpoint through the existing explicit restore grant. The service must
retain its database and checkpoint, and the returning trusted host must retain its
credentials. The new authority epoch preserves the published world; later progress
can be rolled back. The UI reports that restoration. An observer can re-register
first but cannot start an authority runtime. Other players rejoin their prior seats.

Both the native trusted-WSS and browser RTC fixtures kill/restart the service as
well as all game processes. They validate the saved frame before shutdown and the
continued publication afterward. A common world check covers post-restore play.
This is recovery of explicitly published progress, not a promise to retain every
last live tick or cosmetic chat line after total process loss.

The recovery notice uses the shared [backup-status observation](../../replay/godot/room_backup.md).
It distinguishes an approved backup from preparation, stale progress or uncertain
control; a prior host change does not imply the next backup is ready.
