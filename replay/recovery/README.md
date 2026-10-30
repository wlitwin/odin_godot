# Replay checkpoint replication

`replay/recovery` transfers complete authority checkpoints to an explicitly trusted
successor. It builds on `replay/net` archives and the borrowed transport interface.
Use it to keep an eligible backup ready before a host stops. It provides
transfer, validation and retention; it does not select a legitimate leader,
fence a partitioned authority, discover a new host, or reconnect game clients.

The reusable [transfer package](../transfer/README.md) also supports bounded canonical
records. Recovery retains compatible `Sender` / `Blob_Receiver` facade names.
Supply the expected envelope kind and an `accept(user, archive, bytes) -> bool`
callback to `blob_init`; opt the Sender into the same kind with `archive_kind`.
The core verifies source/scope, chunks, SHA-256 and envelope integrity before the
callback. The callback must validate and install atomically, borrow bytes only for
its duration, and return false on failure. Receipts are retained for retry handling;
the generic core does not retain decoded application values. The typed checkpoint
Receiver wraps this core and still retains the two validated authority checkpoints
required by the sender/coordinator contract. Both receiver owners must stay at
stable addresses. Existing checkpoint callers keep their APIs and canonical archive
format. Optional transfer representations require negotiated peer support.

The [P2P spectator](../p2p/spectators.md) uses the generic core for confirmed history;
its separate envelope kind cannot be installed as an authority checkpoint.

## Ownership and integration

The application installs `Scope{room, epoch, binding, content}` and a specific
transport peer on each endpoint. A binding identifies a particular authorized
source/successor connection. Replace the binding when reconnecting/replacing that
peer, even if the transport reuses its numeric ID. These identifiers are context
checks, not credentials or authentication. A successor receives the complete
authority projection, including hidden fields; select it accordingly.

```odin
sender: recovery.Sender
receiver: recovery.Receiver(World, Control, Action, Event, SEATS)
error := recovery.sender_init(&sender, scope, successor_peer, wire)
error = recovery.receiver_init(&receiver, scope, authority_peer, wire, model)

// Authority side: capture at a simulation boundary, then publish an owned copy.
error = recovery.sender_publish(&sender, &checkpoint, model, now_ms)

// Each endpoint's packet dispatcher, after transport.poll/receive:
result := recovery.receiver_receive(&receiver, packet.from, packet_bytes, now_ms)
// Or sender_receive on the publishing endpoint.
error = recovery.receiver_update(&receiver, now_ms)
// Or sender_update on the publishing endpoint.
```

Check every error/result. Call `sender_destroy`/`receiver_destroy` once; neither
closes the borrowed transport. Owners must remain at stable addresses and must not
be shallow-copied. `sender_begin` accepts encoded archive bytes and copies them;
`sender_publish` encodes a typed checkpoint first. Only one transfer is active per
sender. `sender_cancel` permits explicit replacement while retaining the last
validated receipt; sequences continue increasing within the binding.

The low-level protocol does not independently drain the wire. `Link` integrates
it with the gameplay runner using `transport.Router`, separate queues, and a combined
output budget. `handles` is only untrusted routing inspection. The standalone ENet
acceptance fixture uses a dedicated wire; the cave replication gate uses the same
connection for actual gameplay and checkpoints.

## Shared gameplay connection

`Link(State, Control, Action, Event, Seats)` owns the router, one outgoing transfer,
an optional incoming receiver, and reusable archive schema metadata. Initialize it
around the underlying transport, then give `link_game_transport` to `server_init`
or `client_init`. Each outer frame calls `link_pump` once, pumps/steps gameplay, and
finally calls `link_server` or `link_client`. Destroy the link before closing the
underlying transport. The Godot `Session` facade performs this ordering.

Receiver opt-in is explicit: set `Link_Config.accept_checkpoints=true`. The
authority then calls `link_target` with a live admitted connection. Use
`net.server_seat_connection` when selecting by playable seat. The binding comes
from the admission ledger's connection generation; it cannot be supplied by an
incoming archive. The target interval defaults to one simulation second. New
archives wait for the active transfer to complete/fail, avoiding endless replacement
of partial transfers. Retargeting and `link_untarget` discard that target's current
receipt; sequence numbers keep increasing so selecting the same live peer again
does not collide with old transfers.

The link does not automatically reauthorize a replacement connection. A disconnected,
kicked, or generation-mismatched target receives no further work. Its old receipt
remains inspectable along with an unavailable status. Selecting a new live connection
is an explicit application/coordinator decision. Incoming archives remain available
after connection loss for the eventual takeover driver.

Packet routing preserves sender identity and delivery mode. Only bounded checkpoint messages
enter the background queue; every consumer still validates its
own protocol. Queue overflow may drop unreliable background datagrams, which the transfer
repairs. Reliable background messages use the router's bounded retention/backpressure path. Combined byte/rate budgets reserve capacity for gameplay; a saturated game
may defer checkpoints until their timeout. The most recent backup failure remains
in `Link.error`/`model_error`; it does not halt active gameplay. The migration driver
must consider checkpoint age and successor availability rather than assume a fresh
replica always exists. Custom policy validators must be installed before receiver
initialization, with an immutable user descriptor valid for the receiver's lifetime.

`receiver_latest` returns the newest validated receipt. `receiver_checkpoint`
looks up an **exact** archive descriptor and returns a read-only borrow, valid until
the next receive/destroy. The takeover driver must use the receipt authorized by
the coordinator; newest does not by itself mean authorized. The archive can be
passed to `net.server_restore` or persisted by an application.

By default, a saved custom admission policy is rejected. Install `policy_valid`
and its immutable user descriptor to explicitly validate the policy ID/data before
acknowledgement. The application must also provide the corresponding admission
implementation during restore. Policy bytes never deserialize callbacks.

## Transfer and retention protocol

Protocol v1 uses canonical `RPLY` envelopes with kinds `0x5101`–`0x5105`:

| Message | Meaning |
| --- | --- |
| Offer | Version/chunk size, room/binding, archive sequence/tick/size/SHA-256, and last acknowledged archive to retain |
| Chunk | Archive sequence and chunk index followed by exactly the expected bytes |
| Progress | Offer receipt, or a 64-chunk acknowledgement bitmap |
| Ready | Exact descriptor of a fully reconstructed and validated archive |
| Failed | Explicit integrity/archive/policy/retention/timeout failure |

Transfers use 1,024-byte chunks. The largest packet is 1,102 bytes, within the
configured test datagram envelope. A bounded selective-repeat window repairs lost
chunks and progress messages over the unreliable transport channel. Repeated
offers repair lost Ready packets. ACKs cannot claim chunks that were never sent.
Packet checksums protect framing; the final SHA-256 identifies the complete
archive. Neither provides peer authentication.

The receiver preallocates one 1 MiB reassembly buffer, with fixed bitmaps. Offers
cannot allocate arbitrary buffers. Bounds, version, scope, exact chunk length,
duplicate consistency, final digest, checkpoint codec, game-state validity, and
custom policy support are checked before a Ready receipt. Timeouts apply at receive
as well as update, so a late final chunk cannot bypass the deadline.

Two validated archives may be retained. Each new offer names the authority's last
acknowledged archive as its retention anchor. A newer candidate whose Ready was
lost may be superseded, while that older anchor remains available. Validation uses
a temporary third checkpoint; only a successful decode changes stored owners.
An incomplete, corrupt, rejected, or timed-out transfer cannot replace a usable
archive. Unknown retention claims are rejected. A completed transfer is a receipt
for **validated process memory**, not a disk/power-loss guarantee. The successor
must remain available, or another eligible replica is required.

`Stats` records packets/bytes, retries, duplicate chunks, deferral, rejection,
validation, and failures. Receipts include archive tick and receipt time; the game
can calculate checkpoint age. The caller supplies monotonic milliseconds; time
reversal is rejected. CPU measurements belong around the calls so the pure package
does not depend on an operating-system clock or Godot.

## Evidence and limits

```sh
nix develop --command bash tests/replay_recovery/run.sh
nix develop --command bash tests/replay_recovery_enet/run.sh
```

Nine native tests cover receipt/restore/action identity, lost Ready and retention,
invalid state, timeout and recovery, same-archive connection rebinding, wrong peers,
corrupt packets, time reversal, custom policies, offer limits/version/retention,
out-of-range chunks, and a large private cave archive under deterministic faults.
The integration test runs gameplay plus repeated archives, checks that an unselected
observer receives none, retargets the same connection, and revokes the target.
The package and actual Godot probe also type-check for WASM. This is not a browser
network runtime gate; ENet is still native-only.

The real two-process ENet fixture transfers a cave simulation with looted inventory
and an active rock, plus 72,000 bytes of authority-only fixture data. With 120 ms receive
delay, up to 20 ms jitter, 10% unreliable loss, and 10% duplication, one debug-build
run recorded:

```text
archive: 75,591 bytes, tick 49
capture/encode: 39,591 us
transfer through Ready: 2,043 ms, 173,838 sent bytes, 95 retries
receiver packet processing/validation: 193,712 us accumulated
restore and first continued simulation tick: 108,260 us
```

The restored complete frame equals the transferred checkpoint, includes the
private data and conserved loot, and continues simulation. These are single-run
instrumentation receipts, not percentile benchmarks or old/new game comparisons.
The fixture adds private data specifically to exceed the 64 KiB packet limit;
ordinary Cavecrawl archives are smaller. Those measurements motivated reusable
`net.Checkpoint_Codec` metadata. Receivers warm it at initialization; `Link` warms
its publishing codec when a target is selected. The same fixture with warm metadata
recorded 1,574 us capture/encode and 7,304 us accumulated receiver processing, with
identical archive bytes. One-time fresh server restore still builds its runtime
schemas (139,521 us in that run). These remain individual debug measurements.

The first Godot debug build terminated inside the Odin compiler. Direct debug,
non-debug, and the subsequent normal project build succeeded without a source
workaround; the crash has not been reproduced or claimed fixed.

The live Cavecrawl gate is `examples/replay_cavecrawl/replication_run.sh`. It keeps
gameplay and periodic backups on the same ENet connection, with the same fault
settings, and verifies a common checkpoint containing the guest's loot and open
door. Save/resume and restarted-host/guest recovery gates remain separate.

The [Room driver](../godot/room.md) installs coordinator-approved successor and
fencing decisions, then performs planned or abrupt takeover with surviving-client
frontier reconciliation. See the [recovery contract](../../docs/replay/recovery.md)
and [roadmap](../../docs/replay/roadmap.md) for its guarantees and remaining work.

## Independent application consumers

`link_add_application(&config, Application_Route{user, handles})` reserves another
bounded receive lane before `link_init`. It returns `(lane, ok)`; adding an identical
route is idempotent and a full registry returns false. Obtain that borrowed lane
with `link_application_lane(&link, lane)`. The original `application_handles` and
`link_application_transport` retain lane 2, so existing asset consumers continue
to work. Extra routes use lanes 3–7, with the same router budgets and primary reserve.

Classification is ordered: checkpoint, original application, additional routes,
then gameplay fallback. Handlers should match only their own protocol. Routing is
not authentication; each consumer validates live admission and scope. All enabled
consumers must drain their lanes after the shared pump. A full reliable receive
lane preserves its packet and can exert transport backpressure. [Comms](../comms/README.md)
uses an additional route while Session assets keep their existing one.


## Schema-aware checkpoint compression

Link negotiates both ordinary block compression (Features bit 128) and Frame
schema grouping (bit 256, requiring 128). It obtains the fixed Frame schema and
canonical section offset from its checkpoint codec. Both endpoints validate the
same plan fingerprint. Grouped candidates are selected only when smaller; ordinary
compression and original offers remain available. Receiver reconstruction ends
with the same raw archive SHA-256, canonical envelope and typed checkpoint checks.
Archive identity, retention and coordinator authority decisions remain unchanged.

The [transfer contract](../transfer/README.md) describes layout lifetimes, bounded
scratch and statistics. Low-level `sender_publish` can use a caller-owned codec
for grouping; Link manages this automatically. The earlier experimental early-send
schedules are not installed: gameplay and recovery retain their normal service
order and the coordinator still enforces the configured rollback limit.


## Checkpoint delivery channel

Features bit 512 advertises support for checkpoint messages on the existing
reliable channel. Link uses it when available; absent capability retains the
unreliable path. The receiver mirrors reliable delivery after validating traffic,
and cannot be downgraded by delayed datagrams in the same scope. Capabilities are
immutable for a connection and reset on reconnect. Raw/compressed/schema-grouped
archives all retain the same descriptors and validation.

For RTC this separates checkpoints from the unreliable snapshot credit window.
It does not add credits, widen staging queues, change the shared byte budget, or
prioritize checkpoints ahead of gameplay. Reliable chunk retries belong to the
transport; the archive sender does not duplicate them. Reliable congestion can
still delay gameplay on that channel, so callers must inspect actual backup age
and failure state. A fresh replica is never an unconditional guarantee.
