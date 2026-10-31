# Restoring a published checkpoint

Use a Restore decision when no live authority remains and a trusted member
needs to resume a published checkpoint. Checkpoint protocol **3** retains
version 2's explicit `Restore` decision and adds complete asset-package
transfer. Upload and download do not grant authority. A restore selects one exact durable publication and obtains a
new authority epoch only after current membership, policy, lease and storage checks.
The private Bundle/Record and gameplay/checkpoint formats remain unchanged.

## Client sequence

1. Recover the existing enrollment credentials, then register the fresh process
   through the authority RPC Challenge/Rebind handshake on the same connection.
   The checkpoint-enabled service permits replacement of an expired owner's
   incarnation only after lease expiry and coordinator restart quarantine. A live
   owner is still protected. Registration preserves the stable game token and
   grants no lease; the old owner identity remains in the record until a restore
   or another authorized migration decision wins.
2. Read status and download the selected publication through the checkpoint client.
   `client_prepare` performs typed checkpoint validation and copies it into an owned
   `authority.Prepared`. Keep that owner at a stable address. Prepare every required
   external game asset before requesting authority.
3. Call `client_restore` with the current authority Lease, exact Publication and
   owned Prepared. No ordinary authority RPC may be pending simultaneously. Restore
   uses that Lease's request sequence; normal upload/download operation sequences
   remain separate. Continue multiplexing checkpoint and authority replies.
4. A successful correlated reply installs a lease for the new epoch and sets its
   `require_owner` flag. Check `lease_live` before restoring: a delayed successful
   decision can arrive with no usable lease time. Use `prepared_restore` or the
   equivalent Session path with that lease/permit and the correct local seat.
   Supply `Resume_Options.local_incarnation` for a fresh process; Session forwards
   a nonzero `Session_Options.incarnation`. Zero retains legacy saved incarnation
   behavior, and a supplied older incarnation is rejected before runtime creation.

```odin
publication := client.saved.publication
error := checkpoint.client_prepare(&client, &prepared, game_model)
// Check error; prepare referenced assets before continuing.
error = checkpoint.client_restore(&client, &lease, publication, &prepared)
// Pump the shared control connection. After a successful reply and live lease:
restore_error := authority.prepared_restore(
    &prepared, &server, game_model, gameplay_wire, &lease, local_seat,
    options = {local_incarnation = lease.identity.incarnation},
)
```

This abbreviated example omits application error/UI handling. Client close or
failure cancels its outstanding lease request, not a possibly committed authority
decision. Keep Prepared until the chosen restore/retry outcome is resolved.

## Authority and storage contract

`service_recover_published` is a trusted integration entry point. The protocol
server verifies HMAC, exact request context and current identity/nonce/peer/
connection/coordinator-generation binding before calling the backend. The backend
must atomically guard the authority commit against publication replacement; this
entry point is not a public function that authenticates arbitrary raw arguments.

The SQLite adapter loads and validates the deployment-selected model, then holds
the exact publication as a scoped commit guard. The existing provisioning commit
reloads the publication inside `BEGIN IMMEDIATE` and compares all its metadata,
including revision and Point. The private Bundle, new authority epoch, recovered
Point and restore request frontier commit together through the existing Room
callback. No second in-memory Bundle can diverge from the service's Record.

Restore requires:

- An enabled trusted host. Dedicated policy additionally requires infrastructure.
- A current playable reservation for the actor's stable token in a cooperative
  checkpoint, with no matching game ban. A merely enrolled peer cannot take another
  player's local seat. Dedicated infrastructure uses the dedicated local-seat path.
- An expired owner lease and elapsed restart quarantine. A concurrent live owner
  renewal or a different coordinator process is fenced by the durable Record CAS.
- The exact latest publication revision, model contract and Point. A checkpoint in
  the current epoch is allowed. A prior grant's exact recovered Point remains
  eligible after that grant/service was lost without a newer publication; arbitrary
  older points are refused.
- The existing `max_known_rollback` bound and final-release constraint. A save can
  be durable yet too old to authorize. Set save cadence and deployment recovery
  policy deliberately; publication alone does not override that policy.

The primitive stages the grant with existing coordinator rules, then persists the
request result. Admitted policy refusals such as `Busy` and `Too_Old` also persist
their frontier, so replay after expiry cannot turn the same rejected request into
a grant. Malformed/unauthorized requests and unavailable/mismatched publications
are rejected before this decision admission. A later explicit request uses a new
lease sequence and is evaluated against the then-current state.

An exact lost grant reply returns the durable result without advancing epoch or
renewing its lease. A higher RPC frontier makes an older request stale. If the
coordinator restarts, its usual generation advance/quarantine still applies; a
fresh registered process may need a newer grant using the same exact retained
source Point. Old traffic cannot resurrect the earlier epoch.

While the endpoint remains live, an exact request whose digest/result still matches
the durable frontier uses a cached receipt plus a freshly calculated authority
view. It does not repeat model/asset decoding or block a queued lease renewal.
Stale frontiers are rejected before storage loading. Cache loss still uses the
validated storage path; the cache itself never establishes authority.

`allow_expired_owner_rebind` is a trusted service opt-in installed while an attached
checkpoint endpoint has a recovery backend. Closing that endpoint restores its
previous setting. Services without recovery support retain the former blanket
owner-rebind refusal. The opt-in does not itself check or grant a saved-world claim.

## Validation and integration status

Low-level callers should refresh a successful Restore grant with a new correlated
authority `Renew` before beginning runtime setup. The Restore request may
spend much of its lifetime in transfer/validation, and its local lease deadline
is anchored to request start. Even an already expired local permit can request
renewal; only the coordinator decides whether the reservation still exists.
Installation and simulation still require a live permit. `Room` handles this
exchange automatically. The [delayed-grant test](../../../tests/replay_restore_renewal/README.md)
covers both a successful same-epoch renewal and an expired-reservation refusal.

Native TLS fixtures restore the three actual Cavecrawl, Speedball and Scrapyard
models after all original client processes and the service have exited: incarnation
2 receives epoch 2 and advances a saved tick-1 simulation to tick 11. Unit tests
cover stale traffic, lease/quarantine, excessive rollback, missing playable seats,
lost grants, rejected-request replay, storage Point/publication substitution and
dedicated infrastructure/final-release rules. Real processes killed before/after
the restore commit recover respectively epoch 1/request 2 or epoch 2/request 3,
while publication 1 remains intact; fresh coordinator startup is inactive.

Godot Room/Party drives the complete download/preparation/restore lifecycle and
Cavecrawl exposes resume/retry UI. Separate native and browser tests resume actual
saved cave play and accept new guests after all original processes have exited.
Room distinguishes service-known rollback from local confirmation history.
Atomic asset packages cover declared dependencies including Scrapyard sprays.
Broader asset profiles, other game acceptance and broader loss reporting remain
integration work. See [Room restoration](../../godot/room_restore.md) and the
[M5 plan](../checkpoints.md).
