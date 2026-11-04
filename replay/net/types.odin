package replay_net

import "core:mem"
import r "godot:replay"
import sc "godot:replay/schema"
import tr "godot:replay/transport"
import view "godot:replay/view"
import delta "godot:replay/delta"

MAX_PEERS :: 16
INPUT_WINDOW :: 8
ACTION_CAPACITY :: 16
GAME_EVENTS :: 32
WIRE_EVENTS :: 40 // 32 gameplay occurrences + up to eight action verdicts
PROTOCOL_VERSION :: u64(7)
Token :: [16]u8

Error :: enum {
	None, Invalid_Config, Invalid_Model, Not_Initialized, Wrong_Phase,
	Invalid_Input, Capacity, Transport, Simulation, Presentation, Invalid_Time,
	Invalid_Schema, Invalid_Frame,
	Invalid_Checkpoint, Checkpoint_Contract, Checkpoint_Policy,
	Fenced,
	Incomplete_State,
}

// A coordinator/lease adapter supplies a fresh authorization check. This callback
// must read current time, not a timestamp cached at the start of a render frame.
Permit :: r.Commit_Gate

@(private)
permitted :: proc(required: bool, permit: Permit, epoch: u64) -> bool {
	return !required || (permit.allow != nil && permit.allow(permit.user, epoch))
}
Phase :: enum u8 {Joining, Running, Resyncing, Rejected, Disconnected, Failed}
Reject :: enum u8 {None, Contract, Full, Invalid_Token, Token_In_Use, Projection, Denied, Locked, Banned, Removed}
Action_Reason :: enum u8 {None, Predicate, Invalid, Stale, Future, Disconnected}
Event_Kind :: enum u8 {Gameplay, Action_Result}
Control_Timing :: enum u8 {Scheduled, Latest_Observation}
Action_Timing :: enum u8 {Scheduled, Receipt}

Net_Event :: struct($Event: typeid) {
	kind: Event_Kind,
	value: Event,
	seat: u16,
	sequence: u64,
	applied: bool,
	reason: Action_Reason,
}

// Seat order is stable. Joins/leaves occur once at their simulation tick.
Batch :: struct($Control, $Action: typeid, $Seats: int) {
	authority: Authority_Observation,
	prediction_group: u64, // runtime metadata; never supplied in a gameplay packet
	prediction_seat: u16,
	controls: [Seats]Control,
	views: [Seats]View_Time,
	stamps: [Seats]View_Stamp,
	joins, leaves: u64,
	fresh: u64,
	has_action: [Seats]bool,
	actions: [Seats]Action,
	sequences: [Seats]u64,
	rejections: [Seats]Action_Reason,
}

// Process-local lifetime declarations; never encoded or included in schemas.
// Each nonnil data pointer names the EXACT context retained by this owner.
Owned_Context :: r.Owned_Context
Runner_Ownership :: struct {
 allocator,model,wire,permit,profile_clock,profile_sample,identity,admission:Owned_Context,
}
@(private)
Runner_Retains :: r.Owner_Retains

Model :: struct($State, $Control, $Action, $Event: typeid, $Seats: int) {
	complete_state: bool, // managed mode requires complete transactions and an explicit codec
	complete_codec: Complete_Codec(State, Net_Event(Event)),
	authority: Authority_Policy(State, Event),
	control_timing: Control_Timing,
	action_timing: Action_Timing, // opt-in receipt scheduling; predicted actions still reconcile
	action_schedule: Action_Schedule(Action), // optional versioned per-payload override
	group: Prediction_Group(State),
	replication:Replication(State,Control,Event,Seats),
	step: proc(state: ^State, controls: [Seats]Control, joins, leaves: u64, ctx: ^r.Step(Event)),
	step_view: proc(state: ^State, controls: [Seats]Control, views: [Seats]View_Time, joins, leaves: u64, ctx: ^r.Step(Event)),
	action: proc(state: ^State, seat: u16, action: Action, ctx: ^r.Step(Event)) -> bool,
	control_valid: proc(control: Control) -> bool,
	action_valid: proc(action: Action) -> bool,
	// Authority admission only, never called by prediction or replay. Query
	// local infrastructure here; the accepted/rejected decision enters Batch.
	action_admission_user: rawptr,
	action_admit: proc(user: rawptr, seat: u16, action: Action) -> bool,
	state_valid: proc(state: State) -> bool,
	event_owner: proc(event: Event) -> u16,
	event_policy: proc(event: Event) -> view.Policy, // presentation only; survives journal reconstruction
	hold: proc(control: Control) -> Control,
	neutral: Control,
	reset_player: proc(state: ^State, seat: u16, ctx: ^r.Step(Event)),
	user: rawptr, // immutable assets/configuration, never role or live scene state
	user_context,action_admission_context:Owned_Context, // optional runtime ownership only
}

Config :: struct {
	epoch, content: u64,
	hz: u32,
	history: int,
	lead: u32,
	max_future: u32,
	max_prediction: u32,
	snapshot_every: u32,
	watch_delay: u32,
	timeout_ms: u64,
	packets_per_pump: int,
	bytes_per_pump: int,
	snapshot_history: int,
	delta_snapshots: bool,
	egress_bytes_per_second: int,
	egress_bytes_per_pump: int,
	unreliable_packet_limit: int,
	require_permit: bool,
	max_rewind, max_view_span, view_slack: u32,
}
DEFAULT_CONFIG :: Config{
	epoch = 1, content = 1, hz = 60, history = 128, lead = 12,
	max_future = 64, max_prediction = 96, snapshot_every = 3,
	watch_delay = 6,
	timeout_ms = 10000, packets_per_pump = 64, bytes_per_pump = 256 * 1024,
	snapshot_history = 32, delta_snapshots = true,
	egress_bytes_per_second = 256 * 1024, egress_bytes_per_pump = 256 * 1024,
	unreliable_packet_limit = 1200,
	max_rewind = 30, max_view_span = 12, view_slack = 4,
}

Stats :: struct {
 compact_observations, observation_bytes_saved:u64,
	replay_samples, replay_wall_us, replay_max_us, replay_max_depth, profile_errors: u64,
	replay_histogram: [20]u64,
	rx_packets, tx_packets, rx_bytes, tx_bytes: u64,
	rejected_packets, rejected_inputs, duplicate_actions, held_inputs, fenced_packets: u64,
	corrections, replayed_ticks, resyncs, stalls: u64,
	reused_correction_ticks:u64,
	snapshot_catchups, watch_catchups: u64,
	timing_samples, timing_rejected, lead_updates: u64,
	full_snapshots, delta_snapshots, snapshot_bytes_saved: u64,
	baseline_misses, rejected_acks, egress_deferred: u64,
	large_reliable_snapshots, lz4_snapshots, shuffled_snapshots, shuffle_attempts, shuffle_bytes_saved: u64,
	redundant_facts, redundant_fact_bytes: u64,
 compact_recent_facts, recent_fact_bytes_saved:u64,
	fact_repair_requests, fact_repairs, fact_repair_bytes, fact_repair_oversize: u64,
	action_copy_batches, action_copies, action_copy_bytes, action_copy_oversize: u64,
	fragmented_snapshots, snapshot_parts_sent, snapshot_parts_received, snapshot_parts_expired: u64,
	snapshot_parity_sent, snapshot_parity_received, snapshot_parity_bytes, snapshot_shards_recovered: u64,
	rejected_replica_views,filtered_events:u64,
	rejected_views, expired_views: u64,
}

// Latest successful authority correction, sampled at one identical prediction
// tick before/after replay. Presentation can smooth the correction without
// mistaking ordinary simulation movement for an error. Consume after each pump.
State_Correction :: struct($State: typeid) {
	serial, authority_tick: u64,
	before, after: r.Frame(State),
	replayed_ticks: u32,
}

Resync_Reason :: enum u8 {Prediction_Limit, Facts_Overflow, Snapshot_Ahead, History_Missing, Facts_Missing}
Resync_Notice :: struct {serial: u64, reason: Resync_Reason, head, confirmed, facts, incoming_tick, at_ms: u64}

Action_Outcome :: struct {sequence, tick: u64, applied: bool, reason: Action_Reason}

Recovery_Disposition :: enum u8 {Applied, Rejected, Retained, Retired, Settled_Unknown}
Recovered_Action :: struct {epoch, sequence: u64, disposition: Recovery_Disposition, outcome: Action_Outcome}
Client_Recovery :: struct {
	from_epoch, to_epoch, previous_confirmed, previous_head, recovered_tick: u64,
	old_seat, new_seat: u16,
	received, settled: u64,
	count: u8,
	actions: [ACTION_CAPACITY]Recovered_Action,
}

@(private)
Peer_Phase :: enum u8 {Vacant, Pending, Running, Disconnected}

@(private)
Queued_Action :: struct($Action: typeid) {
	sequence, tick: u64,
	value: Action,
	reason: Action_Reason,
	predicted: bool,
	sent: bool,
}

@(private)
Peer :: struct($Action: typeid) {
	phase: Peer_Phase,
	connection: tr.Peer_Id,
	incarnation: u64,
	welcome_view: Sent_View,
	rtt_floor_ms, rtt_floor_until: u64,
	token_hash: [32]u8,
	seat: u16,
	spectator, local: bool,
	generation, serial, last_seen, facts_sent, snapshot_sent, recent_facts_sent: u64,
	input_newest: u64,
	action_received, action_settled: u64,
	actions: [ACTION_CAPACITY]Queued_Action(Action),
	action_head, action_count: int,
	checkpoint_pending: bool,
	request_seen: u64,
	echo_ms: u64,
	budget_packets, budget_bytes: f64,
	send_budget: f64,
	recent: [ACTION_CAPACITY]Action_Outcome,
	recent_head, recent_count: int,
}

@(private)
Input_Slot :: struct($Control: typeid) {tick: u64, value: Control, view: View_Time}

Server :: struct($State, $Control, $Action, $Event: typeid, $Seats: int) {
 ownership:Runner_Ownership, // guard before typed containers/callbacks
 owner_retains:Runner_Retains,
 owner_cleanup:bool,
 compact_recent_facts_disabled:bool, // set before feature negotiation
 compact_observations_disabled:bool, // set before feature negotiation
	epoch_discovery: bool, // opt-in direct-session query, never a lease replacement
	delta_workspace: delta.Lz4_Workspace,
	shuffle_workspace: []u8,
	profile_clock: Profile_Clock,
	profile_metrics: [Profile_Metric]r.Timing,
	profile_user: rawptr,
	profile_sample: proc(user: rawptr, metric: Profile_Metric, elapsed_us: u64),
	allocator: mem.Allocator,
	initialized: bool,
	complete_charge:u64,
	complete_lease:bool,
	physics: ^Server_Physics(State, Control, Action, Event, Seats),
	permit: Permit,
	identity_user: rawptr,
	identity_check: proc(user: rawptr, token_hash: [32]u8, incarnation: u64) -> bool,
	frame_error: r.Error,
	model: Model(State, Control, Action, Event, Seats),
	cfg: Config,
	wire: tr.Transport,
	codecs: Codecs,
	contract: u64,
	timeline: r.Timeline(State, Batch(Control, Action, Seats), Net_Event(Event)),
	peers: [MAX_PEERS]Peer(Action),
	inputs: []Input_Slot(Control),
	held: [Seats]Control,
	held_views: [Seats]View_Time,
	facts: []Facts_Packet(Event),
	checkpoints: []Welcome_Packet(State, Control, Seats),
	joins, leaves, now, generation: u64,
	fresh: u64,
	locked: bool,
	banned: [64][32]u8,
	banned_count: int,
	admission_user: rawptr,
	admission: proc(user: rawptr, token_hash: [32]u8, spectator: bool) -> bool,
	time_set: bool,
	local_seat: u16,
	stats: Stats,
	rxb, txb: []u8,
	snapshot_tx: [MAX_PEERS]Snapshot_Tx,
	tx_remaining, flush_cursor: int,
}

// Last failed presentation operation, for local diagnostics only. No payloads,
// network contract, checkpoints, or simulation state depend on this record.
Presentation_Stage :: enum {None, Predicted_Batch, Authority_Batch, Confirmation, Watch}
Presentation_Failure :: struct {
 serial: u64,
 stage: Presentation_Stage,
 error: view.Error,
 epoch, tick, head, confirmed, watch_tick: u64,
 queue_count: int,
 slot_valid: bool,
 slot_tick: u64,
 slot_count: int,
}

Client :: struct($State, $Control, $Action, $Event: typeid, $Seats: int) {
 ownership:Runner_Ownership, // guard before typed containers/callbacks
 owner_retains:Runner_Retains,
 owner_cleanup:bool,
 compact_observations_enabled,compact_observations_negotiated:bool,
 compact_recent_facts_enabled:bool,
	reuse_equal_corrections:bool, // opt-in deterministic state/input reuse; never used by audit
	epoch_query_pending:bool,
	epoch_query_nonce:Token,
	presentation_failure: Presentation_Failure,
	// Set before first pump to test/use the protocol-7 fallback.
	snapshot_parts_enabled, lz4_snapshots_enabled, snapshot_erasure_enabled, snapshot_shuffle_enabled, features_sent: bool,
	fact_repair_enabled, fact_repair_negotiated, fact_repair_sent: bool,
	fact_repair_last: u64,
	action_copies_enabled, action_copies_negotiated, action_copies_sent: bool,
	action_copies_last: u64,
	observer_names_negotiated: bool,
	snapshot_parts: [SNAPSHOT_ASSEMBLIES]Snapshot_Assembly,
	resync_notice: Resync_Notice,
	profile_clock: Profile_Clock,
	profile_metrics: [Profile_Metric]r.Timing,
	profile_user: rawptr,
	profile_sample: proc(user: rawptr, metric: Profile_Metric, elapsed_us: u64),
	allocator: mem.Allocator,
	initialized: bool,
	complete_charge:u64,
	complete_lease:bool,
	physics: ^Client_Physics(State, Control, Action, Event, Seats),
	permit: Permit,
	model: Model(State, Control, Action, Event, Seats),
	cfg: Config,
	wire: tr.Transport,
	authority: tr.Peer_Id,
	codecs: Codecs,
	contract: u64,
	token: Token,
	incarnation: u64,
	spectator: bool,
	phase: Phase,
	rejection: Reject,
	seat: u16,
	generation, serial, now, started, last_hello, last_received: u64,
	time_set, hello_sent: bool,
	request_sequence: u64,
	timeline: r.Timeline(State, Batch(Control, Action, Seats), Net_Event(Event)),
	journal: view.Journal(Net_Event(Event)),
	held: [Seats]Control,
	facts: []Facts_Packet(Event),
	facts_contiguous, baseline: u64,
	authority_tick_seen: u64, // validated authority progress; facts/state may still be incomplete
	pending: Snapshot_Packet(State, Control, Seats),
	has_pending: bool,
	authority_frame: r.Frame(State),
	actions: [ACTION_CAPACITY]Queued_Action(Action),
	action_count: int,
	next_action: u64,
	last_outcome, last_action_send, last_heartbeat: u64,
	observed: []r.Frame(State),
	observed_valid: []bool,
	input_scratch: []u8,
	observed_ids: []u64,
	presented: View_Stamp,
	mixed_presentation: bool,
	watch_clock: f64,
	lead_ticks: u32,
	clock_scale: f64,
	input_sent: []Input_Sent,
	input_timing: Input_Timing,
	outcomes: [ACTION_CAPACITY]Action_Outcome,
	outcome_recovered: [ACTION_CAPACITY]bool,
	outcome_head, outcome_count: int,
	view_reset: u64,
	has_world, recovering, recovery_ready: bool,
	recovery: Client_Recovery,
	stats: Stats,
	correction: State_Correction(State),
	rxb, txb: []u8,
	snapshot_rx: delta.Cache,
	snapshot_scratch, shuffle_workspace: []u8,
	snapshot_ticks: []u64,
	snapshot_latest, snapshot_latest_hash: u64,
	baseline_request_id, baseline_request_hash, baseline_request_time: u64,
}

// Whole-owned value/codec buffers. context is an explicit retained codec or
// container allocation; it never implies ownership of arbitrary child pointers.
Container_Ownership :: struct {allocator,data_context:Owned_Context}
@(private)
Container_Lifetime :: struct {ownership:Container_Ownership,retains:r.Owner_Retains,cleanup:bool}
@(private)
container_acquire :: proc(life:^Container_Lifetime,ownership:Container_Ownership,allocator:mem.Allocator,context_data:rawptr=nil,required:bool=false)->Error {
 if required && r.owner_is_nil(ownership.allocator.owner){return .Invalid_Model}
 if r.owner_contexts_check({owner=ownership.allocator.owner,owner_allocator_data=ownership.allocator.data},allocator)!=.None{return .Invalid_Model}
 if error:=owned_context_check(ownership.data_context,context_data,required);error!=.None{return error}
 life.ownership=ownership
 owners:=[?]r.Owner{ownership.allocator.owner,ownership.data_context.owner}
 return r.owner_retains_acquire(&life.retains,owners[:])==.None?Error.None:Error.Invalid_Model
}
@(private)
container_access :: proc(life:^Container_Lifetime,access:r.Owner_Access=.Read)->Error {
 if r.owner_access(life.ownership.allocator.owner,access)!=.None || r.owner_access(life.ownership.data_context.owner,access)!=.None{return .Invalid_Model}
 if r.owner_retains_access(&life.retains,access)!=.None{return .Invalid_Model}
 return .None
}
@(private)
container_drop :: proc(life:^Container_Lifetime)->Error {
 return r.owner_retains_drop(&life.retains)==.None?Error.None:Error.Invalid_Model
}
