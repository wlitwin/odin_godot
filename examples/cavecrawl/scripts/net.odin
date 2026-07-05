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

my_name :: proc() -> string {
	return env_string("CAVE_NAME", "spelunker")
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
	if !gd.host(self.owner, port()) {
		kui.lobby_set_status(&self.ui, "Could not host (port taken?)")
		gd.print_str("CAVE_HOST_FAIL")
		return
	}
	ksess.session_host_start(&self.ses, my_name())
	self.cols = kcombat.combat_columns(&self.ses) // the ledger, on the scoreboard
	self.slain_col = ksess.session_stat_column(&self.ses, "slain") // the game's own column
	self.running = true
	kui.lobby_show_menu(&self.ui, false, false)
	kui.lobby_set_status(&self.ui, fmt.tprintf("Hosting on :%d — waiting for friends", port()))
	kui.lobby_refresh(&self.ui, &self.ses)
	kui.chat_show(&self.chat, true)
	gd.print_str("CAVE_HOSTING")
}

@(gd_method)
cave_lobby_on_join :: proc(self: ^CaveLobby) {
	if self.running {return}
	if !gd.join(self.owner, "127.0.0.1", port()) {
		kui.lobby_set_status(&self.ui, "Could not start joining")
		return
	}
	ksess.session_client_start(&self.ses, my_token(), my_name())
	self.running = true
	kui.lobby_show_menu(&self.ui, false, false)
	kui.lobby_set_status(&self.ui, "Joining the cave...")
	kui.chat_show(&self.chat, true)
	gd.print_str("CAVE_JOINING")
}
