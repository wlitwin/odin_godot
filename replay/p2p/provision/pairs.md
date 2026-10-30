# Pair-key provisioning

Use `Pair_Service` to obtain the pair key and current peer endpoint needed for a
native authenticated P2P link. It is an optional bounded read service over an
existing P2P Hub.
It supplies the [native link](../link/README.md) with a pair grant and the remote
member's currently registered endpoint. It does not alter durable schemas or
grant simulation authority. Embeddings route its messages explicitly; the Duel
service enables it alongside provisioning, registration and RTC signaling.

Requests/replies use separate canonical kinds `0x5054` / `0x5055`, version 1 and
separate HMAC domains. A request binds room/content, current identity, the process
registration nonce, remote member and a fresh challenge. The service checks the
MAC, current enabled identity and exact registered nonce before deriving a key.
Only full fixed rosters with a registered remote member are eligible. Reply errors
carry no key or endpoint.

The service rate-limits each enrolled member independently (burst 8, four reads
per second), does not write storage, and refuses poisoned owners or backwards
time. Pair secrets are deterministic for their committed scope/identities. A
remote rebind changes the returned key; an old requester incarnation is denied.

Use the same verified confidential transport as enrollment. A MAC is not
encryption. Only explicit loopback fixtures may use a plain channel. Never place
pair replies in public rosters, recordings or participant archives.

`Pair_Client` borrows a ready registration `Client`, clock and transport. Route its
packets separately from registration RPCs (a Router lane is suitable). Each begin
requires a new nonzero challenge; adjacent reuse is refused. Replies must match
the exact signed request hash, member pair and the owner's accepted match scope.
The client retries within a ten-second bound. Close it before its borrowed owner.

Three tests in `tests/replay_p2p_provision` cover symmetric pair issuance without
root-key disclosure, no durable writes, incarnation rotation, bad MAC/current-
registration refusal, self/unknown-peer rejection, delayed-reply correlation and
per-member request budgets. The native [P2P Direct owner](../../godot/p2p_direct.md)
requests these decisions before admitting a physical ENet connection,
including process replacement.
