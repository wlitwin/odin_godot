package replay_net_legacy

import "core:reflect"
import r "godot:replay"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

server_init :: proc(s: ^Server($State, $Control, $Action, $Event, $Seats), initial: r.Frame(State),
                    model: Model(State, Control, Action, Event, Seats), wire: tr.Transport,
                    cfg := DEFAULT_CONFIG, local_seat: u16 = 0, allocator := context.allocator, permit: Permit = {}, incarnation: u64 = 0) -> Error {
	#assert(Seats >= 1 && Seats <= 8)
	if s.initialized || !config_valid(cfg) || int(local_seat) > Seats {return .Invalid_Config}
	if cfg.require_permit && permit.allow == nil {return .Fenced}
	if (model.step == nil && model.step_view == nil) || model.control_valid == nil || model.hold == nil || model.state_valid == nil ||
	   !model.control_valid(model.neutral) || !model.state_valid(initial.state) || !group_config_valid(model.group) || !replication_config_valid(model.replication) || model.control_timing > .Latest_Observation {return .Invalid_Model}
	s.allocator, s.model, s.cfg, s.wire, s.local_seat = allocator, model, cfg, wire, local_seat
	s.permit = permit
	if !codecs_init(&s.codecs, State, Control, Action, Event, Seats, allocator,model.replication.id!=0) {server_destroy(s); return .Invalid_Schema}
	s.contract = contract_hash(&s.codecs, cfg, Seats, model.control_timing, replication=model.replication.id)
	thunk := proc(state: ^State, input: Batch(Control, Action, Seats), ctx: ^r.Step(Net_Event(Event))) {network_step(state, input, ctx)}
	frame_error := r.init(&s.timeline, initial, thunk, cfg = {cfg.history, WIRE_EVENTS}, epoch = cfg.epoch,
	                      allocator = allocator, user = &s.model)
	if frame_error != .None {server_destroy(s); s.frame_error = frame_error; return .Invalid_Frame}
	s.inputs = make([]Input_Slot(Control), MAX_PEERS * cfg.history, allocator)
	s.facts = make([]Facts_Packet(Event), cfg.history, allocator)
	s.checkpoints = make([]Welcome_Packet(State, Control, Seats), MAX_PEERS, allocator)
	s.rxb = make([]u8, tr.MAX_PACKET_BYTES, allocator)
	s.txb = make([]u8, tr.MAX_PACKET_BYTES, allocator)
	for &tx in s.snapshot_tx {
		if !snapshot_tx_init(&tx, s.codecs.snapshot.wire_size, cfg.snapshot_history, allocator) {server_destroy(s); return .Invalid_Config}
	}
	maximum := max(s.codecs.welcome.wire_size, max(s.codecs.snapshot.wire_size, s.codecs.facts.wire_size)) + sc.HEADER_BYTES
	if cfg.egress_bytes_per_pump < maximum {server_destroy(s); return .Invalid_Config}
	s.tx_remaining = cfg.egress_bytes_per_pump
	for &held in s.held {held = model.neutral}
	if local_seat != 0 {
		s.peers[0] = {phase = .Running, local = true, seat = local_seat, incarnation = incarnation}
		s.joins |= u64(1) << uint(local_seat - 1)
		s.fresh |= u64(1) << uint(local_seat - 1)
	}
	s.initialized = true
	return .None
}

server_destroy :: proc(s: ^Server($State, $Control, $Action, $Event, $Seats)) {
	r.destroy(&s.timeline)
	codecs_destroy(&s.codecs)
	delete(s.inputs, s.allocator)
	delete(s.facts, s.allocator)
	delete(s.checkpoints, s.allocator)
	delete(s.rxb, s.allocator)
	delete(s.txb, s.allocator)
	for &tx in s.snapshot_tx {snapshot_tx_destroy(&tx)}
	s^ = {}
}

server_local :: proc(s: ^Server($State, $Control, $Action, $Event, $Seats), control: Control) -> Error {
	if !s.initialized || s.local_seat == 0 {return .Wrong_Phase}
	if !permitted(s.cfg.require_permit, s.permit, s.cfg.epoch) {return .Fenced}
	if !s.model.control_valid(control) {return .Invalid_Input}
	s.held[s.local_seat - 1] = control
	return .None
}

server_issue :: proc(s: ^Server($State, $Control, $Action, $Event, $Seats), action: Action) -> (sequence: u64, error: Error) {
	if !s.initialized || s.local_seat == 0 {return 0, .Wrong_Phase}
	if !permitted(s.cfg.require_permit, s.permit, s.cfg.epoch) {return 0, .Fenced}
	if s.model.action == nil || s.model.action_valid == nil || !s.model.action_valid(action) {return 0, .Invalid_Input}
	peer: ^Peer(Action)
	for &candidate in s.peers {if candidate.local && candidate.seat == s.local_seat {peer = &candidate; break}}
	if peer == nil {return 0, .Wrong_Phase}
	if peer.action_count == ACTION_CAPACITY || peer.action_received >= max(u64) >> 8 {return 0, .Capacity}
	if s.timeline.head == max(u64) {return 0, .Capacity}
	reason := Action_Reason.None
	if s.model.action_admit != nil && !s.model.action_admit(s.model.action_admission_user, s.local_seat, action) {reason = .Invalid}
	if !permitted(s.cfg.require_permit, s.permit, s.cfg.epoch) {return 0, .Fenced}
	peer.action_received += 1
	peer.actions[(peer.action_head + peer.action_count) % ACTION_CAPACITY] = {
		sequence = peer.action_received, tick = s.timeline.head + 1, value = action, reason = reason,
	}
	peer.action_count += 1
	return peer.action_received, .None
}

server_pump :: proc(s: ^Server($State, $Control, $Action, $Event, $Seats), now_ms: u64) -> Error {
	if !s.initialized {return .Not_Initialized}
	started, timed := profile_start(s.profile_clock)
	defer profile_finish(&s.profile_metrics, .Pump, s.profile_clock, started, timed, s.profile_user, s.profile_sample)
	if !permitted(s.cfg.require_permit, s.permit, s.cfg.epoch) {tr.poll(&s.wire); return .Fenced}
	if s.time_set && now_ms < s.now {return .Invalid_Time}
	dt := s.time_set ? f64(now_ms - s.now) / 1000 : 0
	s.now, s.time_set = now_ms, true
	s.tx_remaining = s.cfg.egress_bytes_per_pump
	for &peer in s.peers {
		peer.budget_packets = min(peer.budget_packets + dt * 240, 480)
		peer.budget_bytes = min(peer.budget_bytes + dt * 256 * 1024, 512 * 1024)
		peer.send_budget = min(peer.send_budget + dt * f64(s.cfg.egress_bytes_per_second), server_burst(s))
		if peer.local || (peer.phase != .Running && peer.phase != .Pending) {continue}
		if s.now - peer.last_seen > s.cfg.timeout_ms {server_drop(s, &peer)}
	}
	tr.poll(&s.wire)
	for &peer in s.peers {
		if !peer.local && (peer.phase == .Running || peer.phase == .Pending) && !tr.peer_connected(&s.wire, peer.connection) {
			server_drop(s, &peer)
		}
		if !peer.local && (peer.phase == .Running || peer.phase == .Pending) && s.identity_check != nil &&
		   !s.identity_check(s.identity_user, peer.token_hash, peer.incarnation) {server_drop(s, &peer)}
	}
	bytes := 0
	for _ in 0 ..< s.cfg.packets_per_pump {
		packet := tr.receive(&s.wire, s.rxb)
		if packet.state == .Empty || packet.state == .Disconnected {break}
		if packet.state != .Received {s.stats.rejected_packets += 1; continue}
		bytes += packet.count
		s.stats.rx_packets += 1
		s.stats.rx_bytes += u64(packet.count)
		if bytes > s.cfg.bytes_per_pump {s.stats.rejected_packets += 1; break}
		if !permitted(s.cfg.require_permit, s.permit, s.cfg.epoch) {return .Fenced}
		server_receive(s, packet.from, s.rxb[:packet.count])
	}
	server_flush(s)
	return .None
}

server_step :: proc(s: ^Server($State, $Control, $Action, $Event, $Seats)) -> Error {
	if !s.initialized {return .Not_Initialized}
	if !permitted(s.cfg.require_permit, s.permit, s.cfg.epoch) {return .Fenced}
	if s.timeline.head == max(u64) {return .Simulation}
	tick := s.timeline.head + 1
	batch := Batch(Control, Action, Seats){joins = s.joins, leaves = s.leaves, fresh = s.fresh}
	held := s.held
	views := s.held_views
	for &control in batch.controls {control = s.model.neutral}
	for &peer, index in s.peers {
		if peer.seat == 0 || peer.phase == .Vacant {continue}
		seat := int(peer.seat - 1)
		if peer.phase != .Disconnected {
			if !peer.local {
				slot := &s.inputs[index * s.cfg.history + int(tick % u64(s.cfg.history))]
				if slot.tick == tick {held[seat], views[seat] = slot.value, slot.view} else {
					held[seat] = s.model.hold(held[seat]); s.stats.held_inputs += 1
				}
			}
			if !s.model.control_valid(held[seat]) {return .Invalid_Model}
			batch.controls[seat] = held[seat]
			if peer.local {views[seat] = {tick, tick, 0, .Live}}
			if views[seat].status == .Historical && f64(tick) - view_position(views[seat]) > f64(s.cfg.max_rewind) {views[seat].status = .Expired; s.stats.expired_views += 1}
			batch.views[seat] = views[seat]
		}
		if peer.action_count > 0 {
			action := &peer.actions[peer.action_head]
			if action.tick <= tick {
				batch.has_action[seat] = true
				batch.actions[seat] = action.value
				batch.sequences[seat] = action.sequence
				batch.rejections[seat] = action.reason
			}
		}
	}
	gate: r.Commit_Gate
	if s.cfg.require_permit {gate = s.permit}
	started, timed := profile_start(s.profile_clock)
	result := r.advance(&s.timeline, batch, gate)
	profile_finish(&s.profile_metrics, .Advance, s.profile_clock, started, timed, s.profile_user, s.profile_sample)
	if result.error == .Commit_Rejected {return .Fenced}
	if result.error != .None {return .Simulation}
	s.held = held
	s.held_views = views
	s.joins, s.leaves, s.fresh = 0, 0, 0
	r.confirm_through(&s.timeline, tick)
	fact := &s.facts[tick % u64(s.cfg.history)]
	fact^ = {tick = tick}
	n, err := r.copy_events(&s.timeline, tick, fact.events[:])
	if err != .None {return .Simulation}
	fact.count = u16(n)
	for occurrence in fact.events[:n] {
		event := occurrence.value
		if event.kind != .Action_Result {continue}
		for &peer in s.peers {
			if peer.seat != event.seat || peer.action_count == 0 {continue}
			if peer.actions[peer.action_head].sequence != event.sequence {continue}
			peer.action_settled = event.sequence
			peer.action_head = (peer.action_head + 1) % ACTION_CAPACITY
			peer.action_count -= 1
			if peer.recent_count == ACTION_CAPACITY {peer.recent_head = (peer.recent_head + 1) % ACTION_CAPACITY; peer.recent_count -= 1}
			peer.recent[(peer.recent_head + peer.recent_count) % ACTION_CAPACITY] = {event.sequence, tick, event.applied, event.reason}
			peer.recent_count += 1
		}
	}
	// A joining client's checkpoint includes the tick that created its avatar.
	for &peer, index in s.peers {
		if peer.phase == .Pending {server_checkpoint(s, index)}
	}
	server_flush(s)
	return .None
}

@(private)
server_receive :: proc(s: ^Server($State, $Control, $Action, $Event, $Seats), from: tr.Peer_Id, bytes: []u8) {
	meta, _, report := sc.inspect(bytes)
	if report.error != .None {s.stats.rejected_packets += 1; return}
	if meta.kind == u16(Kind.Hello) {
		hello: Hello_Packet
		_, report = sc.unpack(&s.codecs.hello, &hello, bytes, meta)
		if report.error != .None {s.stats.rejected_packets += 1; return}
		if meta.epoch != s.cfg.epoch || meta.content != s.cfg.content || hello.contract != s.contract {
			server_reject(s, from, .Contract, meta); return
		}
		if !token_valid(hello.token) {server_reject(s, from, .Invalid_Token, meta); return}
		token_hash := token_digest(hello.token)
		if s.identity_check != nil && !s.identity_check(s.identity_user, token_hash, hello.incarnation) {server_reject(s, from, .Denied, meta); return}
		for peer in s.peers {if peer.local && peer.token_hash == token_hash {server_reject(s, from, .Token_In_Use, meta); return}}
		for banned in s.banned[:s.banned_count] {if banned == token_hash {server_reject(s, from, .Banned, meta); return}}
		if s.admission != nil && !s.admission(s.admission_user, token_hash, hello.spectator) {server_reject(s, from, .Denied, meta); return}
		if !hello.spectator && s.codecs.state.excluded_fields != 0 && s.model.replication.id==0 {server_reject(s, from, .Projection, meta); return}
		index := -1
		for &peer, i in s.peers {
			if peer.local || peer.phase == .Vacant || peer.token_hash != token_hash {continue}
			if peer.phase != .Disconnected && peer.connection != from {
				if s.identity_check != nil && hello.incarnation > peer.incarnation {server_drop(s, &peer)} else {server_reject(s, from, .Token_In_Use, meta); return}
			}
			if peer.spectator != hello.spectator {server_reject(s, from, .Denied, meta); return}
			index = i
			if peer.phase == .Running || peer.phase == .Pending {
				peer.last_seen = s.now
				if peer.phase == .Running {peer.checkpoint_pending = true}
				return
			}
			break
		}
		// One connection cannot reserve several seats/tokens.
		for peer in s.peers {
			if (peer.phase == .Running || peer.phase == .Pending) && peer.connection == from {
				server_reject(s, from, .Denied, meta); return
			}
		}
		if index < 0 {
			if s.locked {server_reject(s, from, .Locked, meta); return}
			for peer, i in s.peers {if peer.phase == .Vacant {index = i; break}}
			if index < 0 {server_reject(s, from, .Full, meta); return}
			seat := u16(0)
			if !hello.spectator {
				for candidate in 1 ..= Seats {
					used := false
					for peer in s.peers {if peer.phase != .Vacant && int(peer.seat) == candidate {used = true; break}}
					if !used {seat = u16(candidate); break}
				}
				if seat == 0 {server_reject(s, from, .Full, meta); return}
			}
			s.peers[index] = {seat = seat, spectator = hello.spectator, token_hash = token_hash}
			if seat != 0 {s.fresh |= u64(1) << uint(seat - 1)}
		}
		peer := &s.peers[index]
		peer.incarnation = hello.incarnation
		s.generation += 1
		peer.generation, peer.connection, peer.phase, peer.last_seen = s.generation, from, .Pending, s.now
		peer.budget_packets, peer.budget_bytes = 480, 512 * 1024
		peer.send_budget = server_burst(s)
		peer.request_seen = 0
		peer.echo_ms = hello.sent_ms
		for &slot in s.inputs[index * s.cfg.history:(index + 1) * s.cfg.history] {slot = {}}
		peer.input_newest = 0
		if peer.seat != 0 {
			s.joins |= u64(1) << uint(peer.seat - 1)
			s.leaves &= ~(u64(1) << uint(peer.seat - 1))
		}
		return
	}
	index := -1
	for peer, i in s.peers {if peer.phase == .Running && !peer.local && peer.connection == from {index = i; break}}
	if index < 0 {s.stats.rejected_packets += 1; return}
	peer := &s.peers[index]
	if peer.budget_packets < 1 || peer.budget_bytes < f64(len(bytes)) {s.stats.rejected_packets += 1; return}
	peer.budget_packets -= 1
	peer.budget_bytes -= f64(len(bytes))
	expected := sc.Envelope_Meta{kind = meta.kind, epoch = s.cfg.epoch, content = s.cfg.content}
	#partial switch Kind(meta.kind) {
	case .Inputs, .Inputs_Compact:
		packet: Inputs_Packet(Control)
		decoded:=false
		if meta.kind==u16(Kind.Inputs_Compact) {decoded=compact_inputs_decode(&s.codecs,&packet,bytes,expected)} else {
			_,report=sc.unpack(&s.codecs.inputs,&packet,bytes,expected);decoded=report.error==.None
		}
		if s.model.control_timing != .Scheduled || !decoded || packet.generation != peer.generation || packet.serial != peer.serial ||
		   peer.spectator || packet.count == 0 || packet.count > INPUT_WINDOW {s.stats.rejected_inputs += 1; return}
		for sample, i in packet.samples[:packet.count] {
			if sample.tick == 0 || (sample.tick > s.timeline.head && sample.tick - s.timeline.head > u64(s.cfg.max_future)) ||
			   !s.model.control_valid(sample.value) {s.stats.rejected_inputs += 1; return}
			if i > 0 && packet.samples[i - 1].tick >= sample.tick {s.stats.rejected_inputs += 1; return}
		}
		for sample in packet.samples[:packet.count] {
			if sample.tick <= s.timeline.head {continue}
			slot := &s.inputs[index * s.cfg.history + int(sample.tick % u64(s.cfg.history))]
			if slot.tick == sample.tick {continue} // first accepted value for this tick wins
			slot^ = {sample.tick, sample.value, server_view(s, index, sample.view)}
			peer.input_newest = max(peer.input_newest, sample.tick)
		}
		peer.last_seen = s.now
	case .Observation:
		packet: Observation_Packet(Control)
		_, report = sc.unpack(&s.codecs.observation, &packet, bytes, expected)
		sample := packet.sample
		if s.model.control_timing != .Latest_Observation || report.error != .None || packet.generation != peer.generation || packet.serial != peer.serial || peer.spectator ||
		   sample.tick == 0 || sample.tick != meta.tick || !s.model.control_valid(sample.value) ||
		   (sample.tick > s.timeline.head && sample.tick - s.timeline.head > u64(s.cfg.max_future)) {s.stats.rejected_inputs += 1; return}
		if sample.tick > peer.input_newest && (sample.tick > s.timeline.head || s.timeline.head - sample.tick < u64(s.cfg.history)) {
			if s.timeline.head == max(u64) {s.stats.rejected_inputs += 1; return}
			due := s.timeline.head + 1
			slot := &s.inputs[index * s.cfg.history + int(due % u64(s.cfg.history))]
			slot^ = {due, sample.value, server_view(s, index, sample.view)}
			peer.input_newest = sample.tick
		}
		peer.last_seen = s.now
	case .Action:
		packet: Action_Packet(Action)
		_, report = sc.unpack(&s.codecs.action, &packet, bytes, expected)
		if report.error != .None || packet.generation != peer.generation || packet.serial != peer.serial || peer.spectator ||
		   packet.sequence == 0 || packet.sequence > max(u64) >> 8 {s.stats.rejected_packets += 1; return}
		peer.last_seen = s.now
		if packet.sequence <= peer.action_received {s.stats.duplicate_actions += 1; return}
		if packet.sequence != peer.action_received + 1 || peer.action_count == ACTION_CAPACITY {s.stats.rejected_packets += 1; return}
		reason := Action_Reason.None
		if s.model.action == nil || s.model.action_valid == nil || !s.model.action_valid(packet.value) {reason = .Invalid}
		if packet.tick <= s.timeline.head {reason = .Stale}
		if packet.tick > s.timeline.head && packet.tick - s.timeline.head > u64(s.cfg.max_future) {reason = .Future}
		if reason == .None && s.model.action_admit != nil && !s.model.action_admit(s.model.action_admission_user, peer.seat, packet.value) {reason = .Invalid}
		if !permitted(s.cfg.require_permit, s.permit, s.cfg.epoch) {return}
		due := reason == .None ? packet.tick : s.timeline.head + 1
		peer.actions[(peer.action_head + peer.action_count) % ACTION_CAPACITY] = {sequence = packet.sequence, tick = due, value = packet.value, reason = reason}
		peer.action_count += 1
		peer.action_received = packet.sequence
	case .Resync:
		packet: Request_Packet
		_, report = sc.unpack(&s.codecs.request, &packet, bytes, expected)
		if report.error != .None || packet.generation != peer.generation || packet.sequence == 0 {s.stats.rejected_packets += 1; return}
		peer.last_seen = s.now
		if packet.sequence > peer.request_seen {peer.request_seen = packet.sequence; peer.echo_ms = packet.sent_ms; server_checkpoint(s, index)}
		peer.checkpoint_pending = true
	case .Heartbeat:
		packet: Request_Packet
		_, report = sc.unpack(&s.codecs.request, &packet, bytes, expected)
		if report.error != .None || packet.generation != peer.generation || packet.serial != peer.serial {s.stats.rejected_packets += 1; return}
		peer.last_seen = s.now
	case .Snapshot_Ack, .Baseline_Miss:
		ack: Snapshot_Ack
		_, report = sc.unpack(&s.codecs.snapshot_ack, &ack, bytes, expected)
		if report.error != .None {s.stats.rejected_acks += 1; return}
		server_snapshot_ack(s, index, ack, meta.kind == u16(Kind.Baseline_Miss))
	case:
		s.stats.rejected_packets += 1
	}
}

@(private)
server_reject :: proc(s: ^Server($State, $Control, $Action, $Event, $Seats), to: tr.Peer_Id, reason: Reject, meta: sc.Envelope_Meta) {
	s.stats.rejected_packets += 1
	envelope := meta
	envelope.kind = u16(Kind.Reject)
	if sc.pack(&s.codecs.reject, Reject_Packet{reason}, envelope, s.txb).error == .None {
		server_send(s, to, .Reliable, s.txb[:sc.HEADER_BYTES + s.codecs.reject.wire_size])
	}
}

@(private)
server_checkpoint :: proc(s: ^Server($State, $Control, $Action, $Event, $Seats), index: int) {
	peer := &s.peers[index]
	frame, _ := r.current(&s.timeline)
	value,ok:=replica_project(s.model,frame,s.held,Recipient{peer.seat,peer.spectator},&s.codecs.replica,s.txb)
	if !ok {s.stats.rejected_replica_views+=1;peer.checkpoint_pending=false;return}
	peer.serial += 1
	peer.welcome_view = {}
	peer.rtt_floor_ms, peer.rtt_floor_until = 0, 0
	snapshot_tx_reset(&s.snapshot_tx[index])
	frame.state=value.state
	checkpoint := &s.checkpoints[index]
	checkpoint^ = {generation = peer.generation, serial = peer.serial, seat = peer.seat,
	               echo_ms = peer.echo_ms,
	               action_settled = peer.action_settled, action_received = peer.action_received,
	               frame = frame, held = value.held, completed_count = u8(peer.recent_count)}
	for i in 0 ..< peer.recent_count {checkpoint.completed[i] = peer.recent[(peer.recent_head + i) % ACTION_CAPACITY]}
	peer.checkpoint_pending = true
}

@(private)
server_flush :: proc(s: ^Server($State, $Control, $Action, $Event, $Seats)) {
	start := s.flush_cursor
	s.flush_cursor = (s.flush_cursor + 1) % MAX_PEERS
	for offset in 0 ..< MAX_PEERS {
		index := (start + offset) % MAX_PEERS
		peer := &s.peers[index]
		if peer.local || (peer.phase != .Running && peer.phase != .Pending) {continue}
		if peer.checkpoint_pending {
			checkpoint := &s.checkpoints[index]
			meta := sc.Envelope_Meta{kind = u16(Kind.Welcome), epoch = s.cfg.epoch, tick = checkpoint.frame.tick, content = s.cfg.content}
			if sc.pack(&s.codecs.welcome, checkpoint^, meta, s.txb).error != .None {continue}
			if server_send(s, peer.connection, .Reliable, s.txb[:sc.HEADER_BYTES + s.codecs.welcome.wire_size]) != .Sent {continue}
			peer.checkpoint_pending = false
			peer.welcome_view = {tick = checkpoint.frame.tick, sent_ms = s.now, valid = true}
			peer.phase = .Running
			peer.facts_sent = max(peer.facts_sent, checkpoint.frame.tick)
		}
		if peer.phase != .Running {continue}
		if s.timeline.head - peer.facts_sent >= u64(s.cfg.history) {server_checkpoint(s, index); continue}
		for _ in 0 ..< 8 {
			if peer.facts_sent >= s.timeline.head {break}
			tick := peer.facts_sent + 1
			fact := s.facts[tick % u64(s.cfg.history)]
			if fact.tick != tick {server_checkpoint(s, index); break}
			fact.generation, fact.serial = peer.generation, peer.serial
			if s.model.replication.id!=0 {
				historical,found:=r.read(&s.timeline,tick);if !found {server_checkpoint(s,index);break}
				count:=fact.count;fact=replica_facts(s.model,historical,Recipient{peer.seat,peer.spectator},fact)
				s.stats.filtered_events+=u64(count-fact.count)
			}
			meta := sc.Envelope_Meta{kind = u16(Kind.Facts), epoch = s.cfg.epoch, tick = tick, content = s.cfg.content}
			size, ok := pack_facts(&s.codecs, fact, meta, s.txb)
			if !ok {break}
			if server_send(s, peer.connection, .Reliable, s.txb[:size]) != .Sent {break}
			peer.facts_sent = tick
		}
		if s.timeline.head == 0 {continue}
		if !s.snapshot_tx[index].force_full && (s.timeline.head % u64(s.cfg.snapshot_every) != 0 || peer.snapshot_sent == s.timeline.head) {continue}
		server_snapshot(s, index)
	}
}

@(private)
server_send :: proc(s: ^Server($State, $Control, $Action, $Event, $Seats), to: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> tr.Send_Result {
	if !permitted(s.cfg.require_permit, s.permit, s.cfg.epoch) {return .Backpressure}
	peer: ^Peer(Action)
	for &candidate in s.peers {if candidate.connection == to && candidate.phase != .Vacant {peer = &candidate; break}}
	if len(bytes) > s.tx_remaining || (peer != nil && peer.send_budget < f64(len(bytes))) {
		s.stats.egress_deferred += 1
		return .Backpressure
	}
	result := tr.send(&s.wire, to, channel, bytes)
	if result == .Sent {
		s.stats.tx_packets += 1; s.stats.tx_bytes += u64(len(bytes))
		s.tx_remaining -= len(bytes)
		if peer != nil {peer.send_budget -= f64(len(bytes))}
	}
	return result
}

@(private)
server_burst :: proc(s: ^Server($State, $Control, $Action, $Event, $Seats)) -> f64 {
	maximum := max(s.codecs.welcome.wire_size, max(s.codecs.snapshot.wire_size, s.codecs.facts.wire_size)) + sc.HEADER_BYTES
	return f64(max(s.cfg.egress_bytes_per_second * 2, maximum))
}

@(private)
server_drop :: proc(s: ^Server($State, $Control, $Action, $Event, $Seats), peer: ^Peer(Action)) {
	peer.phase = .Disconnected
	peer.connection = 0
	if peer.seat != 0 {
		s.leaves |= u64(1) << uint(peer.seat - 1)
		s.held[peer.seat - 1] = s.model.neutral
	}
	for i in 0 ..< peer.action_count {
		action := &peer.actions[(peer.action_head + i) % ACTION_CAPACITY]
		action.reason, action.tick = .Disconnected, s.timeline.head + 1
	}
}
