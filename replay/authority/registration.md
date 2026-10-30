# Process registration and gameplay identity

A control key identifies an authorized member. A process incarnation identifies
one running instance of that member. The service assigns fresh incarnations
through authenticated Challenge/Rebind RPCs; callers do not need to guess the next
counter or reuse an old process identity.

The initial member, key, permissions, game-token hash, and endpoint are
provisioned by a trusted room/admission provider. The
[admission backend](../provision/README.md) persists those credentials together
with invite consumption. Its bounded create/join protocol has native TLS acceptance;
the client journal adds durable native/browser enrollment. Public deployment
remains separate from these local acceptance gates. Registration preserves those
permissions and the game-token binding. It can update the endpoint using an
explicit request, but it cannot enable hosting or create an unknown member.

## Registration contract

1. A client with a fresh random RPC nonce requests a challenge for its member ID.
2. The service issues a random, expiring challenge bound to that nonce, current
   coordinator generation, current incarnation, next incarnation, and endpoint.
3. The client authenticates a Rebind containing that proof.
4. One durable CAS replaces the incarnation and resets/binds its request frontier
   to the new RPC nonce. A replay of that exact committed Rebind is idempotent.

Challenge alone changes no durable identity. Old confirmations do not match a new
challenge, expired challenges fail, and outstanding challenges do not survive a
coordinator restart. Incarnations only increase. A live authority cannot be replaced
through registration. Normally an old host returns after another authority has
been granted; the expired-owner recovery opt-in below provides a separate path.
Recently active instances also prevent another nonce from preempting their member
while the old control connection is still live.

Keys are looked up by stable member ID. Ordinary RPCs must then match both the
current durable incarnation and its bound nonce. Invalid bindings get no live lease.
This prevents a replacement RPC wrapper from inheriting a lease merely because it
knows the member's key. Registration does not claim Byzantine resistance against a
member deliberately sharing its credentials or lying about game state.

`Room` performs this handshake by default. Its initial `identity.incarnation` is a
nonzero hint; the accepted identity is returned in `room.options.identity`.
`provisioned_incarnation=true` bypasses registration only when a trusted provider
already assigned this particular process identity. A zero registration endpoint
retains the provisioned endpoint.

A checkpoint-enabled service may opt into expired-owner registration after lease
expiry and restart quarantine. This replaces only the member incarnation/nonce;
it never inherits the old owner's lease. The separate
[published restore decision](../provision/checkpoint/restore.md) must authorize an
exact saved checkpoint and a newer epoch. A live owner remains protected, and
services without this opt-in retain the owner-rebind refusal.

## Gameplay binding

Member records include the SHA-256 hash of the stable game token. The gameplay
Hello carries the process incarnation, and the authority's Room validates it
against the authenticated coordinator roster. The network runner rejects stale
incarnations, retires their connection binding, and allows a validated newer
instance to reclaim the token's reserved seat and action frontier. Checkpoints
preserve incarnation metadata. Backup selection resolves the member's latest
incarnation and checks the selected gameplay connection's token hash before
disclosing an authority archive.

The stable player token preserves game identity; the increasing incarnation fences
the old process. Cavecrawl's returned-host gate kills the original host, migrates
to a successor, starts a fresh old-host process, verifies a newer incarnation and
the original seat, and executes another gameplay action. The guest stays running
throughout and retains its inventory.

The current experimental formats are gameplay protocol **7**, checkpoint **4**,
control RPC **2**, and decision record **3**. Earlier experimental records require
an explicit converter; no silent fallback or permission downgrade is provided.
Original Kit formats and games remain separate.

## Extended recovery policy and evidence

A handoff request requires a live selected successor. Loss before freezing cancels
the request. Loss after the source retires can recover the surviving source's
frozen world under a new coordinator-approved epoch. If the final checkpoint was
already released, its exact hash/tick/size must match; neither side can substitute
a different world or revive the retired epoch. Competing valid claims are serialized
by the durable store.

```sh
nix develop --command bash tests/replay_migration/extended_run.sh
nix develop --command bash tests/replay_migration/partition_run.sh
```

These real-process gates passed:

- Returned killed host: newer incarnation 103, original seat 1, new accepted action.
- Two planned handoffs: the guest remains alive through epoch 3 and two migrations.
- Old-host control partition: gameplay stops at a fixed tick after lease expiry;
  the guest continues on the successor; the isolated owner later rejoins.
- Successor killed during handoff: the surviving source recovers under epoch 2,
  with conserved guest inventory and a fresh acknowledged action.

The partition injection pauses the old host's control pumping; its gameplay
connection remains present. This establishes the lease/room behavior under that
specific partition, not every network topology or every crash instruction boundary.
These gates do not establish broader combat coverage, competitive migration,
lobby/invite provisioning or other platform/reachability profiles; consult each
feature's own acceptance results.
