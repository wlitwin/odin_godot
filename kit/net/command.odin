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

// Decode-args-and-run thunk, generated per command by scriptgen. Contract: decode
// ALL args, check r.err, only then call the author proc — a truncated packet must
// never reach gameplay code (generated thunks do this; hand-written ones must).
Command_Proc :: proc(entity: rawptr, r: ^Reader) -> bool

Command_Desc :: struct {
	name:    string, // stripped verb ("open") — diagnostics only
	predict: bool,
	invoke:  Command_Proc,
}

// Per entity TYPE: the command table + the replicated-field descriptor that
// powers prediction reverts, torn-state restore, and reject-truth snapshots.
Command_Set :: struct {
	entity_desc: ^Entity_Desc,
	commands:    []Command_Desc,
}

// Complete outgoing message bytes → whoever owns the transport. The session
// layer prepends its own framing (message-kind byte) and sends reliable.
Send_Proc :: proc(user: rawptr, bytes: []u8)

// One per session participant. Clients use pending/msg/send; the host uses
// dedup. now_tick is stamped onto pending entries — the owner advances it with
// the net ticker so pending_expire(&ctx.pending, …) can time out lost results.
Command_Ctx :: struct {
	is_authority: bool,
	now_tick:     u64,
	send:         Send_Proc,
	send_user:    rawptr,
	pending:      Pending_Table, // client: in-flight predictions
	dedup:        map[u64]Dedup_Window, // host: per-peer exactly-once windows
	msg:          Writer, // outgoing command message scratch (reused per issue)

	// in-flight between command_begin and command_issue (generated code only)
	_entity:      Net_Id,
	_seq:         Intent_Seq,
	_args_start:  int,
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
	c := &set.commands[cmd]
	predicted := false
	if c.predict {
		revert := fields_capture(entity, set.entity_desc)
		r := reader_make(ctx.msg.buf[ctx._args_start:])
		if c.invoke(entity, &r) && !r.err {
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
// peer_key is any stable per-sender key (transport peer id now, Player_Id once
// the session layer owns identity).
command_dedup :: proc(ctx: ^Command_Ctx, peer_key: u64, seq: Intent_Seq) -> bool {
	win := ctx.dedup[peer_key] // zero value for a new peer IS the fresh window
	ok := dedup_accept(&win, seq)
	ctx.dedup[peer_key] = win
	return ok
}

// Run a received command authoritatively. Unknown command index, truncated
// args, and proc rejection all return false — and rejection can never leave
// torn state: declared fields are captured first and restored on any failure.
command_execute :: proc(entity: rawptr, set: ^Command_Set, cmd: u16, r: ^Reader) -> bool {
	if int(cmd) >= len(set.commands) {
		return false
	}
	revert := fields_capture(entity, set.entity_desc)
	defer delete(revert)
	if set.commands[cmd].invoke(entity, r) && !r.err {
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
command_reject :: proc(ctx: ^Command_Ctx, res: Command_Result, r: ^Reader, entity: rawptr, set: ^Command_Set) {
	p, had := pending_reject(&ctx.pending, res.seq)
	apply_full(r, entity, set.entity_desc)
	if r.err && had {
		fields_restore(entity, set.entity_desc, p.revert)
	}
	if had {
		pending_dispose(p)
	}
}
