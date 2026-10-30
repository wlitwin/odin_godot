package replay_p2p

import "core:reflect"
import r "godot:replay"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

pump :: proc(p: ^Runner($S, $I, $E, $N), now_ms: u64) -> Error {
	if !p.ready {return .Not_Ready}
	if p.phase == .Failed || p.phase == .Diverged {return p.error}
	if p.phase == .Disconnected {return .Transport}
	if p.time_set && now_ms < p.now {return .Time}
	started, timed := r.profile_read(p.profile.clock)
	defer r.timing_finish(&p.profile.metrics[.Pump], p.profile.clock, started, timed)
	if !p.time_set {p.started = now_ms; for &seen in p.last_seen {seen = now_ms}}
	p.now, p.time_set = now_ms, true
	tr.poll(&p.wire)
	for _ in 0 ..< 64 {
		packet := tr.receive(&p.wire, p.rx)
		if packet.state == .Empty {break}
		if packet.state != .Received {p.stats.rejected += 1; continue}
		if packet.count > MAX_PACKET {p.stats.rejected += 1; continue}
		peer := -1
		for id, i in p.roster {if i != int(p.local) && id == packet.from {peer = i; break}}
		if peer < 0 {p.stats.rejected += 1; continue}
		p.stats.rx_bytes += u64(packet.count)
		receive(p, peer, p.rx[:packet.count])
		if p.phase == .Failed || p.phase == .Diverged {return p.error}
	}
	all := true
	for seen in p.hello_seen {all = all && seen}
	if all {p.phase = .Running}
	if p.phase == .Running {
		if err := repair(p); err != .None {fail(p, err); return err}
		if err := settle(p); err != .None {fail(p, err); return err}
	}
	broadcast(p, false)
	for seen, i in p.last_seen {
		if i == int(p.local) {continue}
		if p.now - seen > p.cfg.timeout_ms {p.phase, p.error = .Disconnected, .Transport; return .Transport}
	}
	return .None
}

@(private)
broadcast :: proc(p: ^Runner($S, $I, $E, $N), force: bool) {
	for peer, i in p.roster {
		if i == int(p.local) {continue}
		if !force && p.sent_once[i] && p.now - p.sent_at[i] < p.cfg.retry_ms {continue}
		// Continuing Hello packets acknowledge the contract independently of
		// input delivery, so one side cannot strand the other's handshake.
		hello := Hello{p.cfg.session, p.contract, p.initial_tick, p.initial_hash, p.received[i]}
		if !send(p, i, &p.hello_codec, HELLO, hello) {continue}
		p.sent_at[i], p.sent_once[i] = p.now, true
		if !p.hello_seen[i] {continue}
		packet := Packet(I){contract = p.contract, ack = p.received[i], hash_tick = p.hash_tick, hash = p.chain}
		for &value in packet.values {value = p.model.neutral}
		if p.acknowledged[i] < p.sampled {
			packet.start = p.acknowledged[i] + 1
			for offset in 0 ..< WINDOW {
				tick := packet.start + u64(offset)
				if tick > p.sampled {break}
				slot := input_slot(p, int(p.local), tick)
				if !slot.valid || slot.tick != tick {fail(p, .History); return}
				packet.values[offset] = slot.value
				packet.count += 1
			}
		}
		send(p, i, &p.packet_codec, INPUTS, packet)
	}
}

@(private)
send :: proc(p: ^Runner($S, $I, $E, $N), peer: int, codec: ^sc.Schema, kind: u16, value: $T) -> bool {
	n := sc.HEADER_BYTES + codec.wire_size
	if sc.pack(codec, value, {kind = kind, epoch = p.cfg.epoch, tick = p.timeline.head, content = p.cfg.content}, p.tx).error != .None {return false}
	if tr.send(&p.wire, p.roster[peer], .Unreliable, p.tx[:n]) != .Sent {return false}
	p.stats.tx_bytes += u64(n)
	return true
}

@(private)
receive :: proc(p: ^Runner($S, $I, $E, $N), peer: int, bytes: []u8) {
	meta, _, header := sc.inspect(bytes)
	if header.error != .None {p.stats.rejected += 1; return}
	expected := sc.Envelope_Meta{kind = meta.kind, epoch = p.cfg.epoch, content = p.cfg.content}
	if meta.kind == HELLO {
		packet: Hello
		_, report := sc.unpack(&p.hello_codec, &packet, bytes, expected)
		if report.error != .None {p.stats.rejected += 1; return}
		if packet.session != p.cfg.session {p.stats.rejected += 1; return}
		if packet.contract != p.contract || packet.initial_tick != p.initial_tick || packet.initial_hash != p.initial_hash {fail(p, .Invalid_Model); return}
		if !p.hello_seen[peer] {
			// A restored/reconnected peer may have forgotten a formerly ACKed
			// suffix. Rebase delivery to its durable frontier, never regenerate it.
			if packet.received < p.initial_tick + u64(p.cfg.delay) || packet.received > p.sampled || p.sampled - packet.received > u64(p.cfg.history) {fail(p, .History); return}
			for tick := packet.received + 1; tick <= p.sampled; tick += 1 {
				slot := input_slot(p, int(p.local), tick)
				if !slot.valid || slot.tick != tick {fail(p, .History); return}
			}
			p.acknowledged[peer] = packet.received
		}
		p.hello_seen[peer], p.last_seen[peer] = true, p.now
		return
	}
	if meta.kind != INPUTS || !p.hello_seen[peer] {p.stats.rejected += 1; return}
	packet: Packet(I)
	_, report := sc.unpack(&p.packet_codec, &packet, bytes, expected)
	if report.error != .None || packet.contract != p.contract || packet.count > WINDOW || packet.ack > p.sampled || packet.hash_tick < p.initial_tick || packet.hash_tick > meta.tick ||
	   (packet.hash_tick > p.timeline.head && packet.hash_tick - p.timeline.head >= u64(p.cfg.history)) ||
	   (packet.count != 0 && (packet.start <= p.initial_tick + u64(p.cfg.delay) || packet.start > max(u64) - u64(packet.count - 1) ||
	    meta.tick > max(u64) - u64(p.cfg.delay) - 1 || packet.start + u64(packet.count - 1) > meta.tick + u64(p.cfg.delay) + 1)) {
		p.stats.rejected += 1; return
	}
	for value, offset in packet.values[:packet.count] {
		tick := packet.start + u64(offset)
		if !p.model.input_valid(value) || (tick > p.timeline.head && tick - p.timeline.head >= u64(p.cfg.history)) {p.stats.rejected += 1; return}
		slot := input_slot(p, peer, tick)
		if slot.valid && slot.tick == tick && !reflect.equal(slot.value, value) {fail(p, .Conflict); return}
		if tick <= p.timeline.confirmed {continue}
		if slot.valid && slot.tick != tick && slot.tick > p.timeline.confirmed {p.stats.rejected += 1; return}
	}
	for value, offset in packet.values[:packet.count] {
		tick := packet.start + u64(offset)
		slot := input_slot(p, peer, tick)
		if slot.valid && slot.tick == tick {p.stats.duplicate_inputs += 1; continue}
		if tick <= p.timeline.confirmed {continue}
		if tick <= p.timeline.head {
			old, found := r.read_input(&p.timeline, tick)
			if !found {fail(p, .History); return}
			if !reflect.equal(old[peer], value) {p.dirty = p.dirty == 0 ? tick : min(p.dirty, tick)}
		}
		slot^ = {tick, value, true}
	}
	for p.received[peer] < max(u64) {
		tick := p.received[peer] + 1
		slot := input_slot(p, peer, tick)
		if !slot.valid || slot.tick != tick {break}
		p.received[peer] = tick
	}
	p.acknowledged[peer] = max(p.acknowledged[peer], packet.ack)
	if !p.remote_hash[peer].valid || packet.hash_tick > p.remote_hash[peer].tick {
		p.remote_hash[peer] = {packet.hash_tick, packet.hash, true}
	} else if packet.hash_tick == p.remote_hash[peer].tick && packet.hash != p.remote_hash[peer].value {fail(p, .Conflict); return}
	p.last_seen[peer] = p.now
}
