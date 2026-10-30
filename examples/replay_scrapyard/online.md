# Online party menus

Replay Scrapyard now uses the shared `replay/godot.Party` flow with the standalone
[room service](../replay_room_service/README.md). Configure `RSY_ROOM_SERVICE` to
enable Create Party, Join Party, Watch with an invite, Rejoin Recent, and Copy Party
Invite. Copy is also available in the Escape menu during play. The existing
solo/direct/preconfigured-room paths remain available without this setting.

For local testing, run the service with Scrapyard's content ID:

```sh
REPLAY_ROOM_CONTENT=0x5253435241503048 \
REPLAY_ROOM_DB="$PWD/.replay-room-data/scrapyard.sqlite3" \
REPLAY_ROOM_CREATE_DB=1 REPLAY_ROOM_LOCAL_DEVELOPMENT=1 \
nix develop --command bash examples/replay_room_service/run.sh

RSY_ROOM_SERVICE=ws://127.0.0.1:49740 RSY_ROOM_LOCAL=1 \
nix develop --command bash examples/replay_scrapyard/play.sh
```

Create the private data directory first and omit database creation on later service
runs. For multiple players on one machine, give each a separate `RSY_PROFILE_DIR`,
`RSY_ROOMS_DB` and `RSY_PORT`. A browser profile similarly represents one player.
Use ordinary WSS and appropriate reachable gameplay/ICE endpoints outside explicit
loopback development; Internet deployment is not established by these local gates.

| Setting | Meaning |
| --- | --- |
| `RSY_ROOM_SERVICE` / `room_service` | Admission/control/RTC signaling URL |
| `RSY_ROOM_LOCAL=1` / `room_local=1` | Explicit loopback WS development opt-in |
| `RSY_ROOM_CA` | Optional native CA certificate for verified private TLS |
| `RSY_ROOMS_DB` | Native room credential file, default `user://rooms.sqlite3` |
| `RSY_ROOM_ADDRESS` / `room_address` | Advertised native gameplay address |
| `RSY_PORT` / `port` | Native gameplay port, default 49610 |
| `RSY_ICE_JSON` | Native RTC deployment configuration, when using an RTC extension |
| `RSY_ROOM_RELAY=1` / `room_relay=1` | Obtain and refresh credentials from the room service |

Browser hosts set `globalThis.replayIceConfig` before Godot starts, keeping relay
credentials out of query parameters. The asset-aware party flow also passes an
actual relay-only TURN gate; [deployment settings](../../replay/godot/ice-deployment.md)
describe configuration, ownership and remaining Internet/expiry acceptance.

The credential file is separate from the progression profile. The game's personal
token still selects its saved name, loadout, cores and parts. Only the Session's
network token comes from the room grant. Native/browser acceptance starts from
existing profiles and proves those identities and values remain through enrollment,
takeover and fresh-process rejoin.

The host issues a reproducible trusted co-op invitation with `SEATS - 1` uses.
Its permission is stated in the menu. Rejoining repeats the same issuance parameters
without adding uses or changing the invite. A refused/revoked invite does not erase
an existing member credential. Invite rotation/revocation controls and general
durable invitation-operation records remain future work.

Room automatically selects a connected eligible successor. Scrapyard retains its
own `spray_preparation_ready` callback and action-admission model: the successor
cannot acknowledge an asset-bearing checkpoint before its PNG dependencies are
available. The online gates deliberately withhold the spray, observe that barrier,
release the asset and then hand off active combat. A returned host gets a newer
incarnation, its original seat/loadout and an accepted new shot.

This does not change competitive trust, progression-authority rules, duplicate-live-
identity policy or the simulation model. A stored credential is not a game save or
authority lease. All-participants-gone recovery, fuller connection failure UX,
Steam, public deployment and the remaining parity/comparison ledger remain work.
The original sibling Scrapyard stays independently runnable and untouched.

```sh
nix develop --command bash examples/replay_scrapyard/online_run.sh
nix develop --command bash examples/replay_scrapyard/online_web_run.sh
```

See [integration evidence](../../docs/replay/results/scrapyard-party-2026-09-07/README.md)
and the [shared Party API](../../replay/godot/party.md).
## Durable party progress and sprays

The online host can now use the save action/menu to store a complete checkpoint
with its required spray PNGs. The game and service enumerate current sprays plus
executable pending declarations; missing or invalid dependencies prevent publication.
The checkpoint and package commit atomically under one room publication revision.

Rejoining an abandoned saved party downloads and validates those bytes into the
game's asset cache before requesting a new authority epoch. Native and browser
tests start with an empty cache and no local spray copy, restore the same stamped
image, fire again and publish revision 2. Personal loadout/progression records and
network identity remain separate.

```sh
nix develop --command bash examples/replay_scrapyard/party_asset_restore_run.sh
nix develop --command bash examples/replay_scrapyard/party_asset_restore_web_run.sh
```

The room package profile is bounded to 1 MiB including checkpoint and assets, with
32 unique dependencies. Scrapyard retains its 128 KiB per-spray limit. This does not
relax the room's known rollback limit; a durable save can still be too old to grant
recovery. See [package semantics](../../replay/provision/checkpoint/assets.md).
