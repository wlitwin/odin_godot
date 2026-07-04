//gd:extends Node
//gd:class CaveLobby
package cavecrawl_scripts

// ----------------------------------------------------------------------------
// CAVECRAWL — the friendslop toolkit's example game, grown one phase at a
// time. Phase 1: it boots to a WORKING LOBBY — host a cave or join one,
// watch the spelunker list fill in live (names, host crown, you-marker,
// measured ping), and reconnect-proof identity underneath it all.
//
// This file is the whole game so far, and most of it is button wiring:
//   * kit/ui builds the lobby controls (lobby_make / lobby_refresh).
//   * kit/session runs identity, roster, stats, and (from phase 2 on) the
//     world — this node just forwards transport packets and drains events.
//   * kit/netgd is the wire. Host = ENet :4242; Join = localhost for now
//     (room codes ride the WebRTC signaling server in a later phase).
//
// Identity: CAVE_NAME / CAVE_TOKEN env override the defaults so tests (and
// impatient friends sharing a machine) can pick who they are. A real build
// persists the token in user:// — that lands with save/load (phase 6).
// ----------------------------------------------------------------------------

import gd "godot:godot"
import "godot:gdext"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import kui "godot:kit/ui"
import netgd "godot:kit/netgd"
import "core:fmt"
import "core:strconv"
import "core:time"

DEFAULT_PORT :: 4242
MSG_SESSION :: u8(0) // all kit/session traffic under one game byte

CaveLobby :: struct {
	owner:     gd.Node,
	ses:       ksess.Session,
	ui:        kui.Lobby,
	running:   bool, // hosting or joining (transport is up)
	join_sent: bool, // client: JOIN goes out once the transport connects
}

@(private = "file")
now_s :: proc "contextless" () -> f64 {
	return f64(time.tick_now()._nsec) / 1e9
}

@(private = "file")
env_string :: proc(name: cstring, fallback: string) -> string {
	env := gd.os_get_environment(gd.singleton_os(), gd.new_string_cstring(name))
	buf: [64]u8
	n := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&env, cast(cstring)&buf[0], len(buf) - 1)
	if n <= 0 {
		return fallback
	}
	return fmt.tprintf("%s", string(buf[:n]))
}

@(private = "file")
port :: proc() -> int {
	if p, ok := strconv.parse_int(env_string("CAVE_PORT", "")); ok {
		return p
	}
	return DEFAULT_PORT
}

@(private = "file")
my_name :: proc() -> string {
	return env_string("CAVE_NAME", "spelunker")
}

@(private = "file")
my_token :: proc() -> u64 {
	t := env_string("CAVE_TOKEN", "")
	if t != "" {
		h := u64(1469598103934665603) // fnv64a over the env token string
		for c in transmute([]u8)t {
			h = (h ~ u64(c)) * 1099511628211
		}
		return h
	}
	// First run without persistence: derive from the clock. Phase 6 stores it.
	return u64(time.tick_now()._nsec)
}

@(private = "file")
session_send :: proc(user: rawptr, to_peer: int, bytes: []u8, channel: ksess.Channel) {
	self := cast(^CaveLobby)user
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, MSG_SESSION)
	append(&w.buf, ..bytes)
	if channel == .Stream {
		_ = netgd.send_stream(self.owner, to_peer, knet.writer_bytes(&w))
	} else {
		_ = netgd.send_reliable(self.owner, to_peer, knet.writer_bytes(&w))
	}
}

cave_lobby_ready :: proc(self: ^CaveLobby) {
	self.ui = kui.lobby_make(self.owner, "C A V E C R A W L")
	kui.lobby_set_status(&self.ui, "Host a cave, or join one at localhost")
	gd.connect_to(cast(gd.Object)self.ui.host_btn, "pressed", self.owner, "on_host")
	gd.connect_to(cast(gd.Object)self.ui.join_btn, "pressed", self.owner, "on_join")
	gd.print_str("CAVE_UI_READY")
}

@(gd_method)
cave_lobby_on_host :: proc(self: ^CaveLobby) {
	if self.running {return}
	if !gd.host(self.owner, port()) {
		kui.lobby_set_status(&self.ui, "Could not host (port taken?)")
		gd.print_str("CAVE_HOST_FAIL")
		return
	}
	if netgd.listen_packets(self.owner, "on_packet") != .Ok {return}
	self.ses.send = session_send
	self.ses.send_user = self
	ksess.session_host_start(&self.ses, my_name())
	self.running = true
	kui.lobby_show_menu(&self.ui, false, false)
	kui.lobby_set_status(&self.ui, fmt.ctprintf("Hosting on :%d — waiting for friends", port()))
	kui.lobby_refresh(&self.ui, &self.ses)
	gd.print_str("CAVE_HOSTING")
}

@(gd_method)
cave_lobby_on_join :: proc(self: ^CaveLobby) {
	if self.running {return}
	if !gd.join(self.owner, "127.0.0.1", port()) {
		kui.lobby_set_status(&self.ui, "Could not start joining")
		return
	}
	if netgd.listen_packets(self.owner, "on_packet") != .Ok {return}
	self.ses.send = session_send
	self.ses.send_user = self
	ksess.session_client_start(&self.ses, my_token(), my_name())
	self.running = true
	kui.lobby_show_menu(&self.ui, false, false)
	kui.lobby_set_status(&self.ui, "Joining the cave...")
	gd.print_str("CAVE_JOINING")
}

@(private = "file")
roster_changed :: proc(self: ^CaveLobby) {
	n := ksess.session_count(&self.ses, connected_only = true)
	gd.print_str(fmt.tprintf("CAVE_PLAYERS n=%d", n))
	if self.ses.is_host {
		kui.lobby_set_status(&self.ui, fmt.ctprintf("%d spelunkers ready", n))
		// Enough friends: the host may start (phase 3 gives Start a game).
		kui.lobby_show_menu(&self.ui, false, n >= 2)
	}
}

cave_lobby_process :: proc(self: ^CaveLobby, delta: f64) {
	if !self.running {return}

	// Client: seat ourselves as soon as the transport handshake completes.
	if !self.ses.is_host && !self.join_sent {
		mp := gd.node_get_multiplayer(self.owner)
		if cast(rawptr)mp != nil && gd.multiplayer_api_has_multiplayer_peer(mp) {
			peers := gd.multiplayer_api_get_peers(mp)
			if gd.packed_int32_array_size(&peers) > 0 {
				ksess.session_client_join(&self.ses)
				self.join_sent = true
			}
		}
	}

	_, _ = ksess.session_tick(&self.ses, delta, now_s())

	refresh := false
	for {
		ev, ok := ksess.session_poll(&self.ses)
		if !ok {break}
		#partial switch e in ev {
		case ksess.Ev_Welcomed:
			kui.lobby_set_status(&self.ui, "In the cave — waiting for the host to start")
			gd.print_str(fmt.tprintf("CAVE_SEATED me=%d", u64(e.me)))
			refresh = true
		case ksess.Ev_Player_Joined:
			roster_changed(self)
			refresh = true
		case ksess.Ev_Player_Left:
			roster_changed(self)
			refresh = true
		case ksess.Ev_Stats_Updated:
			refresh = true // ping column repaint
		case ksess.Ev_Host_Left:
			kui.lobby_set_status(&self.ui, "The host left — this run is over")
			gd.print_str("CAVE_HOST_LEFT")
		}
	}
	if refresh {
		kui.lobby_refresh(&self.ui, &self.ses)
	}
}

@(gd_method)
cave_lobby_on_packet :: proc(self: ^CaveLobby, id: gd.Int, packet: gd.Packed_Byte_Array) {
	packet := packet
	r := knet.reader_make(netgd.pba_view(&packet))
	if knet.read_u8(&r) == MSG_SESSION {
		ksess.session_handle_packet(&self.ses, int(id), &r)
	}
}

// ---- test driver polls ----

@(gd_method)
cave_lobby_get_players :: proc(self: ^CaveLobby) -> gd.Int {
	return gd.Int(ksess.session_count(&self.ses, connected_only = true))
}

@(gd_method)
cave_lobby_is_seated :: proc(self: ^CaveLobby) -> gd.Bool {
	return gd.Bool(self.ses.joined)
}
