package kit_net

// command — the intent→command→result runtime loop (the DX heart of the toolkit).
//
// A command is a plain proc `proc(self: ^Cls, args…) -> bool` marked
// `@(gd_command)` (owner-only) or with a typed `Action_Policy` preset such as
// `@(gd_command=knet.ACTION_OWNER_PREDICTED)`. The
// AUTHOR writes single-player-looking mutation code with zero role branches;
// scriptgen generates a decode thunk, a Command_Desc table, and a typed
// `<proc>_cmd` issue wrapper — the generated wrapper holds the ONLY role branch:
//
//   authority:  runs the proc directly (deltas carry the change to everyone).
//   client:     serializes the args ONCE, optionally re-runs the SAME proc from
//               those bytes (prediction — client and host execute from identical
//               input), and ships the command to the host on the reliable channel.
//
// Correctness invariants this file owns:
//
//   * `false` really means "no mutation": both the predicted run (client) and
//     command_execute (host) capture the declared fields first and auto-restore
//     when the proc rejects — a command can never leave torn replicated state
//     on ANY peer, even if it mutated before returning false.
//   * Predictions can't leak: an accepted predicted run records a Pending entry
//     whose revert snapshot is freed on confirm, applied on timeout
//     (pending_expire — the session layer drives it), and superseded on reject.
//   * REJECTION CARRIES TRUTH: a reject result embeds a full field snapshot of
//     the entity, so a stale client (predicting against state the host has
//     since changed) snaps to the authoritative values instead of restoring a
//     possibly-stale local revert. Confirms carry nothing — the optimistic
//     state already matches, nothing replays.
//   * EXACTLY-ONCE on the host: command_dedup keys a per-peer Dedup_Window, so
//     retransmits/reconnect replays never re-execute.
//
// This file is engine-free. Sending is a callback (the session layer or a test
// installs it); entity resolution (Net_Id → pointer) is the caller's — commands
// name entities, the registry finds them.

// Everything a command run knows about the run itself — who issued it, whether
// THIS execution is the authoritative one, and the game pointer consequences
// receive. The thunk uses it to fire the verb's `<verb>_then` consequence
// (generated from the name-paired proc) exactly once, on the authority, after
// the verb applies: client predictions and registry replays re-run the VERB
// from the same bytes but carry authority=false, so a consequence can never
// double-fire or fire on spec.
// Command_Outcome is the compact state inside the generated wrapper's detailed
// Action_Outcome, with ONE meaning per value on every peer (distinct from the
// internal wire-level Command_Result struct below):
//
//   Rejected  — the predicate said no on THIS peer. On the host it is final; on a
//               predicting client the LOCAL optimistic apply failed and reverted
//               (nothing stands here — the command was still sent for the host to
//               judge with fresher state).
//   Predicted — a client sent it and it is in flight, the host's verdict pending
//               (it lands as replicated state, or a revert). A predicting command
//               also applied optimistically; a non-predicting one just sent.
//   Applied   — the host's authoritative accept. Done.
//
// "Did it show on my screen?" is `command_ok(r)`; "is it authoritative?" is
// `r.state == .Applied`. Replaces the old `bool` whose truth meant
// authoritative-verdict on the host but tentative-local on a client — the one
// return in the feature that used to force a role branch to read correctly.
Command_Outcome :: enum u8 {
	Rejected,
	Predicted,
	Applied,
}

// Where an action runs. Results from the immediate co-op loop and the
// tick-scheduled simulation loop share one public diagnostic vocabulary, but
// the model remains explicit so equal raw sequence/command ids never alias in
// logs or UI bookkeeping.
Action_Model :: enum u8 {
	Immediate,
	Scheduled,
}

// Why an action did not apply. None is the accepted/pending zero value; every
// rejection path names one of the remaining values on the authority and in the
// issuing peer's final callback.
Action_Reject_Reason :: enum u8 {
	None,
	Access,
	Rate,
	Malformed,
	Stale,
	Predicate,
	Timeout,
}

action_reject_reason_valid :: proc(reason: Action_Reject_Reason) -> bool {
	return reason >= .None && reason <= .Timeout
}

action_rejected :: proc(reason: Action_Reject_Reason) -> bool {
	return reason != .None
}

// The generated `<verb>_cmd` return. `state` preserves the compact, familiar
// Applied/Predicted/Rejected surface; `reason` makes a synchronous refusal
// actionable; `seq` lets UI correlate the later confirmed/rejected callback.
// A zero seq is normal for an authority-local immediate action.
Action_Outcome :: struct {
	state:  Command_Outcome,
	reason: Action_Reject_Reason,
	seq:    u32,
	model:  Action_Model,
}

action_outcome :: proc(
	state: Command_Outcome,
	reason := Action_Reject_Reason.None,
	seq: u32 = 0,
	model := Action_Model.Immediate,
) -> Action_Outcome {
	return {state = state, reason = reason, seq = seq, model = model}
}

// It applied on THIS peer (authoritatively on the host, optimistically on a
// client) — the role-free "should I show local feedback?" check. The overload
// keeps low-level code returning Command_Outcome source-compatible while
// generated wrappers return the detailed Action_Outcome.
command_state_ok :: proc(r: Command_Outcome) -> bool {
	return r != .Rejected
}

action_outcome_ok :: proc(r: Action_Outcome) -> bool {
	return command_state_ok(r.state)
}

command_ok :: proc {
	command_state_ok,
	action_outcome_ok,
}

Command_Env :: struct {
	authority: bool, // this run is the authoritative one — consequences fire
	user:      rawptr, // the game pointer `_then` procs receive (ctx.game_user)
	by:        Player_Id, // who issued the command (ctx.me locally; the resolved sender on the host)
}

// Decode-args-and-run thunk, generated per command by scriptgen. Contract: decode
// ALL args, check r.err, only then call the author proc — a truncated packet must
// never reach gameplay code; when the proc applies and env.authority is set, fire
// the command's `_then` consequence (generated thunks do all of this; hand-written
// ones must).
Command_Proc :: proc(entity: rawptr, r: ^Reader, env: ^Command_Env) -> bool

// A coop verb's wire id. THE ID LAW is stated once, on Command_Desc.id below —
// scriptgen's cmd_wire_id implements it. Distinct from ksim.Cmd_Id: a coop
// command id and a sim command id are raw u16s that flow through near-identical
// issue shapes (command_issue vs ksim.lane_command), so a game holding both
// could hand one namespace's id to the other's proc and the compiler would
// shrug. The distinct types make that swap a build error instead. The wire
// bytes are unchanged — the encoders still write u16(id).
Cmd_Id :: distinct u16

// Who may issue an action through the authority ingress. The declaration is
// independent of the verb predicate: predicates decide whether an otherwise
// authorized action applies to current game state; access decides whether the
// sender was allowed to ask at all. Shared by the immediate co-op loop and the
// tick-scheduled sim lane so promoting an entity does not change vocabulary.
//
// Owner is zero so omitted policy is secure by default in both generated and
// hand-built tables. Open world interactions must say Any_Seat explicitly.
Action_Access :: enum u8 {
	Owner,
	Any_Seat,
	Authority,
}

// Compatibility spelling for low-level code written before commands and sim
// verbs shared the action vocabulary. New APIs and generated code say Action.
Command_Access :: Action_Access

// Whether a client runs an action before the authority answers. This is typed
// separately from access: opening a verb to any seat never silently enables
// prediction, and making a class contested never silently opens its verbs.
Action_Prediction :: enum u8 {
	None,
	Optimistic,
}

// One policy vocabulary for both immediate co-op commands and tick-scheduled
// sim verbs. `max_args_bytes == 0` selects the safe framework default; a
// positive value narrows or explicitly widens that action's encoded argument
// envelope. Negative values are invalid authoring data and fail loudly when a
// descriptor is used.
Action_Policy :: struct {
	access:         Action_Access,
	prediction:     Action_Prediction,
	max_args_bytes: int,
}

ACTION_ARGS_DEFAULT :: 4096
ACTION_ARGS_MAX :: MAX_FIELD_BYTES

// Typed presets cover the normal declarations. The all-zero policy is the
// secure owner-only, non-predicted default, so a hand-built descriptor is safe
// when it omits policy just like bare @(gd_command) is.
ACTION_OWNER :: Action_Policy{}
ACTION_OWNER_PREDICTED :: Action_Policy {
	prediction = .Optimistic,
}
ACTION_ANY_SEAT :: Action_Policy {
	access = .Any_Seat,
}
ACTION_ANY_SEAT_PREDICTED :: Action_Policy {
	access     = .Any_Seat,
	prediction = .Optimistic,
}
ACTION_AUTHORITY :: Action_Policy {
	access = .Authority,
}

action_policy_valid :: proc(policy: Action_Policy) -> bool {
	return(
		policy.max_args_bytes >= 0 &&
		policy.max_args_bytes <= ACTION_ARGS_MAX &&
		!(policy.access == .Authority && policy.prediction == .Optimistic) \
	)
}

action_args_max :: proc(policy: Action_Policy) -> int {
	assert(
		action_policy_valid(policy),
		"invalid Action_Policy: max_args_bytes is outside 0..ACTION_ARGS_MAX or the action predicts authority-only work",
	)
	if policy.max_args_bytes == 0 {
		return ACTION_ARGS_DEFAULT
	}
	return policy.max_args_bytes
}

action_args_allowed :: proc(policy: Action_Policy, bytes: int) -> bool {
	return bytes >= 0 && bytes <= action_args_max(policy)
}

action_predicts :: proc(policy: Action_Policy) -> bool {
	return policy.prediction == .Optimistic
}

// Static, callback-free metadata shared by immediate co-op commands and
// tick-scheduled simulation verbs. Generated execution descriptors embed one
// of these and add only the callback shape required by their runtime model.
// Tooling can therefore inspect either model without learning Command_Proc or
// kit/sim's Lane callback signatures.
Action_Argument_Desc :: struct {
	name:      string,
	type_name: string, // author-facing Odin spelling
	wire_kind: string, // canonical codec suffix (u16, string, net_id, ...)
}

// Values returned after the verb's leading `bool`. They never cross the wire;
// the authority threads them directly into the generated consequence.
Action_Outcome_Value_Desc :: struct {
	name:      string, // generated result_N when the return value is unnamed
	type_name: string,
}

Action_Consequence_Desc :: struct {
	name:           string, // empty when the action has no `<verb>_then` half
	authority_only: bool,
	takes_game:     bool, // consequence receives the generated game facade first
}

Action_Desc :: struct($Id: typeid) {
	name:        string,
	id:          Id, // model-specific distinct wrapper; encoded as its underlying u16
	model:       Action_Model,
	policy:      Action_Policy,
	arguments:   []Action_Argument_Desc,
	outcomes:    []Action_Outcome_Value_Desc,
	consequence: Action_Consequence_Desc,
}

action_desc_valid :: proc(action: Action_Desc($Id), model: Action_Model) -> bool {
	if action.model != model || !action_policy_valid(action.policy) {
		return false
	}
	for arg in action.arguments {
		if arg.name == "" || arg.type_name == "" || arg.wire_kind == "" {return false}
	}
	for outcome in action.outcomes {
		if outcome.name == "" || outcome.type_name == "" {return false}
	}
	if action.consequence.name == "" {
		if action.consequence.authority_only || action.consequence.takes_game {return false}
	} else if !action.consequence.authority_only {
		return false
	}
	return true
}

// The descriptor-level access decision. Seat/connection/spectator checks live
// one layer above this helper; this answers only the action's declared rule.
action_access_allows :: proc(
	policy: Action_Policy,
	by, owner: Player_Id,
	authority: bool,
) -> bool {
	if authority {
		return true
	}
	switch policy.access {
	case .Any_Seat:
		return true
	case .Owner:
		return owner == by
	case .Authority:
		return false
	}
	return false
}

Command_Desc :: struct {
	// The shared descriptor owns name/id/policy/arguments/outcomes/consequence.
	// `using` preserves convenient `cmd.id` / `cmd.policy` selectors for
	// low-level runtime code while keeping one metadata object.
	using action: Action_Desc(Cmd_Id),
	invoke: Command_Proc,
}

// The id → descriptor lookup every receive/issue path routes through (sets are
// a handful of verbs — a scan beats any table). nil = unknown id: reject. Takes
// a raw u16, not a Cmd_Id: this is the RECEIVE/reconcile side, fed by ids read
// off the wire (Command_Header.cmd) and from the pending ledger (Pending.cmd) —
// both raw u16. The issue side converts its Cmd_Id in (the wire id is the same
// value either way).
command_find :: proc(set: ^Command_Set, id: u16) -> ^Command_Desc {
	for &c in set.commands {
		if u16(c.id) == id {
			return &c
		}
	}
	return nil
}

// Per entity TYPE: the command table + the replicated-field descriptor that
// powers prediction reverts, torn-state restore, and reject-truth snapshots.
Command_Set :: struct {
	entity_desc:   ^Entity_Desc,
	commands:      []Command_Desc,
	// Byte offset of the entity struct's `net_id: Net_Id` field, or 0 for
	// none — registry_insert writes the assigned id back through it, so no
	// factory or spawn site ever forgets the assignment (forgetting used to
	// mean commands silently targeting NET_ID_INVALID until the 3s expiry).
	// 0 is safely "none": in script structs the owner handle occupies offset
	// 0, so a real net_id field can never live there. scriptgen emits this.
	net_id_offset: int,
	// The class's `<field>_edge` halves (edge.odin) — delta-lane change
	// presentation, fired by the per-frame registry_edges_tick walk. nil =
	// the class declares none (and pays nothing: no mirror, no diff).
	edges:         []Edge_Desc,
}

// Complete outgoing COMMAND message bytes → whoever owns the transport. The
// session layer prepends its own framing (message-kind byte) and sends
// reliable. (Named apart from kit/session's Send_Proc — that one is the
// peer-addressed transport hookup; this one is command-framing only.)
Command_Send_Proc :: proc(user: rawptr, bytes: []u8)

// One per session participant. Clients use pending/msg/send; the host uses
// dedup. now_tick is stamped onto pending entries — the owner advances it with
// the net ticker so pending_expire(&ctx.pending, …) can time out lost results.
// The cross-entity half of a command: invoked on the AUTHORITY right after a
// command executes — for commands arriving from clients AND for the host's
// own local issues (the generated wrappers call command_hook_local), so games
// never write an "authority inline half" beside each issue site.
Command_Hook :: proc(user: rawptr, player: Player_Id, entity: Net_Id, cmd: u16, ok: bool) // cmd: raw wire id — the hook rides into the session's game-facing dispatch/events

Command_Ctx :: struct {
	is_authority: bool,
	now_tick:     u64,
	send:         Command_Send_Proc,
	send_user:    rawptr,
	pending:      Pending_Table, // client: in-flight predictions
	dedup:        map[u64]Dedup_Window, // host: per-peer exactly-once windows
	msg:          Writer, // outgoing command message scratch (reused per issue)

	// the cross-entity hook, mirrored here so generated wrappers can fire it
	// for the authority's own commands (the session installs all three)
	hook:         Command_Hook,
	hook_user:    rawptr,
	me:           Player_Id, // who "a local issue" is attributed to in the hook

	// THE GAME pointer `<verb>_then` consequences receive (the session installs
	// the factory's user here — the same `self` make_entity gets). Distinct from
	// hook_user, which the session points at ITSELF to route the dispatcher.
	game_user:    rawptr,

	// in-flight between command_begin and command_issue (generated code only)
	_entity:      Net_Id,
	_seq:         Intent_Seq,
	_args_start:  int,
}

// Fire the installed hook for a LOCALLY executed authoritative command — the
// generated wrappers' authority branch calls this so the host's own issues
// take the same cross-entity path client commands do. No-op without a hook
// (and clients never reach it: only the authority branch calls).
command_hook_local :: proc(ctx: ^Command_Ctx, entity: Net_Id, cmd: Cmd_Id, ok: bool) {
	if ctx.hook != nil {
		ctx.hook(ctx.hook_user, ctx.me, entity, u16(cmd), ok) // the hook carries the raw wire id
	}
}

command_ctx_make :: proc(allocator := context.allocator) -> Command_Ctx {
	return Command_Ctx {
		pending = pending_table_make(allocator),
		dedup = make(map[u64]Dedup_Window, allocator),
		msg = writer_make(allocator = allocator),
	}
}

command_ctx_destroy :: proc(ctx: ^Command_Ctx) {
	pending_table_destroy(&ctx.pending)
	delete(ctx.dedup)
	writer_destroy(&ctx.msg)
}

// ---------------------------------------------------------------------------
// Client issue path (driven by the generated `<proc>_cmd` wrappers; also the
// manual escape hatch: begin → write args into ctx.msg → issue).

// Start a command message: header (entity, command index, fresh intent seq),
// then the caller writes the args. Reuses ctx.msg — one command in flight at a
// time between begin and issue.
command_begin :: proc(ctx: ^Command_Ctx, entity: Net_Id, cmd: Cmd_Id) {
	seq := ctx.pending.next_seq
	ctx.pending.next_seq += 1
	writer_reset(&ctx.msg)
	write_net_id(&ctx.msg, entity)
	write_u16(&ctx.msg, u16(cmd)) // wire bytes unchanged: the id crosses as a plain u16
	write_u32(&ctx.msg, u32(seq))
	ctx._entity = entity
	ctx._seq = seq
	ctx._args_start = len(ctx.msg.buf)
}

// Predict (iff declared) and send. The predicted run decodes the args back OUT
// of the message — client and host execute from byte-identical input, so a
// serialization mismatch can't diverge them. Returns whether the command applied
// locally right now (the optimistic answer; the host's result stays
// authoritative either way). A locally-rejected prediction is restored
// immediately but the command is STILL sent — the client's copy may be stale
// and only the host may say no.
Command_Issue_Result :: struct {
	sent:                 bool,
	prediction_attempted: bool,
	prediction_applied:   bool,
	reason:               Action_Reject_Reason,
	seq:                  Intent_Seq,
}

// The complete low-level issue result used by generated wrappers. `sent=false`
// means local policy/size admission refused the action. A locally rejected
// optimistic run is still sent because this peer may be stale; the two
// prediction fields let the wrapper preserve that distinction for presentation.
command_issue_checked :: proc(
	ctx: ^Command_Ctx,
	entity: rawptr,
	set: ^Command_Set,
	cmd: Cmd_Id,
) -> Command_Issue_Result {
	assert(
		!ctx.is_authority,
		"command_issue is the client path — the authority runs the command proc directly",
	)
	c := command_find(set, u16(cmd))
	if c == nil {
		return {reason = .Malformed, seq = ctx._seq} // no such verb on this set — a hand-written caller's bug, never a wire input
	}
	args_bytes := len(ctx.msg.buf) - ctx._args_start
	if !action_args_allowed(c.policy, args_bytes) {
		return {reason = .Malformed, seq = ctx._seq}
	}
	result := Command_Issue_Result {
		sent = true,
		seq  = ctx._seq,
	}
	predicted := false
	if action_predicts(c.policy) {
		result.prediction_attempted = true
		revert := fields_capture(entity, set.entity_desc)
		r := reader_make(ctx.msg.buf[ctx._args_start:])
		// A predicted run is ON SPEC: authority=false keeps the verb's `_then`
		// consequence quiet — it fires once, on the host, when this arrives.
		env := Command_Env {
			authority = false,
			user      = ctx.game_user,
			by        = ctx.me,
		}
		if c.invoke(entity, &r, &env) && !r.err {
			// Keep a copy of the wire args: if authoritative state lands on this
			// entity while the prediction is in flight, the registry re-runs the
			// SAME proc from these bytes on top of it (registry replay).
			args_len := len(ctx.msg.buf) - ctx._args_start
			args := make([]u8, args_len)
			copy(args, ctx.msg.buf[ctx._args_start:])
			pending_record(
				&ctx.pending,
				ctx._seq,
				ctx._entity,
				u16(cmd),
				args,
				revert,
				ctx.now_tick,
			)
			predicted = true
		} else {
			fields_restore(entity, set.entity_desc, revert)
			delete(revert)
			result.reason = .Predicate
		}
	}
	if !predicted {
		pending_record_receipt(&ctx.pending, ctx._seq, ctx._entity, u16(cmd), ctx.now_tick)
	}
	if ctx.send != nil {
		ctx.send(ctx.send_user, writer_bytes(&ctx.msg))
	}
	result.prediction_applied = predicted
	return result
}

// Compatibility escape hatch: historically this returned only whether the
// optimistic run applied. Generated code uses command_issue_checked so it can
// also distinguish a policy/size refusal from a non-predicted send.
command_issue :: proc(ctx: ^Command_Ctx, entity: rawptr, set: ^Command_Set, cmd: Cmd_Id) -> bool {
	return command_issue_checked(ctx, entity, set, cmd).prediction_applied
}

// ---------------------------------------------------------------------------
// Host receive path. The session layer frames/reads the message kind, then:
// read_header → dedup → resolve the entity (registry) → execute → result_write.

Command_Header :: struct {
	entity: Net_Id,
	cmd:    u16,
	seq:    Intent_Seq,
}

command_read_header :: proc(r: ^Reader) -> Command_Header {
	return Command_Header {
		entity = read_net_id(r),
		cmd = read_u16(r),
		seq = Intent_Seq(read_u32(r)),
	}
}

// Exactly-once gate: false = duplicate/stale (drop silently — the reliable
// channel means the original result was delivered; nothing to resend).
// peer_key is the sender's Player_Id as u64 — registry_host_command derives
// env.by (the issuer a `_then` consequence sees) from the SAME value, so any
// other key would mis-attribute every consequence. The session already keys
// this path by Player_Id; hand-driven callers must too.
command_dedup :: proc(ctx: ^Command_Ctx, peer_key: u64, seq: Intent_Seq) -> bool {
	win := ctx.dedup[peer_key] // zero value for a new peer IS the fresh window
	ok := dedup_accept(&win, seq)
	ctx.dedup[peer_key] = win
	return ok
}

// Run a received command authoritatively. Unknown command id (version skew, a
// renamed verb — the lookup misses instead of misdispatching), truncated args,
// and proc rejection all return false — and rejection can never leave torn
// state: declared fields are captured first and restored on any failure. `env`
// is this run's identity (authority + issuer + game pointer) — the thunk fires
// the verb's `_then` consequence off it when the proc applies.
command_execute_reason :: proc(
	entity: rawptr,
	set: ^Command_Set,
	cmd: u16,
	r: ^Reader,
	env: ^Command_Env,
) -> Action_Reject_Reason {
	c := command_find(set, cmd)
	if c == nil {
		return .Malformed
	}
	if !action_args_allowed(c.policy, len(reader_remaining(r))) {
		return .Malformed
	}
	revert := fields_capture(entity, set.entity_desc)
	defer delete(revert)
	ok := c.invoke(entity, r, env)
	if r.err || len(reader_remaining(r)) != 0 {
		fields_restore(entity, set.entity_desc, revert)
		return .Malformed
	}
	if !ok {
		fields_restore(entity, set.entity_desc, revert)
		return .Predicate
	}
	return .None
}

// Compatibility form for low-level callers that only need accepted/refused.
command_execute :: proc(
	entity: rawptr,
	set: ^Command_Set,
	cmd: u16,
	r: ^Reader,
	env: ^Command_Env,
) -> bool {
	return command_execute_reason(entity, set, cmd, r, env) == .None
}

// Result message: confirm = header only (the client's optimistic state already
// matches; nothing replays). Reject = header + a FULL field snapshot — the
// authoritative truth, superseding whatever the client predicted against.
// Admission refusals may deliberately omit the snapshot: the client restores
// its capture and the normal state lane corrects any newer authority change.
// This keeps rate/access replies small while still delivering their typed
// reason immediately instead of disguising them as timeouts.
command_result_write_reason :: proc(
	w: ^Writer,
	h: Command_Header,
	reason: Action_Reject_Reason,
	entity: rawptr = nil,
	set: ^Command_Set = nil,
	truth := false,
) {
	assert(action_reject_reason_valid(reason))
	write_u32(w, u32(h.seq))
	write_net_id(w, h.entity)
	write_u16(w, h.cmd)
	write_u8(w, u8(reason))
	write_bool(w, truth)
	if truth {
		assert(reason != .None && entity != nil && set != nil)
		write_full(w, entity, set.entity_desc)
	}
}

// Compatibility spelling: a false gameplay bool is a predicate rejection and
// retains the historical authoritative-truth payload.
command_result_write :: proc(
	w: ^Writer,
	h: Command_Header,
	ok: bool,
	entity: rawptr,
	set: ^Command_Set,
) {
	command_result_write_reason(w, h, ok ? .None : .Predicate, entity, set, truth = !ok)
}

// ---------------------------------------------------------------------------
// Client result path: read → resolve res.entity (caller) → confirm / reject.

Command_Result :: struct {
	seq:       Intent_Seq,
	entity:    Net_Id,
	cmd:       u16,
	ok:        bool, // compatibility mirror: reason == .None
	reason:    Action_Reject_Reason,
	has_truth: bool,
}

command_result_read :: proc(r: ^Reader) -> Command_Result {
	res := Command_Result {
		seq       = Intent_Seq(read_u32(r)),
		entity    = read_net_id(r),
		cmd       = read_u16(r),
		reason    = Action_Reject_Reason(read_u8(r)),
		has_truth = read_bool(r),
	}
	if !action_reject_reason_valid(res.reason) || (res.reason == .None && res.has_truth) {
		r.err = true
		return res
	}
	res.ok = res.reason == .None
	return res
}

// Confirmed: the prediction stands, its revert is freed, nothing replays.
// (Non-predicted commands have no pending entry; the miss is harmless.)
command_confirm :: proc(ctx: ^Command_Ctx, seq: Intent_Seq) -> bool {
	return pending_confirm(&ctx.pending, seq)
}

// Rejected: pop the pending entry and apply the embedded truth snapshot. If the
// truth is unreadable (truncated packet) fall back to the local revert — a
// rejection must never leave the optimistic state standing.
//
// `owned_here` = this peer OWNS the entity: its .Owner_Stream fields are
// exempt from both the truth and the revert — the host's copy of them is a
// lagged echo of state this peer is authoritative for, and restoring it
// yanks a moving owner backwards on every rejection.
command_reject :: proc(
	ctx: ^Command_Ctx,
	res: Command_Result,
	r: ^Reader,
	entity: rawptr,
	set: ^Command_Set,
	owned_here := false,
) {
	// .Predicted is skipped unconditionally: this proc only runs on CLIENTS,
	// where .Predicted fields belong to the sim lane's reconcile — a
	// reject-truth may only land on the delta-lane fields the command could
	// touch. .Owner joins the skip when this peer owns the entity (its streamed
	// fields are authoritative here, not in the host's lagged truth).
	skip := Subset_Skips{.Predicted}
	if owned_here {
		skip += {.Owner}
	}
	// Return to the entity's pre-prediction baseline first. A compact admission
	// rejection has no truth payload, and a newer prediction's revert captured
	// this one's writes; restoring only the rejected entry would clobber that
	// chain. The registry replays surviving entries oldest-first afterwards.
	#reverse for &pending in ctx.pending.entries {
		if pending.entity == res.entity && pending.predicted {
			fields_restore(entity, set.entity_desc, pending.revert, skip)
		}
	}
	baseline := fields_capture(entity, set.entity_desc)
	defer delete(baseline)
	p, had := pending_reject(&ctx.pending, res.seq)
	if res.has_truth {
		apply_full(r, entity, set.entity_desc, skip)
	}
	if r.err {
		fields_restore(entity, set.entity_desc, baseline, skip)
	}
	if had {
		pending_dispose(p)
	}
}
