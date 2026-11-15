# Native authenticated two-player P2P

`P2P_Direct` manages an ENet connection between two participants enrolled through
`P2P_Party`. It discovers
the peer's registered endpoint, requests a scoped pair key, authenticates the
physical connection and exposes stable member IDs through `transport.Transport`.
It replaces failed transports without owning or rewinding the gameplay runner.
The application retains and rebinds that runner as described below.

1. Open/pump `P2P_Party` with native `Party_Storage`, verified service TLS and a
   native endpoint. The endpoint is re-registered each process, while the original
   persisted enrollment request remains unchanged for exact retries.
2. Once Party is ready, call `p2p_direct_open`. The first member listens; the other
   queries the service before connecting. This convenience owner supports exactly
   two members. Other topologies can use the lower-level pair/link APIs.
   An optional `P2P_Direct_Options.listen` selects the local bind address/port
   independently of the advertised Party endpoint. Empty options retain the
   existing behavior. The options are copied, and the advertised endpoint is never
   rewritten from the bind configuration.
3. Give `p2p_direct_transport` to the game's transport wrappers/runner. Continue
   pumping `p2p_party_frame` once per frame before polling gameplay. Registration
   and pair-key messages use separate Router lanes on the same control socket.
4. Read `p2p_direct_identity` only after admission. The transport uses the remote
   member ID, not the ENet ID. `generation` is a monotone authenticated connection
   serial even when a reopened ENet owner reuses an ID.
5. On a new admitted generation, rebind the retained P2P runner. A fresh returning
   process restores a compatible participant archive; credentials contain no
   simulation/input history. Close the gameplay transport before closing Party.

Pair requests are made for the current connection. A missing remote registration
or rate-limit result retries after 500 ms. ENet connection/cryptographic handshakes
have five-second attempt bounds. Failed links are retired; replacements use fresh
pair decisions and cryptographic nonces. Newer signed roster incarnations retire
older links. Signed registration refusal clears link keys. An unavailable
background control connection does not by itself close an admitted link, but new
admission still needs the service.

The listener permits eight pending ENet peers but admits one pair. This is not a
DDoS availability guarantee. Use `listen` for a local interface behind a forwarded
advertised address/port. Port forwarding is deployment configuration; this owner
does not establish arbitrary NAT traversal. Native/browser gameplay needs
a common backend; this ENet owner does not connect directly to browser WebRTC.

See [link security/lifetime](../p2p/link/README.md) and
[pair provisioning](../p2p/provision/pairs.md). The framing is experimental and has
not received independent cryptographic review. Native macOS integration and WASM
package checks have run; broader platform validation remains separate.

`tests/replay_p2p_native/run.sh` covers TLS enrollment, encrypted gameplay, process
kills and both return roles. Creator return changes its listen port; the survivor
discovers the new signed endpoint and preserves its runner. Game parity is not
part of this integration gate.
