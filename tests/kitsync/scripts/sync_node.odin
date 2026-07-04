//gd:extends Node
//gd:class SyncNode
package kitsync_scripts

// ----------------------------------------------------------------------------
// SyncNode — the SUBJECT of the two-peer kit/net sync test (tests/kitsync): the
// first real wire crossing of the friendslop toolkit. Two headless Godot
// processes connect over ENet localhost; the SERVER mutates gd:"replicate"
// fields and ships a FULL snapshot then a DELTA via kit/netgd; the CLIENT
// applies both with kit/net and prints verified sentinels.
//
// This is the whole stack in one test: gd:"replicate" tag -> scriptgen's
// generated sync_node_net_desc -> shadow diff -> wire bytes ->
// SceneMultiplayer.send_bytes -> ENet -> peer_packet -> apply -> field values.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import knet "godot:kit/net"
import netgd "godot:kit/netgd"
import "core:fmt"

SyncNode :: struct {
	owner:  gd.Node,
	hp:     i32 `gd:"replicate"`,
	x, y:   f32 `gd:"replicate,interp,owner"`,
	state:  u8 `gd:"replicate"`,
	shadow: []u8,
	got:    int, // client: verified packets so far (driver polls via get_got)
}

MSG_FULL :: u8(0)
MSG_DELTA :: u8(1)

sync_node_ready :: proc(self: ^SyncNode) {
	self.shadow = knet.shadow_make(&sync_node_net_desc)
}

@(gd_method)
sync_node_start_host :: proc(self: ^SyncNode, port: gd.Int) {
	gd.print_str(gd.host(self.owner, int(port)) ? "HOST_OK" : "HOST_FAIL")
}

@(gd_method)
sync_node_start_client :: proc(self: ^SyncNode, port: gd.Int) {
	if !gd.join(self.owner, "127.0.0.1", int(port)) {
		gd.print_str("JOIN_FAIL")
		return
	}
	if err := netgd.listen_packets(self.owner, "on_packet"); err != .Ok {
		gd.print_str(fmt.tprintf("LISTEN_FAIL err=%v", err))
		return
	}
	gd.print_str("JOIN_OK")
}

// SERVER: first send after the client connects — a join-snapshot-shaped FULL.
@(gd_method)
sync_node_send_full :: proc(self: ^SyncNode, peer: gd.Int) {
	self.hp = 42
	self.x = 3.5
	self.y = -1.25
	self.state = 7

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, MSG_FULL)
	knet.write_full(&w, self, &sync_node_net_desc)
	// Commit the shadow so the NEXT send diffs against what the client now has.
	knet.shadow_capture(self, self.shadow, &sync_node_net_desc)

	err := netgd.send_reliable(self.owner, int(peer), knet.writer_bytes(&w))
	gd.print_str(err == .Ok ? "SYNC_SENT_FULL" : fmt.tprintf("SYNC_SEND_FAIL err=%v", err))
}

// SERVER: mutate a SUBSET of fields — the delta must carry exactly those.
@(gd_method)
sync_node_send_delta :: proc(self: ^SyncNode, peer: gd.Int) {
	self.hp = 43 // field 0
	self.x = 4.0 // field 1;  y (2) and state (3) untouched

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, MSG_DELTA)
	mask := knet.write_delta(&w, self, self.shadow, &sync_node_net_desc)

	err := netgd.send_reliable(self.owner, int(peer), knet.writer_bytes(&w))
	if err == .Ok {
		gd.print_str(fmt.tprintf("SYNC_SENT_DELTA mask=%d", mask))
	} else {
		gd.print_str(fmt.tprintf("SYNC_SEND_FAIL err=%v", err))
	}
}

// CLIENT: every toolkit packet lands here (wired by netgd.listen_packets).
@(gd_method)
sync_node_on_packet :: proc(self: ^SyncNode, id: gd.Int, packet: gd.Packed_Byte_Array) {
	packet := packet
	r := knet.reader_make(netgd.pba_view(&packet))
	msg := knet.read_u8(&r)
	switch msg {
	case MSG_FULL:
		knet.apply_full(&r, self, &sync_node_net_desc)
		ok := !r.err && self.hp == 42 && self.x == 3.5 && self.y == -1.25 && self.state == 7
		gd.print_str(fmt.tprintf("SYNC_GOT_FULL ok=%v hp=%d x=%v y=%v state=%d from=%d", ok, self.hp, self.x, self.y, self.state, i64(id)))
		if ok {self.got += 1}
	case MSG_DELTA:
		mask := knet.apply_delta(&r, self, &sync_node_net_desc)
		// hp + x changed; y and state must have survived untouched.
		ok := !r.err && mask == 0b0011 && self.hp == 43 && self.x == 4.0 && self.y == -1.25 && self.state == 7
		gd.print_str(fmt.tprintf("SYNC_GOT_DELTA ok=%v mask=%d hp=%d x=%v", ok, mask, self.hp, self.x))
		if ok {self.got += 1}
	case:
		gd.print_str(fmt.tprintf("SYNC_GOT_UNKNOWN msg=%d", msg))
	}
}

// Driver poll: how many packets arrived AND verified.
@(gd_method)
sync_node_get_got :: proc(self: ^SyncNode) -> gd.Int {
	return gd.Int(self.got)
}
