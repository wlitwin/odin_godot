# Fixed-roster P2P admission

Use this package to authenticate a participant through a trusted match provider
before binding a physical connection to a P2P roster slot. Admission does not
supply gameplay state, elect a simulation authority, or resolve a checksum
disagreement by selecting a winning state.

`Match` names a session, content version, epoch and ordered roster of 2–8 nonzero,
unique member IDs. `Registry` is owned by the provider and holds the current
credential incarnation, secret key and enabled flag for each member. Clients get
the match description and only their own credential. Validate the complete registry
with `registry_valid` before publishing it. Stable member order determines player
roles; the first member may create the signaling room and the others may join.

`proof` produces a fixed 116-byte request. It binds the create/join role, session,
epoch, member/incarnation, ordered-match SHA-256 digest and 16-byte connection
challenge under a domain-separated HMAC-SHA256 using the member's 32-byte key.
`verify` checks the registry, exact identity, enabled status, role, challenge, MAC
and complete match scope. The domain is `replay-p2p-admission-v1`; this proof is
separate from the authority-lease rendezvous proof. A room code is the hexadecimal
match digest, not a credential. No secret key is sent in the proof.

The verifier is stateless. The signaling frontend must create a cryptographically
random challenge per connection, consume it once and enforce a deadline. It must
assign the sender identity itself when forwarding signaling messages. Authenticate
the provider through a trusted transport such as verified WSS for deployment;
client proof does not authenticate an arbitrary server to the client.

## Godot integration

The existing bounded `Rendezvous` frontend implements the challenge lifecycle,
rate/size limits and continuation reservations. It accepts an explicit
`Rendezvous_Provider`; ordinary `rendezvous_init` keeps the authority Service policy.
For a P2P registry:

```odin
provider := rgd.rendezvous_p2p_provider(&registry, clock)
cfg := rgd.DEFAULT_RENDEZVOUS_CONFIG
cfg.mesh = true
ok := rgd.rendezvous_provider_init(&frontend, provider, &websocket, cfg)
```

The frontend borrows the registry, clock and socket. Keep their addresses stable.
Poll the socket, route text messages through `rendezvous_receive`, and pump the
frontend as documented in [Rendezvous](../../godot/rendezvous.md). Full-mesh
introductions and signaling are opt-in; ordinary authority rooms remain stars.

The client owns a stable `Rtc_P2P_Auth{match, identity, key}` and opens with
`rtc_p2p_config`. Peer introductions carry member and incarnation as exact 64-bit
hex values. `require_identity` refuses missing/invalid metadata;
`rtc_peer_identity(&rtc, physical_id)` exposes the verified introduction only for
a connected peer on an authenticated signaling connection. Verify that member
against the expected roster, create the logical-to-physical `Remap`, then initialize
or reconnect the P2P runner. A fresh physical ID alone never establishes membership.

## Lifecycle and boundaries

Changing credential incarnation invalidates old admission proofs while retaining
the same match code and stable member roster. Disabling a credential removes its
signaling permission. The provider owns durable credential storage, monotonic
incarnation registration, revocation policy and secure personal-key distribution;
this package does not implement an account database or public provisioning UI.
Registry updates must happen at an externally synchronized boundary.

Admission authenticates connection establishment, while direct gameplay
channels may remain connected after signaling is lost. Revoking signaling
permission therefore does not disconnect an existing player. The application
or provider must also fence that player's gameplay transport or terminate the
fixed-roster match. Changing the roster requires a new match contract.
Authentication identifies the participant; it does not establish that their
simulation is honest.

The signaling frontend retains the first member as the room creator. Its browser
process may return from a compatible archive while peers retain their runners.
The creator keeps numeric RTC ID 1; the survivor detects the new connection
generation and the transport wrappers discard retired buffered work. This requires
the same live provider/match scope; it does not elect a different roster member
to replace the creator or recover its missing inputs.
Fresh participants cannot steal an existing continuation reservation using only a
member key. After the configured reservation expires they may obtain a new ID with
a fresh challenge; the P2P runner still requires a compatible durable input archive.

## Evidence

`tests/replay_p2p_admission/run.sh` checks valid roles and rejection of changed
scope/roster, key, challenge, incarnation and malformed registries. The real Godot
`service_run.sh` admits three members, checks exact identity introductions,
client-to-client signaling and sender-spoof overwriting, and rejects five bad
admission attempts using independently constructed Node HMACs.

`web_run.sh` imports personal fixture credentials in separate Chrome processes,
then performs the Duel's Save & pause, SIGKILL and fresh-browser archive rejoin
for the joining player and the creator in separate scenarios.
The existing authority-based RTC service, signaling continuation/expiry, P2P core
and plain browser fault gates also pass. See the
[recorded results](../../../docs/replay/results/p2p-admission-2026-09-08/README.md).
The service fixture binds loopback and contains published test keys. Public WSS,
account provisioning, authenticated spectator roles and broader platform acceptance
remain open work.
