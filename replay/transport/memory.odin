package replay_transport

import "core:mem"
import r "godot:replay"
import sc "godot:replay/schema"

// Deterministic channel-service model, not an ENet implementation. Reliable
// packets retry and preserve per-direction order; unreliable packets may drop,
// duplicate, and reorder. Time advances only when the harness says so.
Faults :: struct {
	latency_ticks, jitter_ticks: u32,
	loss_permyriad, duplicate_permyriad: u32,
	retry_ticks: u32,
}
DEFAULT_FAULTS :: Faults{retry_ticks = 3}
Memory_Config :: struct {peers, packets, packet_bytes, trace_entries: int}
DEFAULT_MEMORY_CONFIG :: Memory_Config{16, 256, 4096, 16384}
Trace_Kind :: enum u8 {Send, Deliver, Drop, Retry, Close, Fault_Change}
Trace :: struct {tick, sequence: u64, kind: Trace_Kind, from, to: Peer_Id, payload_hash: u64}

@(private)
Pending :: struct {
	active, ready: bool,
	from, to: Peer_Id,
	channel: Channel,
	sequence, due: u64,
	count: int,
}

Memory :: struct {
	allocator: mem.Allocator,
	config: Memory_Config,
	faults: Faults,
	now, sequence: u64,
	rng: r.Rng,
	connected: []bool,
 generations: []u64,
	packets: []Pending,
	bytes: []u8,
	trace: []Trace,
	trace_count, trace_dropped: int,
	trace_hash: u64,
}

Memory_Endpoint :: struct {network: ^Memory, id: Peer_Id, live: bool}

memory_init :: proc(m: ^Memory, seed: u64 = 1, cfg := DEFAULT_MEMORY_CONFIG,
                    faults := DEFAULT_FAULTS, allocator := context.allocator) -> bool {
	if len(m.packets) != 0 || cfg.peers < 2 || cfg.peers > 128 || cfg.packets < 1 || cfg.packets > 4096 ||
	   cfg.packet_bytes < 1 || cfg.packet_bytes > MAX_PACKET_BYTES || cfg.trace_entries < 1 ||
	   cfg.trace_entries > 1_048_576 || !faults_valid(faults) {return false}
	m.allocator, m.config, m.faults, m.rng = allocator, cfg, faults, r.rng_make(seed)
	m.connected = make([]bool, cfg.peers + 1, allocator)
 m.generations = make([]u64, cfg.peers + 1, allocator)
	m.packets = make([]Pending, cfg.packets, allocator)
	m.bytes = make([]u8, cfg.packets * cfg.packet_bytes, allocator)
	m.trace = make([]Trace, cfg.trace_entries, allocator)
	return true
}

memory_destroy :: proc(m: ^Memory) {
	delete(m.connected, m.allocator)
 delete(m.generations, m.allocator)
	delete(m.packets, m.allocator)
	delete(m.bytes, m.allocator)
	delete(m.trace, m.allocator)
	m^ = {}
}

memory_open :: proc(m: ^Memory, e: ^Memory_Endpoint, id: Peer_Id) -> bool {
	if e.live || id == 0 || u64(id) >= u64(len(m.connected)) || m.connected[id] || m.generations[id]==max(u64) {return false}
	m.connected[id] = true; m.generations[id] += 1
	e^ = {m, id, true}
	return true
}

memory_transport :: proc(e: ^Memory_Endpoint) -> Transport {
	return {user = e, send = memory_send, receive = memory_receive, status = memory_status, close = memory_close, connected = memory_connected, generation = memory_generation}
}

@(private)
memory_connected :: proc(user: rawptr, peer: Peer_Id) -> bool {
	e := cast(^Memory_Endpoint)user
	return memory_status(e) == .Connected && u64(peer) < u64(len(e.network.connected)) && e.network.connected[peer]
}

// Record the time of each configuration change. Reproduction also needs the
// seed, configs, input/send trace, and advance schedule supplied by the harness.
memory_set_faults :: proc(m: ^Memory, faults: Faults) -> bool {
	if len(m.packets) == 0 || !faults_valid(faults) {return false}
	m.faults = faults
	values := [5]u64{u64(faults.latency_ticks), u64(faults.jitter_ticks), u64(faults.loss_permyriad), u64(faults.duplicate_permyriad), u64(faults.retry_ticks)}
	hash := u64(0xcbf29ce484222325)
	for value in values {hash = (hash ~ value) * 0x100000001b3}
	note(m, Trace{tick = m.now, kind = .Fault_Change, payload_hash = hash})
	return true
}

memory_advance :: proc(m: ^Memory, to: u64) -> bool {
	if len(m.packets) == 0 || to < m.now || to - m.now > 10000 {return false}
	start := m.now
	for offset in u64(0) ..= to - start {
		m.now = start + offset
		for &packet in m.packets {
			if !packet.active || packet.ready || packet.due > m.now {continue}
			lost := r.rng_next(&m.rng) % 10000 < u64(m.faults.loss_permyriad)
			if lost {
				if packet.channel == .Reliable {
					packet.due = saturating_add(m.now, u64(m.faults.retry_ticks))
					note(m, Trace{m.now, packet.sequence, .Retry, packet.from, packet.to, 0})
				} else {
					packet.active = false
					note(m, Trace{m.now, packet.sequence, .Drop, packet.from, packet.to, 0})
				}
			} else {packet.ready = true}
		}
	}
	return true
}

@(private)
faults_valid :: proc(f: Faults) -> bool {
	return f.latency_ticks <= 10000 && f.jitter_ticks <= 10000 && f.retry_ticks > 0 &&
	       f.retry_ticks <= 10000 && f.loss_permyriad <= 10000 && f.duplicate_permyriad <= 10000
}

@(private)
saturating_add :: proc(a, b: u64) -> u64 {return b > max(u64) - a ? max(u64) : a + b}

@(private)
memory_send :: proc(user: rawptr, to: Peer_Id, channel: Channel, bytes: []u8) -> Send_Result {
	e := cast(^Memory_Endpoint)user
	if memory_status(e) != .Connected {return .Disconnected}
	m := e.network
	if u64(to) >= u64(len(m.connected)) || !m.connected[to] {return .Disconnected}
	if len(bytes) > m.config.packet_bytes {return .Too_Large}
	duplicate := channel == .Unreliable && r.rng_next(&m.rng) % 10000 < u64(m.faults.duplicate_permyriad)
	needed := duplicate ? 2 : 1
	free := 0
	for packet in m.packets {if !packet.active {free += 1}}
	if free < needed || u64(needed) > max(u64) - m.sequence {return .Backpressure}
	for _ in 0 ..< needed {
		for &packet, i in m.packets {
			if packet.active {continue}
			m.sequence += 1
			jitter := r.rng_next(&m.rng) % (u64(m.faults.jitter_ticks) + 1)
			packet = {active = true, from = e.id, to = to, channel = channel, sequence = m.sequence,
			          due = saturating_add(m.now, u64(m.faults.latency_ticks) + jitter), count = len(bytes)}
			copy(m.bytes[i * m.config.packet_bytes:(i + 1) * m.config.packet_bytes], bytes)
			note(m, Trace{m.now, packet.sequence, .Send, packet.from, packet.to, sc.digest(bytes)})
			break
		}
	}
	return .Sent
}

@(private)
memory_receive :: proc(user: rawptr, dst: []u8) -> Received {
	e := cast(^Memory_Endpoint)user
	if memory_status(e) != .Connected {return {state = .Disconnected}}
	m := e.network
	best := -1
	for packet, i in m.packets {
		if !packet.active || !packet.ready || packet.to != e.id || packet.due > m.now {continue}
		if packet.channel == .Reliable {
			blocked := false
			for earlier in m.packets {
				if earlier.active && earlier.from == packet.from && earlier.to == packet.to &&
				   earlier.channel == .Reliable && earlier.sequence < packet.sequence {blocked = true; break}
			}
			if blocked {continue}
		}
		if best < 0 || packet.due < m.packets[best].due ||
		   (packet.due == m.packets[best].due && packet.sequence < m.packets[best].sequence) {best = i}
	}
	if best < 0 {return {state = .Empty}}
	packet := &m.packets[best]
	result := Received{state = .Received, from = packet.from, channel = packet.channel, count = packet.count}
	if len(dst) < packet.count {result.state = .Buffer_Too_Small; return result}
	src := m.bytes[best * m.config.packet_bytes:best * m.config.packet_bytes + packet.count]
	copy(dst, src)
	packet.active = false
	note(m, Trace{m.now, packet.sequence, .Deliver, packet.from, packet.to, sc.digest(src)})
	return result
}

@(private)
memory_status :: proc(user: rawptr) -> Status {
	e := cast(^Memory_Endpoint)user
	return e.live && e.network != nil && u64(e.id) < u64(len(e.network.connected)) &&
	       e.network.connected[e.id] ? .Connected : .Disconnected
}

@(private)
memory_close :: proc(user: rawptr) {
	e := cast(^Memory_Endpoint)user
	if !e.live {return}
	if memory_status(e) != .Connected {e.live = false; return}
	m := e.network
	m.connected[e.id] = false
	for &packet in m.packets {if packet.from == e.id || packet.to == e.id {packet.active = false}}
	note(m, Trace{tick = m.now, kind = .Close, from = e.id})
	e.live = false
}

@(private)
note :: proc(m: ^Memory, event: Trace) {
	if m.trace_count < len(m.trace) {m.trace[m.trace_count] = event; m.trace_count += 1} else {m.trace_dropped += 1}
	// Hash logical fields, never struct padding. This also covers trace overflow.
	values := [6]u64{event.tick, event.sequence, u64(event.kind), u64(event.from), u64(event.to), event.payload_hash}
	for value in values {m.trace_hash = (m.trace_hash ~ value) * 0x100000001b3}
}

@(private)
memory_generation :: proc(user: rawptr, peer: Peer_Id) -> u64 {
 e:=cast(^Memory_Endpoint)user
 return memory_connected(user,peer) ? e.network.generations[peer] : 0
}
