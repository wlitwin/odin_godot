package replay_net

import tr "godot:replay/transport"
import r "godot:replay"
import v "godot:replay/view"

Departing_Host :: struct($S, $C, $A: typeid, $N: int) {
	frame: r.Frame(S), held: [N]C,
	epoch, received, settled: u64,
	seat: u16,
	count: int,
	actions: [ACTION_CAPACITY]Queued_Action(A),
}

server_departing :: proc(s: ^Server($S, $C, $A, $E, $N)) -> Departing_Host(S, C, A, N) {
	h: Departing_Host(S, C, A, N)
	h.frame, _ = r.current(&s.timeline)
	h.epoch, h.seat, h.held = s.cfg.epoch, s.local_seat, s.held
	for peer in s.peers {
		if !peer.local {continue}
		h.received, h.settled, h.count = peer.action_received, peer.action_settled, peer.action_count
		for i in 0 ..< peer.action_count {h.actions[i] = peer.actions[(peer.action_head + i) % ACTION_CAPACITY]}
	}
	return h
}

client_seed_departing :: proc(c: ^Client($S, $C, $A, $E, $N), h: Departing_Host(S, C, A, N)) -> Error {
	if !c.initialized || c.has_world || c.cfg.epoch != h.epoch || !c.model.state_valid(h.frame.state) {return .Wrong_Phase}
	if h.count < 0 || h.count > ACTION_CAPACITY || int(h.seat) > N || (h.seat == 0) != c.spectator ||
	   h.settled > h.received || h.received - h.settled != u64(h.count) {return .Invalid_Input}
	value,valid:=replica_project(c.model,h.frame,h.held,Recipient{h.seat,c.spectator},&c.codecs.replica,c.txb)
	if !valid {return .Invalid_Model}
	frame:=r.Frame(S){h.frame.tick,value.state}
	prediction, projected := group_frame(c.model, frame, h.seat, c.spectator)
	if !projected {return .Invalid_Model}
	if r.reset_checkpoint(&c.timeline, prediction, h.epoch) != .None {return .Invalid_Frame}
	c.actions, c.action_count, c.next_action, c.last_outcome = h.actions, h.count, h.received, h.settled
	c.seat, c.held, c.has_world = h.seat, value.held, true
	v.journal_destroy(&c.journal)
	if v.journal_init(&c.journal, epoch = h.epoch, baseline = h.frame.tick,
	                  cfg = {c.cfg.history, WIRE_EVENTS, c.cfg.history * WIRE_EVENTS * 2}, allocator = c.allocator) != .None {return .Presentation}
	client_install_policy(c)
	return .None
}

// The application supplies a coordinator-approved newer epoch and connection.
// Pending old-epoch actions are quarantined until the new authority's Welcome
// resolves its durable frontiers. No old command is blindly resubmitted.
client_authority :: proc(c: ^Client($S, $C, $A, $E, $N), epoch: u64, wire: tr.Transport,
                         authority: tr.Peer_Id = 1, permit: Permit = {}) -> Error {
	if !c.initialized || epoch <= c.cfg.epoch || authority == 0 {return .Invalid_Config}
	if c.cfg.require_permit && permit.allow == nil {return .Fenced}
	if c.recovery_ready || c.outcome_count != 0 || c.journal.queue_count != 0 {return .Presentation}
	if !c.recovering {
		c.recovery = {from_epoch = c.cfg.epoch, previous_confirmed = c.timeline.confirmed,
		              previous_head = c.timeline.head, old_seat = c.seat}
	}
	c.recovery.to_epoch = epoch
	c.cfg.epoch, c.wire, c.authority, c.permit = epoch, wire, authority, permit
	c.generation, c.serial, c.request_sequence = 0, 0, 0
	c.phase, c.rejection, c.recovering = .Joining, .None, true
 c.observer_names_negotiated=false
	c.time_set, c.hello_sent, c.has_pending = false, false, false
	client_timing_reset(c)
	return .None
}

client_recovery :: proc(c: ^Client($S, $C, $A, $E, $N)) -> (Client_Recovery, bool) {
	if !c.recovery_ready {return {}, false}
	c.recovery_ready = false
	return c.recovery, true
}

@(private)
welcome_valid :: proc(packet: Welcome_Packet($S, $C, $N)) -> bool {
	packet := packet
	if packet.action_settled > packet.action_received || packet.action_received > max(u64) >> 8 ||
	   packet.action_received - packet.action_settled > ACTION_CAPACITY ||
	   u64(packet.completed_count) != min(packet.action_settled, ACTION_CAPACITY) {return false}
	for outcome, i in packet.completed[:packet.completed_count] {
		if outcome.sequence != packet.action_settled - u64(packet.completed_count) + 1 + u64(i) ||
		   outcome.tick == 0 || outcome.tick > packet.frame.tick || outcome.applied != (outcome.reason == .None) {return false}
	}
	return true
}

@(private)
client_reconcile_actions :: proc(c: ^Client($S, $C, $A, $E, $N), packet: Welcome_Packet(S, C, N)) {
	packet := packet
	c.recovery = recovery_actions(c.recovery, c.actions[:c.action_count], packet)
	kept := 0
	for action, i in c.actions[:c.action_count] {
		if c.recovery.actions[i].disposition != .Retained {continue}
		c.actions[kept] = action
		c.actions[kept].predicted, c.actions[kept].sent = true, true
		kept += 1
	}
	c.action_count, c.next_action, c.last_outcome = kept, packet.action_received, packet.action_settled
	c.recovering, c.recovery_ready = false, true
}

// Read-only reconciliation for a predicting client promoted into the authority.
client_checkpoint_recovery :: proc(c: ^Client($S, $C, $A, $E, $N), cp: ^Checkpoint(S, C, A, N), epoch: u64) -> (Client_Recovery, bool) {
	if !c.initialized || !cp.ready || epoch <= c.cfg.epoch {return {}, false}
	hash := token_digest(c.token)
	for peer in cp.peers {
		if peer.token_hash != hash || peer.spectator {continue}
		packet := Welcome_Packet(S, C, N){seat = peer.seat, frame = cp.frame, action_received = peer.action_received, action_settled = peer.action_settled}
		for saved in cp.outcomes {if saved.peer == peer.index {
			if packet.completed_count == ACTION_CAPACITY {return {}, false}
			packet.completed[packet.completed_count] = saved.outcome; packet.completed_count += 1
		}}
		report := Client_Recovery{from_epoch = c.cfg.epoch, to_epoch = epoch, previous_confirmed = c.timeline.confirmed, previous_head = c.timeline.head, old_seat = c.seat}
		return recovery_actions(report, c.actions[:c.action_count], packet), true
	}
	return {}, false
}

@(private)
recovery_actions :: proc(initial: Client_Recovery, actions: []Queued_Action($A), packet: Welcome_Packet($S, $C, $N)) -> Client_Recovery {
	packet := packet
	report := initial
	report.recovered_tick, report.new_seat, report.received, report.settled = packet.frame.tick, packet.seat, packet.action_received, packet.action_settled
	report.count = u8(len(actions))
	for action, i in actions {
		entry := Recovered_Action{epoch = report.from_epoch, sequence = action.sequence, disposition = .Retired}
		if action.sequence <= packet.action_settled {
			entry.disposition = .Settled_Unknown
			for outcome in packet.completed[:packet.completed_count] {
				if outcome.sequence == action.sequence {entry.outcome = outcome; entry.disposition = outcome.applied ? .Applied : .Rejected; break}
			}
		} else if action.sequence <= packet.action_received {
			entry.disposition = .Retained
		}
		report.actions[i] = entry
	}
	return report
}
