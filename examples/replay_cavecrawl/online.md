# Party menus and durable enrollment

Create or join a Replay Cavecrawl party through the
[room service](../replay_room_service/README.md), which enrolls trusted members
and coordinates which process may host. This flow supplies member IDs and control
keys instead of requiring players to configure them. With `REPLAY_CAVE_ROOM_SERVICE` configured, the menu
shows **Create party**, **Join party**, **Rejoin recent party**, and **Copy party
invite**. Without it, the existing solo/LAN menu and preconfigured fixtures remain.

Creating or joining first persists the exact enrollment request. A successful
credential becomes usable only after its storage receipt. Native macOS/Linux uses
the optional private SQLite client store; browsers use IndexedDB. Records are
scoped by the exact service URL and room ID. New parties get new records; existing
credentials are not overwritten.

A small recent-party reference is stored separately with its own compare-and-swap.
It changes only after the enrollment request is durable, and before that request
is sent. A failed/conflicting reference stops the attempt. **Rejoin recent party**
loads the exact stored request or credential, then performs normal challenged
process registration. A missing/corrupt record does not create a replacement
identity. Joining again with an invite also finds that room's existing credential.

## Invites and host migration

Cavecrawl issues one co-op invite with `SEATS - 1` uses. Its secret is derived with
HMAC from the creator's persisted claim, exact service URL, room/content, role,
use count and index zero. Retrying after restart reproduces the same capability
and issuance parameters. It does not issue extra uses, revive a revoked invite,
or disclose the creator's secret to recipients. New indices are explicit new
invitations, not automatic retry behavior. This version does not expose invite
rotation/revocation controls.

The invite grants trusted co-op membership, including permission to host and receive
complete authority backups. The menu states that invited friends can keep playing
if the host disconnects. Competitive games must choose their own admission policy;
dedicated public creation/trusted-player invites remain refused by the backend.

Room's opt-in automatic successor mode selects a connected eligible member in
stable seat order, checking the authenticated roster, token, current incarnation,
hosting/trust permission and infrastructure requirement where applicable. Revoking
an active target's eligibility stops further backup publication. Disconnected
targets retain their last inspectable receipt until replacement. Existing explicit
successor configuration remains available.

The setup/storage loop now lives in the shared [Party API](../../replay/godot/party.md),
also used by Scrapyard. Existing Cavecrawl enrollment and recent-room keys are
preserved. An unavailable invite no longer prevents an already authorized creator
from using its stored credential; the UI reports the invitation separately.

The menu flow uses the normal checkpoint/lease machinery. Tests exercise planned
handoff with zero lost ticks, preserved guest loot, and a departed host reopening
its profile with a fresh incarnation and the same invite. The ordinary Leave
button still closes the Room; a surviving prepared successor follows the abrupt
recovery policy. This does not claim that a party whose every participant exits
can resurrect gameplay from coordinator credentials alone. The service stores
authority decisions, not game checkpoints.

## Configuration and profiles

| Setting | Purpose |
| --- | --- |
| `REPLAY_CAVE_ROOM_SERVICE` / browser `room_service` | Provisioning/control/signaling service URL |
| `REPLAY_CAVE_ROOM_LOCAL=1` / `room_local=1` | Explicit loopback WS development mode |
| `REPLAY_CAVE_ROOM_CA` | Optional native certificate authority for a private verified TLS service |
| `REPLAY_CAVE_ROOMS_DB` | Native credential database, default isolated `user://rooms.sqlite3` |
| `REPLAY_CAVE_ROOM_ADDRESS` / `room_address` | Advertised gameplay endpoint host, default `127.0.0.1` |
| `REPLAY_CAVE_PORT` / `port` | Native gameplay port, default 49422 |
| `REPLAY_CAVE_ICE_JSON` | Native RTC deployment configuration, when using an RTC extension |
| `REPLAY_CAVE_ROOM_RELAY=1` / `room_relay=1` | Obtain and refresh credentials from the room service |

Browser hosts can supply `globalThis.replayIceConfig` before Godot starts. It is
not a query parameter. Actual relay-only UDP/TCP tests now cover this party flow;
see [ICE deployment settings](../../replay/godot/transport/ice-deployment.md) for scope and limits.

Native clients on the same machine need different gameplay ports and different
credential databases when representing different players. For different machines,
advertise addresses reachable by the other peers; a loopback address is local only.
This example does not provide automatic NAT traversal for ENet. Browser RTC uses
the service's challenged signaling; public relay/ICE deployment remains work.

The browser menu can be opened with `room_service` and explicit local-development
parameters; the invite itself is pasted into the game, not placed in a URL. Browser
profiles represent separate players. Same-origin tabs sharing storage reuse the
same room credential, and process registration applies the existing live-instance
rules. Display-name preferences and local solo saves remain separate.

The party remains bound to its original service URL. Moving services, retiring
profiles, forgotten recent-room records, invitation rotation and all-participants-
gone gameplay recovery need explicit workflows; no identity or authority fallback
is inferred. Original Cavecrawl, original Scrapyard and the Kit framework remain
separately runnable.

See [native/browser evidence](../../docs/replay/results/cave-online-menu-2026-09-07/README.md)
and the [library enrollment contract](../../replay/provision/enrollment.md).

## Party checkpoint publication

An online host can now request a durable service checkpoint through F5/the save
action or **Store party checkpoint**. Set `REPLAY_CAVE_ROOM_CHECKPOINT_MS=10000`
(browser parameter `room_checkpoint_ms=10000`) for automatic publication. The
default is manual; valid automatic intervals are 1–120 seconds. The configured
service must support Cavecrawl checkpoints. Solo/local saves stay separate.

The Room driver handles status lookup, immutable capture, authenticated upload and
lost-reply recovery while leases and live backups continue. The stored tick is a
durable snapshot boundary; work after it is not claimed as saved. An interruption
may leave the outcome uncertain until a fresh status check.

**Rejoin recent party** can now recover that stored progress after everyone leaves.
It joins a live host when one exists; otherwise a trusted returning player downloads
the saved world and obtains a newer authority epoch before play resumes. Missing,
invalid or too-old saves show a recovery error and retry option instead of starting
an empty replacement world. The service's configured rollback limit still applies.
Native and browser tests resume the saved cave, admit a new guest, execute new loot
actions and store the continued game. See [Room restoration](../../replay/godot/room_restore.md)
and the remaining [M5 plan](../../replay/provision/checkpoints.md).
See the [Room API](../../replay/godot/room_save.md).
