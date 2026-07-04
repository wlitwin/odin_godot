//gd:extends Node
//gd:class SyncNode
package kitsync_scripts

// ----------------------------------------------------------------------------
// SyncNode — the SUBJECT of the two-peer kit/net sync test (tests/kitsync). Two
// headless Godot processes connect over ENet localhost and prove the whole
// friendslop replication stack:
//
//   PART 1 (state): the SERVER mutates gd:"replicate" fields and ships a FULL
//   snapshot then a DELTA via kit/netgd; the CLIENT applies both with kit/net
//   and prints verified sentinels.
//
//   PART 2 (commands): the CLIENT issues the `bump` @(gd_command="predict")
//   through its generated `sync_node_bump_cmd` wrapper — predicted locally,
//   shipped to the host, executed authoritatively, CONFIRMED (prediction
//   stands, pending drains). Then the server silently flips `locked` (no delta
//   — the client is now stale), the client issues bump again: predicted
//   locally, REJECTED by the host, and the reject's embedded truth snapshot
//   snaps the client back (hp reverts, locked becomes visible, pending drains).
//
// The author surface for part 2 is `sync_node_bump` — single-player-looking
// mutation, ZERO role branches — plus one `_cmd` wrapper call. Everything else
// (prediction, revert, dedup, truth) is the toolkit.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import knet "godot:kit/net"
import netgd "godot:kit/netgd"
import "core:fmt"

SyncNode :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     i32 `gd:"replicate"`,
	x, y:   f32 `gd:"replicate,interp"`, // host-authoritative here (owner streams are kitacid's)
	state:  u8 `gd:"replicate"`,
	locked: u8 `gd:"replicate"`, // server flips this SILENTLY to force a stale prediction
	shadow: []u8,
	ctx:    knet.Command_Ctx,
	got:    int, // client: verified packets/results so far (driver polls via get_got)
	cmds:   int, // server: commands executed so far (driver polls via get_cmds)
}

MSG_FULL :: u8(0)
MSG_DELTA :: u8(1)
MSG_CMD :: u8(2)
MSG_RESULT :: u8(3)

sync_node_ready :: proc(self: ^SyncNode) {
	self.shadow = knet.shadow_make(&sync_node_net_desc)
	self.ctx = knet.command_ctx_make()
	self.net_id = knet.Net_Id(1) // single test entity; the registry layer will assign these
}

// THE command under test: single-player-looking mutation, zero role branches.
// Predicted on the issuing client, authoritative on the host — same proc.
@(gd_command = "predict")
sync_node_bump :: proc(self: ^SyncNode, amount: i32) -> bool {
	if self.locked != 0 {return false}
	self.hp += amount
	return true
}

@(gd_method)
sync_node_start_host :: proc(self: ^SyncNode, port: gd.Int) {
	if !gd.host(self.owner, int(port)) {
		gd.print_str("HOST_FAIL")
		return
	}
	self.ctx.is_authority = true
	// The host receives commands on the same raw-bytes path the client uses.
	if err := netgd.listen_packets(self.owner, "on_packet"); err != .Ok {
		gd.print_str(fmt.tprintf("LISTEN_FAIL err=%v", err))
		return
	}
	gd.print_str("HOST_OK")
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
	self.ctx.send = send_command_bytes
	self.ctx.send_user = self
	gd.print_str("JOIN_OK")
}

// The session-layer glue the toolkit's ctx delegates sending to: frame the raw
// command bytes with the message kind and ship them to the host (peer 1).
@(private = "file")
send_command_bytes :: proc(user: rawptr, bytes: []u8) {
	self := cast(^SyncNode)user
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, MSG_CMD)
	append(&w.buf, ..bytes)
	if err := netgd.send_reliable(self.owner, 1, knet.writer_bytes(&w)); err != .Ok {
		gd.print_str(fmt.tprintf("SYNC_CMD_SEND_FAIL err=%v", err))
	}
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
	self.x = 4.0 // field 1;  y (2), state (3), locked (4) untouched

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

// CLIENT: issue the predicted bump through the GENERATED wrapper — the one call
// that is identical on every peer.
@(gd_method)
sync_node_issue_bump :: proc(self: ^SyncNode) {
	applied := sync_node_bump_cmd(&self.ctx, self, 5)
	gd.print_str(
		fmt.tprintf(
			"SYNC_CMD_ISSUED predicted=%v hp=%d pending=%d",
			applied,
			self.hp,
			knet.pending_count(&self.ctx.pending),
		),
	)
}

// Every toolkit packet (both roles) lands here, wired by netgd.listen_packets.
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
	case MSG_CMD:
		// HOST: dedup → execute (auto-restores on rejection) → result (reject
		// embeds the authoritative truth snapshot).
		h := knet.command_read_header(&r)
		if !knet.command_dedup(&self.ctx, u64(id), h.seq) {
			gd.print_str(fmt.tprintf("SYNC_CMD_DUP seq=%d", u32(h.seq)))
			return
		}
		ok := knet.command_execute(self, &sync_node_command_set, h.cmd, &r)
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, MSG_RESULT)
		knet.command_result_write(&w, h, ok, self, &sync_node_command_set)
		_ = netgd.send_reliable(self.owner, int(id), knet.writer_bytes(&w))
		gd.print_str(fmt.tprintf("SYNC_CMD_EXEC ok=%v hp=%d", ok, self.hp))
		self.cmds += 1
		if self.cmds == 1 {
			// Diverge SILENTLY (no delta): the client's next prediction runs
			// against stale state and must be rejected — with truth attached.
			self.locked = 1
		}
	case MSG_RESULT:
		res := knet.command_result_read(&r)
		if res.ok {
			knet.command_confirm(&self.ctx, res.seq)
			ok := self.hp == 48 && knet.pending_count(&self.ctx.pending) == 0
			gd.print_str(fmt.tprintf("SYNC_CMD_CONFIRM ok=%v hp=%d pending=%d", ok, self.hp, knet.pending_count(&self.ctx.pending)))
			if ok {self.got += 1}
		} else {
			// res.entity names the entity; this test has exactly one.
			knet.command_reject(&self.ctx, res, &r, self, &sync_node_command_set)
			ok := !r.err && self.hp == 48 && self.locked == 1 && knet.pending_count(&self.ctx.pending) == 0
			gd.print_str(fmt.tprintf("SYNC_CMD_REJECT ok=%v hp=%d locked=%d pending=%d", ok, self.hp, self.locked, knet.pending_count(&self.ctx.pending)))
			if ok {self.got += 1}
		}
	case:
		gd.print_str(fmt.tprintf("SYNC_GOT_UNKNOWN msg=%d", msg))
	}
}

// Driver polls: client progress / server command count.
@(gd_method)
sync_node_get_got :: proc(self: ^SyncNode) -> gd.Int {
	return gd.Int(self.got)
}

@(gd_method)
sync_node_get_cmds :: proc(self: ^SyncNode) -> gd.Int {
	return gd.Int(self.cmds)
}
