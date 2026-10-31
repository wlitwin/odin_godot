# kit/steamgd — Steam transport and invite flow

Use `kit/steamgd` to host and join through Steam lobbies and overlay invites.
Friends can select "Join Game" in the overlay without entering an IP address.
The package requires the GodotSteam GDExtension's MultiplayerPeer build,
which registers both the `Steam` singleton and `SteamMultiplayerPeer` class.
It supplies a transport beneath [kit/netgd](netgd.md)'s `Session_Wire`, sharing
the session integration used by ENet.

## Talking to GodotSteam by name

The package looks up GodotSteam at runtime through the engine singleton,
dynamic `object_call`s, and ClassDB instantiation. It cannot link at compile
time to classes that another extension may not register. This lets the game
compile and ship without GodotSteam installed. `available()` checks for it at
runtime, and package procedures safely skip unavailable operations. The same
`Session_Wire` handles either transport.

GodotSteam names are centralized in this module: `SINGLETON`, `PEER_CLASS`,
and the `gd.sname(...)` method names. Update those lookups if a supported
GodotSteam build changes its API names.

<a id="the-flow"></a>

## Overlay invite sequence

The invite-via-overlay flow is:

```
host:   init(APP_ID) -> create_lobby(max) -> [signal lobby_created] ->
        host_peer(node) -> session_host_start -> invite_overlay(lobby_id)

guest:  friend hits "Join Game" in the Steam overlay ->
        [signal join_requested(lobby_id, friend)] -> join_lobby(lobby_id) ->
        [signal lobby_joined] -> client_peer(node, lobby_owner(lobby_id)) ->
        connected_to_server fires -> the wire's on_net_up joins the session
        exactly like ENet
```

## The wire is transport-agnostic

`Session_Wire` listens to SceneMultiplayer's `peer_packet`, `peer_disconnected`,
`connected_to_server`, `connection_failed`, and `server_disconnected` signals.
Replacing ENet's `gd.host` / `gd.join` calls with `host_peer` / `client_peer`
changes the installed `MultiplayerPeer` while retaining those signals, the
four forwarders, the channel plan, and the session.

## API

- `available() -> bool`: reports whether GodotSteam is registered in this
  process. The result does not change during the run.
- `init(app_id := TEST_APP_ID) -> bool`: brings Steamworks up (`steamInitEx`, callbacks
  embedded in the engine loop). False means Steam is not running, there is no appid, or there is no
  extension, so show your non-Steam lobby instead. Call once, before any lobby work. `TEST_APP_ID` is 480
  (Spacewar, Valve's test app that every Steamworks account can develop against).
- `listen(node, on_lobby_created := "", on_lobby_joined := "", on_join_requested := "") -> bool`:
  connects GodotSteam's lobby signals to the game's `@(gd_method)`s (Godot signals must
  land on script methods, the same contract as `netgd.wire_listen`). Empty names skip. The
  handler signatures:
  - `on_lobby_created(result: int, lobby_id: int)`: a result of 1 means success
  - `on_lobby_joined(lobby_id: int, perms: int, locked: bool, response: int)`
  - `on_join_requested(lobby_id: int, friend_id: int)`: fires when the overlay's "Join Game" button is used
- `create_lobby(max_members := 4, type := Lobby_Type.Friends_Only)`: the answer arrives on
  `lobby_created`. `Lobby_Type` is Steam's ELobbyType: `Private`,
  `Friends_Only` (the default), `Public`, or `Invisible`.
- `join_lobby(lobby_id: u64)`: the answer arrives on `lobby_joined`.
- `leave_lobby(lobby_id: u64)`: releases the one piece of Steam state that outlives the multiplayer
  peer. Replacing the peer drops its connection but leaves Steam lobby
  membership active and visible to friends. Call this when returning to the
  menu or before joining another lobby; it is harmless when not a member.
- `lobby_owner(lobby_id: u64) -> u64`: identifies the host of the lobby, the steam id the client peer
  connects to.
- `my_steam_id() -> u64`, `persona_name(allocator := context.temp_allocator) -> string`:
  return identity information; the persona name is the natural default for session names.
- `invite_overlay(lobby_id: u64)`: opens the Steam overlay's invite dialog so
  players can invite friends to the lobby.
- `host_peer(node: gd.Node) -> bool`: installs a Steam host peer on the node's
  MultiplayerAPI (transport seat 1, like ENet hosting). From here the `Session_Wire` takes
  over unchanged.
- `client_peer(node: gd.Node, host_steam_id: u64) -> bool`: installs a Steam client peer
  connected to the lobby owner. `connected_to_server` fires when the handshake lands, and the
  wire's `on_net_up` forward joins the session exactly like ENet.

Both peer procs print an actionable error and return false if `SteamMultiplayerPeer` isn't
registered (i.e. you installed a non-MultiplayerPeer build of GodotSteam).

## The Transport record

`ksteam.TRANSPORT` implements the
[`netgd.Transport`](netgd.md#swapping-transports) record used by Kit's generic
connection helpers:

```odin
// on_lobby_created(result, lobby_id):   host
kboot.boot_open_host(&self.boot, &ksteam.TRANSPORT, {}, name)
ksteam.invite_overlay(u64(lobby_id))

// on_lobby_joined(lobby_id, ...):       guest
kboot.boot_open_join(&self.boot, &ksteam.TRANSPORT, ksteam.endpoint_of(u64(lobby_id)), name, token)
```

The game still creates and joins lobbies in its Steam signal handlers. Once
that lookup completes, pass the resulting `Endpoint` to the connection helper.
`endpoint_of(lobby_id)` returns `{peer_id = lobby_owner(lobby_id)}`: Steam
connects to the host's Steam id, using the lobby to find it.

Three `Transport` callbacks are nil in the current Steam integration:

- `pump`: the engine polls the peer, like ENet, so there is nothing to pump.
- `close`: the peer is replaced by the next install; lobby membership is the part that
  outlives it, and the lobby id is yours (call `leave_lobby`).
- `address`: there is no verified way to ask which steam id is behind a multiplayer peer.
  Without a verified mapping, host migration cannot identify a successor.
  `rendezvous` is therefore `.None`, and host migration is disabled on Steam;
  `succession_torch` reports this once with the transport name. Some GodotSteam
  builds expose peer-to-Steam-id mapping, but this repository has not verified
  it against a running Steam client and extension. Enabling migration requires
  implementing `address` against a real build, adding the `Rendezvous_Kind`
  branch, and verifying the handoff.

## Worked example: cavecrawl

`examples/cavecrawl/scripts/net.odin` runs both transports through the same session code. In
`ready()` (`cavecrawl.odin`), it detects Steam, initializes it, and listens:

```odin
if steamgd.available() && env_int("CAVE_STEAM", 1) != 0 {
	self.steam_on = steamgd.init(env_int("CAVE_APPID", steamgd.TEST_APP_ID))
	if self.steam_on {
		steamgd.listen(self.owner, "on_lobby_created", "on_lobby_joined", "on_join_requested")
	}
}
```

The Host handler selects the transport. ENet calls `gd.host`; Steam waits for
`lobby_created`. Both then call the shared `begin_hosting` session setup.
Joining uses the corresponding shared `begin_joining` procedure.

```odin
@(gd_method)
cave_lobby_on_lobby_created :: proc(self: ^CaveLobby, result: gd.Int, lobby_id: gd.Int) {
	if int(result) != 1 { ... return }
	self.steam_lobby = u64(lobby_id)
	if !steamgd.host_peer(self.owner) { ... return }
	begin_hosting(self)
	steamgd.invite_overlay(self.steam_lobby)
}
```

`lobby_joined` also fires when the host joins the lobby it created. Check the
lobby owner before creating a client peer so the host does not connect to itself:

```odin
@(gd_method)
cave_lobby_on_lobby_joined :: proc(self: ^CaveLobby, lobby_id: gd.Int, _perms: gd.Int, _locked: gd.Bool, _response: gd.Int) {
	owner := steamgd.lobby_owner(u64(lobby_id))
	if owner == 0 || owner == steamgd.my_steam_id() {
		return // our own lobby (hosts join what they create), or no Steam
	}
	self.steam_lobby = u64(lobby_id)
	if !steamgd.client_peer(self.owner, owner) { ... return }
	// connected_to_server triggers the wire's on_net_up session join.
	begin_joining(self)
}

@(gd_method)
cave_lobby_on_join_requested :: proc(self: ^CaveLobby, lobby_id: gd.Int, _friend: gd.Int) {
	steamgd.join_lobby(u64(lobby_id)) // handles the overlay's "Join Game" request
}
```

The four wire forwards, `wire_attach`/`wire_listen`, kicks, and the latency shim are all identical
to the ENet path; see [netgd.md](netgd.md).

## Live verification

The Steam connection path requires a running Steam client and cannot be
verified by the headless test. To check it live:

1. Drop the **GodotSteam MultiplayerPeer** GDExtension into the project (the build that
   registers `SteamMultiplayerPeer`, not just the `Steam` singleton).
2. Place `steam_appid.txt` with `480` (Spacewar) next to the binary, or use your real app id.
3. Use two logged-in Steam accounts that are friends; run host on one, and accept the overlay
   invite on the other.

Cavecrawl's headless `run.sh` checks the fallback path: when `available()` is
false, the game uses its non-Steam lobby and logs `CAVE_STEAM off`. That test
does not verify a live Steam connection. Set `CAVE_STEAM=0` to disable the Steam
path even when GodotSteam is installed.
