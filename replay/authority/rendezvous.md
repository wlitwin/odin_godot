# Authenticated RTC rendezvous primitives

A room code is a routing identifier, not proof of authority. `rendezvous_code`
derives a 64-character code from the authenticated view's room, content, epoch and
owner identity. `rendezvous_proof` signs a fixed 116-byte create/join request with
the member's provisioned key and a signaling connection's challenge.

`rendezvous_verify` runs beside the native authority Service. It checks the MAC,
connection challenge, current live grant, exact process incarnation and enabled
membership. Only the current owner can create the authority's room; another
registered member may join it. A changed content/epoch/owner produces a different
room code. A stale grant, wrong challenge, tampered proof or non-owner creation
request fails. Verification does not renew a lease or mutate durable records.

The signaling service must issue a fresh cryptographic challenge per connection,
expire it and consume it once. Passing a reused challenge to this stateless
verifier would not implement replay protection. The [Godot frontend](../godot/rendezvous.md) now implements that lifecycle and
connects it to RTC authorization. Public deployment/provisioning remains separate
from the verified loopback fixtures.
