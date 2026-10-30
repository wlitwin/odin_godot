# Authenticated authority service and durable storage

Use `Service` to expose a room's authority coordinator over Replay's transport
interface. `Rpc_Client` correlates replies with a time-limited `Lease`; the SQLite
adapter durably commits each coordinator decision with compare-and-swap.
[Process registration](registration.md) supplies fresh incarnations for known
members, and the [Room driver](../godot/room.md) connects these decisions to live
gameplay.

The evidence below describes the service fixture's tests, including planned
simulation transfer and coordinator crash/restart. Broader integration results
belong to the Room gates and [framework audit](../../docs/replay/framework-audit.md).

## Trust and message contract

Provision enabled `Member` records and distinct, unpredictable 32-byte keys for
their member IDs. Keep keys in the admission/secret provider, not the public
room record. A game process obtains a fresh incarnation through Challenge/Rebind
or a trusted provisioner. Reconnecting its control transport retains its
lease/request sequence. Fixture keys are deterministic test data and
must not be used for deployment.

Each `Rpc_Client` also requires a fresh 16-byte cryptographic nonce. `rpc_nonce`
uses the native entropy source when available; other embeddings must supply one.
Replies bind the member/incarnation, nonce, request sequence, and SHA-256 of the
exact request. Request and reply MACs use separate protocol-domain prefixes and
HMAC-SHA-256. Verification uses the standard crypto package's constant-time
comparison. A key belonging to one identity cannot authenticate another identity.

Control RPCs provide Query, Start, Renew, Nominate, Prepare, Release, Claim,
Recover_Owner, Challenge, and Rebind. Requests/replies use canonical bounded envelopes and append a
32-byte MAC. They authenticate metadata; they do **not encrypt** it. Use a suitable
protected transport/deployment if room identities or endpoints are confidential.
The control plane does not transmit the game's complete private checkpoint.

Bad MACs, unknown/disabled identities, wrong lengths, and invalid schemas do not
reach the store. Each pump consumes at most 32 packets and authenticated identities
have request token buckets. The receive buffer can drain the transport's full
64 KiB packet limit, then rejects oversize RPCs, so an oversized packet cannot
remain at the queue head and block all later requests.

## Atomic replay protection

Decision record version 3 includes a per-member request sequence, request hash,
result, and bound client nonce. The service evaluates a command on a private coordinator copy, then
commits its decision and replay frontier together through one real CAS operation.
This includes reads and rejected commands: an older delayed mutation cannot run
after a newer Query, including after service restart.

An identical retry of the latest request returns its recorded result and a fresh
view of current remaining lease time; it does not renew again or repeat the
decision. Older sequences, or different payloads at the same sequence, are stale.
The reply's sequence floor allows an RPC wrapper to continue an already running
incarnation's sequence. It is not permission for a new game process to reuse that
incarnation or reconstruct an absent world.

`rpc_begin` records the local request start before sending. `rpc_client_pump`
retries those same bytes, without moving the lease's reference time. A timeout
returns `Busy` and has an unknown remote outcome; it is not evidence that a command
was never committed. `rpc_completed` reports a validated reply for the current
request. After an uncertain operation, inspect the coordinator's durable view and
use a new request rather than assume failure or success.

Retired owners can continue receiving authenticated control metadata while their
gameplay permit stays permanently disabled for that epoch. This lets an old owner
learn that its final archive has been prepared and submit its release.

## SQLite adapter

```odin
store: authority_sqlite.Store
error := authority_sqlite.open(&store, database_path) // existing file by default
record, found, load_error := authority_sqlite.load(&store, room, content)
// Check every result. Create a new file/room only through explicit provisioning.
error2 := authority.service_init(&service, record, authority_sqlite.commit,
                                 &store, clock, transport, credentials[:])
```

Pass `create=true` only when explicitly creating a new database. A missing existing
database does not silently become a room with a reset epoch floor. Existing rows
are validated against the canonical record schema, room, content, and revision.

The store uses `BEGIN IMMEDIATE` for read/compare/write, stores the decision and
request frontiers in one canonical blob, and returns success only after COMMIT.
It verifies WAL journal mode and FULL synchronization, enables `fullfsync` and
checkpoint synchronization, and bounds busy waiting. SQLite documents the WAL/FULL
durability boundary and synchronization behavior in its
[WAL documentation](https://www.sqlite.org/wal.html) and
[synchronous pragma documentation](https://www.sqlite.org/pragma.html#pragma_synchronous).

The current adapter supports native macOS and Linux and links SQLite. The Nix dev
shell includes it. The runtime tests here ran on macOS. This is a local-file
backend, not a replicated coordinator database; use one authoritative database on
a supported local filesystem. The implementation relies on SQLite and the storage
stack honoring their synchronization contract. Tests kill processes and verify
recovery; they do not physically interrupt machine power or certify storage hardware.

A competing coordinator initialization commits a new generation/revision, so an
older instance's next CAS fails. Restart quarantine still outlasts old possible
leases. `Recover_Owner` permits the same surviving owner to prepare its frozen world
and obtain a newer epoch after quarantine. If a grant committed immediately before
its reply was lost, the exact checkpoint recorded by that grant can also be used;
the claimant must actually possess it. Neither path revives the old epoch.

## Evidence

```sh
nix develop --command bash tests/replay_authority/run.sh
nix develop --command bash tests/replay_authority_sqlite/run.sh
nix develop --command bash tests/replay_authority_service/run.sh
```

The service assessment recorded 19 native tests plus a WASM type-check. Cases cover
MAC forgery/cross-identity requests, nonce-bound replies, oversized ingress, durable
replay frontiers across newer reads/restart, lost replies, storage failures, and
recovery of an unconsumed committed grant. SQLite tests reopen the database, race
stale CAS connections, and force a write failure. A subprocess dies with an
uncommitted corrupt replacement; a fresh process recovers the prior epoch, tick,
and request frontier.

The Godot service gate runs coordinator, old owner, and successor processes. It
transfers the actual cave model (including private fixture data, looted inventory,
and a live projectile), retires the old owner, prepares/releases/claims through
authenticated RPCs, and restores the successor's simulation at epoch 2. The gate
then kills the coordinator, reopens its SQLite record as generation 2, keeps the
successor alive, waits through quarantine, and resumes its retained world at epoch 3.

This proves the decision service, durability, and simulation transfer components.
The fixture uses explicit test provisioning and a separate checkpoint connection.
This fixture does not prove migration of live Cavecrawl clients, gameplay
rendezvous or every M5 crash/partition scenario. Consult the
[Room driver](../godot/room.md) and its acceptance cases for those integrations.
