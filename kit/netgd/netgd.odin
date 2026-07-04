package kit_netgd

// kit/netgd — the engine-facing half of the toolkit's networking (kit/net is the
// pure core; THIS file is the only place the wire model touches Godot).
//
// Transport strategy: ride the engine's SceneMultiplayer raw-bytes path
// (`send_bytes` out, the `peer_packet` signal in) on top of whatever
// MultiplayerPeer the game installed — the existing ergonomic wrappers
// (gd.host/gd.join for ENet, gd.webrtc_host/webrtc_join for browser room codes)
// already handle peer creation, so the toolkit works over every transport those
// support, and Steam later slots in the same way. Riding SceneMultiplayer (rather
// than owning the peer and polling it) keeps @(gd_rpc) and the engine's
// spawner/synchronizer interop working alongside the toolkit.
//
// CHANNEL PLAN (see the design doc's wire model):
//   channel 0 — untouched: the engine's own RPC/replication traffic.
//   CHANNEL_RELIABLE — commands, results, transitions, chat, join snapshots
//                      (send RELIABLE: discrete + rare, loss story = none needed).
//   CHANNEL_STREAM   — owner-authoritative state snapshots (send
//                      UNRELIABLE_ORDERED: last-value semantics, a drop is
//                      superseded by the next tick's snapshot).
//
// State ownership rule (same as the events package): NO package globals — a
// session's transport state lives in the owning SCRIPT's struct. These procs are
// stateless sugar.

import gd "godot:godot"
import "godot:gdext"
import "core:mem"

CHANNEL_RELIABLE :: 1
CHANNEL_STREAM :: 2

// Transfer-mode aliases so call sites read as intent, not enum spelunking.
RELIABLE :: gd.Multiplayer_Peer_Transfer_Mode.Transfer_Mode_Reliable
UNRELIABLE_ORDERED :: gd.Multiplayer_Peer_Transfer_Mode.Transfer_Mode_Unreliable_Ordered

// Send raw bytes to `peer` (0 = broadcast to all peers, >0 = that peer only,
// <0 = everyone except -peer — engine semantics). The bytes are copied into the
// engine packet; the caller's buffer is untouched and reusable immediately.
send_to :: proc "contextless" (
	node: gd.Node,
	peer: int,
	bytes: []u8,
	mode: gd.Multiplayer_Peer_Transfer_Mode,
	channel: int,
) -> gd.Error {
	mp := gd.node_get_multiplayer(node)
	if cast(rawptr)mp == nil {return .Failed}
	// The default MultiplayerAPI implementation IS SceneMultiplayer; a project
	// that swapped in a custom MultiplayerAPIExtension is outside the toolkit's
	// support (documented), so this cast is the supported path.
	sm := cast(gd.Scene_Multiplayer)mp

	pba := gd.new_packed_byte_array()
	defer gd.free_packed_byte_array(pba)
	if len(bytes) > 0 {
		gd.packed_byte_array_resize(&pba, gd.Int(len(bytes)))
		dst := gdext.packed_byte_array_operator_index(cast(gdext.TypePtr)&pba, 0)
		mem.copy(dst, raw_data(bytes), len(bytes))
	}
	return gd.scene_multiplayer_send_bytes(sm, pba, gd.Int(peer), mode, gd.Int(channel))
}

// Reliable-channel convenience (commands/transitions/chat/snapshots).
send_reliable :: proc "contextless" (node: gd.Node, peer: int, bytes: []u8) -> gd.Error {
	return send_to(node, peer, bytes, RELIABLE, CHANNEL_RELIABLE)
}

// Stream-channel convenience (owner-authoritative per-tick snapshots).
send_stream :: proc "contextless" (node: gd.Node, peer: int, bytes: []u8) -> gd.Error {
	return send_to(node, peer, bytes, UNRELIABLE_ORDERED, CHANNEL_STREAM)
}

// Wire `node`'s SceneMultiplayer `peer_packet(id, packet)` signal to `method` —
// an @(gd_method) on the SAME node's script:
//
//     @(gd_method)
//     session_on_packet :: proc(self: ^Session, id: gd.Int, packet: gd.Packed_Byte_Array) {
//         r := knet.reader_make(netgd.pba_view(&packet))
//         ...
//     }
//
// Call it once, after the node is inside the tree (get_multiplayer needs that).
listen_packets :: proc "contextless" (node: gd.Node, method: cstring) -> gd.Error {
	mp := gd.node_get_multiplayer(node)
	if cast(rawptr)mp == nil {return .Failed}
	return gd.connect_to(cast(gd.Object)mp, "peer_packet", cast(gd.Object)node, method)
}

// Zero-copy view of a Packed_Byte_Array's contents — valid only while `pba` is
// alive (i.e. inside the receiving method call). Feed it to knet.reader_make;
// clone anything you keep.
pba_view :: proc "contextless" (pba: ^gd.Packed_Byte_Array) -> []u8 {
	n := int(gd.packed_byte_array_size(pba))
	if n == 0 {return nil}
	p := gdext.packed_byte_array_operator_index_const(cast(gdext.TypePtr)pba, 0)
	return ([^]u8)(p)[:n]
}
