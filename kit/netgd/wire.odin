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
	if on_peer_left != "" {
		gd.connect_to(cast(gd.Object)mp, "peer_disconnected", obj, on_peer_left)
	}
	if on_net_up != "" {
		gd.connect_to(cast(gd.Object)mp, "connected_to_server", obj, on_net_up)
	}
	if on_net_down != "" {
		gd.connect_to(cast(gd.Object)mp, "connection_failed", obj, on_net_down)
		gd.connect_to(cast(gd.Object)mp, "server_disconnected", obj, on_net_down)
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
		if wire.dropping[i].due <= knet.now_s() {
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