package replay_telemetry

import sc "godot:replay/schema"
import tr "godot:replay/transport"

// Session metadata, never simulation state. Measurements include application
// pumping/queueing at both ends and are not pure transport or one-way latency.
MAX_PEERS :: 16
MAX_SEATS :: 16
INTERVAL_MS :: u64(1000)
STALE_MS :: u64(5000)
PACKET_KIND :: u16(0x4447)
Scope :: struct {room, epoch, content: u64}
Binding :: struct {peer: tr.Peer_Id, generation: u64, seat: u16}
Row :: struct {present, known: bool, round_trip_ms: u32, age_ms: u32}
Kind :: enum u8 {None, Probe, Echo, Report}
Packet :: struct {version: u16, room, binding, sequence: u64, kind: Kind, rows: [MAX_SEATS]Row}
Peer :: struct {binding: Binding, pending, sent_at, next_send, sample_at, echo_seen: u64, round_trip_ms: u32, known: bool}
Diagnostics :: struct {
	ready, bound, enabled, authority, time_set: bool,
	codec: sc.Schema, wire: tr.Transport, scope: Scope, local: Binding,
	peers: [MAX_PEERS]Peer, count: int,
	now, sequence, report_seen, report_at, next_report, rejected: u64,
	rows: [MAX_SEATS]Row,
	rxb, txb: [512]u8,
}

init :: proc(d: ^Diagnostics, allocator := context.allocator) -> bool {
	if d.ready {return false}
	if sc.init(&d.codec, Packet, allocator = allocator).error != .None {return false}
	if d.codec.wire_size + sc.HEADER_BYTES > len(d.txb) {sc.destroy(&d.codec); return false}
	d.ready = true
	return true
}
destroy :: proc(d: ^Diagnostics) {sc.destroy(&d.codec); d^ = {}}
handles :: proc(bytes: []u8) -> bool {
	meta, _, report := sc.inspect(bytes)
	return report.error == .None && meta.kind == PACKET_KIND && len(bytes) <= 512
}

// Bindings are supplied by the admitted session, not discovered from packets.
// Client binding generation is its own connection generation on both endpoints.
configure :: proc(d: ^Diagnostics, wire: tr.Transport, scope: Scope, authority: bool,
                  local: Binding, bindings: []Binding, enabled: bool, now: u64) -> bool {
	if !d.ready || len(bindings) > MAX_PEERS || (!authority && len(bindings) > 1) ||
	   local.seat > MAX_SEATS || scope.epoch == 0 || scope.content == 0 ||
	   (d.time_set && now < d.now) {return false}
	for b, i in bindings {
		if b.peer == 0 || b.generation == 0 || b.seat > MAX_SEATS {return false}
		if authority && b.seat != 0 && b.seat == local.seat {return false}
		for prior in bindings[:i] {if prior.peer == b.peer || (authority && b.seat != 0 && prior.seat == b.seat) {return false}}
	}
	reset := !d.bound || d.scope != scope || d.authority != authority || d.local != local || d.enabled != enabled
	if !authority && (d.count != len(bindings) || (len(bindings) == 1 && d.peers[0].binding != bindings[0])) {reset = true}
	stalled := d.time_set && now - d.now >= STALE_MS
	old := d.peers
	if reset || stalled {old = {}; d.rows = {}; d.report_at = 0; d.next_report = 0}
	if reset {d.report_seen = 0}
	d.peers = {}
	for b, i in bindings {
		d.peers[i].binding = b
		for peer in old {if peer.binding == b {d.peers[i] = peer; break}}
	}
	d.count, d.wire, d.scope, d.authority, d.local, d.enabled = len(bindings), wire, scope, authority, local, enabled
	d.now, d.time_set, d.bound = now, true, true
	return true
}

@(private)
next_sequence :: proc(d: ^Diagnostics) -> u64 {
	if d.sequence == max(u64) {return 0}
	d.sequence += 1
	return d.sequence
}
@(private)
send_packet :: proc(d: ^Diagnostics, peer: ^Peer, packet: Packet) -> bool {
	p := packet; p.version, p.room, p.binding = 1, d.scope.room, peer.binding.generation
	if sc.pack(&d.codec, p, {kind = PACKET_KIND, epoch = d.scope.epoch, content = d.scope.content}, d.txb[:]).error != .None {return false}
	return tr.send(&d.wire, peer.binding.peer, .Unreliable, d.txb[:d.codec.wire_size + sc.HEADER_BYTES]) == .Sent
}

read :: proc(d: ^Diagnostics, seat: u16) -> (row: Row) {
	if !d.ready || !d.enabled || seat == 0 || seat > MAX_SEATS {return}
	if d.authority {
		if seat == d.local.seat {return {present = true, known = true}}
		for peer in d.peers[:d.count] {
			if peer.binding.seat != seat {continue}
			row.present = true
			if peer.known && d.now - peer.sample_at < STALE_MS {row.known = true; row.round_trip_ms = peer.round_trip_ms; row.age_ms = u32(d.now - peer.sample_at)}
			return
		}
	} else if d.report_seen != 0 && d.now - d.report_at < STALE_MS {
		row = d.rows[seat - 1]
		age := u64(row.age_ms) + d.now - d.report_at
		if age >= STALE_MS {row.known = false; row.round_trip_ms = 0; row.age_ms = 0} else {row.age_ms = u32(age)}
	}
	return
}

@(private)
receive_packet :: proc(d: ^Diagnostics, from: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> bool {
	if !d.enabled || channel != .Unreliable {return false}
	peer: ^Peer
	for &candidate in d.peers[:d.count] {if candidate.binding.peer == from {peer = &candidate; break}}
	if peer == nil {return false}
	p: Packet
	_, report := sc.unpack(&d.codec, &p, bytes, {kind = PACKET_KIND, epoch = d.scope.epoch, content = d.scope.content})
	if report.error != .None || p.version != 1 || p.room != d.scope.room || p.binding != peer.binding.generation || p.sequence == 0 {return false}
	if d.authority {
		if p.kind != .Echo || p.rows != ([MAX_SEATS]Row{}) || p.sequence != peer.pending || d.now - peer.sent_at >= STALE_MS {return false}
		peer.round_trip_ms, peer.sample_at, peer.known, peer.pending = u32(d.now - peer.sent_at), d.now, true, 0
		return true
	}
	#partial switch p.kind {
	case .Probe:
		if p.rows != ([MAX_SEATS]Row{}) || p.sequence <= peer.echo_seen {return false}
		// One response per new authority nonce. Failure waits for its next probe.
		peer.echo_seen = p.sequence
		send_packet(d, peer, {kind = .Echo, sequence = p.sequence})
		return true
	case .Report:
		if p.sequence <= d.report_seen {return false}
		for row in p.rows {
			if (!row.present && row != (Row{})) || (!row.known && (row.round_trip_ms != 0 || row.age_ms != 0)) ||
			   row.round_trip_ms >= u32(STALE_MS) || row.age_ms >= u32(STALE_MS) {return false}
		}
		d.rows, d.report_seen, d.report_at = p.rows, p.sequence, d.now
		return true
	}
	return false
}

frame :: proc(d: ^Diagnostics) {
	if !d.ready || !d.bound {return}
	for _ in 0 ..< 64 {
		packet := tr.receive(&d.wire, d.rxb[:])
		if packet.state != .Received {break}
		if !receive_packet(d, packet.from, packet.channel, d.rxb[:packet.count]) {d.rejected += 1}
	}
	if !d.enabled || !d.authority {return}
	for &peer in d.peers[:d.count] {
		if d.now < peer.next_send || (peer.pending != 0 && d.now - peer.sent_at < STALE_MS) {continue}
		peer.next_send = d.now + INTERVAL_MS
		sequence := next_sequence(d); if sequence == 0 {continue}
		if send_packet(d, &peer, {kind = .Probe, sequence = sequence}) {peer.pending, peer.sent_at = sequence, d.now}
	}
	if d.now < d.next_report {return}
	d.next_report = d.now + INTERVAL_MS
	packet := Packet{kind = .Report, sequence = next_sequence(d)}; if packet.sequence == 0 {return}
	for &row, i in packet.rows {row = read(d, u16(i + 1))}
	for &peer in d.peers[:d.count] {send_packet(d, &peer, packet)}
}
