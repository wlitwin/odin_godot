# P2P party setup

`P2P_Party` composes durable `Party` enrollment with the fixed-roster P2P
registration client. It supplies an authenticated match descriptor and WebRTC
configuration without creating an authority `Room` or owning the gameplay runner.

1. Open `P2P_Party` with a `Party_Config` and the game's required player count.
   Use Player invites with `invite_uses = players - 1`. Checkpoint publication is
   an authority operation and must be disabled. Browser storage uses IndexedDB;
   native callers supply the existing `Party_Storage` adapter.
2. Pump `p2p_party_frame` until `party.recent_loaded`. Call `p2p_party_begin` with
   Create, Join plus a parsed ticket, or Rejoin. The existing journal persists the
   request, grant and recent-room selection. A creator's `party.code` becomes
   shareable before other participants have enrolled.
3. Continue pumping. After enrollment, the owner opens a separate control
   connection, obtains a fresh nonce using Godot Crypto, performs Challenge/Rebind,
   then queries until the entire enabled roster exists. This path creates no
   gameplay authority lease; the fixed-roster P2P protocol governs gameplay.
4. When `ready`, obtain `p2p_party_rtc`. Keep the owner at its stable address while
   RTC borrows its authorization/ICE callbacks. The first roster member creates
   signaling; other members join. Supply the returned match scope and ordered
   roster to the P2P runner, and bind physical connections only after checking
   authenticated member identities. A transport ID is not a simulation player ID.
5. Close gameplay transports before `p2p_party_close`, then close borrowed native
   storage. Close/reopen the owner to retry a failed enrollment/registration.

The lower-level `replay/p2p/provision.Client` supports non-Godot drivers. It takes
an enrollment grant, required count, cryptographic per-process nonce, clock and
transport. It registers an incarnation, waits for complete membership, and returns
the match plus the local credential through `client_admission`. It retains the
durable grant unchanged, so a new process can reuse the original stored grant and
register a newer incarnation. Roster queries continue every 500 ms, with the same
nonce and monotonically increasing sequence. Unanswered requests fail after ten
seconds; they do not expose a speculative registration result.

The high-level owner requires a connected control socket within ten seconds.
Errors clear readiness and are explicit through `failed`, the underlying Party
and registration state, and `p2p_party_message`. It does not close an already
running game on a control error. The embedding game chooses that policy. Duel
continues established P2P gameplay if registration control becomes unavailable;
it requires fresh registration for a future process. Automatic control reconnection
after readiness is not implemented here.

## Signaling service

`P2P_Rendezvous_Hub` connects a bounded provisioning Hub to a WebSocket server.
Route binary packets to the P2P provisioning/control entry points and text packets
to `p2p_rendezvous_hub_receive`. Poll the socket once and pump the signaling hub
each frame. The first text message chooses a current opaque room code; per-room
challenge/MAC verification still decides admission. Rooms always use a mesh.

A guest may finish enrollment before the creator starts signaling. P2P party RTC
configuration enables `wait_for_host` for guests: an explicit `no_room` reply can
retry on a fresh socket after 500 ms, bounded by the original 15-second deadline.
Authentication, malformed-protocol and other errors are not converted into retries.
Existing signaling continuation behavior remains separate.

## Current game coverage

[Duel](../../examples/replay_duel/README.md) uses this owner for browser
create/join/rejoin. Its separate [service](../../examples/replay_duel_service/README.md)
combines private SQLite enrollment and challenged mesh signaling. Browser return
still requires a compatible participant archive: room credentials do not contain
the simulation or input history.

The native [P2P Direct owner](p2p_direct.md) supplies authenticated two-player
ENet gameplay, endpoint discovery and connection replacement. Party keeps
registration and pair provisioning on separate Router lanes of one socket;
`p2p_party_pair_begin` is also available to custom transport owners. Its endpoint
is registered from the current configuration, allowing a returning process to
change ports without rewriting the durable enrollment request.

Account/device transfer, public deployment and broader outage recovery remain
work. ENet and browser WebRTC are separate gameplay backends; a native RTC
extension must not be assumed available.
