package kit_session

// traffic — one authority-ingress budget for every client-originated packet.
//
// Channel budgets bound the whole reliable and stream pipes per transport
// peer. The action budget is narrower and shared by immediate co-op commands
// and kit/sim's tick-scheduled commands; a command therefore has to fit both
// its reliable-channel budget and its per-player action budget. Zero rates mean
// that dimension is unlimited. A completely zero limit is disabled.

import knet "godot:kit/net"

Traffic_Limit :: struct {
	packets_per_second: int,
	bytes_per_second:   int,
	// Token capacity in seconds of traffic. Zero uses one second. A small burst
	// lets an honest frame spike through while sustained traffic remains bounded.
	burst_seconds:      f64,
}

Traffic_Config :: struct {
	reliable: Traffic_Limit,
	stream:   Traffic_Limit,
	actions:  Traffic_Limit,
}

Traffic_Class :: enum u8 {
	Reliable,
	Stream,
	Action,
}

// What the authority should do after refusing an over-budget packet. Drop is
// the safe default. Kick/Ban also revoke the seat; when a transport drop hook
// is installed (kit/netgd does this automatically), the socket closes after
// the deliberate SES_KICKED reason has had time to flush.
Traffic_Response :: enum u8 {
	Drop,
	Kick,
	Ban,
}

Traffic_Violation :: struct {
	player:  knet.Player_Id,
	peer:    Peer_Id,
	class:   Traffic_Class,
	bytes:   int,
	strikes: u64, // this class's run-lifetime denied-packet count for the player
}

Traffic_Hook :: proc(user: rawptr, violation: Traffic_Violation) -> Traffic_Response

Traffic_Counter :: struct {
	packets: u64, // admitted packets
	bytes:   u64, // admitted bytes
	dropped: u64,
}

Traffic_Stats :: struct {
	reliable: Traffic_Counter,
	stream:   Traffic_Counter,
	actions:  Traffic_Counter,
}

// One model-neutral authority door for every client-originated action. The
// immediate and scheduled runtimes resolve their own entity/descriptor shapes,
// then present the same facts here before either can execute or enqueue work.
Authority_Ingress_Stage :: enum u8 {
	None,
	Seat,
	Dedup,
	Decode,
	Target,
	Access,
	Arguments,
	Tick,
	Budget,
	Queue,
}

Authority_Action_Request :: struct {
	model:          knet.Action_Model,
	player:         knet.Player_Id,
	peer:           Peer_Id,
	seq:            u32,
	entity:         knet.Net_Id,
	action:         u16,
	packet_bytes:   int,
	payload_valid:  bool,
	target_exists:  bool,
	action_exists:  bool,
	owner:           knet.Player_Id,
	policy:          knet.Action_Policy,
	args_bytes:      int,
	args_valid:      bool,
	has_tick:        bool,
	tick:            u64,
	authority_tick:  u64,
	max_future_tick: u64,
	queue_depth:     int,
	queue_limit:     int, // zero = no model-specific queue bound
}

Authority_Action_Decision :: struct {
	admitted: bool,
	respond:  bool, // false for uncorrelatable/duplicate traffic
	reason:   knet.Action_Reject_Reason,
	stage:    Authority_Ingress_Stage,
}

AUTHORITY_INGRESS_MODELS :: 2
AUTHORITY_INGRESS_REASONS :: int(knet.Action_Reject_Reason.Timeout) + 1
AUTHORITY_INGRESS_STAGES :: int(Authority_Ingress_Stage.Queue) + 1

Authority_Ingress_Stats :: struct {
	admitted:  u64,
	rejected:  u64,
	duplicate: u64,
	by_model:  [AUTHORITY_INGRESS_MODELS]u64,
	by_reason: [AUTHORITY_INGRESS_REASONS]u64,
	by_stage:  [AUTHORITY_INGRESS_STAGES]u64,
}

@(private)
Authority_Action_Key :: struct {
	player: knet.Player_Id,
	model:  knet.Action_Model,
}

@(private = "file")
authority_ingress_record :: proc(
	s: ^Session,
	req: Authority_Action_Request,
	decision: Authority_Action_Decision,
) {
	mi := int(req.model)
	if decision.admitted {
		s.authority_ingress.admitted += 1
		if mi >= 0 && mi < len(s.authority_ingress.by_model) {
			s.authority_ingress.by_model[mi] += 1
		}
		return
	}
	s.authority_ingress.rejected += 1
	ri := int(decision.reason)
	if ri >= 0 && ri < len(s.authority_ingress.by_reason) {
		s.authority_ingress.by_reason[ri] += 1
	}
	si := int(decision.stage)
	if si >= 0 && si < len(s.authority_ingress.by_stage) {
		s.authority_ingress.by_stage[si] += 1
	}
	if decision.stage == .Dedup {
		s.authority_ingress.duplicate += 1
	}
	session_production_log(s, Production_Log_Record {
		kind = .Action_Rejected,
		action_reason = decision.reason,
		action_model = req.model,
		player = req.player,
		peer = req.peer,
		stage = decision.stage,
		bytes = u32(max(req.packet_bytes, 0)),
		count = s.authority_ingress.rejected,
	})
}

// The order is deliberate and shared: authenticated playing seat, nonzero
// replay-protected sequence, structurally complete payload/target/descriptor,
// declared access, action byte contract, plausible tick, traffic budget, then
// the execution model's bounded queue. A refusal is recorded exactly once.
session_authority_action_admit :: proc(
	s: ^Session,
	req: Authority_Action_Request,
) -> Authority_Action_Decision {
	decision := Authority_Action_Decision{respond = req.seq != 0}
	refuse :: proc(
		decision: ^Authority_Action_Decision,
		reason: knet.Action_Reject_Reason,
		stage: Authority_Ingress_Stage,
	) {
		decision.reason = reason
		decision.stage = stage
	}

	p, seated := s.players[req.player]
	if !s.is_host || !seated || !p.connected || p.spectator || p.peer != req.peer {
		refuse(&decision, .Access, .Seat)
		authority_ingress_record(s, req, decision)
		return decision
	}
	if req.seq == 0 {
		decision.respond = false
		refuse(&decision, .Malformed, .Dedup)
		authority_ingress_record(s, req, decision)
		return decision
	}
	key := Authority_Action_Key{player = req.player, model = req.model}
	window := s.authority_action_seen[key]
	fresh := knet.dedup_accept(&window, knet.Intent_Seq(req.seq))
	s.authority_action_seen[key] = window
	if !fresh {
		decision.respond = false
		refuse(&decision, .Stale, .Dedup)
		authority_ingress_record(s, req, decision)
		return decision
	}
	if !req.payload_valid {
		refuse(&decision, .Malformed, .Decode)
		authority_ingress_record(s, req, decision)
		return decision
	}
	if !req.target_exists {
		refuse(&decision, .Stale, .Target)
		authority_ingress_record(s, req, decision)
		return decision
	}
	if !req.action_exists {
		refuse(&decision, .Malformed, .Target)
		authority_ingress_record(s, req, decision)
		return decision
	}
	if !knet.action_access_allows(req.policy, req.player, req.owner, false) {
		refuse(&decision, .Access, .Access)
		authority_ingress_record(s, req, decision)
		return decision
	}
	if !req.args_valid || !knet.action_args_allowed(req.policy, req.args_bytes) {
		refuse(&decision, .Malformed, .Arguments)
		authority_ingress_record(s, req, decision)
		return decision
	}
	if req.has_tick {
		max_tick := max(u64)
		if req.authority_tick <= max(u64) - req.max_future_tick {
			max_tick = req.authority_tick + req.max_future_tick
		}
		if req.tick == 0 || req.tick > max_tick {
			refuse(&decision, .Stale, .Tick)
			authority_ingress_record(s, req, decision)
			return decision
		}
	}
	if !session_admit_traffic(s, req.player, req.peer, .Action, req.packet_bytes) {
		refuse(&decision, .Rate, .Budget)
		authority_ingress_record(s, req, decision)
		return decision
	}
	if req.queue_limit > 0 && req.queue_depth >= req.queue_limit {
		refuse(&decision, .Rate, .Queue)
		authority_ingress_record(s, req, decision)
		return decision
	}
	decision.admitted = true
	decision.reason = .None
	decision.stage = .None
	authority_ingress_record(s, req, decision)
	return decision
}

session_authority_ingress_stats :: proc(s: ^Session) -> Authority_Ingress_Stats {
	return s.authority_ingress
}

@(private)
traffic_config_valid :: proc(cfg: Traffic_Config) -> bool {
	limits := [?]Traffic_Limit{cfg.reliable, cfg.stream, cfg.actions}
	for limit in limits {
		if limit.packets_per_second < 0 || limit.bytes_per_second < 0 || limit.burst_seconds < 0 {
			return false
		}
	}
	return true
}

@(private)
Traffic_Bucket :: struct {
	packet_tokens: f64,
	byte_tokens:   f64,
	last:          f64,
	ready:         bool,
	count:         Traffic_Counter,
}

@(private)
Traffic_Seat :: struct {
	// Reliable/stream limits are per TRANSPORT peer and reset on reconnect.
	// The action bucket and all counters belong to the stable player seat.
	peer:     Peer_Id,
	reliable: Traffic_Bucket,
	stream:   Traffic_Bucket,
	actions:  Traffic_Bucket,
}

// The transport-independent primitive shared by channel and action admission.
@(private)
traffic_admit :: proc(bucket: ^Traffic_Bucket, limit: Traffic_Limit, now: f64, bytes: int) -> bool {
	if bytes < 0 {
		return false
	}
	packet_rate := max(limit.packets_per_second, 0)
	byte_rate := max(limit.bytes_per_second, 0)
	if packet_rate == 0 && byte_rate == 0 {
		bucket.count.packets += 1
		bucket.count.bytes += u64(bytes)
		return true
	}
	burst := limit.burst_seconds > 0 ? limit.burst_seconds : 1.0
	packet_cap := f64(packet_rate) * burst
	byte_cap := f64(byte_rate) * burst
	if !bucket.ready {
		bucket.packet_tokens = packet_cap
		bucket.byte_tokens = byte_cap
		bucket.last = now
		bucket.ready = true
	} else {
		dt := max(now - bucket.last, 0)
		if packet_rate > 0 {
			bucket.packet_tokens = min(packet_cap, bucket.packet_tokens + dt * f64(packet_rate))
		}
		if byte_rate > 0 {
			bucket.byte_tokens = min(byte_cap, bucket.byte_tokens + dt * f64(byte_rate))
		}
		bucket.last = max(bucket.last, now)
	}
	packets_ok := packet_rate == 0 || bucket.packet_tokens >= 1
	bytes_ok := byte_rate == 0 || bucket.byte_tokens >= f64(bytes)
	if !packets_ok || !bytes_ok {
		bucket.count.dropped += 1
		return false
	}
	if packet_rate > 0 {
		bucket.packet_tokens -= 1
	}
	if byte_rate > 0 {
		bucket.byte_tokens -= f64(bytes)
	}
	bucket.count.packets += 1
	bucket.count.bytes += u64(bytes)
	return true
}

@(private = "file")
traffic_limit_for :: proc(s: ^Session, class: Traffic_Class) -> Traffic_Limit {
	switch class {
	case .Reliable:
		return s.cfg.traffic.reliable
	case .Stream:
		return s.cfg.traffic.stream
	case .Action:
		return s.cfg.traffic.actions
	}
	return {}
}

@(private = "file")
traffic_bucket_for :: proc(seat: ^Traffic_Seat, class: Traffic_Class) -> ^Traffic_Bucket {
	switch class {
	case .Reliable:
		return &seat.reliable
	case .Stream:
		return &seat.stream
	case .Action:
		return &seat.actions
	}
	return nil
}

@(private = "file")
traffic_refuse :: proc(s: ^Session, violation: Traffic_Violation) {
	s.traffic_dropped += 1
	session_production_log(s, Production_Log_Record {
		kind = .Traffic_Refused,
		player = violation.player,
		peer = violation.peer,
		class = violation.class,
		bytes = u32(max(violation.bytes, 0)),
		count = s.traffic_dropped,
	})
	response := Traffic_Response.Drop
	if s.traffic_hook != nil {
		response = s.traffic_hook(s.traffic_hook_user, violation)
	}
	if response == .Drop {
		return
	}
	peer, kicked := session_kick(
		s,
		violation.player,
		ban = response == .Ban,
		reason = response == .Ban ? .Banned : .Traffic_Policy,
	)
	if kicked && s.drop_peer != nil {
		s.drop_peer(s.drop_peer_user, peer)
	}
}

@(private)
session_admit_traffic :: proc(
	s: ^Session,
	player: knet.Player_Id,
	peer: Peer_Id,
	class: Traffic_Class,
	bytes: int,
) -> bool {
	if !s.is_host || player == s.me {
		return true
	}
	seat := s.traffic[player]
	if seat.peer != peer {
		// A reconnect is a new transport peer: it cannot inherit an exhausted
		// channel bucket. Keep its stable-seat action pressure and telemetry.
		reliable_count := seat.reliable.count
		stream_count := seat.stream.count
		seat.peer = peer
		seat.reliable = Traffic_Bucket{count = reliable_count}
		seat.stream = Traffic_Bucket{count = stream_count}
	}
	bucket := traffic_bucket_for(&seat, class)
	limit := traffic_limit_for(s, class)
	ok := traffic_admit(bucket, limit, s.now, bytes)
	s.traffic[player] = seat
	if ok {
		return true
	}
	traffic_refuse(s, Traffic_Violation {
		player  = player,
		peer    = peer,
		class   = class,
		bytes   = bytes,
		strikes = bucket.count.dropped,
	})
	return false
}

// Shared action admission for immediate co-op and tick-scheduled commands.
// Call after the session has authenticated `player`; authority-authored work
// and a disabled (zero) limit pass without special cases at the call site.
session_admit_action :: proc(s: ^Session, player: knet.Player_Id, bytes: int) -> bool {
	p, seated := s.players[player]
	if !seated || !p.connected || p.spectator {
		return false
	}
	return session_admit_traffic(s, player, p.peer, .Action, bytes)
}

// Per-player, run-lifetime ingress totals. Channel buckets reset their tokens
// on reconnect, but their counters remain attached to the stable player id.
session_traffic_stats :: proc(s: ^Session, player: knet.Player_Id) -> (Traffic_Stats, bool) {
	seat, ok := s.traffic[player]
	if !ok {
		return {}, false
	}
	return Traffic_Stats {
		reliable = seat.reliable.count,
		stream   = seat.stream.count,
		actions  = seat.actions.count,
	}, true
}

session_traffic_dropped :: proc(s: ^Session) -> u64 {
	return s.traffic_dropped
}

// Install one operational policy hook. It is called only on the authority and
// only after a packet has been refused, so logging/reporting cannot accidentally
// turn an admitted packet into application work. Returning Kick/Ban performs
// the session half automatically; netgd supplies the socket-close half.
session_set_traffic_hook :: proc(s: ^Session, user: rawptr, hook: Traffic_Hook) {
	s.traffic_hook_user = user
	s.traffic_hook = hook
}
