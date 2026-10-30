# Durable room removal

`rpc_remove(client, epoch, target_identity)` is an optional authenticated extension.
Only the current live authority may disable another exact member/incarnation.
Self-removal, stale epochs, changed incarnations, expired ownership and requests
after release are refused. Trusted administration can still manage membership
through `coordinator_member`.

Removal uses the existing Request/Reply layouts with separate envelope kinds
`0x5203`/`0x5204` and separate HMAC domains. The Query-shaped payload contains only
the epoch and target in `successor`; all other command fields must be zero. Normal
Query remains Query, even with unused fields. Existing authority RPC schema,
protocol version and durable record layouts remain unchanged. Old services ignore
the new kind; callers must handle an unsupported-operation timeout.

The service stages the membership change and request frontier/result together and
publishes them in one durable CAS. Disabling the nominated successor also clears
its binding, prepared checkpoint and release state. An exact latest-request retry
does not repeat the decision. Older requests cannot run after a newer read.
Provisioned rooms use the same transaction as their enrollment bundle, so a
service restart or old gameplay save cannot re-enable the removed enrollment.

Disabled keys can authenticate only a minimal denial, with zero remaining lease
and no roster, endpoint or checkpoint disclosure. The response identifies only
the requesting member as disabled and changes no durable frontier. Provisioning
retains these keys in a separate denial-only table when reopening a room. They
remain excluded from registration, rendezvous, checkpoint access and authority
claims. Removal cannot retract checkpoint data already disclosed to a previously
trusted participant.

Removal is durable for the room, not an account-wide ban or a proof that a person
cannot acquire a separately authorized identity. It does not revoke outstanding
invitations; applications must manage invite access separately.
