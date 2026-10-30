package replay_godot

import gd "godot:godot"
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
Session :: struct($State, $Control, $Action, $Event: typeid, $Seats: int) {
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
                     model: net.Model(State, Control, Action, Event, Seats), options := SESSION_OPTIONS) -> net.Error {
	if s.ready || (options.discover_epoch && options.network.require_permit) {return .Invalid_Config}
	s.allocator = context.allocator
	s.options = options; s.options.address = nil; s.options.rtc = {};s.options.steam.peer=nil // transient caller strings are not retained
	if err := session_connect(s, options); err != .None {return err}
	s.token = options.token
	empty_token: net.Token
	if s.token == empty_token {s.token = storagegd.session_token()}
	err: net.Error
	if s.authority {
		err = net.server_init(&s.server, initial, model, s.wire, options.network, local_seat = options.role == .Server ? 0 : 1, permit = options.permit, incarnation = options.incarnation)
		if err==.None {s.server.epoch_discovery=options.discover_epoch;s.server.compact_observations_disabled=options.disable_compact_observations;s.server.compact_recent_facts_disabled=options.disable_compact_recent_facts}
		if err == .None && s.server.local_seat != 0 {err = net.server_set_local_token(&s.server, s.token)}
	} else {
		err = net.client_init(&s.client, model, s.wire, s.token, spectator = options.role == .Observer, cfg = options.network, permit = options.permit, incarnation = options.incarnation)
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
                       options: Session_Options, resume: net.Resume_Options) -> net.Error {
	if s.ready || (options.role != .Solo && options.role != .Host && options.role != .Server) {return .Wrong_Phase}
	s.allocator = context.allocator
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
	if err := net.server_restore(&s.server, cp, model, s.wire, resume); err != .None {session_close(s); return err}
	s.server.epoch_discovery=options.discover_epoch;s.server.compact_observations_disabled=options.disable_compact_observations;s.server.compact_recent_facts_disabled=options.disable_compact_recent_facts
	s.token = options.token
	r.clock_init(&s.clock, s.server.cfg.hz)
	s.ready = true
	return .None
}

session_save :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats), path: string,
                     policy_id: u64 = 0, policy_data: []u8 = nil) -> storagegd.Storage_Result {
	if !s.ready || !s.authority {return {.Codec, .Wrong_Phase}}
	cp: net.Checkpoint(State, Control, Action, Seats)
	defer net.checkpoint_destroy(&cp)
	if err := net.checkpoint_capture(&s.server, &cp, policy_id, policy_data); err != .None {return {.Codec, err}}
	return storagegd.checkpoint_write(&cp, s.server.model, path, s.link.publish_codec.ready ? &s.link.publish_codec : nil)
}

// Explicitly authorize one admitted remote player to receive complete authority
// checkpoints. Automatic takeover remains a separate coordinator/fencing policy.
session_backup_seat :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats), seat: u16,
                           interval_ticks: u32 = 0, policy_id: u64 = 0, policy_data: []u8 = nil) -> net.Error {
	if !s.ready || !s.authority || !s.link.ready {return .Wrong_Phase}
	connection, live := net.server_seat_connection(&s.server, seat)
	if !live {return .Invalid_Input}
	return session_backup_peer(s,connection.peer,interval_ticks,policy_id,policy_data)
}

// Explicit trust for a live admitted connection, including an infrastructure
// observer with no playable seat. This does not nominate or authorize takeover.
session_backup_peer :: proc(s:^Session($S,$C,$A,$E,$N),peer:tr.Peer_Id,
                           interval_ticks:u32=0,policy_id:u64=0,policy_data:[]u8=nil)->net.Error {
	if !s.ready || !s.authority || !s.link.ready {return .Wrong_Phase}
	return rec.link_target(&s.link,&s.server,peer,interval_ticks,policy_id,policy_data)
}

session_backup_receipt :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats)) -> (rec.Receipt, bool) {
	if !s.ready || !s.link.ready {return {}, false}
	if s.authority {return s.link.outgoing.acknowledged, s.link.outgoing.acknowledged.archive.sequence != 0}
	return rec.receiver_latest(&s.link.incoming)
}

@(private)
session_connect :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats), options: Session_Options, preserve_runtime: bool = false) -> net.Error {
	s.role = options.role
	s.authority = options.role == .Solo || options.role == .Host || options.role == .Server
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
		if !rec.link_init(&s.link, s.base_wire, options.replication) {if preserve_runtime {session_disconnect(s)} else {session_close(s)}; return .Invalid_Config}
		s.wire = rec.link_game_transport(&s.link)
	}
	return .None
}

@(private)
session_disconnect :: proc(s: ^Session($S, $C, $A, $E, $N)) {
	rec.link_destroy(&s.link); tr.close(&s.base_wire)
	s.wire, s.client.wire, s.server.wire = {}, {}, {}
}

session_close :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats)) {
	delete(s.reset_changes, s.allocator)
	rec.link_destroy(&s.link)
	net.server_destroy(&s.server)
	net.client_destroy(&s.client)
	tr.close(&s.base_wire)
	s^ = {}
}

session_frame :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats), dt: f64, control: Control) -> net.Error {
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
	if s.delay.packets != nil {tr.delay_time(&s.delay, now)}
	if s.link.ready && !rec.link_pump(&s.link, now) {return .Invalid_Time}
	catchups := s.client.stats.snapshot_catchups
	err := s.authority ? net.server_pump(&s.server, now) : net.client_pump(&s.client, now)
	if err == .Fenced {
		s.fenced = true; r.clock_init(&s.clock, s.authority ? s.server.cfg.hz : s.client.cfg.hz)
		if !s.authority {s.change_count = view.drain(&s.client.journal, s.changes[:])}
		return .None
	}
	if err != .None {return err}
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
	if s.link.ready && !s.fenced {
		if s.authority {rec.link_server(&s.link, &s.server, now)} else {rec.link_client(&s.link, &s.client, now)}
	}
	return .None
}

session_issue :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats), action: Action) -> (sequence: u64, error: net.Error) {
	if !s.ready {return 0, .Not_Initialized}
	if s.authority {return net.server_issue(&s.server, action)}
	return net.client_issue(&s.client, action)
}

session_state :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats)) -> (frame: r.Frame(State), ok: bool) {
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
	if !s.ready || s.fenced {return}
	if s.authority {return r.current(&s.server.timeline)}
	if s.client.phase != .Running {return}
	return s.client.authority_frame, true
}

session_changes :: proc(s: ^Session($State, $Control, $Action, $Event, $Seats), dst: []view.Change(net.Net_Event(Event))) -> int {
	n := min(len(dst), s.change_count)
	copy(dst, s.changes[:n])
	for i in n ..< s.change_count {s.changes[i - n] = s.changes[i]}
	s.change_count -= n
	return n
}
