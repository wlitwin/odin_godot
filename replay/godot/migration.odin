package replay_godot
import gd "godot:godot"

import "core:fmt"
import r "godot:replay"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import auth "godot:replay/authority"
import tr "godot:replay/transport"
import view "godot:replay/view"
import transportgd "godot:replay/godot/transport"

// Replace the gameplay connection only after receiving an authenticated live
// coordinator view. The client runtime remains in place, with its pending action
// ledger and old presentation history available for Welcome reconciliation.
session_redirect :: proc(s: ^Session($S, $C, $A, $E, $N), lease: ^auth.Lease, transport: ^Migration_Transport = nil) -> net.Error {
	if !s.ready || s.authority || lease.require_owner || !auth.lease_live(lease, lease.view.epoch) {return .Fenced}
	if lease.content != s.client.cfg.content || lease.view.epoch < s.client.cfg.epoch {return .Checkpoint_Contract}
	if s.change_count != 0 || s.client.journal.queue_count != 0 || s.client.outcome_count != 0 || s.client.recovery_ready {return .Presentation}
	options := s.options
	if err := migration_transport(&options, lease, transport); err != .None {return err}
	options.address = fmt.ctprintf("%s", string(cast(cstring)&lease.view.endpoint.host[0]))
	options.port, options.permit = lease.view.endpoint.port, auth.lease_permit(lease)
	// Keep the authenticated RTC reservation only while reconnecting to the
	// same authority term and exact signaling scope. New epochs use new rooms.
	if options.backend == .Rtc && s.rtc.ready && lease.view.epoch == s.client.cfg.epoch &&
	   lease.identity.incarnation == s.client.incarnation && options.rtc.url == s.rtc.config.url && options.rtc.room == s.rtc.room {
		if continuation, ok := transportgd.rtc_continuation(&s.rtc); ok {options.rtc.continuation = continuation}
	}
	policy_user, policy_valid := s.link.policy_user, s.link.policy_valid
	session_disconnect(s)
	s.client.phase = .Disconnected
	if err := session_connect(s, options, true); err != .None {return err}
	s.link.policy_user, s.link.policy_valid = policy_user, policy_valid
	if lease.view.epoch > s.client.cfg.epoch {
		if err := net.client_authority(&s.client, lease.view.epoch, s.wire, permit = options.permit); err != .None {return err}
	} else {
		s.client.permit = options.permit
		if err := net.client_reconnect(&s.client, s.wire); err != .None {return err}
	}
	r.clock_init(&s.clock, s.client.cfg.hz)
	return .None
}

// Prepare cancellation output before releasing an old runtime. Applications own
// actual effect instances; these changes close the retained old-epoch IDs.
@(private)
session_reset_effects :: proc(s: ^Session($S, $C, $A, $E, $N), epoch, tick: u64) -> ([]view.Change(net.Net_Event(E)), net.Error) {
	if s.change_count != 0 || s.reset_index < len(s.reset_changes) {return nil, .Presentation}
	if !s.authority {
		if view.journal_reset(&s.client.journal, epoch, tick) != .None {return nil, .Presentation}
		changes := make([]view.Change(net.Net_Event(E)), s.client.journal.queue_count, s.allocator)
		view.drain(&s.client.journal, changes)
		return changes, .None
	}
	changes := make([]view.Change(net.Net_Event(E)), s.server.cfg.history * net.WIRE_EVENTS, s.allocator)
	count := 0
	head := s.server.timeline.head
	first := head > u64(s.server.cfg.history - 1) ? head - u64(s.server.cfg.history - 1) : 0
	for at := first; at <= head; at += 1 {
		events: [net.WIRE_EVENTS]r.Occurrence(net.Net_Event(E))
		n, err := r.copy_events(&s.server.timeline, at, events[:])
		if err == .None {for event in events[:n] {changes[count] = {kind = .Cancel, occurrence = event, confirmed = true}; count += 1}}
		if at == max(u64) {break}
	}
	exact := make([]view.Change(net.Net_Event(E)), count, s.allocator)
	copy(exact, changes[:count]); delete(changes, s.allocator)
	return exact, .None
}

session_takeover :: proc(s: ^Session($S, $C, $A, $E, $N), prepared: ^auth.Prepared, lease: ^auth.Lease, transport: ^Migration_Transport = nil, dedicated:bool=false) -> net.Error {
	if !s.ready || !lease.require_owner {return .Wrong_Phase}
	options := s.options
	if err := migration_transport(&options, lease, transport); err != .None {return err}
	model := s.authority ? s.server.model : s.client.model
	cp: net.Checkpoint(S, C, A, N); defer net.checkpoint_destroy(&cp)
	// Borrow already validated schema metadata before closing the old Session.
	// The decoded checkpoint owns its values independently of this cache.
	codec := s.authority ? &s.link.publish_codec : &s.link.incoming.archive_codec
	if !codec.ready {codec = nil}
	if err := auth.prepared_decode(prepared, &cp, model, lease, s.allocator, codec); err != .None {return err}
	authority_role:=dedicated || s.role==.Server ? Session_Role.Server : .Host
	seat:=u16(0)
	if authority_role!=.Server {
		found:bool;seat,found=net.checkpoint_seat(&cp,s.token)
		if !found {return .Invalid_Input}
	}
	report := net.Client_Recovery{from_epoch = cp.header.epoch, to_epoch = lease.view.epoch, recovered_tick = cp.frame.tick, new_seat = seat}
	if !s.authority && authority_role!=.Server {report, _ = net.client_checkpoint_recovery(&s.client, &cp, lease.view.epoch)}
	changes, err := session_reset_effects(s, lease.view.epoch, cp.frame.tick)
	if err != .None {return err}
	options.role, options.token, options.port = authority_role, s.token, lease.view.endpoint.port
	options.network = net.checkpoint_config(cp.header, cp.settings)
	options.network.epoch, options.permit = lease.view.epoch, auth.lease_permit(lease)
	allocator := s.allocator
	serial := s.recovery_serial
	session_close(s)
	if err := session_resume(s, &cp, model, options, {epoch = lease.view.epoch, local_seat = seat, permit = options.permit}); err != .None {delete(changes, allocator); return err}
	s.reset_changes, s.recovery, s.recovery_serial = changes, report, serial + 1
	return .None
}

// An old owner may rejoin as a player once a newer authority is approved. Its
// world has already been checkpointed and its lease retired; normal Welcome
// restores its stable seat/token. Local effects are explicitly closed first.
session_rejoin :: proc(s: ^Session($S, $C, $A, $E, $N), lease: ^auth.Lease, transport: ^Migration_Transport = nil) -> net.Error {
	if !s.ready || !s.authority || lease.require_owner || !auth.lease_live(lease, lease.view.epoch) || lease.view.epoch <= s.server.cfg.epoch {return .Fenced}
	model, options := s.server.model, s.options
	if err := migration_transport(&options, lease, transport); err != .None {return err}
	history := net.server_departing(&s.server)
	changes, err := session_reset_effects(s, lease.view.epoch, 0)
	if err != .None {return err}
	options.role, options.token, options.port = history.seat == 0 ? .Observer : .Client, s.token, lease.view.endpoint.port
	options.network = s.server.cfg
	options.permit = auth.lease_permit(lease)
	options.address = fmt.ctprintf("%s", string(cast(cstring)&lease.view.endpoint.host[0]))
	allocator := s.allocator
	serial := s.recovery_serial
	session_close(s)
	if err := session_open(s, r.Frame(S){}, model, options); err != .None {delete(changes, allocator); return err}
	if err := net.client_seed_departing(&s.client, history); err != .None {delete(changes, allocator); session_close(s); return err}
	if err := net.client_authority(&s.client, lease.view.epoch, s.wire, permit = options.permit); err != .None {delete(changes, allocator); session_close(s); return err}
	s.reset_changes = changes
	s.recovery_serial = serial
	return .None
}


// Explicit transport destination for a verified authority view. RTC room identity
// is derived from that view; the provider URL is trusted embedding configuration.
// This does not reinterpret the coordinator's existing native endpoint encoding.
Migration_Transport :: struct {backend:Session_Backend,rtc:transportgd.Rtc_Config,steam:transportgd.Steam_Config}
@(private)
migration_transport :: proc(options:^Session_Options,lease:^auth.Lease,target:^Migration_Transport)->net.Error {
 if target==nil {return options.backend==.Enet ? .None : .Invalid_Config}
 if target.backend==.Rtc {
  code:=auth.rendezvous_code(lease.view)
  if target.rtc.authorize==nil || target.rtc.room!=string(code[:]) {return .Invalid_Config}
 } else if target.backend==.Steam {
  when gd.IS_WEB {return .Invalid_Config}
  config,valid:=transportgd.steam_target(target.steam,lease.view.endpoint,lease.require_owner)
  if !valid {return .Invalid_Config}
  options.steam=config
 } else if target.backend!=.Enet {return .Invalid_Config}
 options.backend,options.rtc=target.backend,target.rtc
 return .None
}
