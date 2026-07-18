package kit_net

// command — the intent→command→result runtime loop (the DX heart of the toolkit).
//
// A command is a plain proc `proc(self: ^Cls, args…) -> bool` marked
// `@(gd_command)` (host-only) or `@(gd_command="predict")` (optimistic). The
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
// Command_Outcome — what a generated `<verb>_cmd` wrapper hands back, ONE meaning
// per value on every peer, so the call site needs no `is_host` branch (distinct
// from the internal wire-level Command_Result struct below):
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
// "Did it show on my screen?" is `command_ok(r)` (== `r != .Rejected`); "is it
// authoritative?" is `r == .Applied`. Replaces the old `bool` whose truth meant
// authoritative-verdict on the host but tentative-local on a client — the one
// return in the feature that used to force a role branch to read correctly.
Command_Outcome :: enum u8 {
	Rejected,
	Predicted,
	Applied,
}

// It applied on THIS peer (authoritatively on the host, optimistically on a
// client) — the role-free "should I show local feedback?" check.
command_ok :: proc(r: Command_Outcome) -> bool {
	return r != .Rejected
}

Command_Env :: struct {
	authority: bool,      // this run is the authoritative one — consequences fire
	user:      rawptr,    // the game pointer `_then` procs receive (ctx.game_user)
	by:        Player_Id, // who issued the command (ctx.me locally; the resolved sender on the host)
}

// Decode-args-and-run thunk, generated per command by scriptgen. Contract: decode
// ALL args, check r.err, only then call the author proc — a truncated packet must
// never reach gameplay code; when the proc applies and env.authority is set, fire
// the command's `_then` consequence (generated thunks do all of this; hand-written
// ones must).
Command_Proc :: proc(entity: rawptr, r: ^Reader, env: ^Command_Env) -> bool

Command_Desc :: struct {
	name:    string, // stripped verb ("open") — diagnostics only
	// The verb's STABLE wire id — what `command_begin` ships and receivers look
	// up (never an array position: reordering procs must not renumber the wire).
	// scriptgen stamps an FNV-1a hash of the verb name and refuses same-set
	// collisions at build time; hand-built sets pick any values unique within
	// the set (a single command's zero value is fine). An id the receiver
	// doesn't know (version skew, a renamed verb) MISSES the lookup and rejects
	// cleanly instead of dispatching to whatever lives at that position.
	id:      u16,
	predict: bool,
	invoke:  Command_Proc,
}

// The id → descriptor lookup every receive/issue path routes through (sets are
// a handful of verbs — a scan beats any table). nil = unknown id: reject.
command_find :: proc(set: ^Command_Set, id: u16) -> ^Command_Desc {
	for &c in set.commands {
		if c.id == id {
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
Command_Hook :: proc(user: rawptr, player: Player_Id, entity: Net_Id, cmd: u16, ok: bool)

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
command_hook_local :: proc(ctx: ^Command_Ctx, entity: Net_Id, cmd: u16, ok: bool) {
	if ctx.hook != nil {
		ctx.hook(ctx.hook_user, ctx.me, entity, cmd, ok)
	}
}

command_ctx_make :: proc(allocator := context.allocator) -> Command_Ctx {
	return Command_Ctx {
		pending = pending_table_make(allocator),
		dedup   = make(map[u64]Dedup_Window, allocator),
		msg     = writer_make(allocator = allocator),
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
command_begin :: proc(ctx: ^Command_Ctx, entity: Net_Id, cmd: u16) {
	seq := ctx.pending.next_seq
	ctx.pending.next_seq += 1
	writer_reset(&ctx.msg)
	write_net_id(&ctx.msg, entity)
	write_u16(&ctx.msg, cmd)
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
command_issue :: proc(ctx: ^Command_Ctx, entity: rawptr, set: ^Command_Set, cmd: u16) -> bool {
	assert(!ctx.is_authority, "command_issue is the client path — the authority runs the command proc directly")
	c := command_find(set, cmd)
	if c == nil {
		return false // no such verb on this set — a hand-written caller's bug, never a wire input
	}
	predicted := false
	if c.predict {
		revert := fields_capture(entity, set.entity_desc)
		r := reader_make(ctx.msg.buf[ctx._args_start:])
		// A predicted run is ON SPEC: authority=false keeps the verb's `_then`
		// consequence quiet — it fires once, on the host, when this arrives.
		env := Command_Env{authority = false, user = ctx.game_user, by = ctx.me}
		if c.invoke(entity, &r, &env) && !r.err {
			// Keep a copy of the wire args: if authoritative state lands on this
			// entity while the prediction is in flight, the registry re-runs the
			// SAME proc from these bytes on top of it (registry replay).
			args := make([]u8, len(ctx.msg.buf) - ctx._args_start)
			copy(args, ctx.msg.buf[ctx._args_start:])
			pending_record(&ctx.pending, ctx._seq, ctx._entity, cmd, args, revert, ctx.now_tick)
			predicted = true
		} else {
			fields_restore(entity, set.entity_desc, revert)
			delete(revert)
		}
	}
	if ctx.send != nil {
		ctx.send(ctx.send_user, writer_bytes(&ctx.msg))
	}
	return predicted
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
		cmd    = read_u16(r),
		seq    = Intent_Seq(read_u32(r)),
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
command_execute :: proc(entity: rawptr, set: ^Command_Set, cmd: u16, r: ^Reader, env: ^Command_Env) -> bool {
	c := command_find(set, cmd)
	if c == nil {
		return false
	}
	revert := fields_capture(entity, set.entity_desc)
	defer delete(revert)
	if c.invoke(entity, r, env) && !r.err {
		return true
	}
	fields_restore(entity, set.entity_desc, revert)
	return false
}

// Result message: confirm = header only (the client's optimistic state already
// matches; nothing replays). Reject = header + a FULL field snapshot — the
// authoritative truth, superseding whatever the client predicted against.
command_result_write :: proc(w: ^Writer, h: Command_Header, ok: bool, entity: rawptr, set: ^Command_Set) {
	write_u32(w, u32(h.seq))
	write_net_id(w, h.entity)
	write_bool(w, ok)
	if !ok {
		write_full(w, entity, set.entity_desc)
	}
}

// ---------------------------------------------------------------------------
// Client result path: read → resolve res.entity (caller) → confirm / reject.

Command_Result :: struct {
	seq:    Intent_Seq,
	entity: Net_Id,
	ok:     bool,
}

command_result_read :: proc(r: ^Reader) -> Command_Result {
	return Command_Result {
		seq    = Intent_Seq(read_u32(r)),
		entity = read_net_id(r),
		ok     = read_bool(r),
	}
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
command_reject :: proc(ctx: ^Command_Ctx, res: Command_Result, r: ^Reader, entity: rawptr, set: ^Command_Set, owned_here := false) {
	// skip_predicted unconditionally: this proc only runs on CLIENTS, where
	// .Predicted fields belong to the sim lane's reconcile — a reject-truth
	// may only land on the delta-lane fields the command could touch.
	p, had := pending_reject(&ctx.pending, res.seq)
	apply_full(r, entity, set.entity_desc, skip_owner = owned_here, skip_predicted = true)
	if r.err && had {
		fields_restore(entity, set.entity_desc, p.revert, skip_owner = owned_here, skip_predicted = true)
	}
	if had {
		pending_dispose(p)
	}
}
