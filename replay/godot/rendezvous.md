# Coordinator-backed RTC signaling

Use `Rendezvous` to admit authenticated room members to RTC signaling. It is a
bounded JSON frontend alongside the native authority Service.
It borrows that Service and a raw Websocket listener. Poll the listener once,
route binary messages to `auth.service_receive`, route text to
`rendezvous_receive`, and call `rendezvous_pump` every frame. Close the frontend
before closing its borrowed owners.

A create/join request must name the exact room code derived from the current
signed authority view. The frontend issues a fresh cryptographic challenge on
that WebSocket connection. A response consumes the challenge once and must arrive
before its deadline. `auth.rendezvous_verify` checks the member key, registered
incarnation, live grant and requested role. Only the approved owner receives RTC
peer ID 1. Other enabled members receive increasing IDs. A disconnected RTC instance may
retain its ID through authenticated continuation; a fresh instance does not gain
that reservation merely by presenting the member key. A second live connection
for an already admitted identity is rejected.

The relay introduces an authority star and overwrites the sender ID itself.
Only admitted peers can relay SDP/ICE, and clients can signal only the authority.
It never carries gameplay packets. New authority terms remove old signaling
memberships. Expired grants, disabled/rebound members, disconnected sockets and
expired challenges are pruned. Existing direct data channels remain subject to
Room's gameplay lease and epoch checks, independently of signaling.

Defaults allow 32 signaling connections, five-second challenges, a 15-second
continuation grace period, a burst of 64
messages and 32 messages/second per connection. JSON is limited to 32 KiB and
nesting depth 16. Outgoing backpressure disconnects the affected signaling peer
instead of silently dropping an introduction or SDP message. The shared listener
and control service retain their own packet/connection budgets.

Client setup uses a stable `Rtc_Grant_Auth` containing a verified View, identity
and provisioned key:

```odin
cfg := transportgd.rtc_grant_config(&authorization, signaling_url, is_owner)
transportgd.rtc_open(&rtc, cfg)
```

The generic `Rtc_Config.authorize` callback can answer other compatible challenged
providers. Its returned text is borrowed for the immediate send. Authenticated
registration requires strict equality with the requested room; unauthenticated
legacy relays remain supported by ordinary `rtc_open` calls.

Room owns this authorization state and copied provider configuration through
host/client role changes. Its `Migration_Transport` names RTC explicitly, using
the configured provider URL plus the room/content/epoch/owner-derived code. The
coordinator's existing native endpoint record and wire formats are unchanged;
RTC destinations are not interpreted as ENet addresses.

Authenticated registrations receive a random continuation token. On signaling
loss the frontend holds the identity/peer ID for the bounded grace period. A
reconnection must answer a fresh challenge and present that token; comparisons
use constant-time verification. Disabled/rebound members, obsolete terms and
expired reservations cannot resume. Tokens are invalidated with the room term.
They supplement member authentication and do not replace it.

`rtc_grant_config` enables automatic signaling recovery. It retries after 500 ms,
retains healthy peer connections and fragment state, and checks that the resumed
ID/token match. Incomplete connections are deliberately rebuilt, with replacement
introductions to both endpoints. A rejected or expired continuation surfaces an
error for the enclosing session to handle; it never silently adopts a new ID.
Legacy relays remain opt-in and need not implement continuation.

Real-browser gates cover host/client recovery with unchanged connection
serials, packets received during the outage, wrong-token rejection and late join
after recovery. Cavecrawl also continues in the same epoch with no migration.
Its planned/crash and broader migration gates remain available. Public provisioning,
TLS/TURN deployment and other browser engines still need acceptance. The local
fixture contains test keys and is not a production account/admission service.

## Explicit providers and P2P rosters

`rendezvous_provider_init` accepts a borrowed `Rendezvous_Provider` with a clock,
current scope, enabled-identity predicate and fixed-proof verifier. The provider
owns credential persistence and policy. The common frontend still enforces the
per-connection random challenge, one-time use, deadline, duplicate/reservation
checks and packet budgets. Its verifier callback consumes the existing 116-byte
proof slot and returns an exact identity and room code. `rendezvous_init` wraps the
authority Service in this interface and preserves the existing lease policy.

`Rendezvous_Config.mesh` allows introductions and forwarding among all admitted
peers. It defaults to false. Provider introductions include exact member/incarnation
metadata; the RTC client can require it and expose it for logical roster binding.
The [P2P admission provider](../p2p/admission/README.md) authenticates a fixed match
without creating a gameplay authority lease. Its current creator transport and
credential-issuance boundaries remain explicit.
