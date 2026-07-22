# kit/steamgd — Steam transport and invite flow

Steam lobbies, overlay invites, and a Steam `MultiplayerPeer`. Reach for this when you
want players to host and join over Steam — friends clicking "Join Game" in the Steam
overlay — instead of typing IP addresses. It runs on the **GodotSteam** GDExtension (the
"MultiplayerPeer" build, which registers both the `Steam` singleton and the
`SteamMultiplayerPeer` class) and plugs in under [kit/netgd](netgd.md)'s `Session_Wire`. The
wire is the same wire ENet uses; only the transport underneath changes.

## Talking to GodotSteam by name

Everything here reaches GodotSteam **by name** — engine singleton lookup, dynamic
`object_call`s, ClassDB instantiation — never a compile-time link, since the toolkit cannot
link against classes another extension may or may not register. The results:

- this package compiles and ships with **no GodotSteam installed**;
- `available()` answers at runtime, and every proc no-ops safely without it;
- your game keeps **one** code path — its `Session_Wire` never changes.

The GodotSteam name surface lives in this one file (the `SINGLETON` / `PEER_CLASS`
constants and the `gd.sname(...)` method names), so version drift across GodotSteam builds
lands in a single place.

## The flow

Invite-via-overlay — the friendslop shape:

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

SceneMultiplayer's signals — `peer_packet`, `peer_disconnected`, `connected_to_server`,
`connection_failed`, `server_disconnected` — fire identically over **any** `MultiplayerPeer`.
The wire binds to SceneMultiplayer, not to a transport, so swapping ENet for Steam is
swapping `gd.host` / `gd.join` for `host_peer` / `client_peer`. Nothing else moves: not the
four forwards, not the channel plan, not the session.

## API

- `available() -> bool` — is GodotSteam in this process at all? (Never changes mid-run.)
- `init(app_id := TEST_APP_ID) -> bool` — brings Steamworks up (`steamInitEx`, callbacks
  embedded in the engine loop). False = Steam isn't running / no appid / no extension — show
  your non-Steam lobby instead. Call once, before any lobby work. `TEST_APP_ID` is 480
  (Spacewar, Valve's test app — every Steamworks account can develop against it).
- `listen(node, on_lobby_created := "", on_lobby_joined := "", on_join_requested := "") -> bool`
  — connects GodotSteam's lobby signals to the game's `@(gd_method)`s (Godot signals must
  land on script methods — same contract as `netgd.wire_listen`). Empty names skip. The
  handler signatures:
  - `on_lobby_created(result: int, lobby_id: int)` — result 1 = ok
  - `on_lobby_joined(lobby_id: int, perms: int, locked: bool, response: int)`
  - `on_join_requested(lobby_id: int, friend_id: int)` — overlay "Join Game"
- `create_lobby(max_members := 4, type := Lobby_Type.Friends_Only)` — the answer arrives on
  `lobby_created`. `Lobby_Type` is Steam's ELobbyType: `Private`, `Friends_Only` (the
  friendslop default), `Public`, `Invisible`.
- `join_lobby(lobby_id: u64)` — the answer arrives on `lobby_joined`.
- `leave_lobby(lobby_id: u64)` — the one piece of Steam state that outlives the multiplayer
  peer. A replaced peer drops the connection; Steam keeps you *seated* in the lobby, still
  listed to your friends, until you say this. Say it on the way back to the menu and before
  joining a different lobby; harmless if you are not in it.
- `lobby_owner(lobby_id: u64) -> u64` — who hosts the lobby; the steam id the client peer
  connects to.
- `my_steam_id() -> u64`, `persona_name(allocator := context.temp_allocator) -> string` —
  identity; the persona name is the natural default for session names.
- `invite_overlay(lobby_id: u64)` — pops the Steam overlay's invite dialog: the whole "get
  your friends in" UI, for free.
- `host_peer(node: gd.Node) -> bool` — installs a Steam host peer on the node's
  MultiplayerAPI (transport seat 1, like ENet hosting). From here the `Session_Wire` takes
  over unchanged.
- `client_peer(node: gd.Node, host_steam_id: u64) -> bool` — installs a Steam client peer
  connected to the lobby owner. `connected_to_server` fires when the handshake lands — the
  wire's `on_net_up` forward joins the session exactly like ENet.

Both peer procs print an actionable error and return false if `SteamMultiplayerPeer` isn't
registered (i.e. you installed a non-MultiplayerPeer build of GodotSteam).

## The Transport record

`ksteam.TRANSPORT` is a [`netgd.Transport`](netgd.md#swapping-transports) record, so the
generic kit/boot doors work with Steam:

```odin
// on_lobby_created(result, lobby_id):   host
kboot.boot_open_host(&self.boot, &ksteam.TRANSPORT, {}, name)
ksteam.invite_overlay(u64(lobby_id))

// on_lobby_joined(lobby_id, ...):       guest
kboot.boot_open_join(&self.boot, &ksteam.TRANSPORT, ksteam.endpoint_of(u64(lobby_id)), name, token)
```

The lobby half stays in your signal handlers: asking for a lobby and getting the answer
back on a signal is a Steam conversation, not a transport verb. What the doors take is the
`Endpoint` that conversation produces — `endpoint_of(lobby_id)` is
`{peer_id = lobby_owner(lobby_id)}`, because Steam addresses peers by steam id and the
lobby is only the phonebook.

**Three slots are nil.** Each names a capability Steam does not offer through the generic
door:

- `pump` — the engine polls the peer, like ENet, so there is nothing to pump.
- `close` — the peer is replaced by the next install; lobby membership is the part that
  outlives it, and the lobby id is yours (call `leave_lobby`).
- `address` — there is no verified way to ask which steam id is behind a multiplayer peer.
  Without it the host-migration handoff cannot name an heir, so `rendezvous` is `.None` and
  **host migration is off on Steam**; `succession_torch` reports this once, naming the
  transport. GodotSteam exposes the peer-to-steam-id mapping on builds that have it, but it
  cannot be verified from this repo (no Steam client, no linked extension, every call by
  name). To turn migration on: fill the `address` slot against a real build, add the
  `Rendezvous_Kind` arm, and Steam migrates.

## Worked example: cavecrawl

`examples/cavecrawl/scripts/net.odin` runs both transports through the same session code. In
`ready()` (`cavecrawl.odin`): detect, init, listen —

```odin
if steamgd.available() && env_int("CAVE_STEAM", 1) != 0 {
	self.steam_on = steamgd.init(env_int("CAVE_APPID", steamgd.TEST_APP_ID))
	if self.steam_on {
		steamgd.listen(self.owner, "on_lobby_created", "on_lobby_joined", "on_join_requested")
	}
}
```

The Host button branches on the transport, then both paths converge on `begin_hosting` —
shared **verbatim** by ENet (`gd.host`) and Steam (`lobby_created`): the session cannot tell
the transports apart. Same shape for `begin_joining`.

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

The guest side has one guard to remember — **`lobby_joined` fires for the host's own lobby
too** (hosts join what they create), so check the owner before making a client peer:

```odin
@(gd_method)
cave_lobby_on_lobby_joined :: proc(self: ^CaveLobby, lobby_id: gd.Int, _perms: gd.Int, _locked: gd.Bool, _response: gd.Int) {
	owner := steamgd.lobby_owner(u64(lobby_id))
	if owner == 0 || owner == steamgd.my_steam_id() {
		return // our own lobby (hosts join what they create), or no Steam
	}
	self.steam_lobby = u64(lobby_id)
	if !steamgd.client_peer(self.owner, owner) { ... return }
	// connected_to_server will fire -> the wire's on_net_up seats us.
	begin_joining(self)
}

@(gd_method)
cave_lobby_on_join_requested :: proc(self: ^CaveLobby, lobby_id: gd.Int, _friend: gd.Int) {
	steamgd.join_lobby(u64(lobby_id)) // the overlay's "Join Game" lands here
}
```

The four wire forwards, `wire_attach`/`wire_listen`, kicks, the latency shim — all identical
to the ENet path; see [netgd.md](netgd.md).

## Live verification

This cannot run headless — it needs the Steam client. The checklist:

1. Drop the **GodotSteam MultiplayerPeer** GDExtension into the project (the build that
   registers `SteamMultiplayerPeer`, not just the `Steam` singleton).
2. `steam_appid.txt` with `480` (Spacewar) next to the binary, or your real app id.
3. Two logged-in Steam accounts that are friends; run host on one, accept the overlay invite
   on the other.

Until you've done that, `available()` false-ing into your non-Steam lobby is the correct,
tested behavior — cavecrawl's `run.sh` asserts the headless runs log `CAVE_STEAM off`
(graceful absence), and the `CAVE_STEAM=0` env knob switches the paths off even with
GodotSteam installed.
