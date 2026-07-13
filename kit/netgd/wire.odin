package kit_netgd

// The SESSION transport binding — the ~50 lines every game used to write by
// hand: the Send_Proc adapter (kind byte + channel pick), the packet route,
// the engine's connection signals, and the client's join handshake. Godot
// signals must land on @(gd_method)s of a script (scriptgen only processes
// game scripts), so the game keeps four ONE-LINE methods; this file owns
// everything behind them:
//
//     wire: netgd.Session_Wire   // a field on the game's script struct
//
//     // ready():
//     netgd.wire_attach(&self.wire, self.owner, &self.ses, MSG_GAME)
//     netgd.wire_listen(&self.wire, "on_packet", "on_peer_left", "on_net_up", "on_net_down")
//
//     // the four forwards:
//     on_packet(id, packet)  -> netgd.wire_receive(&self.wire, id, packet)
//     on_peer_left(id)       -> ksess.session_peer_disconnected(&self.ses, ksess.Peer_Id(id))
//     on_net_up()            -> ksess.session_client_join(&self.ses)
//     on_net_down()          -> ksess.session_peer_disconnected(&self.ses, ksess.HOST_PEER)
//
//     // process():
//     netgd.wire_pump(&self.wire, now)
//
// The disconnect signals are NOT optional plumbing: without them an alt-F4'd
// client haunts the roster forever and a failed join hangs on "Joining...".

import gd "godot:godot"
import "godot:gdext"
import knet "godot:kit/net"
import ksess "godot:kit/session"

// One session's transport binding. Lives in the game's script struct (no
// package globals); `latency` is the built-in acid-test shim — see
// wire_set_latency.
Session_Wire :: struct {
	node:     gd.Node,
	ses:      ^ksess.Session,
	kind:     u8, // the game's one message byte for session traffic
	latency:  f64, // injected one-way receive delay, seconds (0 = off)
	delayed:  [dynamic]Wire_Delayed,
	dropping: [dynamic]Wire_Drop, // sockets scheduled to close (kicks)
}

Wire_Delayed :: struct {
	due:  f64,
	from: ksess.Peer_Id,
	data: []u8,
}

Wire_Drop :: struct {
	due:  f64,
	peer: ksess.Peer_Id,
}

// Install the session's Send_Proc (kind byte + reliable/stream channel pick).
// Survives session_host_start / session_client_start / session_host_resume —
// call once in ready().
wire_attach :: proc(wire: ^Session_Wire, node: gd.Node, ses: ^ksess.Session, kind: u8) {
	wire.node = node
	wire.ses = ses
	wire.kind = kind
	ksess.session_set_transport(ses, wire, wire_send)
	// WEB: core:time is stuck inside the wasm module — every knet pacer and
	// ticker freezes on it. Swap the toolkit clock for the engine's before
	// anything reads it (native keeps the core:time path untouched).
	when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
		knet.set_clock(web_clock)
	}
}

when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
	@(private = "file")
	web_clock :: proc "contextless" () -> f64 {
		return f64(gd.time_get_ticks_usec(gd.singleton_time())) / 1e6
	}
}

@(private = "file")
wire_send :: proc(user: rawptr, to_peer: ksess.Peer_Id, bytes: []u8, channel: ksess.Channel) {
	wire := cast(^Session_Wire)user
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, wire.kind)
	append(&w.buf, ..bytes)
	if channel == .Stream {
		_ = send_stream(wire.node, int(to_peer), knet.writer_bytes(&w))
	} else {
		_ = send_reliable(wire.node, int(to_peer), knet.writer_bytes(&w))
	}
}

// Connect the engine's transport signals to the game's four forwarding
// @(gd_method)s (see the header). Empty method names skip that signal.
// Call after the node is in the tree (ready() qualifies).
wire_listen :: proc "contextless" (
	wire: ^Session_Wire,
	on_packet: cstring,
	on_peer_left: cstring = "",
	on_net_up: cstring = "",
	on_net_down: cstring = "",
) -> gd.Error {
	mp := gd.node_get_multiplayer(wire.node)
	if cast(rawptr)mp == nil {return .Failed}
	obj := cast(gd.Object)wire.node
	if err := gd.connect_to(cast(gd.Object)mp, "peer_packet", obj, on_packet); err != .Ok {
		return err
	}
	// The optional signals propagate failures too: a typo'd method name that
	// failed silently here produces exactly the bug this file's header warns
	// about — an unwired peer_disconnected means ghosts haunt rosters forever.
	if on_peer_left != "" {
		if err := gd.connect_to(cast(gd.Object)mp, "peer_disconnected", obj, on_peer_left); err != .Ok {
			return err
		}
	}
	if on_net_up != "" {
		if err := gd.connect_to(cast(gd.Object)mp, "connected_to_server", obj, on_net_up); err != .Ok {
			return err
		}
	}
	if on_net_down != "" {
		if err := gd.connect_to(cast(gd.Object)mp, "connection_failed", obj, on_net_down); err != .Ok {
			return err
		}
		if err := gd.connect_to(cast(gd.Object)mp, "server_disconnected", obj, on_net_down); err != .Ok {
			return err
		}
	}
	return .Ok
}

// Route one received packet: strip the kind byte (other kinds are not ours —
// the game routes those itself before calling this) and hand the rest to the
// session; with a latency shim active, buffer instead and wire_pump delivers.
wire_receive :: proc(wire: ^Session_Wire, id: gd.Int, packet: gd.Packed_Byte_Array) {
	packet := packet
	view := pba_view(&packet)
	if len(view) == 0 || view[0] != wire.kind {
		return
	}
	if wire.latency > 0 {
		data := make([]u8, len(view) - 1)
		copy(data, view[1:])
		append(&wire.delayed, Wire_Delayed{due = knet.now_s() + wire.latency, from = ksess.Peer_Id(id), data = data})
		return
	}
	r := knet.reader_make(view[1:])
	ksess.session_handle_packet(wire.ses, ksess.Peer_Id(id), &r)
}

// Per-frame: deliver latency-shimmed packets whose time has come, and close
// any sockets a kick scheduled. (Without a shim or a pending kick this is a
// no-op — still call it; the shim is how you acid-test YOUR game's feel
// under real round trips: netgd.wire_set_latency(&wire, 120).)
wire_pump :: proc(wire: ^Session_Wire, now: f64) {
	for len(wire.delayed) > 0 && wire.delayed[0].due <= now {
		pkt := wire.delayed[0]
		ordered_remove(&wire.delayed, 0)
		r := knet.reader_make(pkt.data)
		ksess.session_handle_packet(wire.ses, pkt.from, &r)
		delete(pkt.data)
	}
	for i := 0; i < len(wire.dropping); {
		if wire.dropping[i].due <= now { // one clock rules the pump
			drop_peer(wire.node, wire.dropping[i].peer)
			unordered_remove(&wire.dropping, i)
			continue
		}
		i += 1
	}
}

// Schedule a kicked peer's socket to close shortly — the second half of a
// kick (session_kick unseats and returns the seat; this severs it). DEFERRED
// on purpose: an immediate ENet disconnect races its own outgoing queue and
// the SES_KICKED the session just sent is discarded — the kicked player then
// sees a mystery host-crash instead of the truth. The delay lets the
// reliable queue flush and ack; the session already ignores the unseated
// peer, so nothing it sends in the gap matters.
wire_drop :: proc(wire: ^Session_Wire, peer: ksess.Peer_Id, after := 0.75) {
	append(&wire.dropping, Wire_Drop{due = knet.now_s() + after, peer = peer})
}

// Inject one-way receive latency (milliseconds; 0 disables). Every packet
// this peer RECEIVES is held that long before the session sees it — the
// toolkit's own acid tests run at 120ms so predictions are proven to bite
// instantly while confirms measurably ride the slow wire. Test your game
// the same way.
wire_set_latency :: proc(wire: ^Session_Wire, ms: int) {
	wire.latency = f64(ms) / 1000.0
}

// A connected peer's remote address as the HOST sees it — the rendezvous
// info for live migration over ENet (session Ev_Backup_Target -> read the
// designated holder's address -> session_set_successor_info). Same-subnet
// truth only: across NAT the address the host sees may not be reachable by
// the other peers (Steam and room-code transports don't have this problem —
// their rendezvous blobs are lobby ids). ok=false off-ENet or unknown peer.
peer_address :: proc(node: gd.Node, peer: ksess.Peer_Id, allocator := context.temp_allocator) -> (addr: string, ok: bool) {
	mp := gd.node_get_multiplayer(node)
	if cast(rawptr)mp == nil {return "", false}
	p := gd.multiplayer_api_get_multiplayer_peer(mp)
	if cast(rawptr)p == nil {return "", false}
	if !bool(gd.object_is_class(cast(gd.Object)p, gd.gstr("ENetMultiplayerPeer"))) {return "", false}
	pkt := gd.e_net_multiplayer_peer_get_peer(cast(gd.E_Net_Multiplayer_Peer)p, gd.Int(peer))
	if cast(rawptr)pkt == nil {return "", false}
	gs := gd.e_net_packet_peer_get_remote_address(pkt)
	defer gd.free_string(gs)
	buf: [64]u8
	n := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&gs, cast(cstring)&buf[0], len(buf) - 1)
	if n <= 0 {return "", false}
	out := make([]u8, min(int(n), len(buf) - 1), allocator)
	copy(out, buf[:len(out)])
	return string(out), true
}

// Sever a peer's transport connection — the second half of a kick:
// session_kick unseats the player and returns the seat; this closes its
// socket so the kicked client can't keep talking (the session would ignore
// it, but the wire shouldn't hum). GRACEFUL (force=false) on purpose: the
// SES_KICKED message the session just queued must flush before the socket
// dies, or the kicked player sees a mystery host-crash instead of the truth.
drop_peer :: proc "contextless" (node: gd.Node, peer: ksess.Peer_Id) {
	mp := gd.node_get_multiplayer(node)
	if cast(rawptr)mp == nil {return}
	p := gd.multiplayer_api_get_multiplayer_peer(mp)
	if cast(rawptr)p == nil {return}
	gd.multiplayer_peer_disconnect_peer(p, gd.Int(peer), false)
}
// ---- the two buttons, minus the ceremony ---------------------------------------
//
// Every game's Host/Join handlers repeat the same two-step: bring the
// transport up, then start the session over it. The UI around them (status
// lines, menu hiding) stays the game's — or use kit/boot, which wraps these
// with the stock lobby ritual.

// Host on `port`. false = the transport refused (port taken) — the session
// was NOT started; tell the player and let them try again. `token` is the
// host's own reconnect identity (see session_host_start) — pass it so a
// dead host can reclaim its seat from whoever resumes the run. `dedicated`
// makes this authority a SERVER, not a player (see session_host_start).
begin_host :: proc(wire: ^Session_Wire, port: int, name: string, max_peers := 32, token: u64 = 0, dedicated := false) -> bool {
	if !gd.host(wire.node, port, max_peers) {
		return false
	}
	ksess.session_host_start(wire.ses, name, token, dedicated)
	return true
}

// Join `addr:port` as `token`/`name`. false = the transport refused outright;
// an unreachable host surfaces later as Ev_Join_Failed (the join timeout).
begin_join :: proc(wire: ^Session_Wire, addr: cstring, port: int, token: u64, name: string) -> bool {
	if !gd.join(wire.node, addr, port) {
		return false
	}
	ksess.session_client_start(wire.ses, token, name)
	return true
}

// ---- the same two buttons, WebRTC flavor -----------------------------------------------
//
// Browser co-op pairs through a ROOM CODE brokered by a signaling relay
// instead of an address the joiner already knows — and the code is ASSIGNED
// by the relay after the host connects, so it arrives async (read it back
// with gd.webrtc_room_code once web_poll has pumped the handshake). The
// session layer neither knows nor cares: once the data channel installs the
// multiplayer peer, everything above these calls is the ENet path verbatim.

// Host a room on the relay at `url` and start the session AT ONCE —
// authoritative from the first tick; peers drop in when their channel comes
// up. `token` is the host's reconnect identity, exactly as in begin_host.
begin_host_web :: proc(wire: ^Session_Wire, url: cstring, name: string, token: u64 = 0, room: cstring = "") -> bool {
	if !gd.webrtc_host(wire.node, url, room) {
		return false
	}
	ksess.session_host_start(wire.ses, name, token)
	return true
}

// Join `room` (the code the host shared) through the relay at `url`.
begin_join_web :: proc(wire: ^Session_Wire, url: cstring, room: cstring, token: u64, name: string) -> bool {
	if !gd.webrtc_join(wire.node, url, room) {
		return false
	}
	ksess.session_client_start(wire.ses, token, name)
	return true
}

// Pump the signaling handshake — every frame while a web session lives (the
// data channel itself is engine-polled; this services the relay socket).
web_poll :: proc(wire: ^Session_Wire) {
	gd.webrtc_poll(wire.node)
}

// Tear a web session down COMPLETELY so a fresh begin_*_web can start clean
// — the retry after a failed join, or a successor raising a new room.
web_close :: proc(wire: ^Session_Wire) {
	gd.webrtc_close(wire.node)
}
