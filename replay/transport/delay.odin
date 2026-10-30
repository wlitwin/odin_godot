package replay_transport

import "core:mem"
import r "godot:replay"

@(private)
Delayed_Packet :: struct {active: bool, due, sequence: u64, received: Received}

// A bounded receive-delay decorator for real transports. It preserves their
// delivery guarantees, copies packet ownership, and never silently drops a full
// queue. Loss/retry simulation belongs to Memory or a real network fault tool.
// Closing delay_transport forwards close to base, then frees this queue.
Delay :: struct {
	allocator: mem.Allocator,
	base: Transport,
	now, sequence: u64,
	latency_ms: u32,
	jitter_ms, loss_permyriad, duplicate_permyriad: u32,
	rng: r.Rng,
	dropped, duplicated, retired: u64,
	packets: []Delayed_Packet,
	storage: []u8,
}

delay_init :: proc(d: ^Delay, base: Transport, latency_ms: u32, capacity: int = 128,
                   allocator := context.allocator) -> bool {
	if len(d.packets) != 0 || capacity < 1 || capacity > 1024 || latency_ms > 10000 {return false}
	d.allocator, d.base, d.latency_ms = allocator, base, latency_ms
	d.rng = r.rng_make(1)
	d.packets = make([]Delayed_Packet, capacity, allocator)
	d.storage = make([]u8, capacity * MAX_PACKET_BYTES, allocator)
	return true
}

// Simulate the application's channel boundary: reliable traffic remains ordered
// and delivered, while unreliable traffic may be lost, duplicated, or reordered.
// This does not claim to model ENet's lower-level retransmission/congestion loop.
delay_faults :: proc(d: ^Delay, jitter_ms, loss_permyriad, duplicate_permyriad: u32, seed: u64 = 1) -> bool {
	if jitter_ms > 10000 || loss_permyriad > 10000 || duplicate_permyriad > 10000 {return false}
	d.jitter_ms, d.loss_permyriad, d.duplicate_permyriad, d.rng = jitter_ms, loss_permyriad, duplicate_permyriad, r.rng_make(seed)
	return true
}

delay_time :: proc(d: ^Delay, now_ms: u64) -> bool {
	if now_ms < d.now {return false}
	d.now = now_ms
	return true
}

delay_transport :: proc(d: ^Delay) -> Transport {
	return {user = d, send = delay_send, receive = delay_receive, poll = delay_poll, status = delay_status, close = delay_close, connected = delay_connected, generation = delay_generation}
}

@(private)
delay_connected :: proc(user: rawptr, peer: Peer_Id) -> bool {return peer_connected(&(cast(^Delay)user).base, peer)}

@(private)
delay_send :: proc(user: rawptr, to: Peer_Id, channel: Channel, bytes: []u8) -> Send_Result {
	d := cast(^Delay)user
	return send(&d.base, to, channel, bytes)
}

@(private)
delay_poll :: proc(user: rawptr) {
	d := cast(^Delay)user
	poll(&d.base)
	for &slot in d.packets {if slot.active && slot.received.generation != peer_generation(&d.base,slot.received.from) {slot.active=false;d.retired+=1}}
	for &slot, i in d.packets {
		if slot.active {continue}
		bytes := d.storage[i * MAX_PACKET_BYTES:(i + 1) * MAX_PACKET_BYTES]
		packet := receive(&d.base, bytes)
		if packet.state == .Empty || packet.state == .Disconnected {return}
		if packet.state == .Received && packet.channel == .Unreliable && r.rng_next(&d.rng) % 10000 < u64(d.loss_permyriad) {
			d.dropped += 1
			continue
		}
		d.sequence += 1
		due := saturating_add(d.now, u64(d.latency_ms) + r.rng_next(&d.rng) % (u64(d.jitter_ms) + 1))
		if packet.channel == .Reliable {
			for earlier in d.packets {
				if earlier.active && earlier.received.from == packet.from && earlier.received.channel == .Reliable {due = max(due, earlier.due)}
			}
		}
		slot = {active = true, due = due, sequence = d.sequence, received = packet}
		if packet.state == .Received && packet.channel == .Unreliable && r.rng_next(&d.rng) % 10000 < u64(d.duplicate_permyriad) {
			for &duplicate, j in d.packets {
				if duplicate.active {continue}
				d.sequence += 1
				duplicate = {active = true, due = saturating_add(due, r.rng_next(&d.rng) % (u64(d.jitter_ms) + 1)), sequence = d.sequence, received = packet}
				copy(d.storage[j * MAX_PACKET_BYTES:j * MAX_PACKET_BYTES + packet.count], bytes[:packet.count])
				d.duplicated += 1
				break
			}
		}
	}
}

@(private)
delay_receive :: proc(user: rawptr, dst: []u8) -> Received {
	d := cast(^Delay)user
	index := -1
	for &slot, i in d.packets {
		if slot.active && slot.received.generation != peer_generation(&d.base,slot.received.from) {slot.active=false;d.retired+=1}
		if !slot.active || slot.due > d.now {continue}
		if index < 0 || slot.due < d.packets[index].due || (slot.due == d.packets[index].due && slot.sequence < d.packets[index].sequence) {index = i}
	}
	if index < 0 {return {state = .Empty}}
	slot := &d.packets[index]
	result := slot.received
	if result.state == .Received {
		if len(dst) < result.count {result.state = .Buffer_Too_Small; return result}
		copy(dst, d.storage[index * MAX_PACKET_BYTES:index * MAX_PACKET_BYTES + result.count])
	}
	slot.active = false
	return result
}

@(private)
delay_status :: proc(user: rawptr) -> Status {return status(&(cast(^Delay)user).base)}

@(private)
delay_close :: proc(user: rawptr) {
	d := cast(^Delay)user
	close(&d.base)
	delete(d.packets, d.allocator)
	delete(d.storage, d.allocator)
	d^ = {}
}

@(private)
delay_generation :: proc(user: rawptr, peer: Peer_Id) -> u64 {return peer_generation(&(cast(^Delay)user).base,peer)}
