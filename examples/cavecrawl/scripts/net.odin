package cavecrawl_scripts

// Transport + identity: how packets leave and arrive, who this peer IS, and
// the Host/Join buttons that bring the wire up. Everything session-shaped
// stays in kit/session — this file only moves bytes and reads the env.
//
// Identity: CAVE_NAME / CAVE_TOKEN env override the defaults so tests (and
// impatient friends sharing a machine) can pick who they are; otherwise the
// token persists in user://cave_token — reconnects, resumed saves,
// everything rides on keeping it.

import gd "godot:godot"
import "godot:gdext"
import kcombat "godot:kit/combat"
import kcomms "godot:kit/comms"
import knet "godot:kit/net"
import netgd "godot:kit/netgd"
import ksave "godot:kit/save"
import ksess "godot:kit/session"
import steamgd "godot:kit/steamgd"
import kui "godot:kit/ui"
import "core:fmt"
import "core:strconv"

env_string :: proc(name: cstring, fallback: string) -> string {
	env := gd.os_get_environment(gd.singleton_os(), gd.new_string_cstring(name))
	buf: [256]u8
	// string_to_utf8_chars reports the FULL length even when it exceeds the
	// buffer — clamp before slicing or a long value is a bounds-check trap.
	n := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&env, cast(cstring)&buf[0], len(buf) - 1)
	if n <= 0 {
		return fallback
	}
	return fmt.tprintf("%s", string(buf[:min(int(n), len(buf) - 1)]))
}

env_int :: proc(name: cstring, fallback: int) -> int {
	if v, ok := strconv.parse_int(env_string(name, "")); ok {
		return v
	}
	return fallback
}

port :: proc() -> int {
	if p, ok := strconv.parse_int(env_string("CAVE_PORT", "")); ok {
		return p
	}
	return DEFAULT_PORT
}

my_name :: proc(self: ^CaveLobby) -> string {
	n := env_string("CAVE_NAME", "")
	if n == "" && self.steam_on {
		n = steamgd.persona_name() // your Steam name IS your name
	}
	if n == "" {
		n = "spelunker"
	}
	return n
}

my_token :: proc() -> u64 {
	t := env_string("CAVE_TOKEN", "")
	if t != "" {
		h := u64(1469598103934665603) // fnv64a over the env token string
		for c in transmute([]u8)t {
			h = (h ~ u64(c)) * 1099511628211
		}
		return h
	}
	// The PERSISTED identity (phase 6): the token IS who you are across
	// runs — reconnects, resumed saves, everything rides on keeping it.
	return ksave.persistent_token("user://cave_token")
}

// The four transport forwards — Godot signals must land on @(gd_method)s of
// the game's script; netgd.Session_Wire owns everything behind them.

@(gd_method)
cave_lobby_on_packet :: proc(self: ^CaveLobby, id: gd.Int, packet: gd.Packed_Byte_Array) {
	netgd.wire_receive(&self.wire, id, packet)
}

// A transport peer dropped non-gracefully (alt-F4, wifi loss): tell the
// session so the roster shows it and the host stops sending to a ghost.
@(gd_method)
cave_lobby_on_peer_left :: proc(self: ^CaveLobby, id: gd.Int) {
	ksess.session_peer_disconnected(&self.ses, ksess.Peer_Id(id))
}

// Client: the transport handshake completed — ask the host for a seat.
@(gd_method)
cave_lobby_on_net_up :: proc(self: ^CaveLobby) {
	ksess.session_client_join(&self.ses)
}

// Client: the connection failed or the server vanished — same as host loss.
@(gd_method)
cave_lobby_on_net_down :: proc(self: ^CaveLobby) {
	ksess.session_peer_disconnected(&self.ses, ksess.HOST_PEER)
}

// Host: show a player the door, with a run-scoped ban — the two-call kick:
// the session unseats (and tells) them; the wire severs their socket.
@(gd_method)
cave_lobby_kick :: proc(self: ^CaveLobby, player: gd.Int) {
	if !self.ses.is_host {return}
	target := knet.Player_Id(player)
	name := "someone"
	if p, ok := ksess.session_player(&self.ses, target); ok {
		name = p.name
	}
	was, ok := ksess.session_kick(&self.ses, target, ban = true)
	if !ok {return}
	netgd.wire_drop(&self.wire, was) // deferred: the KICKED message flushes first
	kcomms.comms_system(&self.comms, fmt.tprintf("%s was shown the door", name))
	gd.print_str(fmt.tprintf("CAVE_KICKED player=%d", u64(target)))
}

@(gd_method)
cave_lobby_on_host :: proc(self: ^CaveLobby) {
	if self.running {return}
	if self.steam_on {
		// Hosting completes on the lobby_created signal.
		steamgd.create_lobby(4)
		kui.lobby_set_status(&self.ui, "Creating a Steam lobby...")
		gd.print_str("CAVE_STEAM_LOBBY_PENDING")
		return
	}
	if !gd.host(self.owner, port()) {
		kui.lobby_set_status(&self.ui, "Could not host (port taken?)")
		gd.print_str("CAVE_HOST_FAIL")
		return
	}
	begin_hosting(self)
}

// Everything hosting means AFTER a transport is up — shared verbatim by the
// ENet path (gd.host above) and the Steam path (lobby_created below): the
// session cannot tell the transports apart, which is the whole point.
begin_hosting :: proc(self: ^CaveLobby) {
	ksess.session_host_start(&self.ses, my_name(self))
	self.cols = kcombat.combat_columns(&self.ses) // the ledger, on the scoreboard
	self.slain_col = ksess.session_stat_column(&self.ses, "slain") // the game's own column
	self.running = true
	kui.lobby_show_menu(&self.ui, false, false)
	kui.lobby_set_status(&self.ui, self.steam_on ? "Hosting a Steam lobby — invite friends via the overlay" : fmt.tprintf("Hosting on :%d — waiting for friends", port()))
	kui.lobby_refresh(&self.ui, &self.ses)
	kui.chat_show(&self.chat, true)
	gd.print_str("CAVE_HOSTING")
}

@(gd_method)
cave_lobby_on_join :: proc(self: ^CaveLobby) {
	if self.running {return}
	if self.steam_on {
		// Steam joins arrive through the overlay (join_requested below).
		kui.lobby_set_status(&self.ui, "Accept a Steam invite to join (Shift+Tab)")
		return
	}
	if !gd.join(self.owner, "127.0.0.1", port()) {
		kui.lobby_set_status(&self.ui, "Could not start joining")
		return
	}
	begin_joining(self)
}

begin_joining :: proc(self: ^CaveLobby) {
	ksess.session_client_start(&self.ses, my_token(), my_name(self))
	self.running = true
	kui.lobby_show_menu(&self.ui, false, false)
	kui.lobby_set_status(&self.ui, "Joining the cave...")
	kui.chat_show(&self.chat, true)
	gd.print_str("CAVE_JOINING")
}

// ---- the Steam lobby signals (see kit/steamgd's header for the flow) ----

@(gd_method)
cave_lobby_on_lobby_created :: proc(self: ^CaveLobby, result: gd.Int, lobby_id: gd.Int) {
	if int(result) != 1 {
		kui.lobby_set_status(&self.ui, "Steam could not make the lobby")
		gd.print_str("CAVE_STEAM_LOBBY_FAIL")
		return
	}
	self.steam_lobby = u64(lobby_id)
	if !steamgd.host_peer(self.owner) {
		kui.lobby_set_status(&self.ui, "Steam peer failed")
		return
	}
	begin_hosting(self)
	steamgd.invite_overlay(self.steam_lobby)
}

@(gd_method)
cave_lobby_on_lobby_joined :: proc(self: ^CaveLobby, lobby_id: gd.Int, _perms: gd.Int, _locked: gd.Bool, _response: gd.Int) {
	owner := steamgd.lobby_owner(u64(lobby_id))
	if owner == 0 || owner == steamgd.my_steam_id() {
		return // our own lobby (hosts join what they create), or no Steam
	}
	self.steam_lobby = u64(lobby_id)
	if !steamgd.client_peer(self.owner, owner) {
		kui.lobby_set_status(&self.ui, "Steam peer failed")
		return
	}
	// connected_to_server will fire -> the wire's on_net_up seats us.
	begin_joining(self)
}

@(gd_method)
cave_lobby_on_join_requested :: proc(self: ^CaveLobby, lobby_id: gd.Int, _friend: gd.Int) {
	steamgd.join_lobby(u64(lobby_id)) // the overlay's "Join Game" lands here
}
