//gd:extends Node
//gd:class ReplayServiceProbe
package authority_service_probe

import "core:fmt"
import "core:reflect"
import "core:crypto/hmac"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import auth "godot:replay/authority"
import db "godot:replay/authority/sqlite"
import tr "godot:replay/transport"
import sample "godot:tests/replay_recovery/shared/archive"
import transportgd "godot:replay/godot/transport"

OWNER :: auth.Identity{1, 101}
SUCCESSOR :: auth.Identity{2, 102}
ROOM :: u64(44)
Phase :: enum {Start, Nominate, Transfer, Await_Prepared, Release, Await_Claim, Observe, Prepare, Claim, Running, Recover, Done}

ReplayServiceProbe :: struct {
	owner: gd.Node,
	coordinator_role, owner_role, ready: bool,
	phase: Phase,
	clock: auth.Clock_Source,
	store: db.Store,
	service: auth.Service,
	lease: auth.Lease,
	rpc: auth.Rpc_Client,
	control, data: transportgd.Enet,
	control_wire, data_wire: tr.Transport,
	sender: rec.Sender,
	receiver: rec.Receiver(sample.World, sample.Control, sample.Action, sample.Event, sample.SEATS),
	codec: net.Checkpoint_Codec,
	prepared: auth.Prepared,
	server: net.Server(sample.World, sample.Control, sample.Action, sample.Event, sample.SEATS),
	retired: auth.Retirement,
	final_point: auth.Point,
	game_clock: r.Clock,
	started, last_rpc, last_reply, last_hello, last_data_hello, frozen_tick: u64,
	port: u16,
}

replay_service_probe_ready :: proc(self: ^ReplayServiceProbe) {
	self.clock = auth.native_clock()
	now, ok := self.clock.read(self.clock.user)
	if !ok {fail(self, "clock"); return}
	self.started = now
	role := gd.env_string("REPLAY_SERVICE_ROLE", "coordinator")
	self.coordinator_role, self.owner_role = role == "coordinator", role == "owner"
	port := gd.env_int("REPLAY_SERVICE_PORT", 49450)
	if port < 1 || port > 65000 {fail(self, "port"); return}
	self.port = u16(port)
	keys := [2]auth.Credential{{OWNER, {0 = 21}}, {SUCCESSOR, {0 = 22}}} // fixture keys only
	if self.coordinator_role {
		path := gd.env_string("REPLAY_SERVICE_DB", "")
		create := gd.env_int("REPLAY_SERVICE_CREATE", 0) == 1
		if db.open(&self.store, path, create) != .None {fail(self, "store open"); return}
		record, found, err := db.load(&self.store, ROOM, sample.CONTENT)
		if err != .None || (!found && !create) {fail(self, "store load"); return}
		if !found {
			policy := auth.DEFAULT_POLICY; policy.lease_ms = 5000
			record = auth.record_make(ROOM, sample.CONTENT, OWNER, policy)
			for key, i in keys {
				address, _ := auth.endpoint("127.0.0.1", u16(port + i + 1))
				record.members[i] = {identity = key.identity, endpoint = address, enabled = true, can_host = true, trusted_authority = true}
			}
		}
		if !transportgd.enet_host(&self.control, self.port, 8, bind_ip = "127.0.0.1") {fail(self, "service socket"); return}
		self.control_wire = transportgd.enet_transport(&self.control)
		if auth.service_init(&self.service, record, db.commit, &self.store, self.clock, self.control_wire, keys[:]) != .None {fail(self, "service init"); return}
		gd.print_str(fmt.tprintf("REPLAY_SERVICE_READY generation=%d epoch=%d", self.service.coordinator.record.coordinator_generation, self.service.coordinator.record.epoch))
	} else {
		identity := self.owner_role ? OWNER : SUCCESSOR
		auth.lease_init(&self.lease, identity, ROOM, sample.CONTENT, self.clock, self.owner_role)
		if !transportgd.enet_join(&self.control, "127.0.0.1", self.port) {fail(self, "control socket"); return}
		self.control_wire = transportgd.enet_transport(&self.control)
		nonce, generated := auth.rpc_nonce()
		if !generated || !auth.rpc_client_init(&self.rpc, &self.lease, keys[self.owner_role ? 0 : 1].key, nonce, self.control_wire) {fail(self, "client init"); return}
		self.phase = self.owner_role ? .Start : .Observe
		net.checkpoint_codec_init(&self.codec, sample.World, sample.Control, sample.Action, sample.Event, sample.SEATS)
	}
	self.ready = true
}

command :: proc(self: ^ReplayServiceProbe, command: auth.Command, now: u64) {
	if self.rpc.pending || now - self.last_rpc < 100 {return}
	if err := auth.rpc_begin(&self.rpc, command); err != .None {fail(self, fmt.tprintf("rpc begin %v", err)); return}
	self.last_rpc = now
}

replay_service_probe_process :: proc(self: ^ReplayServiceProbe, dt: f64) {
	if !self.ready {return}
	now, ok := self.clock.read(self.clock.user)
	if !ok || now - self.started > 45000 {fail(self, "timeout/clock"); return}
	if self.coordinator_role {
		if auth.service_pump(&self.service) != .None {fail(self, "service storage failure"); return}
		return
	}
	// The RPC wrapper and lease survive a coordinator connection replacement.
	// Reconnect the transport, retaining request bytes/sequence and the client nonce.
	if tr.status(&self.control_wire) == .Disconnected && now - self.last_hello > 300 {
		tr.close(&self.control_wire)
		if transportgd.enet_join(&self.control, "127.0.0.1", self.port) {
			self.control_wire = transportgd.enet_transport(&self.control); self.rpc.wire = self.control_wire
		}
		self.last_hello = now
	}
	if err := auth.rpc_client_pump(&self.rpc); err != .None && err != .Busy {fail(self, fmt.tprintf("rpc %v", err)); return}
	if reply, completed := auth.rpc_completed(&self.rpc); completed && reply.sequence != self.last_reply {
		self.last_reply = reply.sequence
		if reply.result != .None && reply.result != .Busy && reply.result != .Denied && reply.result != .Stale {fail(self, fmt.tprintf("reply %v", reply.result)); return}
		if reply.result == .None {
			#partial switch self.phase {
			case .Start:
				if reply.view.owner == OWNER && reply.view.epoch == 1 {
					if sample.authority(&self.server, auth.lease_permit(&self.lease)) != .None {fail(self, "source world"); return}
					if !transportgd.enet_host(&self.data, self.port + 1, 1, bind_ip = "127.0.0.1") {fail(self, "archive socket"); return}
					self.data_wire = transportgd.enet_transport(&self.data)
					self.phase = .Nominate
				}
			case .Nominate:
				if reply.nominee == SUCCESSOR && reply.binding == 9 {
					self.retired, _ = auth.lease_retire(&self.lease)
					self.frozen_tick = self.server.timeline.head
					self.phase = .Transfer
				}
			case .Await_Prepared:
				if reply.prepared && reply.point.archive == self.sender.acknowledged.archive {self.final_point = reply.point; self.phase = .Release}
			case .Release:
				if reply.released {self.phase = .Await_Claim}
			case .Observe:
				if reply.view.owner == OWNER && reply.view.epoch == 1 && !self.receiver.ready {
					if !transportgd.enet_join(&self.data, "127.0.0.1", self.port + 1) {fail(self, "archive join"); return}
					self.data_wire = transportgd.enet_transport(&self.data)
					if rec.receiver_init(&self.receiver, {ROOM, 1, 9, sample.CONTENT}, 1, self.data_wire, sample.model()) != .None {fail(self, "receiver"); return}
				}
			case .Prepare:
				if reply.prepared && reply.point == self.prepared.point {self.phase = .Claim}
			case .Claim:
				if reply.view.owner == SUCCESSOR && reply.view.epoch == 2 {
					self.lease.require_owner = true
					if auth.prepared_restore(&self.prepared, &self.server, sample.model(), {}, &self.lease, 0) != .None {fail(self, "planned restore"); return}
					frame, _ := r.current(&self.server.timeline)
					if frame.state.cave.players[0].bag[0].count != 3 || frame.state.cave.rocks.count != 1 {fail(self, "restored cave"); return}
					r.clock_init(&self.game_clock, self.server.cfg.hz)
					self.phase = .Running
					gd.print_str(fmt.tprintf("REPLAY_SERVICE_TRANSFER_READY epoch=2 tick=%d", frame.tick))
				}
			case .Recover:
				if reply.view.owner == SUCCESSOR && reply.view.epoch == 3 {
					net.server_destroy(&self.server)
					if auth.prepared_restore(&self.prepared, &self.server, sample.model(), {}, &self.lease, 0) != .None {fail(self, "restart restore"); return}
					if net.server_step(&self.server) != .None {fail(self, "continued simulation"); return}
					gd.print_str(fmt.tprintf("REPLAY_SERVICE_RESTART_OK epoch=3 generation=%d tick=%d", reply.view.coordinator_generation, self.server.timeline.head))
					self.ready = false; gd.scene_tree_quit(gd.get_tree(self.owner), 0); return
				}
			case: }
		}
	}
	if self.data.peer != nil {
		tr.poll(&self.data_wire)
		buffer: [tr.MAX_PACKET_BYTES]u8
		for _ in 0 ..< 64 {
			packet := tr.receive(&self.data_wire, buffer[:])
			if packet.state == .Empty || packet.state == .Disconnected {break}
			if packet.state != .Received {fail(self, "archive packet"); return}
			if self.owner_role {
				fixture_key := auth.Key{0 = 22}
				if !self.sender.ready && self.phase == .Transfer && packet.count == 48 && hmac.verify(.SHA256, buffer[16:48], buffer[:16], fixture_key[:]) {
					rec.sender_init(&self.sender, {ROOM, 1, 9, sample.CONTENT}, packet.from, self.data_wire)
					cp: sample.Checkpoint; defer net.checkpoint_destroy(&cp)
					net.checkpoint_capture(&self.server, &cp)
					if rec.sender_publish(&self.sender, &cp, sample.model(), now, &self.codec) != .None {fail(self, "publish"); return}
				} else if self.sender.ready {rec.sender_receive(&self.sender, packet.from, buffer[:packet.count], now)}
			} else {
				if rec.receiver_receive(&self.receiver, packet.from, buffer[:packet.count], now) == .Validated {
					if self.prepared.ready {continue}
					receipt, _ := rec.receiver_latest(&self.receiver)
					if auth.prepared_copy(&self.prepared, &self.receiver, receipt.archive) != .None {fail(self, "owned checkpoint"); return}
					self.phase = .Prepare
				}
			}
		}
		if self.owner_role && self.sender.ready {
			rec.sender_update(&self.sender, now)
			if self.sender.phase == .Complete && self.phase == .Transfer {self.phase = .Await_Prepared}
		} else if self.receiver.ready && self.phase != .Running && self.phase != .Recover {
			rec.receiver_update(&self.receiver, now)
			if !self.prepared.ready && tr.status(&self.data_wire) == .Connected && now - self.last_data_hello >= 200 {
				hello: [48]u8
				copy(hello[:16], self.rpc.nonce[:])
				fixture_key := auth.Key{0 = 22}
				hmac.sum(.SHA256, hello[16:], hello[:16], fixture_key[:])
				tr.send(&self.data_wire, 1, .Reliable, hello[:]); self.last_data_hello = now
			}
		}
	}
	if self.owner_role && self.phase >= .Transfer {
		if net.server_step(&self.server) != .Fenced || self.server.timeline.head != self.frozen_tick {fail(self, "old authority advanced"); return}
		if self.lease.view.epoch == 2 {
			gd.print_str("REPLAY_SERVICE_OLD_OWNER_FENCED")
			self.ready = false; gd.scene_tree_quit(gd.get_tree(self.owner), 0); return
		}
	}
	#partial switch self.phase {
	case .Start: command(self, {verb = .Start}, now)
	case .Nominate: command(self, {verb = .Nominate, epoch = 1, successor = SUCCESSOR, binding = 9}, now)
	case .Transfer, .Await_Prepared, .Await_Claim, .Observe: command(self, {verb = .Query}, now)
	case .Release: command(self, {verb = .Release, retired = self.retired, point = self.final_point}, now)
	case .Prepare: command(self, {verb = .Prepare, point = self.prepared.point}, now)
	case .Claim:
		if self.rpc.reply.released || self.lease.view.remaining_ms == 0 {command(self, {verb = .Claim, epoch = 1, point = self.prepared.point}, now)} else {command(self, {verb = .Query}, now)}
	case .Running:
		if self.lease.view.coordinator_generation > 1 && !auth.lease_live(&self.lease, 2) {
			auth.prepared_destroy(&self.prepared)
			if auth.prepared_capture(&self.prepared, &self.server, ROOM, SUCCESSOR.incarnation, &self.codec) != .None {fail(self, "retain owner world"); return}
			self.phase = .Recover
		} else {
			steps, _ := r.clock_add(&self.game_clock, dt)
			for _ in 0 ..< steps {
				if net.server_step(&self.server) == .Fenced {r.clock_init(&self.game_clock, self.server.cfg.hz); break}
				r.clock_consume(&self.game_clock)
			}
			command(self, {verb = .Renew, epoch = 2, tick = self.server.timeline.head}, now)
		}
	case .Recover: command(self, {verb = .Recover_Owner, epoch = 2, point = self.prepared.point}, now)
	case: }
}

fail :: proc(self: ^ReplayServiceProbe, message: string) {
	self.ready = false
	gd.print_str(fmt.tprintf("REPLAY_SERVICE_FAIL %s", message))
	gd.scene_tree_quit(gd.get_tree(self.owner), 1)
}

replay_service_probe_exit_tree :: proc(self: ^ReplayServiceProbe) {
	auth.rpc_client_destroy(&self.rpc); auth.service_destroy(&self.service)
	rec.sender_destroy(&self.sender); rec.receiver_destroy(&self.receiver)
	auth.prepared_destroy(&self.prepared); net.checkpoint_codec_destroy(&self.codec)
	net.server_destroy(&self.server)
	tr.close(&self.control_wire); tr.close(&self.data_wire); db.close(&self.store)
}
