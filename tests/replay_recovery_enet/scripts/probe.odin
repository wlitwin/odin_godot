//gd:extends Node
//gd:class ReplayReplicaProbe
package replay_replica_probe

import "core:fmt"
import "core:reflect"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"
import sample "godot:tests/replay_recovery/shared/archive"
import storagegd "godot:replay/godot/storage"
import transportgd "godot:replay/godot/transport"

ReplayReplicaProbe :: struct {
	owner: gd.Node,
	enet: transportgd.Enet,
	delay: tr.Delay,
	wire: tr.Transport,
	sender: rec.Sender,
	archive_codec: net.Checkpoint_Codec,
	receiver: rec.Receiver(sample.World, sample.Control, sample.Action, sample.Event, sample.SEATS),
	server: net.Server(sample.World, sample.Control, sample.Action, sample.Event, sample.SEATS),
	ready, host, restored: bool,
	started, last_hello, done_at, validation_us: u64,
	token: net.Token,
}

replay_replica_probe_ready :: proc(self: ^ReplayReplicaProbe) {
	self.started = gd.time_get_ticks_msec(gd.singleton_time())
	self.host = gd.env_string("REPLAY_REPLICA_ROLE", "successor") == "host"
	self.token = storagegd.session_token(gd.env_string("REPLAY_REPLICA_KEY", "replica-fixture-only"))
	port := gd.env_int("REPLAY_REPLICA_PORT", 49430)
	if port < 1 || port > 65535 {replay_replica_probe_fail(self, "port"); return}
	ok := self.host ? transportgd.enet_host(&self.enet, u16(port), 1, bind_ip = "127.0.0.1") : transportgd.enet_join(&self.enet, "127.0.0.1", u16(port))
	if !ok {replay_replica_probe_fail(self, "transport"); return}
	self.wire = transportgd.enet_transport(&self.enet)
	if !tr.delay_init(&self.delay, self.wire, 120) || !tr.delay_faults(&self.delay, 20, 1000, 1000, self.host ? 81 : 93) {
		replay_replica_probe_fail(self, "fault configuration"); return
	}
	self.wire = tr.delay_transport(&self.delay)
	if self.host {
		if sample.authority(&self.server) != .None {replay_replica_probe_fail(self, "authority fixture"); return}
		if net.checkpoint_codec_init(&self.archive_codec, sample.World, sample.Control, sample.Action, sample.Event, sample.SEATS) != .None {
			replay_replica_probe_fail(self, "archive schema"); return
		}
	} else {
		if rec.receiver_init(&self.receiver, {21, 1, 42, sample.CONTENT}, 1, self.wire, sample.model()) != .None {
			replay_replica_probe_fail(self, "receiver"); return
		}
	}
	self.ready = true
	if self.host {gd.print_str("REPLAY_REPLICA_HOST_READY")}
}

replay_replica_probe_process :: proc(self: ^ReplayReplicaProbe, dt: f64) {
	if !self.ready {return}
	now := gd.time_get_ticks_msec(gd.singleton_time())
	if now - self.started > 25000 {replay_replica_probe_fail(self, "timeout"); return}
	tr.delay_time(&self.delay, now)
	tr.poll(&self.wire)
	if self.done_at != 0 {
		if now >= self.done_at {gd.scene_tree_quit(gd.get_tree(self.owner), 0)}
		return
	}
	if !self.host && tr.status(&self.wire) == .Connected && !self.restored && now - self.last_hello >= 200 {
		tr.send(&self.wire, 1, .Reliable, self.token[:]); self.last_hello = now
	}
	buffer: [tr.MAX_PACKET_BYTES]u8
	for _ in 0 ..< 64 {
		packet := tr.receive(&self.wire, buffer[:])
		if packet.state == .Empty || packet.state == .Disconnected {break}
		if packet.state != .Received {replay_replica_probe_fail(self, "packet"); return}
		bytes := buffer[:packet.count]
		if self.host {
			if len(bytes) == 16 {
				token: net.Token; copy(token[:], bytes)
				if token != self.token || self.sender.ready {continue}
				// Explicit loopback test grant; production installs a coordinator-
				// approved source/successor and binding before disclosing private data.
				if rec.sender_init(&self.sender, {21, 1, 42, sample.CONTENT}, packet.from, self.wire) != .None {replay_replica_probe_fail(self, "sender"); return}
				cp: sample.Checkpoint
				defer net.checkpoint_destroy(&cp)
				begin := gd.time_get_ticks_usec(gd.singleton_time())
				if net.checkpoint_capture(&self.server, &cp) != .None || rec.sender_publish(&self.sender, &cp, sample.model(), now, &self.archive_codec) != .None {
					replay_replica_probe_fail(self, "capture"); return
				}
				gd.print_str(fmt.tprintf("REPLAY_REPLICA_CAPTURE bytes=%d tick=%d cpu_us=%d", self.sender.archive.bytes, cp.frame.tick,
				                        gd.time_get_ticks_usec(gd.singleton_time()) - begin))
			} else {rec.sender_receive(&self.sender, packet.from, bytes, now)}
		} else if packet.from == 1 {
			if len(bytes) == 2 && bytes[0] == 'O' && bytes[1] == 'K' && self.restored {self.done_at = now + 500; continue}
			begin := gd.time_get_ticks_usec(gd.singleton_time())
			result := rec.receiver_receive(&self.receiver, packet.from, bytes, now)
			self.validation_us += gd.time_get_ticks_usec(gd.singleton_time()) - begin
			if result == .Validated && !self.restored {
				receipt, _ := rec.receiver_latest(&self.receiver)
				cp, found := rec.receiver_checkpoint(&self.receiver, receipt.archive)
				if !found || receipt.archive.bytes <= tr.MAX_PACKET_BYTES {replay_replica_probe_fail(self, "large archive"); return}
				begin_restore := gd.time_get_ticks_usec(gd.singleton_time())
				if net.server_restore(&self.server, cp, sample.model(), {}, {epoch = 2, local_seat = 1}) != .None {replay_replica_probe_fail(self, "restore"); return}
				frame, _ := r.current(&self.server.timeline)
				if !reflect.equal(frame, cp.frame) || frame.state.cave.players[0].bag[0].count != 3 || frame.state.cave.rocks.count != 1 {
					replay_replica_probe_fail(self, "complete cave world"); return
				}
				if net.server_step(&self.server) != .None {replay_replica_probe_fail(self, "continued simulation"); return}
				self.restored = true
				gd.print_str(fmt.tprintf("REPLAY_REPLICA_SUCCESSOR_OK bytes=%d tick=%d validation_us=%d restore_us=%d", receipt.archive.bytes,
				                        cp.frame.tick, self.validation_us, gd.time_get_ticks_usec(gd.singleton_time()) - begin_restore))
			}
		}
	}
	if self.host && self.sender.ready {
		if err := rec.sender_update(&self.sender, now); err != .None {replay_replica_probe_fail(self, fmt.tprintf("send %v", err)); return}
		if self.sender.phase == .Failed {replay_replica_probe_fail(self, fmt.tprintf("rejected %v", self.sender.remote_failure)); return}
		if self.sender.phase == .Complete {
			done := [2]u8{'O', 'K'}
			if tr.send(&self.wire, self.sender.target, .Reliable, done[:]) == .Sent {
				gd.print_str(fmt.tprintf("REPLAY_REPLICA_SENDER_OK tick=%d elapsed_ms=%d tx_bytes=%d retries=%d", self.sender.acknowledged.archive.tick,
				                        now - self.sender.started, self.sender.stats.tx_bytes, self.sender.stats.retries))
				self.done_at = now + 1000
			}
		}
	} else if !self.host {
		if err := rec.receiver_update(&self.receiver, now); err != .None && err != .Transport {replay_replica_probe_fail(self, "receive update"); return}
	}
}

replay_replica_probe_fail :: proc(self: ^ReplayReplicaProbe, message: string) {
	self.ready = false
	gd.print_str(fmt.tprintf("REPLAY_REPLICA_FAIL %s", message))
	gd.scene_tree_quit(gd.get_tree(self.owner), 1)
}

replay_replica_probe_exit_tree :: proc(self: ^ReplayReplicaProbe) {
	rec.sender_destroy(&self.sender); rec.receiver_destroy(&self.receiver)
	net.server_destroy(&self.server)
	net.checkpoint_codec_destroy(&self.archive_codec)
	tr.close(&self.wire)
}
