# Steam packet transport

Replay has an explicit Steam Session backend built over GodotSteam's
`SteamMultiplayerPeer`. It uses the same typed handshake, seat admission, input/
action protocol, snapshots and checkpoint machinery as the other transports.
The adapter retains a peer directly; it does not install SceneMultiplayer or rely
on Kit. ENet now shares its bounded packet/lifetime adapter.

The interface was checked against GodotSteam 4.22.1, upstream commit
[`5853a7741d174cfa37edee1ca44a11581a989d0b`](https://codeberg.org/godotsteam/godotsteam/src/commit/5853a7741d174cfa37edee1ca44a11581a989d0b/godotsteam_multiplayer_peer.cpp).
The separately released GDExtension loaded under Godot 4.7.1 and exposed the
expected native class/methods without initializing Steam. This is ABI/capability
evidence, not successful Steam network delivery. The current verified envelope is
listed below.

```odin
runtime: rgd.Steam_Runtime // stable address; outlives every using Session
if rgd.steam_runtime_init(&runtime, MY_APP_ID) != .None {return}

options := rgd.SESSION_OPTIONS
options.role = .Host // .Client on the other device
options.backend = .Steam
options.steam = rgd.STEAM_CONFIG
options.steam.runtime = &runtime
options.steam.virtual_port = 0
options.steam.host_steam_id = host_id // required for clients; u64, not a seat

err := rgd.session_open(&session, initial, model, options)
// Normal session_frame / session_changes / session_issue calls follow.
```

Initialization is explicit and uses the client Steam API. It can launch an app
session/presence and requires a suitable installed GodotSteam build, Steam client
and app entitlement. `steam_available` only checks native capability and has none
of those initialization effects. Missing runtime/capability or an unexpected API
shape returns a typed error; it does not silently fall back to ENet.

The runtime requests manual callbacks. `Steam` transport polling pumps
`run_callbacks` before polling its peer. If the game is waiting for lobby/invite
callbacks before opening a Session, call `steam_runtime_poll` in its own outer
loop. Polling must remain on the Godot/Steam owning thread. This client-API adapter
is not an implementation of the SteamGameServer SDK; `.Server` still means Replay's
no-local-player authority role using the configured runtime.

Godot peer IDs and Steam IDs are different types/identities. `steam_id` returns the
local Godot transport ID. `steam_remote_id` maps a currently connected peer to the
Steam ID reported by the provider. `steam_parse_id` accepts nonzero decimal 64-bit
IDs and rejects malformed/overflowing endpoints. A transport address is not a
Replay simulation seat or a grant of authority; admission policy remains separate.

`steam_open_peer` accepts a fresh caller-created peer implementing the same API.
The adapter validates the base class and required methods, retains the peer,
attaches connection callbacks and calls `create_host` / `create_client`. Session
options can supply that peer through `steam.peer`; it is borrowed only during open,
then removed from the retained options. Normal operation constructs the native
class dynamically. The supplied runtime must remain alive.

## Ownership and bounds

The shared MultiplayerPeer adapter keeps one owned 64 KiB receive buffer and a
bounded connected-peer registry. A short destination preserves the pending packet
until a later read can copy it. Reliable/unreliable modes are reported separately,
channel zero is selected explicitly, and invalid targets/oversized outgoing
messages are refused. The provider must support Replay's 64 KiB logical packet
limit; GodotSteam's inspected Sockets implementation supports larger messages.

The wrapper forwards the shared adapter's [connection generations](multiplayer-generations.md).
Pending copies and backend packets preceding a replacement connection cannot
acquire the new peer generation. This local metadata does not authenticate a Steam ID.

Close all Sessions/peers before releasing their runtime. Callbacks are detached
before peer shutdown, buffers and references are released, and repeated close is
safe. `steam_runtime_release` clears the borrowed runtime binding; it intentionally
does not shut down a Steam API shared with other peers or lobby services. Lobby
membership, invitations and SDK shutdown remain application-owned lifecycle work.
No invitation or message to another Steam account is sent by capability detection.

## Validation and outstanding work

`tests/replay_steam/run.sh` uses a named API-contract fixture: a Godot
MultiplayerPeerExtension delegates packets to real ENet while exposing the inspected
Steam constructor/mapping methods. Separate processes exchange 64 KiB payloads,
exercise both transfer modes and pending-buffer copies, then run a complete Replay
handshake, validated loot action and authority checkpoint. Constructor/initialization
failure cases verify rejection and cleanup. The fixture uses no Valve service.

`tests/replay_steam/capability_run.sh` loads a supplied addon and inspects the real
class/method surface with Steam auto-initialization disabled. The pinned release
passed this on macOS ARM64. `tests/replay_steam/live_run.sh` is an opt-in live test
for two logged-in Steam accounts/devices. Its output uses a separate live sentinel;
contract or capability success cannot satisfy that gate.

Live Valve relay/P2P behavior, invitations/lobby UX, entitlement/account boundaries,
SteamGameServer support and broader platforms remain pending. [Room endpoint/recovery integration](steam_room.md) now supplies explicit Steam
addresses and fresh peer construction through takeover/rejoin. Its local contract
fixture remains distinct from live multi-account acceptance. Existing ENet/RTC Room
profiles remain available. These gaps stay
requirements of the full roadmap; this adapter is not a completed Steam deployment.
