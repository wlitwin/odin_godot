# Replay room service

Run this standalone Godot/Odin service to enroll room members, coordinate which
process may accept gameplay results, and connect peers through RTC signaling. Its
admission hub persists credentials; its authority coordinator grants and checks
time-bounded hosting leases. It supports one game content ID
and up to 32 resident rooms (16 by default). Native clients can use ENet gameplay;
browser clients use RTC. The service stores and transfers durable checkpoints
for the compiled Cavecrawl, Speedball, Scrapyard, Quickdraw, Claimball, Slopball and Slopball3D models. It does not run gameplay;
checkpoint download does not grant authority or automatically resume a game.

The bundled SQLite service currently runs on macOS/Linux. Both frameworks and all
original games remain separate. This is an experimental deployment example, not
a hosted service or a completed Internet operational profile.

## Local Cavecrawl

From the repository root, create a private data directory and start the service:

```sh
mkdir -m 700 -p .replay-room-data
REPLAY_ROOM_CONTENT=0x4341564552504c39 \
REPLAY_ROOM_DB="$PWD/.replay-room-data/rooms.sqlite3" \
REPLAY_ROOM_CREATE_DB=1 REPLAY_ROOM_LOCAL_DEVELOPMENT=1 \
nix develop --command bash examples/replay_room_service/run.sh
```

Creation is explicit. On subsequent runs omit `REPLAY_ROOM_CREATE_DB=1`, so losing
the database does not silently erase previous authority decisions.

In another terminal:

```sh
REPLAY_CAVE_ROOM_SERVICE=ws://127.0.0.1:49740 \
REPLAY_CAVE_ROOM_LOCAL=1 \
nix develop --command bash examples/replay_cavecrawl/play.sh
```

Choose **Create party**, then share **Copy party invite**. Another player pastes
it and chooses **Join party**. **Rejoin recent party** loads that game's stored
credential. See [the game flow](../replay_cavecrawl/online.md) for profile separation,
gameplay addresses, browser use and recovery boundaries.

## Configuration

| Environment variable | Meaning |
| --- | --- |
| `REPLAY_ROOM_CONTENT` | Required nonzero decimal or `0x` hexadecimal game content ID |
| `REPLAY_ROOM_CHECKPOINT_MODEL` | Optional required model: `cavecrawl`, `cavecrawl-owned`, `speedball`, `scrapyard`, `quickdraw`, `claimball`, `slopball`, `slopball3d`; `disabled` turns checkpoint endpoints off. By default, a matching compiled content ID enables its model; other content IDs remain admission-only |
| `REPLAY_ROOM_DB` | Required private SQLite file path; protect its directory/backups |
| `REPLAY_ROOM_CREATE_DB=1` | Explicit first-time database creation |
| `REPLAY_ROOM_BIND` | Listener address, default `127.0.0.1` |
| `REPLAY_ROOM_PORT` | Listener port, default `49740` |
| `REPLAY_ROOM_CAPACITY` | Resident/persisted room limit, 1–32, default 16 |
| `REPLAY_ROOM_CERT`, `REPLAY_ROOM_KEY` | TLS certificate/chain and private-key file paths |
| `REPLAY_ROOM_LOCAL_DEVELOPMENT=1` | Permit plain WS only on literal `127.0.0.1` or `::1` |
| `REPLAY_ROOM_MODE` | New-room policy: `cooperative` (default) or `dedicated` |
| `REPLAY_ROOM_TURN_SECRET_FILE` | Optional server-only Coturn shared-secret file |
| `REPLAY_ROOM_TURN_URLS` | Comma-separated TURN endpoints for credential issuance |
| `REPLAY_ROOM_TURN_TTL` | Credential lifetime, 5–3600 seconds, default 600 |
| `REPLAY_ROOM_TURN_RELAY_ONLY=1` | Require relay-only ICE in issued settings |

The optional [relay provider](../../replay/relay/README.md) authenticates enabled
members through a connection-bound challenge and issues expiring credentials.
Clients never receive the signing secret. Coturn uses the same server-only secret
with `use-auth-secret`; the client helper refreshes credentials in the background.

Without explicit loopback development mode, certificate/key material is required.
The client must verify the certificate and hostname. Public browser origins need
appropriate HTTPS/WSS deployment and reachable ICE/TURN infrastructure; those
deployment gates remain open. The loopback fixture is not evidence of Internet
reachability.

Dedicated mode refuses public creation of infrastructure credentials. Preload
dedicated rooms using trusted admission administration. Existing records retain
their policies; changing the new-room mode does not rewrite them. The service
rejects wrong-content/corrupt or excessive startup inventories rather than dropping
records to fit capacity.

## Durable checkpoints

The deployment's content ID selects validation code; client requests cannot select
a model or schema. An explicit model/content mismatch fails before opening the
database. Match this value to the game build’s `CONTENT` constant; changing it
selects a different compatibility contract. Current compiled models are:

| Model | Content ID |
| --- | --- |
| Cavecrawl | `0x4341564552504c39` |
| Cavecrawl with owner observations | `0x434156454f574e33` |
| Speedball | `0x5253504545444234` |
| Scrapyard | `0x525343524150304b` |
| Quickdraw | `0x52515549434b4432` |
| Claimball | `0x52434c41494d4233` |
| Slopball | `0x52534c4f50423234` |
| Slopball3D | `0x52534c4f50334434` |

Each admitted room receives one bounded checkpoint endpoint. Unknown-room traffic
does not create endpoints, load storage or restart coordinators. Metadata and
checkpoint bytes commit atomically with publication and a compare-and-swap
(CAS) against the full coordinator Record. A final authorization guard rejects a lease that expires during validation or
storage work. A normal player cannot read authority-only checkpoints; reads require
trusted hosting permission, and dedicated rooms additionally require infrastructure.

Use the [checkpoint client API](../../replay/provision/checkpoint/README.md) on the
same connection as the registered authority RPC. Upload/download/status packets
are signed, and the service multiplexes them with admission, authority, signaling
and relay traffic. Each endpoint holds at most one 1 MiB transfer with a 30-second
lifetime and bounded packet budgets. Room capacity bounds the total endpoint count.
An exact committed retry returns its publication without renewing authority.

This stores the game model's complete checkpoint, including embedded definitions
and its declared external asset bytes. Scrapyard's current and executable pending
spray dependencies use a [complete atomic package](../../replay/provision/checkpoint/assets.md),
validated by the service and installed before restoration. Personal profiles remain
separate. [Room/Party](../../replay/godot/room_save.md) handles manual/automatic
publication and Cavecrawl exposes its save status; other games still need UI and
asset preparation, and
all-members-gone gameplay needs the complete Room/Party restore flow. The service
now supports an explicit [published restore grant](../../replay/provision/checkpoint/restore.md):
expired-owner registration remains lease/quarantine fenced, then a separate CAS
authorizes an exact saved publication under a newer epoch. Native model fixtures
exercise this. Room/Party now drives it through Cavecrawl's native/browser rejoin
menu, with callback-gated asset preparation. Scrapyard now also passes native/browser
restoration after deleting its local spray copy. Broader asset profiles and game
acceptance remain open. Slopball now has native WSS and browser RTC acceptance
for restoring its published owner-streamed world and first actual solver momentum
after all game processes and the service stop; see [its restore flow](../replay_slopball/online.md#reopening-a-saved-party).
Slopball3D also has native/browser acceptance for quaternion and angular-momentum
recovery, including restoration by another trusted saved player before the creator
returns; see [the 3D flow](../replay_slopball3d/online.md#reopening-a-saved-party).

All binary admission and control packets share the socket. An initial RTC text
message selects a current opaque room code; the existing challenge/MAC still
authenticates that connection against that room's registered members. Later signals
stay bound to the selected room. Room/epoch changes and poisoned coordinators close
their signaling connections. Other rooms retain their own mappings and state.

This service owns its whole room set. Concurrent copies using the same database
fence each other's CAS writes; this is not a highly available coordinator cluster.
Anonymous co-op creation is bounded by the hub's room and request limits. Account
authorization, per-user quotas, room retirement, public abuse controls and operational
monitoring remain additional deployment work.

## Verification

```sh
nix develop --command bash examples/replay_cavecrawl/online_run.sh
nix develop --command bash examples/replay_cavecrawl/online_web_run.sh
nix develop --command bash tests/replay_room_checkpoint/run.sh
CHECKPOINT_RESTORE=1 nix develop --command bash tests/replay_room_checkpoint/run.sh
```

These drive actual menus, durable enrollment, automatic successor selection,
handoff, loot conservation and fresh-process rejoin. Browser acceptance includes
two simultaneous isolated rooms. Native uses verified fixture TLS; browser uses
explicit loopback WS and real RTC. See [recorded evidence](../../docs/replay/results/cave-online-menu-2026-09-07/README.md).

The checkpoint gate uses the actual standalone service and each of the three game
models over verified TLS. It publishes and downloads a tick-1 checkpoint, kills
the service, reopens the same database, and verifies the identical archive from a
fresh trusted incarnation 2 with zero authority lease. It also rejects mismatched
deployment models before database creation. This is native seeded-state persistence
evidence. Cavecrawl's native/browser Room tests additionally publish during active
play and after migration. Its `party_restore_run.sh` and `party_restore_web_run.sh`
gates resume actual saved cave play after every original process has exited, then
admit a new guest and publish the continued game.
