# Room admission and private coordinator storage

`replay/provision` supplies the server-side create/invite/join state machine for
an authority-controlled room. `Room` owns an existing `authority.Service`; its
durable `Bundle` contains the authority record, member credentials, enrollment
retry records and invite consumption. Every change uses the same revision CAS.
This closes the previous gap between durable membership and separately configured
service keys. The game simulation and host-migration protocol are unchanged.

The SQLite store also provides [durable room checkpoint publication](checkpoints.md)
with separate revision CAS, typed validation and atomic metadata/bytes. The
[authenticated transfer endpoints](checkpoint/README.md) have native TLS restart
acceptance. The standalone service now registers the three compiled game models;
Room/Party owns publication and authenticated cold restore with native/browser
acceptance. Game models/dependencies must still opt into the typed service contract;
see [published restore](../godot/room_restore.md).

The [create/join protocol and Godot connection](protocol.md) now expose this
backend through a bounded room hub and verified TLS. Native create/join/restart
acceptance passes on loopback. The [client journal](enrollment.md) adds durable
native/browser enrollment. Shared Party menus and Room recovery are integrated into
multiple example games. Public deployment, human accounts, global room discovery
and room retirement remain separate product/deployment work. Tests use isolated
provisioning and profile data; these local gates are not public reachability claims.

## API and ownership

```odin
import provision "godot:replay/provision"
import storage "godot:replay/provision/sqlite"

// Server setup: private path, stable room ID and deployment-selected content/policy.
// Keep these owners at stable addresses; call provision.close before storage.close.
store: storage.Store
room: provision.Room

// For creation only, the creator has generated and retained a fresh Secret.
// Check errors at every boundary. An existing room must be loaded, not recreated.
bundle, make_error := provision.make_room(room_id, content_id, creator_claim, endpoint)
open_error := provision.open(&room, bundle, storage.commit, &store, authority_clock, control_wire)

// Only return credentials after successful durable creation/admission.
creator, creator_error := provision.creator_grant(&room, creator_claim)
ticket, invite_error := provision.invite(&room, creator_claim, invite_secret, .Player)
guest, join_error := provision.join(&room, ticket, guest_claim, guest_endpoint)

// Existing authority RPC and rendezvous code use this same live service.
authority.service_pump(&room.service)
```

The abbreviated example assumes `storage.open` has succeeded and that room lookup
has established absence. On restart, call `storage.load` and pass its complete
bundle to `provision.open`; do not rebuild a bundle from gameplay archives. The
authority service advances its persisted coordinator generation and applies the
existing lease quarantine. A second owner fences the first owner's subsequent CAS
writes. Calls on one owner are serialized, including packet delivery.

Room IDs and allowed content/policies are the hosting application's responsibility.
A create client must retain the same requested room ID and creator claim across
retries. The hub atomically resolves competing creates and returns existing grants
only after verifying the creator claim and original endpoint/content. Corrupt
records are never interpreted as absent rooms. The backend does not allocate
global room IDs or keep an unbounded map of rooms.

`provision.secret()` obtains 32 cryptographic random bytes on supported native
targets. An explicit `Entropy` callback supports other runtimes and deterministic
tests; it must provide cryptographic entropy in deployment. Unsupported runtime
entropy, zero values and generated credential collisions fail. No pseudo-random
fallback is provided. Generate the creator claim, invite secret and each enrollment
claim independently, before submitting their corresponding request.

## Invite and retry rules

- `.Player` grants membership and its control/gameplay credentials. It grants no
  authority-backup or hosting permission. This role does not choose a gameplay
  seat or restrict the game's own spectator admission policy.
- `.Trusted_Peer` explicitly grants co-op hosting and permission to receive complete
  authority backups. It is refused for dedicated rooms; infrastructure enrollment
  needs trusted deployment administration.
- The creator claim authorizes invite issue/revocation. Creator administration is
  separate from the current gameplay host and does not move on host migration.
  Disabling the creator member also disables its invite administration.
- An invite has a fixed role and finite use limit. Repeating its issuance with
  the same secret and parameters returns the same ticket. Changed parameters or
  a revoked ticket are refused. Exhaustion never refills the invite.
- Join retries must present the same ticket, enrollment claim and original
  endpoint. A committed retry returns the same control key and stable game token,
  plus the member's current incarnation. It consumes no further use and performs
  no write. Changed payloads and disabled members are refused.
- Revoking a ticket prevents new enrollment. It does not ban previously enrolled
  members or prevent them from recovering a lost successful response. Trusted
  membership administration still uses `authority.coordinator_member` through
  `room.service.coordinator`; its commit is routed into the same private bundle.
- Process Challenge/Rebind can update an enrolled member's incarnation/endpoint.
  The original enrollment endpoint remains stored solely to identify exact join
  retries. Ordinary RPCs still require the current bound nonce/incarnation.

Membership, control key, game token, retry record and invite decrement enter one
durable transaction. An error publishes no grant and no in-memory partial join.
A storage failure poisons the running authority: the backend does not guess whether
the commit reached storage. Reloading in a fresh owner resolves that uncertainty.

Capacity is currently **16 lifetime member slots and 16 lifetime invite slots per
room**, with at most 15 uses per invite. Disabled members and revoked/spent invites
remain tombstones. IDs, credentials and old retry proofs are never recycled into
new members. Long-lived public rooms will need an explicit bounded retirement and
credential lifecycle before these limits can be expanded safely.

## Client handoff

An authenticated, confidential provisioning frontend returns only the caller's
`Grant`. Populate the Godot `Room_Options.identity`, `.key`, `.room`, and
`.session.token` from that grant; require `.session.network.content` to match its
content. The creator is the room's bootstrap member (stable member ID 1). Keep
`provisioned_incarnation=false` so a newly opened game process goes through the
existing challenged registration flow. The grant is a membership credential, not
a live authority lease. Do not use its host permission as a substitute for the
coordinator's current grant.

Control/gameplay endpoints and ENet/WebSocket/RTC connection settings remain
deployment inputs. Client credentials need private durable storage before users
can rely on fresh-process reconnect. Enrollment secrets must not appear in URLs,
logs or public rosters. Providing the backend over a plain public socket does not
provide the confidentiality that credential issuance requires.

## Storage and compatibility

`replay/provision/sqlite` is native macOS/Linux storage. It reuses the authority
store's checked WAL/FULL/fullfsync connection settings and writes a distinct
`replay_provision` table. Compare/read/write happens within `BEGIN IMMEDIATE`.
New files are exclusively created with mode 0600. Existing files with group/other
permissions, symlinks and non-regular files are refused without changing them.
The caller must supply a private directory and protect SQLite sidecars/backups;
the bundle is plaintext at rest. Missing-file creation is explicit. Existing
corrupt records are retained and produce a read error, even when creation is enabled.

The bundle format is version **1**, canonical kind `0x5052`, with its authority
revision in the envelope tick and game content ID in the content field. It contains
decision record version 3. The gameplay protocol (7), checkpoint (4) and authority
RPC (2) are unchanged. Older authority-only database rows cannot be upgraded
without a trusted source for their missing keys and game tokens; no automatic
import or fallback is attempted.

The private bundle is never a migration checkpoint. A trusted gameplay successor
may receive full simulation state but does not receive room administration claims,
control keys, unused invite capabilities or other members' game tokens.

## Verification

```sh
nix develop --command bash tests/replay_provision/run.sh
nix develop --command bash tests/replay_provision_sqlite/run.sh
```

Core tests exercise exact retries, revoked/exhausted invites, disabled/rebound
members, dedicated policy, entropy failure, capacity, uncertain commits and a
complete authenticated authority handoff using newly enrolled credentials. The
package also checks for freestanding WASM; this does not claim browser provisioning.
SQLite tests cover reopen, another owner's CAS, read-only storage, corrupt blobs
and private file modes. Separate process-kill fixtures interrupt a real join before
and after SQLite commit and verify the corresponding retry behavior in fresh
processes. See [recorded evidence](../../docs/replay/results/room-provisioning-2026-09-07/README.md).
