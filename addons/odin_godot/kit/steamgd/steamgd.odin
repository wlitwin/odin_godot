package kit_steamgd

// kit/steamgd — the STEAM transport & invite flow, over the GodotSteam
// GDExtension (the "GodotSteam MultiplayerPeer" build, which registers both
// the `Steam` singleton and the `SteamMultiplayerPeer` class).
//
// Everything here talks to GodotSteam BY NAME — engine singleton lookup,
// dynamic calls, ClassDB instantiation — because the toolkit cannot link
// against classes another extension may or may not register. That means:
//   * this package compiles and ships with NO GodotSteam installed;
//   * available() answers at runtime, and every proc no-ops safely without it;
//   * a game keeps ONE code path — its Session_Wire never changes, because
//     SceneMultiplayer's signals (peer_packet, peer_disconnected,
//     connected_to_server...) fire identically over any MultiplayerPeer.
//     Swapping ENet for Steam is swapping gd.host/gd.join for the calls
//     below. Nothing else moves.
//
// THE FLOW (invite-via-overlay — the friendslop shape):
//   host:  init(APP_ID) -> create_lobby(max) -> [signal lobby_created] ->
//          host_peer(node) -> session_host_start -> invite_overlay(lobby_id)
//   guest: friend hits "Join Game" in the Steam overlay ->
//          [signal join_requested(lobby_id, friend)] -> join_lobby(lobby_id) ->
//          [signal lobby_joined] -> client_peer(node, lobby_owner(lobby_id))
//          -> connected_to_server fires -> the wire's on_net_up joins the
//          session exactly like ENet.
//
// LIVE VERIFICATION (cannot run headless — needs the Steam client):
//   1. Drop the GodotSteam MultiplayerPeer GDExtension into the project.
//   2. steam_appid.txt with 480 (Spacewar, Valve's test app) next to the
//      binary, or your real app id.
//   3. Two logged-in Steam accounts that are friends; run host on one,
//      accept the overlay invite on the other.
//
// GodotSteam's name surface, isolated below — API drift across GodotSteam
// versions lands in ONE place.

import gd "godot:godot"
import "godot:gdext"
import "core:fmt"

@(private)
SINGLETON: cstring : "Steam"
@(private)
PEER_CLASS: cstring : "SteamMultiplayerPeer"

// Steam's ELobbyType: who can see and join the lobby.
Lobby_Type :: enum int {
	Private      = 0, // invite-only
	Friends_Only = 1, // friends can see + join (the friendslop default)
	Public       = 2,
	Invisible    = 3,
}

// The Spacewar test app id — every Steamworks account can develop against it.
TEST_APP_ID :: 480

// The Steam singleton, if the GodotSteam extension is present.
steam :: proc "contextless" () -> (s: gd.Object, ok: bool) {
	e := gd.singleton_engine()
	if !bool(gd.engine_has_singleton(e, gd.sname(SINGLETON))) {
		return {}, false
	}
	return gd.engine_get_singleton(e, gd.sname(SINGLETON)), true
}

// Is GodotSteam in this process at all? (The answer never changes mid-run.)
available :: proc "contextless" () -> bool {
	_, ok := steam()
	return ok
}

@(private)
vint :: proc "contextless" (v: i64) -> gd.Variant {
	v := gd.Int(v)
	return gd.variant_from_int(&v)
}

@(private)
vbool :: proc "contextless" (v: bool) -> gd.Variant {
	v := gd.Bool(v)
	return gd.variant_from_bool(&v)
}

@(private)
dict_int :: proc "contextless" (d: ^gd.Dictionary, key: cstring) -> i64 {
	ks := gd.new_string_cstring(key)
	k := gd.variant_from_string(&ks)
	defer gd.variant_destroy(&k)
	v := gd.dictionary_get(d, k, gd.Variant{})
	defer gd.variant_destroy(&v)
	return gd.variant_to_int(&v)
}

// Bring the Steamworks API up (steamInitEx, callbacks embedded in the engine
// loop). False = Steam isn't running / no appid / no extension — show your
// non-Steam lobby instead. Call once, before any lobby work.
init :: proc(app_id := TEST_APP_ID) -> bool {
	s, ok := steam()
	if !ok {
		return false
	}
	a := vint(i64(app_id))
	defer gd.variant_destroy(&a)
	b := vbool(true)
	defer gd.variant_destroy(&b)
	ret := gd.object_call(s, gd.sname("steamInitEx"), a, b)
	defer gd.variant_destroy(&ret)
	d := gd.variant_to_dictionary(&ret)
	defer gd.free_dictionary(d)
	status := dict_int(&d, "status")
	if status != 0 {
		gd.print_str(fmt.tprintf("kit/steamgd: steamInitEx status=%d (is Steam running? steam_appid.txt present?)", status))
	}
	return status == 0
}

// Connect GodotSteam's lobby signals to the game's @(gd_method)s (Godot
// signals must land on script methods — same contract as netgd.wire_listen).
// Empty names skip that signal.
//   on_lobby_created(result: int, lobby_id: int)   — result 1 = ok
//   on_lobby_joined(lobby_id: int, perms: int, locked: bool, response: int)
//   on_join_requested(lobby_id: int, friend_id: int) — overlay "Join Game"
listen :: proc "contextless" (node: gd.Node, on_lobby_created: cstring = "", on_lobby_joined: cstring = "", on_join_requested: cstring = "") -> bool {
	s, ok := steam()
	if !ok {
		return false
	}
	obj := cast(gd.Object)node
	if on_lobby_created != "" {
		gd.connect_to(s, "lobby_created", obj, on_lobby_created)
	}
	if on_lobby_joined != "" {
		gd.connect_to(s, "lobby_joined", obj, on_lobby_joined)
	}
	if on_join_requested != "" {
		gd.connect_to(s, "join_requested", obj, on_join_requested)
	}
	return true
}

// Ask Steam for a lobby; the answer arrives on the lobby_created signal.
create_lobby :: proc(max_members := 4, type := Lobby_Type.Friends_Only) {
	s, ok := steam()
	if !ok {
		return
	}
	t := vint(i64(type))
	defer gd.variant_destroy(&t)
	m := vint(i64(max_members))
	defer gd.variant_destroy(&m)
	r := gd.object_call(s, gd.sname("createLobby"), t, m)
	gd.variant_destroy(&r)
}

// Enter a lobby (from join_requested, or an id a friend pasted); the answer
// arrives on the lobby_joined signal.
join_lobby :: proc(lobby_id: u64) {
	s, ok := steam()
	if !ok {
		return
	}
	l := vint(i64(lobby_id))
	defer gd.variant_destroy(&l)
	r := gd.object_call(s, gd.sname("joinLobby"), l)
	gd.variant_destroy(&r)
}

// Who hosts this lobby — the steam id the client peer connects to.
lobby_owner :: proc(lobby_id: u64) -> u64 {
	s, ok := steam()
	if !ok {
		return 0
	}
	l := vint(i64(lobby_id))
	defer gd.variant_destroy(&l)
	r := gd.object_call(s, gd.sname("getLobbyOwner"), l)
	defer gd.variant_destroy(&r)
	return u64(gd.variant_to_int(&r))
}

my_steam_id :: proc() -> u64 {
	s, ok := steam()
	if !ok {
		return 0
	}
	r := gd.object_call(s, gd.sname("getSteamID"))
	defer gd.variant_destroy(&r)
	return u64(gd.variant_to_int(&r))
}

// This account's display name — the natural default for session names.
persona_name :: proc(allocator := context.temp_allocator) -> string {
	s, ok := steam()
	if !ok {
		return ""
	}
	r := gd.object_call(s, gd.sname("getPersonaName"))
	defer gd.variant_destroy(&r)
	gs := gd.variant_to_string(&r)
	defer gd.free_string(gs)
	buf: [128]u8
	n := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&gs, cast(cstring)&buf[0], len(buf) - 1)
	if n <= 0 {
		return ""
	}
	out := make([]u8, min(int(n), len(buf) - 1), allocator)
	copy(out, buf[:len(out)])
	return string(out)
}

// Pop the Steam overlay's invite dialog for the lobby — the whole "get your
// friends in" UI, for free.
invite_overlay :: proc(lobby_id: u64) {
	s, ok := steam()
	if !ok {
		return
	}
	l := vint(i64(lobby_id))
	defer gd.variant_destroy(&l)
	r := gd.object_call(s, gd.sname("activateGameOverlayInviteDialog"), l)
	gd.variant_destroy(&r)
}

// Install a Steam HOST peer on the node's MultiplayerAPI (transport seat 1,
// like ENet hosting). From here the Session_Wire takes over unchanged.
host_peer :: proc(node: gd.Node) -> bool {
	return make_peer(node, "create_host", 0)
}

// Install a Steam CLIENT peer connected to `host_steam_id` (the lobby
// owner). connected_to_server fires when the handshake lands — the wire's
// on_net_up forward joins the session exactly like ENet.
client_peer :: proc(node: gd.Node, host_steam_id: u64) -> bool {
	return make_peer(node, "create_client", host_steam_id)
}

@(private)
make_peer :: proc(node: gd.Node, method: cstring, steam_id: u64) -> bool {
	if !available() {
		return false
	}
	db := gd.singleton_class_db()
	pv := gd.class_db_instantiate(db, gd.sname(PEER_CLASS))
	defer gd.variant_destroy(&pv)
	peer := gd.variant_to_object(&pv)
	if cast(rawptr)peer == nil {
		gd.print_str("kit/steamgd: SteamMultiplayerPeer is not registered (install the MultiplayerPeer build of GodotSteam)")
		return false
	}
	err: gd.Variant
	if steam_id != 0 {
		sid := vint(i64(steam_id))
		defer gd.variant_destroy(&sid)
		port := vint(0)
		defer gd.variant_destroy(&port)
		err = gd.object_call(peer, gd.sname(method), sid, port)
	} else {
		port := vint(0)
		defer gd.variant_destroy(&port)
		err = gd.object_call(peer, gd.sname(method), port)
	}
	defer gd.variant_destroy(&err)
	if gd.variant_to_int(&err) != 0 {
		gd.print_str(fmt.tprintf("kit/steamgd: %s failed (%d)", method, gd.variant_to_int(&err)))
		return false
	}
	mp := gd.node_get_multiplayer(node)
	if cast(rawptr)mp == nil {
		return false
	}
	gd.multiplayer_api_set_multiplayer_peer(mp, cast(gd.Multiplayer_Peer)peer)
	return true
}
