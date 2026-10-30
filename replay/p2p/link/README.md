# Authenticated P2P links

Use this experimental transport wrapper to authenticate and encrypt a physical
connection between two provisioned member incarnations. The native [P2P Direct owner](../../godot/p2p_direct.md)
connects it to party provisioning and Duel's ENet transport.

The trusted service derives a pair key from the two enrollment keys using Odin's
HKDF-SHA256 implementation. The derivation binds the entire match scope and the
two sorted member/incarnation identities. A pair never receives the other member's
enrollment key. Changing either incarnation changes the pair key; an unchanged
service restart does not. The key is provisioned through a confidential channel.

Each connection exchanges fresh 32-byte nonces under pair-key HMAC proofs. The
transcript derives separate directional/channel traffic keys and separate
confirmation keys. Confirmation/ack retry handles a lost final handshake message;
an authenticated data packet can also confirm possession of the transcript keys.
Every gameplay packet uses the standard ChaCha20-Poly1305 implementation, with its
header as associated data. No packet reaches the game before authentication.

The construction uses [HKDF](https://www.rfc-editor.org/rfc/rfc5869) and
[ChaCha20-Poly1305](https://www.rfc-editor.org/rfc/rfc8439) from Odin's core crypto
packages. The surrounding Replay handshake/framing is new and is not a standard
protocol or an independently reviewed security claim. This PSK construction does
not provide forward secrecy against later enrollment-key/service compromise.

## Ownership and bounds

- `open` takes a trusted `Grant`, the local identity, physical peer, fresh
  cryptographic nonce, clock and already-connected generation-aware transport.
  A nonce must never be reused for another open. Do not serialize/copy a live Link.
- Supply a dedicated route for this peer, for example through `transport.Router`.
  `pump` consumes its route. Unrelated sender packets are refused, not forwarded.
- `transport` exposes the common transport interface. `identity` exposes the
  remote identity only after admission. It does not create a gameplay roster.
- `close` clears keys and pending plaintext; it does not close the borrowed base.
  The embedding owns the underlying connection's lifetime.
- A changed transport generation or disconnected base fails the link and drops
  pending plaintext. A replacement connection needs a fresh provider decision and
  fresh link nonce; it cannot silently inherit the prior admission.
- Handshake timeout is explicit (250–120000 ms). Receive work is bounded to 32
  packets per pump, plus one retained plaintext packet. Buffer_Too_Small retains
  that packet until a sufficient read or connection retirement.
- Overhead is 32 bytes; plaintext limit is `transport.MAX_PACKET_BYTES - 32`.
  Counters and 64-packet replay windows are separate for reliable/unreliable
  channels. Reliable delivery must preserve per-direction order. Unreliable
  packets older than the replay window are discarded.
- Every encryption consumes a sequence, even if the base reports backpressure.
  A retry cannot encrypt different plaintext with a previously used key/nonce.

The grant represents the provider's identity snapshot. It is not an offline
revocation oracle. The embedding must refresh admission before binding a new
connection and retire links on newer authenticated incarnation/revocation notices.
Peers sharing a pair secret can authenticate that pair; this is not anti-cheat
authority between participants who simulate the complete match.

`tests/replay_p2p_link/run.sh` currently passes seven native tests and WASM checking:
scope/identity key separation, handshake faults, encrypted bidirectional traffic,
tampering/replay/reflection/channel substitution, retained receive buffers,
generation replacement, channel-window independence, bounded denial and nonce
consumption under backpressure. The native party fixture additionally exercises
real encrypted ENet gameplay and connection replacement after a process kill.
