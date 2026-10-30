package replay_net_legacy

import "core:mem"
import delta "godot:replay/delta"
import sc "godot:replay/schema"
import tr "godot:replay/transport"
import r "godot:replay"

DELTA_HEADER_BYTES :: 48

@(private)
Snapshot_Tx :: struct {
	allocator: mem.Allocator,
	sent: delta.Cache,
	baseline, scratch: []u8,
	baseline_id, baseline_hash, next_id: u64,
	reliable_pending: u64,
	force_full: bool,
	views: []Sent_View,
}

@(private)
snapshot_tx_init :: proc(tx: ^Snapshot_Tx, size, slots: int, allocator: mem.Allocator) -> bool {
	if !delta.cache_init(&tx.sent, size, slots, allocator) {return false}
	tx.allocator = allocator
	tx.baseline = make([]u8, size, allocator)
	tx.scratch = make([]u8, size, allocator)
	tx.views = make([]Sent_View, slots, allocator)
	tx.force_full = true
	return true
}

@(private)
snapshot_tx_reset :: proc(tx: ^Snapshot_Tx) {
	delta.cache_clear(&tx.sent)
	for &proof in tx.views {proof = {}}
	tx.baseline_id, tx.baseline_hash, tx.next_id, tx.force_full = 0, 0, 0, true
	tx.reliable_pending = 0
}

@(private)
snapshot_tx_destroy :: proc(tx: ^Snapshot_Tx) {
	delta.cache_destroy(&tx.sent)
	delete(tx.baseline, tx.allocator)
	delete(tx.scratch, tx.allocator)
	delete(tx.views, tx.allocator)
	tx^ = {}
}

@(private)
server_snapshot :: proc(s: ^Server($State, $Control, $Action, $Event, $Seats), index: int) {
	started, timed := profile_start(s.profile_clock)
	defer profile_finish(&s.profile_metrics, .Snapshot, s.profile_clock, started, timed, s.profile_user, s.profile_sample)
	lap,lap_valid:=started,timed
	peer := &s.peers[index]
	tx := &s.snapshot_tx[index]
	if tx.next_id == max(u64) {server_checkpoint(s, index); return}
	// Large state uses ordered reliable delivery. Only one such snapshot may
	// be outstanding; queuing another full world every tick delays facts and
	// the very acknowledgement needed to establish a compact delta baseline.
	if tx.reliable_pending != 0 && (tx.baseline_id == 0 || !s.cfg.delta_snapshots) {return}
	frame, _ := r.current(&s.timeline)
	value,ok:=replica_project(s.model,frame,s.held,Recipient{peer.seat,peer.spectator},&s.codecs.replica,s.txb)
	if !ok {s.stats.rejected_replica_views+=1;return};frame.state=value.state
	packet := Snapshot_Packet(State, Control, Seats){snapshot_id = tx.next_id + 1,
	          generation = peer.generation, serial = peer.serial, frame = frame, held = value.held,
	          action_settled = peer.action_settled, input_newest = peer.input_newest}
	if sc.encode(&s.codecs.snapshot, packet, tx.scratch).error != .None {return}
	profile_lap(&s.profile_metrics,.Snapshot_Encode,s.profile_clock,&lap,&lap_valid,s.profile_user,s.profile_sample)
	target_hash := sc.digest(tx.scratch)
	profile_lap(&s.profile_metrics,.Snapshot_Hash,s.profile_clock,&lap,&lap_valid,s.profile_user,s.profile_sample)
	meta := sc.Envelope_Meta{kind = u16(Kind.Snapshot), epoch = s.cfg.epoch, tick = frame.tick, content = s.cfg.content}
	size := sc.HEADER_BYTES + len(tx.scratch)
	compressed := false
	if s.cfg.delta_snapshots && !tx.force_full && tx.baseline_id != 0 {
		payload := s.txb[sc.HEADER_BYTES:]
		if n, ok := delta.encode(tx.baseline, tx.scratch, payload[DELTA_HEADER_BYTES:]); ok &&
		   n + DELTA_HEADER_BYTES < len(tx.scratch) {
			put64(payload[0:8], peer.generation)
			put64(payload[8:16], peer.serial)
			put64(payload[16:24], tx.baseline_id)
			put64(payload[24:32], tx.baseline_hash)
			put64(payload[32:40], packet.snapshot_id)
			put64(payload[40:48], target_hash)
			meta.kind = u16(Kind.Snapshot_Delta)
			if sc.pack_bytes(s.codecs.snapshot.fingerprint, meta, payload[:DELTA_HEADER_BYTES + n], s.txb).error != .None {return}
			size = sc.HEADER_BYTES + DELTA_HEADER_BYTES + n
			compressed = true
		}
	}
	if !compressed {
		if sc.pack_bytes(s.codecs.snapshot.fingerprint, meta, tx.scratch, s.txb).error != .None {return}
	}
	profile_lap(&s.profile_metrics,.Snapshot_Delta,s.profile_clock,&lap,&lap_valid,s.profile_user,s.profile_sample)
	channel := size > s.cfg.unreliable_packet_limit ? tr.Channel.Reliable : tr.Channel.Unreliable
	if channel == .Reliable && tx.reliable_pending != 0 {return}
	if server_send(s, peer.connection, channel, s.txb[:size]) != .Sent {return}
	profile_lap(&s.profile_metrics,.Snapshot_Send,s.profile_clock,&lap,&lap_valid,s.profile_user,s.profile_sample)
	if channel == .Reliable {s.stats.large_reliable_snapshots += 1; tx.reliable_pending = packet.snapshot_id}
	slot := tx.sent.next
	assert(delta.cache_note_prehashed(&tx.sent, packet.snapshot_id, tx.scratch,target_hash))
	profile_lap(&s.profile_metrics,.Snapshot_Cache,s.profile_clock,&lap,&lap_valid,s.profile_user,s.profile_sample)
	tx.views[slot] = {packet.snapshot_id, frame.tick, s.now, true}
	tx.next_id = packet.snapshot_id
	tx.force_full = false
	peer.snapshot_sent = s.timeline.head
	if compressed {s.stats.delta_snapshots += 1; s.stats.snapshot_bytes_saved += u64(sc.HEADER_BYTES + len(tx.scratch) - size)} else {s.stats.full_snapshots += 1}
}

@(private)
server_snapshot_ack :: proc(s: ^Server($State, $Control, $Action, $Event, $Seats), index: int, ack: Snapshot_Ack, missing: bool) {
	peer := &s.peers[index]
	tx := &s.snapshot_tx[index]
	if ack.generation != peer.generation || ack.serial != peer.serial || ack.id == 0 {s.stats.rejected_acks += 1; return}
	if missing {
		if ack.id == tx.baseline_id && ack.hash == tx.baseline_hash {
			tx.baseline_id, tx.baseline_hash, tx.force_full = 0, 0, true
			tx.reliable_pending = 0 // In-flight deltas may depend on the lost base.
			s.stats.baseline_misses += 1
		}
		return
	}
	if ack.id <= tx.baseline_id {return}
	bytes, hash, found := delta.cache_find(&tx.sent, ack.id)
	if !found || hash != ack.hash {s.stats.rejected_acks += 1; return}
	for proof in tx.views {
		if proof.valid && proof.id == ack.id && s.now >= proof.sent_ms {
			sample := max(s.now - proof.sent_ms, 1)
			if peer.rtt_floor_ms == 0 || s.now >= peer.rtt_floor_until {peer.rtt_floor_ms = sample; peer.rtt_floor_until = s.now + 2000} else {peer.rtt_floor_ms = min(peer.rtt_floor_ms, sample)}
			break
		}
	}
	copy(tx.baseline, bytes)
	tx.baseline_id, tx.baseline_hash = ack.id, hash
	if ack.id >= tx.reliable_pending {tx.reliable_pending = 0}
	peer.last_seen = s.now
}

@(private)
client_snapshot :: proc(c: ^Client($State, $Control, $Action, $Event, $Seats), bytes: []u8, expected: sc.Envelope_Meta, compressed: bool) {
	started, timed := profile_start(c.profile_clock)
	defer profile_finish(&c.profile_metrics, .Snapshot, c.profile_clock, started, timed, c.profile_user, c.profile_sample)
	lap,lap_valid:=started,timed
	meta, body, report := sc.unpack_bytes(c.codecs.snapshot.fingerprint, bytes, expected)
	if report.error != .None {c.stats.rejected_packets += 1; return}
	canonical := body
	canonical_hash:u64
	if compressed {
		if len(body) < DELTA_HEADER_BYTES + 2 {c.stats.rejected_packets += 1; return}
		if get64(body[:8]) != c.generation || get64(body[8:16]) != c.serial {c.stats.rejected_packets += 1; return}
		base_id, base_hash := get64(body[16:24]), get64(body[24:32])
		target_id, target_hash := get64(body[32:40]), get64(body[40:48])
		if target_id <= c.snapshot_latest {client_ack_snapshot(c); return}
		base, hash, found := delta.cache_find(&c.snapshot_rx, base_id)
		if !found || hash != base_hash {
			if c.baseline_request_id != base_id || c.now - c.baseline_request_time >= 100 {
				ack := Snapshot_Ack{c.generation, c.serial, base_id, base_hash}
				client_send(c, &c.codecs.snapshot_ack, .Baseline_Miss, ack, meta.tick, .Reliable)
				c.baseline_request_id, c.baseline_request_time = base_id, c.now
				c.stats.baseline_misses += 1
			}
			return
		}
		if !delta.apply(base, body[DELTA_HEADER_BYTES:], c.snapshot_scratch) {
			c.stats.rejected_packets += 1; return
		}
		canonical_hash=sc.digest(c.snapshot_scratch)
		if canonical_hash!=target_hash {c.stats.rejected_packets+=1;return}
		canonical = c.snapshot_scratch
	} else {canonical_hash=sc.digest(canonical)}
	profile_lap(&c.profile_metrics,.Snapshot_Delta,c.profile_clock,&lap,&lap_valid,c.profile_user,c.profile_sample)
	packet: Snapshot_Packet(State, Control, Seats)
	if sc.decode(&c.codecs.snapshot, &packet, canonical).error != .None {c.stats.rejected_packets+=1;return}
	profile_lap(&c.profile_metrics,.Snapshot_Encode,c.profile_clock,&lap,&lap_valid,c.profile_user,c.profile_sample)
	if packet.generation != c.generation ||
	   packet.serial != c.serial || packet.frame.tick != meta.tick || packet.snapshot_id == 0 || !replica_valid(c.model,packet.frame.state,packet.held,Recipient{c.seat,c.spectator}) {
		c.stats.rejected_packets += 1; return
	}
	if compressed && packet.snapshot_id != get64(body[32:40]) {c.stats.rejected_packets += 1; return}
	profile_lap(&c.profile_metrics,.Snapshot_Validate,c.profile_clock,&lap,&lap_valid,c.profile_user,c.profile_sample)
	if packet.snapshot_id <= c.snapshot_latest {client_ack_snapshot(c); return}
	slot := c.snapshot_rx.next
	if !delta.cache_note_prehashed(&c.snapshot_rx, packet.snapshot_id, canonical,canonical_hash) {c.stats.rejected_packets += 1; return}
	c.snapshot_ticks[slot] = packet.frame.tick
	c.snapshot_latest, c.snapshot_latest_hash = packet.snapshot_id, canonical_hash
	profile_lap(&c.profile_metrics,.Snapshot_Cache,c.profile_clock,&lap,&lap_valid,c.profile_user,c.profile_sample)
	c.baseline_request_id = 0
	// A large reliable snapshot also gates the next large transmission. Its
	// acknowledgement must survive unreliable loss without a heartbeat delay.
	client_ack_snapshot(c, len(bytes) > c.cfg.unreliable_packet_limit ? .Reliable : .Unreliable)
	profile_lap(&c.profile_metrics,.Snapshot_Send,c.profile_clock,&lap,&lap_valid,c.profile_user,c.profile_sample)
	if compressed {c.stats.delta_snapshots += 1} else {c.stats.full_snapshots += 1}
	if packet.frame.tick > c.timeline.confirmed && (!c.has_pending || (packet.frame.tick <= c.facts_contiguous && packet.frame.tick > c.pending.frame.tick)) {c.pending = packet; c.has_pending = true}
	c.last_received = c.now
}

@(private)
client_ack_snapshot :: proc(c: ^Client($State, $Control, $Action, $Event, $Seats), channel: tr.Channel = .Unreliable) {
	if c.snapshot_latest == 0 {return}
	ack := Snapshot_Ack{c.generation, c.serial, c.snapshot_latest, c.snapshot_latest_hash}
	client_send(c, &c.codecs.snapshot_ack, .Snapshot_Ack, ack, c.authority_frame.tick, channel)
}

@(private)
pack_facts :: proc(c: ^Codecs, packet: Facts_Packet($Event), meta: sc.Envelope_Meta, dst: []u8) -> (size: int, ok: bool) {
	packet := packet
	if packet.count > WIRE_EVENTS {return}
	length := c.fact_header.wire_size + int(packet.count) * c.occurrence.wire_size
	if len(dst) < sc.HEADER_BYTES + length {return}
	body := dst[sc.HEADER_BYTES:sc.HEADER_BYTES + length]
	header := Facts_Header{packet.generation, packet.serial, packet.tick, packet.count}
	if sc.encode(&c.fact_header, header, body).error != .None {return}
	for event, i in packet.events[:packet.count] {
		offset := c.fact_header.wire_size + i * c.occurrence.wire_size
		if sc.encode(&c.occurrence, event, body[offset:offset + c.occurrence.wire_size]).error != .None {return}
	}
	if sc.pack_bytes(c.facts.fingerprint, meta, body, dst).error != .None {return}
	return sc.HEADER_BYTES + length, true
}

@(private)
unpack_facts :: proc(c: ^Codecs, dst: ^Facts_Packet($Event), bytes: []u8, expected: sc.Envelope_Meta) -> bool {
	meta, body, report := sc.unpack_bytes(c.facts.fingerprint, bytes, expected)
	if report.error != .None || len(body) < c.fact_header.wire_size {return false}
	header: Facts_Header
	if sc.decode(&c.fact_header, &header, body[:c.fact_header.wire_size]).error != .None ||
	   header.tick != meta.tick || header.count > WIRE_EVENTS {return false}
	if len(body) != c.fact_header.wire_size + int(header.count) * c.occurrence.wire_size {return false}
	packet := Facts_Packet(Event){generation = header.generation, serial = header.serial, tick = header.tick, count = header.count}
	for i in 0 ..< int(header.count) {
		offset := c.fact_header.wire_size + i * c.occurrence.wire_size
		if sc.decode(&c.occurrence, &packet.events[i], body[offset:offset + c.occurrence.wire_size]).error != .None {return false}
	}
	dst^ = packet
	return true
}

@(private)
put64 :: proc(dst: []u8, value: u64) {for i in 0 ..< 8 {dst[i] = u8(value >> uint(i * 8))}}
@(private)
get64 :: proc(src: []u8) -> u64 {value := u64(0); for i in 0 ..< 8 {value |= u64(src[i]) << uint(i * 8)}; return value}
