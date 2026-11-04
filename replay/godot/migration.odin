package replay_godot
import gd "godot:godot"
import rt "godot:runtime"
import bg "godot:box3d/godot"

import "core:fmt"
import "core:mem"
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
session_redirect :: proc(s: ^Session($S, $C, $A, $E, $N), lease: ^auth.Lease, transport: ^Migration_Transport = nil,permit_context:r.Owned_Context={},permit:^net.Permit=nil) -> net.Error {
	if !s.ready || s.authority || lease.require_owner || !auth.lease_live(lease, lease.view.epoch) {return .Fenced}
	if lease.content != s.client.cfg.content || lease.view.epoch < s.client.cfg.epoch {return .Checkpoint_Contract}
	if s.change_count != 0 || s.client.journal.queue_count != 0 || s.client.outcome_count != 0 || s.client.recovery_ready {return .Presentation}
 if !r.owner_is_nil(s.ownership.container.owner){if error:=session_retired_drain(s);error!=.None{return error}}
	options := s.options
	if err := migration_transport(&options, lease, transport); err != .None {return err}
	options.address = fmt.ctprintf("%s", string(cast(cstring)&lease.view.endpoint.host[0]))
	options.port, options.permit = lease.view.endpoint.port, auth.lease_permit(lease)
 if permit!=nil{options.permit=permit^}
	// Keep the authenticated RTC reservation only while reconnecting to the
	// same authority term and exact signaling scope. New epochs use new rooms.
	live_rtc:=session_rtc(s)
	if options.backend == .Rtc && live_rtc.ready && lease.view.epoch == s.client.cfg.epoch &&
	   lease.identity.incarnation == s.client.incarnation && options.rtc.url == live_rtc.config.url && options.rtc.room == live_rtc.room {
		if continuation, ok := transportgd.rtc_continuation(live_rtc); ok {options.rtc.continuation = continuation}
	}
 if !r.owner_is_nil(s.ownership.container.owner){options.network.epoch=lease.view.epoch;return session_redirect_owned(s,options,permit_context)}
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

session_takeover :: proc(s: ^Session($S, $C, $A, $E, $N), prepared: ^auth.Prepared, lease: ^auth.Lease, transport: ^Migration_Transport = nil, dedicated:bool=false,permit_context:r.Owned_Context={}) -> net.Error {
 // Cross-role migration has no accepted managed-physics transaction yet.
 // Reject before inspecting leases, cancelling effects or closing the runtime.
 if s.ready && !r.owner_is_nil(s.ownership.container.owner) && session_sdk_physics(s.authority?s.server.model:s.client.model){return .Invalid_Config}
	if !s.ready || !lease.require_owner {return .Wrong_Phase}
	options := s.options
	if err := migration_transport(&options, lease, transport); err != .None {return err}
	model := s.authority ? s.server.model : s.client.model
	cp: net.Checkpoint(S, C, A, N); defer net.checkpoint_destroy(&cp)
	// Borrow already validated schema metadata before closing the old Session.
	// The decoded checkpoint owns its values independently of this cache.
	codec := s.authority ? &session_link(s).publish_codec : &session_link(s).incoming.archive_codec
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
 if !r.owner_is_nil(s.ownership.container.owner){
  options.role,options.token,options.port=authority_role,s.token,lease.view.endpoint.port
  options.network=net.checkpoint_config(cp.header,cp.settings);options.network.epoch=lease.view.epoch;options.permit=auth.lease_permit(lease)
  return session_takeover_owned(s,&cp,model,options,report,seat,permit_context)
 }
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
session_rejoin :: proc(s: ^Session($S, $C, $A, $E, $N), lease: ^auth.Lease, transport: ^Migration_Transport = nil,permit_context:r.Owned_Context={}) -> net.Error {
 // Cross-role migration has no accepted managed-physics transaction yet.
 // Reject before inspecting leases, cancelling effects or closing the runtime.
 if s.ready && !r.owner_is_nil(s.ownership.container.owner) && session_sdk_physics(s.authority?s.server.model:s.client.model){return .Invalid_Config}
	if !s.ready || !s.authority || lease.require_owner || !auth.lease_live(lease, lease.view.epoch) || lease.view.epoch <= s.server.cfg.epoch {return .Fenced}
	model, options := s.server.model, s.options
	if err := migration_transport(&options, lease, transport); err != .None {return err}
	history := net.server_departing(&s.server)
	complete_history:net.Complete_Departing_Host(S,C,A,E,N)
	if model.complete_state {
		err:net.Error;complete_history,err=net.server_departing_complete(&s.server)
		if err!=.None{return err}
	}
	defer net.complete_departing_destroy(&complete_history)
 if !r.owner_is_nil(s.ownership.container.owner){
  options.role,options.token,options.port=history.seat==0?.Observer:.Client,s.token,lease.view.endpoint.port
  options.network=s.server.cfg;options.permit=auth.lease_permit(lease);options.address=fmt.ctprintf("%s",string(cast(cstring)&lease.view.endpoint.host[0]))
  return session_rejoin_owned(s,model,options,history,&complete_history,lease.view.epoch,permit_context)
 }
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
	if model.complete_state {
		if err:=net.client_seed_departing_complete(&s.client,&complete_history);err!=.None{delete(changes,allocator);session_close(s);return err}
	} else if err := net.client_seed_departing(&s.client, history); err != .None {delete(changes, allocator); session_close(s); return err}
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

@(private)
session_redirect_owned :: proc(s:^Session($S,$C,$A,$E,$N),options:Session_Options,permit_context:r.Owned_Context)->net.Error {
 if r.owner_retains_access(&s.retained,.Execute)!=.None{return .Invalid_Model}
 if error:=session_retired_drain(s);error!=.None{return error}
 callback_stats,callback_status:=rt.managed_callable_stats()
 if callback_status!=bg.OK || callback_stats.inflight_calls!=0{return .Wrong_Phase}
 permit_context:=permit_context
 if r.owner_is_nil(permit_context.owner){permit_context=s.ownership.permit}
 if r.owned_context_access(permit_context,options.permit.user,true,.Execute)!=.None{return .Invalid_Model}
 next_retains:r.Owner_Retains
 owners:=[?]r.Owner{s.ownership.allocator.owner,permit_context.owner,s.ownership.container.owner,s.model_owners[0].owner,s.model_owners[1].owner,s.ownership.rtc_ice.owner,s.ownership.rtc_authorization.owner,s.ownership.identity.owner}
 if r.owner_retains_acquire(&next_retains,owners[:])!=.None{
  if r.owner_retains_drop(&next_retains)!=.None{s.retired_session=next_retains}
  return .Invalid_Model
 }
 candidate,error:=session_connection_open(s,options)
 if error!=.None{
  if r.owner_retains_drop(&next_retains)!=.None{s.retired_session=next_retains}
  return error
 }
 replacement:=net.Context_Replacement{wire=rec.link_game_owner(&candidate.link),permit=permit_context}
 if options.network.epoch>s.client.cfg.epoch{
  error=net.client_authority(&s.client,options.network.epoch,candidate.wire,authority=s.client.authority,permit=options.permit,replacement=&replacement)
 }else{
  next_permit:=options.permit;explicit:^net.Permit
  if next_permit.user!=s.client.permit.user || next_permit.allow!=s.client.permit.allow{explicit=&next_permit}
  error=net.client_reconnect(&s.client,candidate.wire,replacement=&replacement,new_permit=explicit)
 }
 if error!=.None{
  s.retired_connection=candidate;s.retired_client=replacement.retired;s.retired_session=next_retains;_=session_retired_drain(s)
  return error
 }
 // Everything below is publication/owned retirement. No fallible last drop is
 // part of the atomic Client replacement result; pending cleanup stays bounded.
 s.retired_connection=s.connection;s.retired_client=replacement.retired;s.retired_session=s.retained
 s.connection=candidate;s.base_wire=candidate.base_wire;s.wire=candidate.wire;s.retained=next_retains;s.ownership.permit=permit_context
 s.options=options;s.options.address=nil;s.options.rtc={};s.options.steam.peer=nil
 r.clock_init(&s.clock,s.client.cfg.hz)
 _=session_retired_drain(s)
 return .None
}

@(private)
Role_Reset_Stage :: struct($S,$C,$A,$E:typeid,$N:int){ownership:Session_Ownership,models:[2]r.Owned_Context,held:r.Owner_Retains,connection:^Session_Connection(S,C,A,E,N),allocator:mem.Allocator}
@(private)
session_role_stage :: proc(s:^Session($S,$C,$A,$E,$N),model:net.Model(S,C,A,E,N),options:Session_Options,permit_context:r.Owned_Context)->(Role_Reset_Stage(S,C,A,E,N),net.Error){
 stage:=Role_Reset_Stage(S,C,A,E,N){ownership=s.ownership,models=s.model_owners,allocator=s.allocator}
 if error:=session_retired_drain(s);error!=.None{return stage,error}
 stats,status:=rt.managed_callable_stats();if status!=bg.OK || stats.inflight_calls!=0{return stage,.Wrong_Phase}
 permit_context:=permit_context;if r.owner_is_nil(permit_context.owner){permit_context=s.ownership.permit}
 if r.owned_context_access(permit_context,options.permit.user,true,.Execute)!=.None{return stage,.Invalid_Model}
 stage.ownership.permit=permit_context
 if r.owner_retains_acquire(&stage.held,s.retained.owners[:s.retained.count])!=.None{return stage,.Invalid_Model}
 if net.model_ownership_retain(&stage.held,model)!=.None{return stage,.Invalid_Model}
 owners:=[?]r.Owner{model.complete_codec.ownership.data_context.owner,permit_context.owner}
 if r.owner_retains_acquire(&stage.held,owners[:])!=.None{return stage,.Invalid_Model}
 connection,error:=session_connection_open(s,options);stage.connection=connection
 return stage,error
}
@(private)
session_role_discard :: proc(s:^Session($S,$C,$A,$E,$N),stage:^Role_Reset_Stage(S,C,A,E,N)){
 if stage.connection!=nil{if session_connection_close(&stage.connection)!=.None{s.retired_connection=stage.connection;stage.connection=nil}}
 if r.owner_retains_drop(&stage.held)!=.None{s.retired_session=stage.held;stage.held={}}
}
@(private)
session_takeover_owned :: proc(s:^Session($S,$C,$A,$E,$N),cp:^net.Checkpoint(S,C,A,N),model:net.Model(S,C,A,E,N),options:Session_Options,report:net.Client_Recovery,seat:u16,permit_context:r.Owned_Context)->net.Error{
 stage,error:=session_role_stage(s,model,options,permit_context);defer session_role_discard(s,&stage);if error!=.None{return error}
 changes,change_error:=session_reset_effects(s,options.network.epoch,cp.frame.tick);if change_error!=.None{return change_error}
 serial:=s.recovery_serial
 if error:=session_close(s);error!=.None{delete(changes,stage.allocator);return error}
 s.model_owners=stage.models;s.connection=stage.connection;stage.connection=nil
 if error:=session_resume(s,cp,model,options,{epoch=options.network.epoch,local_seat=seat,permit=options.permit},allocator=stage.allocator,ownership=stage.ownership);error!=.None{delete(changes,stage.allocator);return error}
 s.reset_changes,s.recovery,s.recovery_serial=changes,report,serial+1;return .None
}
@(private)
session_rejoin_owned :: proc(s:^Session($S,$C,$A,$E,$N),model:net.Model(S,C,A,E,N),options:Session_Options,history:net.Departing_Host(S,C,A,N),complete:^net.Complete_Departing_Host(S,C,A,E,N),epoch:u64,permit_context:r.Owned_Context)->net.Error{
 stage,error:=session_role_stage(s,model,options,permit_context);defer session_role_discard(s,&stage);if error!=.None{return error}
 changes,change_error:=session_reset_effects(s,epoch,0);if change_error!=.None{return change_error}
 serial:=s.recovery_serial
 if error:=session_close(s);error!=.None{delete(changes,stage.allocator);return error}
 s.model_owners=stage.models;s.connection=stage.connection;stage.connection=nil
 if error:=session_open(s,r.Frame(S){},model,options,allocator=stage.allocator,ownership=stage.ownership);error!=.None{delete(changes,stage.allocator);return error}
 seed_error:net.Error
 if model.complete_state{seed_error=net.client_seed_departing_complete(&s.client,complete)}else{seed_error=net.client_seed_departing(&s.client,history)}
 if seed_error!=.None{delete(changes,stage.allocator);session_close(s);return seed_error}
 if error:=net.client_authority(&s.client,epoch,s.wire,permit=options.permit);error!=.None{delete(changes,stage.allocator);session_close(s);return error}
 s.reset_changes,s.recovery_serial=changes,serial;return .None
}
