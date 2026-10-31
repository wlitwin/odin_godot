# Authenticated checkpoint transfer

Use `replay/provision/checkpoint` to publish or retrieve a room checkpoint
through authenticated upload, download and status operations. It stores and retrieves durable room publications through `replay/transfer`,
which splits data into bounded chunks and retries delivery. A per-room `Server` borrows the existing authority service and a
typed storage backend; a `Client` borrows the registered process's control
connection. Ordinary transfer operations grant no authority. Protocol 2 adds a
separate [guarded restore decision](restore.md) for an exact durable publication.
Protocol 3 adds [complete external asset packages](assets.md) under the same
authenticated publication and restore lifecycle.

## Embedding

```odin
// Keep these owners at stable addresses and serialize their calls.
backend: storage.Checkpoint_Backend(World, Control, Action, Event, SEATS)
endpoint: checkpoint.Server
backend = {&store, game_model()}
ok := checkpoint.server_open(
    &endpoint, &room.service, storage.checkpoint_backend(&backend), control_wire,
)
```

Check `ok` before routing packets. The backend model is selected by the deployment;
the request cannot select code or schemas. Multiplex `server_receive` beside
authority/provisioning handlers and call `server_update` every frame. Close the
checkpoint endpoint before its authority service or Store. It never polls/drains
the shared wire itself. Multiple rooms need separately bounded endpoint owners.

`checkpoint.Hub` manages that bounded endpoint inventory for a provisioning Hub.
Open it with one deployment-selected Backend after the provisioning hub opens,
route `hub_receive`, call `hub_update` after admission processing, and close it
before its provisioning owner. It mirrors only already-admitted resident rooms;
unknown-room checkpoint traffic never creates or restarts a coordinator. Room slots
remain stable for the provisioning owner's lifetime. A poisoned hub refuses routing.

Data uses reliable delivery by default so it works on WebSocket/TLS. An embedding
with an authenticated confidential datagram transport may explicitly select
`data_channel = .Unreliable` on both endpoints; blob retransmission then handles
loss, duplication and reordering. Control requests/replies always use reliable
delivery. Selecting a channel the underlying transport does not support fails to
make progress; there is no implicit transport downgrade.

The client first registers through the authority RPC on the same connection, then opens with its control key, clock and borrowed transport. Build
a `Request` with its identity, process nonce, current coordinator generation,
room/content, model contract and a nonzero operation sequence. Keep operation
sequences increasing within that process; control request retries reuse the entire
request. These sequences are separate from lease/RPC and gameplay action sequences.

- `Upload` supplies the exact checkpoint `Point`, immutable bytes and expected
  publication revision (zero initially). `client_begin` copies the upload bytes.
- `Status` supplies a zero Point/revision and returns current publication metadata.
  An absent save returns `Missing`.
- `Download` supplies a zero Point and the exact publication revision from status.
  A replacement publication returns `Stale`, allowing a fresh status decision.

Route `client_receive` from the shared wire and call `client_update`; continue
ordinary authority renewals independently. `Complete` upload means a durable
publication receipt, not merely chunk delivery. A completed download owns its bytes
in `client.saved` until the next begin or close. `client_decode` requires the game
model before exposing a decoded checkpoint. An application must still prepare
assets and obtain a fresh authority permit before restoring simulation.

## Authorization and commit

Every control message and transfer packet is HMAC-SHA256 authenticated with the
member's control key. Domain and direction separation cover the whole canonical
envelope. Data also names the exact request hash, identity/nonce, coordinator
generation, operation sequence and transfer ID. HMAC supplies integrity and member
authentication, not secrecy: **the embedding must use verified TLS**, or an isolated
local test channel. No private enrollment Bundle or bearer game token is returned.

The server requires an enabled, currently registered identity and nonce on the
bound transport peer and connection generation. Status/download/upload all require
`can_host` and `trusted_authority`; dedicated policy additionally requires
`infrastructure`. A normal player cannot obtain an authority-only archive.

A new upload requires a live owner lease in the checkpoint epoch. Permission is
rechecked while receiving, when the archive completes, and through a `Commit_Guard`
after typed validation and SQL update immediately before commit. If validation or
storage waiting outlives the lease, the transaction rolls back. The backend also
compares the complete durable coordinator Record and publication revision, fencing
a competing service process. A custom backend must honor the same atomicity, model
validation and commit-guard contract; an in-memory callback that merely returns
success is not durable publication.

The currently stored exact publisher/Point/contract can be acknowledged after a
lost reply without a new write or live owner lease. Current trusted registration
is still required. This permits recovery of a commit result without reactivating
its former host. Old revisions cease to be retry targets after replacement.

## Bounds and lifecycle

One transfer is active per endpoint, with at most a 1 MiB archive. Upload allocates
only the declared, validated checkpoint size. Download retains one owned archive.
The shared transfer engine limits chunks, retransmits missing data, checks SHA and
envelope integrity, and times out after 30 seconds. Endpoint destruction, timeout,
registration loss or revoked permissions releases its transfer state. An expired
upload owner also releases its slot, so it cannot block its successor's publication.

Authenticated ingress has a per-room bucket of 64 packets, replenished at 128/s;
control operations have per-member buckets of eight, replenished at four/s.
Malformed traffic performs no storage load or transfer allocation. The embedding
must also bound connections and packets per frame before dispatching.

An explicitly newer operation from the same registered process may supersede its
transfer. This also handles a download whose final acknowledgement was lost.
Another member cannot evict an in-flight transfer; a changed request at the same
sequence cannot replace it. Old signed chunks cannot cross the new request hash or
transfer binding. Status and exact publication acknowledgement do not replace an
ongoing transfer or grant a lease. An uncertain write result is resolved through
status or an exact retry, never an assumed fresh publication.

An exact Status retry reuses its bounded cached read result while current
membership/connection checks still pass. A new request sequence obtains a fresh
publication view. This avoids repeated expensive model/asset validation blocking
authority renewal while a read reply is in flight.

The native SQLite API retains its previous names as aliases for the shared
`Publication`/`Saved` metadata types. Their serialized field layout is unchanged.
Checkpoint protocol **3** includes Restore and signed package descriptors, with a
v3 HMAC domain. Earlier transfer clients and services must be upgraded
together; there is no silent wire fallback. Publication metadata remains version 1;
gameplay, authority RPC, Bundle/Record and archive formats are unchanged. The
protocol package also checks for WASM.

<a id="remaining-integration"></a>

## Integration coverage and limits

The [standalone room service](../../../examples/replay_room_service/README.md)
registers deployment-selected Cavecrawl, Speedball and Scrapyard backends through
the bounded checkpoint Hub. Native TLS tests verify each actual game model across
service restart. [Room/Party save handling](../../godot/room_save.md) owns
status, capture, publication and retries, with native/browser Cavecrawl acceptance.
Room/Party drives the full guarded restore lifecycle, with actual Cavecrawl
resume/retry UI and native/browser acceptance. Other game paths and external
asset profiles beyond the bounded package still require integration. Scrapyard
declares and validates its current/pending spray dependencies. Download alone
grants no authority. See the broader
[all-members-gone recovery plan](../checkpoints.md).
