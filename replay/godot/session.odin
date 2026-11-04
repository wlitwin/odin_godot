package replay_godot

import gd "godot:godot"
import "godot:gdext"
import bg "godot:box3d/godot"
import rt "godot:runtime"
import meter "godot:box3d/godot/meter"
import r "godot:replay"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"
import view "godot:replay/view"
import "core:mem"
import storagegd "godot:replay/godot/storage"
import transportgd "godot:replay/godot/transport"

Session_Role :: enum u8 {Solo, Host, Server, Client, Observer}
Session_Backend :: enum u8 {Enet, Rtc, Steam}
Session_Options :: struct {
	role: Session_Role,
	backend: Session_Backend,
	steam:transportgd.Steam_Config,
	rtc: transportgd.Rtc_Config, // strings are borrowed only during open/resume
	port: u16,
	address: cstring,
	token: net.Token,
	latency_ms, jitter_ms, loss_permyriad, duplicate_permyriad: u32,
	network: net.Config,
	replication: rec.Link_Config,
	permit: net.Permit,
	incarnation: u64,
	discover_epoch:bool, // explicit direct-session preflight; leased sessions reject it
	reuse_equal_corrections:bool, // opt-in; step dependencies must be complete/stable
	disable_lz4: bool, // local delivery preference; not part of durable game state
	disable_snapshot_erasure: bool,
	disable_snapshot_shuffle: bool,
	disable_compact_recent_facts: bool, // optional shared-header recent-fact encoding
	disable_compact_observations: bool, // optional packet-local observation encoding
	disable_action_copies: bool,
	remote_observed: bool, // local effects predict; event_owner selects remote watched effects
}
SESSION_OPTIONS :: Session_Options{role = .Solo, port = 49422, address = "127.0.0.1", network = net.DEFAULT_CONFIG, replication = rec.DEFAULT_LINK_CONFIG}

// Godot-facing lifecycle shell. The game supplies its model, controls/actions,
// and view. Simulation and session ownership remain in the underlying public APIs.
Session_Ownership :: struct {
 allocator,container,permit:r.Owned_Context,
 rtc_ice,rtc_authorization:r.Owned_Context,
 allocation_base:rawptr,
 allocation_bytes:u64,
 identity:r.Owned_Context,
}
Session :: struct($State, $Control, $Action, $Event: typeid, $Seats: int) {
 ownership:Session_Ownership,
 retained:r.Owner_Retains,
 model_owners:[2]r.Owned_Context,
 connection:^Session_Connection(State,Control,Action,Event,Seats),
 retired_connection:^Session_Connection(State,Control,Action,Event,Seats),
 retired_client,retired_session:r.Owner_Retains,
 cleanup:bool,
	ready, authority, fenced: bool,
	control_consumed: bool, // actual input use in the last session_frame, not timeline movement
	allocator: mem.Allocator,
	options: Session_Options,
	role: Session_Role,
	token: net.Token,
	clock: r.Clock,
	enet: transportgd.Enet,
	steam:transportgd.Steam,
	rtc: transportgd.Rtc,
	delay: tr.Delay,
	wire, base_wire: tr.Transport,
	link: rec.Link(State, Control, Action, Event, Seats),
	server: net.Server(State, Control, Action, Event, Seats),
	client: net.Client(State, Control, Action, Event, Seats),
	changes: [net.WIRE_EVENTS * 8]view.Change(net.Net_Event(Event)),
	change_count: int,
	reset_changes: []view.Change(net.Net_Event(Event)),
	reset_index: int,
	recovery: net.Client_Recovery,
	recovery_serial: u64,
}

session_open :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats), initial: r.Frame(State),
                     model: net.Model(State, Control, Action, Event, Seats), options := SESSION_OPTIONS,allocator:=context.allocator,ownership:Session_Ownership={}) -> net.Error {
	if s.ready || (options.discover_epoch && options.network.require_permit) {return .Invalid_Config}
 if error:=session_begin(s,model,options,allocator,ownership);error!=.None{return error}
	s.options = options; s.options.address = nil; s.options.rtc = {};s.options.steam.peer=nil // transient caller strings are not retained
	if err := session_connect(s, options); err != .None {return err}
	s.token = options.token
	empty_token: net.Token
	if s.token == empty_token {s.token = storagegd.session_token()}
	err: net.Error
	if s.authority {
		err = net.server_init(&s.server, initial, model, s.wire, options.network, local_seat = options.role == .Server ? 0 : 1, permit = options.permit, incarnation = options.incarnation,allocator=s.allocator,ownership=session_runner_ownership(s,s.authority))
		if err==.None {s.server.epoch_discovery=options.discover_epoch;s.server.compact_observations_disabled=options.disable_compact_observations;s.server.compact_recent_facts_disabled=options.disable_compact_recent_facts}
		if err == .None && s.server.local_seat != 0 {err = net.server_set_local_token(&s.server, s.token)}
	} else {
		err = net.client_init(&s.client, model, s.wire, s.token, spectator = options.role == .Observer, cfg = options.network, permit = options.permit, incarnation = options.incarnation,allocator=s.allocator,ownership=session_runner_ownership(s,s.authority))
		if err==.None && options.discover_epoch {err=net.client_discover_epoch(&s.client,storagegd.session_token())}
		if err == .None {
			s.client.lz4_snapshots_enabled = !options.disable_lz4
			s.client.snapshot_erasure_enabled = !options.disable_snapshot_erasure
			s.client.snapshot_shuffle_enabled = !options.disable_snapshot_shuffle
			s.client.action_copies_enabled = !options.disable_action_copies
			s.client.compact_observations_enabled = !options.disable_compact_observations
   s.client.compact_recent_facts_enabled = !options.disable_compact_recent_facts
			s.client.reuse_equal_corrections=options.reuse_equal_corrections
			if options.remote_observed {net.client_remote_observed(&s.client)}
		}
	}
	if err != .None {session_close(s); return err}
	if !s.authority {
		s.client.profile_clock.read = proc(user: rawptr) -> (u64, bool) {return gd.time_get_ticks_usec(gd.singleton_time()), true}
	}
	r.clock_init(&s.clock, options.network.hz)
	s.ready = true
	return .None
}

// Starts a fresh authority runtime at a complete checkpoint. The caller chooses
// the newer epoch and recovery policy; this function does not elect/fence a host.
session_resume :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats),
                       cp: ^net.Checkpoint(State, Control, Action, Seats),
                       model: net.Model(State, Control, Action, Event, Seats),
                       options: Session_Options, resume: net.Resume_Options,allocator:=context.allocator,ownership:Session_Ownership={}) -> net.Error {
	if s.ready || (options.role != .Solo && options.role != .Host && options.role != .Server) {return .Wrong_Phase}
 if error:=session_begin(s,model,options,allocator,ownership);error!=.None{return error}
 committed:=false;defer if !committed{session_close(s)}
	s.options = options; s.options.address = nil; s.options.rtc = {};s.options.steam.peer=nil
	if options.discover_epoch && (cp.settings.require_permit || options.network.require_permit) {return .Invalid_Config}
	if !cp.ready || cp.header.content != options.network.content || cp.settings.hz != options.network.hz {return .Checkpoint_Contract}
	if options.role == .Server {
		if resume.local_seat != 0 {return .Invalid_Config}
	} else {
		seat, found := net.checkpoint_seat(cp, options.token)
		if !found || seat != resume.local_seat {return .Invalid_Input}
	}
	if err := session_connect(s, options); err != .None {return err}
	resume:=resume
	if options.incarnation!=0 {resume.local_incarnation=options.incarnation}
	if err := net.server_restore(&s.server,cp,model,s.wire,resume,allocator=s.allocator,ownership=session_runner_ownership(s,true)); err != .None {return err}
	s.server.epoch_discovery=options.discover_epoch;s.server.compact_observations_disabled=options.disable_compact_observations;s.server.compact_recent_facts_disabled=options.disable_compact_recent_facts
	s.token = options.token
	r.clock_init(&s.clock, s.server.cfg.hz)
 committed=true
	s.ready = true
	return .None
}

session_save :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats), path: string,
                     policy_id: u64 = 0, policy_data: []u8 = nil) -> storagegd.Storage_Result {
	if !s.ready || !s.authority {return {.Codec, .Wrong_Phase}}
	cp: net.Checkpoint(State, Control, Action, Seats)
	defer net.checkpoint_destroy(&cp)
	if err := net.checkpoint_capture(&s.server,&cp,policy_id,policy_data,allocator=s.allocator); err != .None {return {.Codec, err}}
	codec:^net.Checkpoint_Codec
 if session_link(s).publish_codec.ready{codec=&session_link(s).publish_codec}
 return storagegd.checkpoint_write(&cp,s.server.model,path,codec,allocator=s.allocator)
}

// Explicitly authorize one admitted remote player to receive complete authority
// checkpoints. Automatic takeover remains a separate coordinator/fencing policy.
session_backup_seat :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats), seat: u16,
                           interval_ticks: u32 = 0, policy_id: u64 = 0, policy_data: []u8 = nil) -> net.Error {
	if !s.ready || !s.authority || !session_link(s).ready {return .Wrong_Phase}
	connection, live := net.server_seat_connection(&s.server, seat)
	if !live {return .Invalid_Input}
	return session_backup_peer(s,connection.peer,interval_ticks,policy_id,policy_data)
}

// Explicit trust for a live admitted connection, including an infrastructure
// observer with no playable seat. This does not nominate or authorize takeover.
session_backup_peer :: proc(s:^Session($S,$C,$A,$E,$N),peer:tr.Peer_Id,
                           interval_ticks:u32=0,policy_id:u64=0,policy_data:[]u8=nil)->net.Error {
	if !s.ready || !s.authority || !session_link(s).ready {return .Wrong_Phase}
	return rec.link_target(session_link(s),&s.server,peer,interval_ticks,policy_id,policy_data)
}

session_backup_receipt :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats)) -> (rec.Receipt, bool) {
	if !s.ready || !session_link(s).ready {return {}, false}
	if s.authority {return session_link(s).outgoing.acknowledged, session_link(s).outgoing.acknowledged.archive.sequence != 0}
	return rec.receiver_latest(session_link(s).incoming)
}

@(private)
session_connect :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats), options: Session_Options, preserve_runtime: bool = false) -> net.Error {
	s.role = options.role
	s.authority = options.role == .Solo || options.role == .Host || options.role == .Server
 if !r.owner_is_nil(s.ownership.container.owner) {
  if options.backend!=.Enet&&options.backend!=.Rtc{return .Invalid_Config}
  connection:=s.connection
  if connection==nil{opened,error:=session_connection_open(s,options);if error!=.None{return error};connection=opened}
  s.connection=connection;s.base_wire=connection.base_wire;s.wire=connection.wire
  return .None
 }
	if options.role != .Solo {
		switch options.backend {
		case .Enet:
			ok := s.authority ? transportgd.enet_host(&s.enet, options.port, 16) : transportgd.enet_join(&s.enet, options.address, options.port)
			if !ok {return .Transport}
			s.base_wire = transportgd.enet_transport(&s.enet)
		case .Rtc:
			cfg := options.rtc; cfg.host = s.authority
			if !transportgd.rtc_open(&s.rtc, cfg, s.allocator) {return .Transport}
			s.base_wire = transportgd.rtc_transport(&s.rtc)
		case .Steam:
			if transportgd.steam_open(&s.steam,options.steam,s.authority)!=.None {return .Transport}
			s.base_wire=transportgd.steam_transport(&s.steam)
		case: return .Invalid_Config
		}
		if options.latency_ms > 0 || options.jitter_ms > 0 || options.loss_permyriad > 0 || options.duplicate_permyriad > 0 {
			if !tr.delay_init(&s.delay, s.base_wire, options.latency_ms) {if preserve_runtime {session_disconnect(s)} else {session_close(s)}; return .Invalid_Config}
			s.base_wire = tr.delay_transport(&s.delay)
			if !tr.delay_faults(&s.delay, options.jitter_ms, options.loss_permyriad, options.duplicate_permyriad, 42) {if preserve_runtime {session_disconnect(s)} else {session_close(s)}; return .Invalid_Config}
		}
		if !rec.link_init(session_link(s), s.base_wire, options.replication) {if preserve_runtime {session_disconnect(s)} else {session_close(s)}; return .Invalid_Config}
		s.wire = rec.link_game_transport(session_link(s))
	}
	return .None
}

@(private)
session_disconnect :: proc(s: ^Session($S, $C, $A, $E, $N)) {
	rec.link_destroy(session_link(s)); tr.close(&s.base_wire)
	s.wire, s.client.wire, s.server.wire = {}, {}, {}
}

session_close :: proc(s:^Session($State,$Control,$Action,$Event,$Seats))->net.Error {
 if r.owner_retains_access(&s.retained)!=.None{return .Invalid_Model}
 if !s.cleanup {
  if !r.owner_is_nil(s.ownership.container.owner){
   callbacks,status:=rt.managed_callable_stats();if status!=bg.OK || callbacks.inflight_calls!=0{return .Wrong_Phase}
   if s.connection!=nil&&s.connection.backend==.Rtc&&s.connection.rtc.callback_depth!=0{return .Wrong_Phase}
  }
  if error:=session_retired_drain(s);error!=.None{return error}
  if net.server_destroy(&s.server)!=.None || net.client_destroy(&s.client)!=.None{return .Wrong_Phase}
  if s.connection!=nil {
   if error:=session_connection_close(&s.connection);error!=.None{return error}
  } else {if rec.link_destroy(&s.link)!=.None{return .Wrong_Phase};tr.close(&s.base_wire)}
  delete(s.reset_changes,s.allocator)
 }
 retained:=s.retained;s^={}
 if r.owner_retains_drop(&retained)!=.None{s.retained=retained;s.cleanup=true;return .Wrong_Phase}
 return .None
}

session_frame :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats), dt: f64, control: Control) -> net.Error {
 if r.owner_retains_access(&s.retained,.Execute)!=.None{return .Invalid_Model}
 // A committed new connection stays active while an old cleanup retries.
 if s.retired_connection!=nil || s.retired_client.count!=0 || s.retired_session.count!=0{_=session_retired_drain(s)}
	s.control_consumed = false
	if !s.ready {return .Not_Initialized}
	if s.change_count != 0 {return .Presentation} // consume the previous frame's effects first
	if s.reset_index < len(s.reset_changes) {
		s.change_count = min(len(s.changes), len(s.reset_changes) - s.reset_index)
		copy(s.changes[:s.change_count], s.reset_changes[s.reset_index:s.reset_index + s.change_count])
		s.reset_index += s.change_count
		r.clock_init(&s.clock, s.authority ? s.server.cfg.hz : s.client.cfg.hz)
		return .None
	}
	now := u64(gd.time_get_ticks_msec(gd.singleton_time()))
	delay := s.connection != nil ? &s.connection.delay : &s.delay
	if delay.packets != nil {tr.delay_time(delay, now)}
	if session_link(s).ready && !rec.link_pump(session_link(s), now) {return .Invalid_Time}
	catchups := s.client.stats.snapshot_catchups
	// Complete-physics Snapshot preparation before a due step would encode
	// the old head, then require a separate signature for the new head's fact.
	// Receive first; the existing step flush publishes the current head.
	coalesce_physics := s.authority && s.server.physics != nil
	err := s.authority ? net.server_pump(&s.server, now, flush_egress = !coalesce_physics) : net.client_pump(&s.client, now)
	if err == .Fenced {
		s.fenced = true; r.clock_init(&s.clock, s.authority ? s.server.cfg.hz : s.client.cfg.hz)
		if !s.authority {s.change_count = view.drain(&s.client.journal, s.changes[:])}
		return .None
	}
	if err != .None {return err}
	// Runs before this public call returns, including zero-step and error
	// paths. Standalone pumps and non-physics sessions retain their behavior.
	defer if coalesce_physics {_ = net.server_flush_pending(&s.server)}
	s.fenced = false
	scale := s.authority ? f64(1) : s.client.clock_scale
	elapsed := dt * scale
	if !s.authority && s.client.stats.snapshot_catchups != catchups {
		r.clock_init(&s.clock, s.client.cfg.hz)
		elapsed = 0 // prediction lead was already rebuilt from the new snapshot
	}
	steps, ok := r.clock_add(&s.clock, elapsed)
	if !ok {return .Invalid_Time}
	for _ in 0 ..< steps {
		if s.authority {
			if s.server.local_seat != 0 {if err := net.server_local(&s.server, control); err != .None {return err}}
			if err := net.server_step(&s.server); err != .None {
				if err == .Fenced {s.fenced = true; r.clock_init(&s.clock, s.server.cfg.hz); break}
				return err
			}
			s.control_consumed = s.server.local_seat != 0
			events: [net.WIRE_EVENTS]r.Occurrence(net.Net_Event(Event))
			n, _ := r.copy_events(&s.server.timeline, s.server.timeline.head, events[:])
			for event in events[:n] {
				s.changes[s.change_count] = {kind = .Begin, occurrence = event, confirmed = true}
				s.change_count += 1
			}
		} else if s.client.phase == .Running && !s.client.spectator {
			err := net.client_step(&s.client, control)
			if err == .None {s.control_consumed = true}
			else if err != .Capacity {
				if err == .Fenced {s.fenced = true; r.clock_init(&s.clock, s.client.cfg.hz); break}
				return err
			}
		}
		r.clock_consume(&s.clock)
	}
	if !s.authority {
		if report, ready := net.client_recovery(&s.client); ready {s.recovery = report; s.recovery_serial += 1}
		s.change_count = view.drain(&s.client.journal, s.changes[:])
		// Welcome can settle actions whose original facts were lost during a
		// resync. Deliver those outcomes even though the old journal was reset.
		outcomes: [net.ACTION_CAPACITY]net.Action_Outcome
		recovered: [net.ACTION_CAPACITY]bool
		count := net.client_outcomes(&s.client, outcomes[:min(len(outcomes),len(s.changes)-s.change_count)], recovered[:])
		for outcome,i in outcomes[:count] {if recovered[i] {
			event := net.Net_Event(Event){kind=.Action_Result,seat=s.client.seat,sequence=outcome.sequence,applied=outcome.applied,reason=outcome.reason}
			s.changes[s.change_count] = {kind=.Begin,confirmed=true,occurrence={id={s.client.cfg.epoch,outcome.tick,0,outcome.sequence<<8|u64(s.client.seat)},value=event}}
			s.change_count += 1
		}}
	}
	if session_link(s).ready && !s.fenced {
		if s.authority {rec.link_server(session_link(s), &s.server, now)} else {rec.link_client(session_link(s), &s.client, now)}
	}
	return .None
}

session_issue :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats), action: Action) -> (sequence: u64, error: net.Error) {
 if r.owner_retains_access(&s.retained,.Execute)!=.None{return 0,.Invalid_Model}
	if !s.ready {return 0, .Not_Initialized}
	if s.authority {return net.server_issue(&s.server, action)}
	return net.client_issue(&s.client, action)
}

session_state :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats)) -> (frame: r.Frame(State), ok: bool) {
 if r.owner_retains_access(&s.retained,.Execute)!=.None{return {},false}
	if !s.ready {return}
	if s.authority {return r.current(&s.server.timeline)}
	if s.client.phase != .Running && !(s.client.recovering && s.client.has_world) {return}
	return r.current(&s.client.timeline)
}

session_seat :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats)) -> u16 {
	return s.authority ? s.server.local_seat : s.client.seat
}

// Authority observations for permissions and external engine adapters. Client
// prediction is not permission to publish an owner stream or commit a handoff.
session_authority_state :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats)) -> (frame: r.Frame(State), ok: bool) {
 if r.owner_retains_access(&s.retained,.Execute)!=.None{return {},false}
	if !s.ready || s.fenced {return}
	if s.authority {return r.current(&s.server.timeline)}
	if s.client.phase != .Running {return}
	return s.client.authority_frame, true
}

session_changes :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats), dst: []view.Change(net.Net_Event(Event))) -> int {
 if r.owner_retains_access(&s.retained,.Execute)!=.None{return 0}
	n := min(len(dst), s.change_count)
	copy(dst, s.changes[:n])
	for i in n ..< s.change_count {s.changes[i - n] = s.changes[i]}
	s.change_count -= n
	return n
}

// The pure import does not activate a profile. Compile flags alone are not
// evidence that a native-free script uses managed physics.
@(private)
session_sdk_physics :: proc(model:net.Model($S,$C,$A,$E,$N))->bool{return model.complete_state && bg.module_profile()!=0}

// The optional SDK path uses one existing Link/Router and one Server/Client.
// Connection generations never move after initialization.
Session_Connection :: struct($S,$C,$A,$E:typeid,$N:int){
 meter_ctx:^meter.Context,allocator:mem.Allocator,
 allocator_owner,self:r.Owned_Context,
 creators:r.Owner_Retains,
 backend:Session_Backend,
 enet:transportgd.Enet,rtc:transportgd.Rtc,delay:tr.Delay,link:rec.Link(S,C,A,E,N),
 base_wire,wire:tr.Transport,
 lanes:^Session_Lane_Lease,
 children_closed,transport_closed,free_requested:bool,
}
@(private)
Session_Lane_Lease :: struct {next,owned_next:^Session_Lane_Lease,user:rawptr,block:bg.Data_Lease,parent:r.Owner,refs:u32,allocator:mem.Allocator}
@(private) session_lanes:^Session_Lane_Lease
session_link :: proc(s:^Session($S,$C,$A,$E,$N))->^rec.Link(S,C,A,E,N){return s.connection!=nil?&s.connection.link:&s.link}
session_transport :: proc(s:^Session($S,$C,$A,$E,$N))->tr.Transport{return s.wire}
// Borrowed live RTC state for room/status/continuation helpers; no phase mutation.
session_rtc :: proc(s:^Session($S,$C,$A,$E,$N))->^transportgd.Rtc{return s.connection!=nil?&s.connection.rtc:&s.rtc}
@(private)
session_make_owner :: proc(lease:bg.Data_Lease)->(r.Owned_Context,net.Error){
 lease:=lease
 service:=bg.service_get();if service.owner_create==nil{return {},.Invalid_Model}
 owner:bg.Owner;status:=service.owner_create(service.user,0,&lease,&owner)
 return {owner,lease.user},status==bg.OK?net.Error.None:net.Error.Invalid_Model
}
@(private)
session_block_owner :: proc(allocator:mem.Allocator,base:rawptr,bytes:u64,user:rawptr,user_bytes:u64)->(r.Owned_Context,net.Error){
 ctx,status:=meter.context_for(allocator);if status!=bg.OK{return {},.Invalid_Model}
 lease,ls:=meter.block_lease(ctx,base,bytes,user,user_bytes);if ls!=bg.OK{return {},.Invalid_Model}
 return session_make_owner(lease)
}
@(private)
session_begin :: proc(s:^Session($S,$C,$A,$E,$N),model:net.Model(S,C,A,E,N),options:Session_Options,allocator:mem.Allocator,ownership:Session_Ownership)->net.Error {
 if s.ready || s.cleanup{return .Wrong_Phase}
 managed:=!r.owner_is_nil(ownership.container.owner)
 if session_sdk_physics(model) && !managed{return .Invalid_Model}
 if !managed{s.allocator=allocator;return .None}
 if (options.backend!=.Enet&&options.backend!=.Rtc) || options.role==.Solo{return .Invalid_Config}
 if r.owner_contexts_check({owner=ownership.allocator.owner,owner_allocator_data=ownership.allocator.data},allocator)!=.None ||
  r.owned_context_access(ownership.container,s,true,.Execute)!=.None || r.owned_context_access(ownership.permit,options.permit.user,true,.Execute)!=.None ||
  net.model_ownership_check(model,true)!=.None{return .Invalid_Model}
 s.ownership=ownership;s.allocator=allocator
 owners:=[?]r.Owner{ownership.allocator.owner,ownership.permit.owner,ownership.container.owner,ownership.rtc_ice.owner,ownership.rtc_authorization.owner,ownership.identity.owner}
 if r.owner_retains_acquire(&s.retained,owners[:])!=.None{return .Invalid_Model}
 for index in 0..<2 {
  user:rawptr=index==0?rawptr(&s.server.model):rawptr(&s.client.model)
  alias:=s.model_owners[index]
  if r.owner_is_nil(alias.owner){
   created,error:=session_block_owner(allocator,ownership.allocation_base,ownership.allocation_bytes,user,size_of(net.Model(S,C,A,E,N)))
   if error!=.None{session_close(s);return error};alias=created
  }else{if r.owned_context_access(alias,user,true,.Execute)!=.None || r.owner_retain(alias.owner)!=.None{session_close(s);return .Invalid_Model}}
  s.model_owners[index]=alias;s.retained.owners[s.retained.count]=alias.owner;s.retained.count+=1
 }
 return .None
}
@(private)
session_runner_ownership :: proc(s:^Session($S,$C,$A,$E,$N),authority:bool)->net.Runner_Ownership {
 if r.owner_is_nil(s.ownership.container.owner){return {}}
 return {allocator=s.ownership.allocator,model=s.model_owners[authority?0:1],wire=rec.link_game_owner(session_link(s)),permit=s.ownership.permit,identity=s.ownership.identity}
}
@(private)
session_connection_alias :: proc(c:^Session_Connection($S,$C,$A,$E,$N),user:rawptr,bytes:u64)->(r.Owned_Context,net.Error){
 binding,error:=session_block_owner(c.allocator,c,size_of(c^),user,bytes);if error!=.None{return {},error}
 if c.creators.count==len(c.creators.owners){r.owner_drop(&binding.owner);return {},.Capacity}
 c.creators.owners[c.creators.count]=binding.owner;c.creators.count+=1
 return binding,.None
}
@(private)
session_connection_open :: proc(s:^Session($S,$C,$A,$E,$N),options:Session_Options)->(result:^Session_Connection(S,C,A,E,N),error:net.Error){
 service:=bg.service_get();ctx,status:=meter.create(service,bg.CATEGORY_REPLAY_CORE);if status!=bg.OK{return nil,.Capacity}
 alloc:=meter.allocator(ctx);c,allocation_error:=new(Session_Connection(S,C,A,E,N),alloc)
 if allocation_error!=.None || c==nil{meter.destroy(&ctx);return nil,.Capacity}
 c.meter_ctx=ctx;c.allocator=alloc;c.backend=options.backend
 allocator_owner,ae:=session_make_owner(meter.data_lease(ctx));if ae!=.None{mem.free(c,alloc);meter.destroy(&ctx);return nil,ae};c.allocator_owner=allocator_owner
 self,se:=session_block_owner(alloc,c,size_of(c^),c,size_of(c^));if se!=.None{owner:=c.allocator_owner.owner;mem.free(c,alloc);r.owner_drop(&owner);meter.destroy(&ctx);return nil,se};c.self=self
 committed:=false;defer if !committed{
  if cleanup_error:=session_connection_close(&c);cleanup_error!=.None{s.retired_connection=c}
 }
 base_owner:r.Owned_Context
 switch options.backend{
 case .Enet:
  packets,pe:=session_connection_alias(c,&c.enet.packets,size_of(c.enet.packets));if pe!=.None{return nil,pe}
  if transportgd.multiplayer_prepare(&c.enet.packets,{allocator=allocator_owner,container=packets})!=bg.OK{return nil,.Invalid_Model}
  opened:=(options.role==.Host || options.role==.Server || options.role==.Solo)?transportgd.enet_host(&c.enet,options.port,16,allocator=alloc):transportgd.enet_join(&c.enet,options.address,options.port,allocator=alloc)
  if !opened{return nil,.Transport}
  c.base_wire=transportgd.enet_transport(&c.enet);base_owner=packets
 case .Rtc:
  container,ce:=session_connection_alias(c,&c.rtc,size_of(c.rtc));if ce!=.None{return nil,ce}
  configuration,ve:=session_connection_alias(c,&c.rtc.config,size_of(c.rtc.config));if ve!=.None{return nil,ve}
  ice,authorization:=s.ownership.rtc_ice,s.ownership.rtc_authorization
  if options.rtc.ice_source!=nil&&options.rtc.ice_user==nil&&r.owner_is_nil(ice.owner){ice=configuration}
  if options.rtc.authorize!=nil&&options.rtc.authorization_user==nil&&r.owner_is_nil(authorization.owner){authorization=configuration}
  owned:=transportgd.Rtc_Ownership{allocator=allocator_owner,container=container,configuration=configuration,ice=ice,authorization=authorization}
  if transportgd.rtc_prepare(&c.rtc,owned)!=bg.OK{return nil,.Invalid_Model}
  cfg:=options.rtc;cfg.host=options.role==.Host||options.role==.Server
  if !transportgd.rtc_open(&c.rtc,cfg,alloc){return nil,.Transport}
  c.base_wire=transportgd.rtc_transport(&c.rtc);base_owner=container
 case .Steam:return nil,.Invalid_Config
 }

 if options.latency_ms!=0 || options.jitter_ms!=0 || options.loss_permyriad!=0 || options.duplicate_permyriad!=0 {
  delay_owner,de:=session_connection_alias(c,&c.delay,size_of(c.delay));if de!=.None{return nil,de}
  if !tr.delay_init(&c.delay,c.base_wire,options.latency_ms,allocator=alloc) || !tr.delay_faults(&c.delay,options.jitter_ms,options.loss_permyriad,options.duplicate_permyriad,42){return nil,.Capacity}
  c.base_wire=tr.delay_transport(&c.delay);base_owner=delay_owner
 }
 owned:rec.Link_Ownership;owned.allocator=allocator_owner;owned.wire=base_owner;owned.lane_user=self
 owned.container,error=session_connection_alias(c,&c.link,size_of(c.link));if error!=.None{return nil,error}
 owned.config,error=session_connection_alias(c,&c.link.cfg,size_of(c.link.cfg));if error!=.None{return nil,error}
 outgoing,e:=session_connection_alias(c,&c.link.outgoing,size_of(c.link.outgoing));if e!=.None{return nil,e}
 incoming,ie:=session_connection_alias(c,&c.link.incoming,size_of(c.link.incoming));if ie!=.None{return nil,ie}
 incoming_model,ime:=session_connection_alias(c,&c.link.incoming.model,size_of(c.link.incoming.model));if ime!=.None{return nil,ime}
 incoming_codec,ice:=session_connection_alias(c,&c.link.incoming.archive_codec,size_of(c.link.incoming.archive_codec));if ice!=.None{return nil,ice}
 publish_codec,pce:=session_connection_alias(c,&c.link.publish_codec,size_of(c.link.publish_codec));if pce!=.None{return nil,pce}
 owned.outgoing={allocator=allocator_owner,container=outgoing}
 owned.incoming={transfer={allocator=allocator_owner,container=incoming,accept=incoming},model=incoming_model,codec={allocator=allocator_owner,data_context=incoming_codec}}
 owned.codec={allocator=allocator_owner,data_context=publish_codec}
 owned.lane_owner=proc(user:rawptr,router:^tr.Router,wire:tr.Transport)->(r.Owned_Context,net.Error){return session_lane_owner(cast(^Session_Connection(S,C,A,E,N))user,router,wire)}
 if !rec.link_init(&c.link,c.base_wire,options.replication,alloc,ownership=owned){return nil,.Invalid_Config}
 c.wire=rec.link_game_transport(&c.link);committed=true;return c,.None
}
@(private)
session_lane_owner :: proc(c:^Session_Connection($S,$C,$A,$E,$N),router:^tr.Router,wire:tr.Transport)->(r.Owned_Context,net.Error){
 ctx:=c.meter_ctx
 lease,status:=meter.block_lease(ctx,raw_data(router.lanes),u64(len(router.lanes))*size_of(router.lanes[0]),wire.user,size_of(router.lanes[0]));if status!=bg.OK{return {},.Invalid_Model}
 node,allocation_error:=new(Session_Lane_Lease,c.allocator);if allocation_error!=.None || node==nil{return {},.Capacity}
 node^={next=session_lanes,owned_next=c.lanes,user=wire.user,block=lease,parent=c.self.owner,allocator=c.allocator};session_lanes=node;c.lanes=node
 return session_make_owner({wire.user,session_lane_retain,session_lane_drop})
}
@(private)
session_lane_retain :: proc "c"(user:rawptr)->bg.Status {
 context=gdext.godot_context();node:=session_lanes
 for node!=nil{if node.user==user{break};node=node.next};if node==nil{return bg.INVALID_HANDLE}
 if node.block.retain(user)!=bg.OK{return bg.INVALID_HANDLE}
 if r.owner_retain(node.parent)!=.None{node.block.drop(user);return bg.INCOMPATIBLE}
 node.refs+=1;return bg.OK
}
@(private)
session_lane_drop :: proc "c"(user:rawptr)->bg.Status {
 context=gdext.godot_context();node:=session_lanes
 for node!=nil{if node.user==user{break};node=node.next};if node==nil || node.refs==0{return bg.INVALID_HANDLE}
 parent:=node.parent
 if r.owner_drop(&parent)!=.None{return bg.INCOMPATIBLE}
 if node.block.drop(user)!=bg.OK{return bg.INVALID_HANDLE}
 node.refs-=1;return bg.OK
}
@(private)
session_connection_close :: proc(owner:^^Session_Connection($S,$C,$A,$E,$N))->net.Error {
 if owner==nil || owner^==nil{return .None};c:=owner^
 if r.owner_access(c.self.owner)!=.None{return .Invalid_Model}
 if !c.children_closed {
  if error:=session_connection_retire(c);error!=.None{return error}
  node:=c.lanes
  for node!=nil{if node.refs!=0{return .Wrong_Phase};node=node.owned_next}
  node=c.lanes
  for node!=nil{
   next:=node.owned_next;previous:^Session_Lane_Lease;scan:=session_lanes
   for scan!=node{previous=scan;scan=scan.next}
   if previous==nil{session_lanes=node.next}else{previous.next=node.next}
   mem.free(node,node.allocator);node=next
  }
  c.lanes=nil;c.children_closed=true
 }
 if r.owner_retains_drop(&c.creators)!=.None{return .Wrong_Phase}
 ctx,alloc,allocator_owner,self:=c.meter_ctx,c.allocator,c.allocator_owner.owner,c.self.owner
 if !c.free_requested{c.free_requested=true;mem.free(c,alloc)}
 if r.owner_drop(&self)!=.None{return .Wrong_Phase}
 owner^=nil
 if r.owner_drop(&allocator_owner)!=.None{return .Wrong_Phase}
 return meter.destroy(&ctx)==bg.OK?net.Error.None:net.Error.Wrong_Phase
}

// Logical close can complete while an old Client table still retains exact lane
// blocks. Full physical cleanup follows only after that retired table releases.
@(private)
session_connection_retire :: proc(c:^Session_Connection($S,$C,$A,$E,$N))->net.Error {
 if c==nil{return .None}
 if r.owner_access(c.self.owner)!=.None{return .Invalid_Model}
 if c.transport_closed{return .None}
 if c.backend==.Rtc{if transportgd.rtc_try_close(&c.rtc)!=bg.OK{return .Wrong_Phase}}else{if transportgd.multiplayer_try_close(&c.enet.packets)!=bg.OK{return .Wrong_Phase}}
 if rec.link_destroy(&c.link)!=.None{return .Wrong_Phase}
 if c.delay.packets!=nil{c.delay.base={};wire:=tr.delay_transport(&c.delay);tr.close(&wire)}
 c.transport_closed=true;return .None
}
@(private)
session_retired_drain :: proc(s:^Session($S,$C,$A,$E,$N))->net.Error {
 if s.retired_connection!=nil{if error:=session_connection_retire(s.retired_connection);error!=.None{return error}}
 if r.owner_retains_drop(&s.retired_client)!=.None{return .Wrong_Phase}
 if r.owner_retains_drop(&s.retired_session)!=.None{return .Wrong_Phase}
 if s.retired_connection!=nil{if error:=session_connection_close(&s.retired_connection);error!=.None{return error}}
 return .None
}
